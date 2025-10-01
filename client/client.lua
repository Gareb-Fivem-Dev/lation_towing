-- Targeting: ox_target only
local ox_target = exports.ox_target
local towJobStartLocation = lib.points.new(Config.StartJobLocation, Config.StartJobRadius)
local targetVehicle, currentlyTowedVehicle, towVehicle, inService, spawnedVehicle, spawnedVehiclePlate
local jobAssigned, enabledCalls, car, location, targetCarBlip, dropOffBlip
local missionDeliver -- { x,y,z,index }
local missionIsUrgent, missionUrgentId = false, nil

-- Debug helper
local function cdbg(fmt, ...)
    if not Config.ClientDebug then return end
    local ok, msg = pcall(string.format, fmt, ...)
    print(('[lation_towing][client] %s'):format(ok and msg or tostring(fmt)))
end

-- Localization loader: pick by Config.Locale; locales/*.lua should set a global Locale
do
    local lang = (Config.Locale or 'en'):lower()
    -- Locale files are loaded via fxmanifest shared_scripts; select the right one here
    -- If multiple Locale tables are loaded, prefer the one matching Config.Locale
    -- We support pattern Locale_en / Locale_de to avoid collisions; otherwise fallback to Locale
    local selected
    if _G['Locale_' .. lang] then
        selected = _G['Locale_' .. lang]
    elseif type(Locale) == 'table' then
        selected = Locale
    end
    if type(selected) == 'table' then
        Notifications = selected.Notifications or Notifications
        Target = selected.Target or Target
        ContextMenu = selected.ContextMenu or ContextMenu
        ProgressCircle = selected.ProgressCircle or ProgressCircle
        AlertDialog = selected.AlertDialog or AlertDialog
        OfficerUI = selected.OfficerUI or OfficerUI
    end
end

-- Officer helper: provide current map waypoint as drop-off to server when calling /towcall
lib.callback.register('lation_towing:getOfficerDropoff', function()
    local blip = GetFirstBlipInfoId(8) -- BLIP_WAYPOINT
    if not DoesBlipExist(blip) then
        return nil
    end
    local wx, wy, wz = table.unpack(GetBlipCoords(blip))
    local found, gz = GetGroundZFor_3dCoord(wx + 0.0, wy + 0.0, wz ~= 0.0 and wz or 1000.0, false)
    local waypoint = { x = wx, y = wy, z = found and gz or (wz ~= 0.0 and wz or 0.0) }

    -- Build options: waypoint, nearest depot, nearest road node
    local opts = {}
    local function dist2(ax, ay, bx, by) local dx, dy = ax - bx, ay - by return dx*dx + dy*dy end

    -- Nearest depot from Config.DeliverLocations (if any)
    local nearestDepot
    local nearestDepotIdx
    if type(Config.DeliverLocations) == 'table' and #Config.DeliverLocations > 0 then
        local best, bestIdx
        for i = 1, #Config.DeliverLocations do
            local v = Config.DeliverLocations[i]
            local d2 = dist2(wx, wy, v.x, v.y)
            if not best or d2 < best then
                best, bestIdx = d2, i
            end
        end
        if bestIdx then
            local v = Config.DeliverLocations[bestIdx]
            nearestDepot = { x = v.x, y = v.y, z = v.z }
            nearestDepotIdx = bestIdx
        end
    end

    -- Snap to nearest road node
    local nodeOk, nx, ny, nz = GetClosestVehicleNode(wx + 0.0, wy + 0.0, waypoint.z + 1.0, 1, 3.0, 0)
    local nearestRoad = nodeOk and { x = nx, y = ny, z = nz } or nil

    -- Build lib context to confirm
    local selection
    lib.registerContext({
        id = 'tow_officer_dropoff_select',
        title = (OfficerUI and OfficerUI.title) or 'Urgent Tow Drop-off',
        options = (function()
            local t = {}
            table.insert(t, {
                title = (OfficerUI and OfficerUI.useWaypoint) or 'Use waypoint location',
                description = ('X: %.1f, Y: %.1f'):format(waypoint.x, waypoint.y),
                icon = 'location-dot',
                onSelect = function() selection = waypoint end
            })
            if nearestDepot then
                table.insert(t, {
                    title = (OfficerUI and OfficerUI.snapDepot) or 'Snap to nearest depot',
                    description = (nearestDepotIdx and Config.DeliverLabels and Config.DeliverLabels[nearestDepotIdx]) and ('Depot: ' .. Config.DeliverLabels[nearestDepotIdx]) or ('X: %.1f, Y: %.1f'):format(nearestDepot.x, nearestDepot.y),
                    icon = 'warehouse',
                    onSelect = function()
                        nearestDepot.index = nearestDepotIdx
                        selection = nearestDepot
                    end
                })
            end
            if nearestRoad then
                table.insert(t, {
                    title = (OfficerUI and OfficerUI.snapRoad) or 'Snap to nearest road',
                    description = ('X: %.1f, Y: %.1f'):format(nearestRoad.x, nearestRoad.y),
                    icon = 'road',
                    onSelect = function() selection = nearestRoad end
                })
            end
            return t
        end)()
    })
    lib.showContext('tow_officer_dropoff_select')

    -- Wait briefly for a selection (context callbacks execute sync on same thread)
    local start = GetGameTimer()
    while not selection and GetGameTimer() - start < 2000 do
        Wait(50)
    end

    return selection or waypoint
end)

-- Plate generator: 'TOW' + 6 random alphanumeric characters
local function generateTowPlate()
    local charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local suffix = {}
    for i = 1, 5 do
        local idx = math.random(1, #charset)
        suffix[i] = string.sub(charset, idx, idx)
    end
    return 'TOW' .. table.concat(suffix)
end

-- Group job assigned interactive UI
RegisterNetEvent('lation_towing:client:groupJobAssigned', function(coords, locIndex)
    local streetHash, crossHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(streetHash)
    if crossHash and crossHash ~= 0 then
        local cross = GetStreetNameFromHashKey(crossHash)
        if cross and cross ~= '' then
            streetName = ('%s / %s'):format(streetName, cross)
        end
    end
    cdbg('groupJobAssigned: coords=%.2f,%.2f,%.2f index=%s street=%s', coords.x, coords.y, coords.z, tostring(locIndex), streetName)

    -- Also show a quick notify with index and street
    lib.notify({
        title = Notifications.title,
        description = ('New towing job: Location #%s on %s'):format(locIndex or '?', streetName or 'Unknown'),
        type = 'success',
        icon = Notifications.icon,
        position = Notifications.position,
        duration = 6000
    })

    lib.registerContext({
        id = 'lation_towing_group_job',
        title = Notifications.title,
        options = {
            {
                title = ('New towing job (Location #%s)'):format(locIndex or '?'),
                description = ('Street: %s'):format(streetName or 'Unknown'),
                icon = 'map-marker-alt'
            },
            {
                title = 'Set Waypoint',
                description = 'Set GPS to pickup location',
                icon = 'location-dot',
                onSelect = function()
                    SetNewWaypoint(coords.x, coords.y)
                end
            }
        }
    })

    lib.showContext('lation_towing_group_job')
end)

-- Urgent mission from LEO: set waypoint/blip and mark urgent state
RegisterNetEvent('lation_towing:client:startUrgentMission', function(data)
    -- data: { coords=vector3, vehicleNetId, plate, urgentId, createdAt, timeLimit }
    missionIsUrgent = true
    missionUrgentId = data.urgentId
    missionVehicleNetId = data.vehicleNetId
    missionVehPlate = data.plate
    vehicleIssues = {} -- no issues for urgent by default
    missionDeliver = data.deliver or missionDeliver

    local coords = data.coords
    SetNewWaypoint(coords.x, coords.y)
    if targetCarBlip and DoesBlipExist(targetCarBlip) then RemoveBlip(targetCarBlip) end
    targetCarBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(targetCarBlip, Config.Blips.pickupVehicle.blipSprite)
    SetBlipDisplay(targetCarBlip, 4)
    SetBlipColour(targetCarBlip, Config.Blips.pickupVehicle.blipColor)
    SetBlipScale(targetCarBlip, Config.Blips.pickupVehicle.blipScale)
    SetBlipAsShortRange(targetCarBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(('Urgent Tow #%s'):format(tostring(missionUrgentId)))
    EndTextCommandSetBlipName(targetCarBlip)

    -- Group blip if enabled
    if isSlrnGroupsEnabled() then
        createGroupBlip(coords, Config.Blips.pickupVehicle, 'towing_pickup')
    end

    jobAssigned = true
    lib.notify({
        title = Notifications.title,
        description = ('URGENT: Blocking lane tow assigned (ID #%s). Clear it fast for higher pay.'):format(tostring(missionUrgentId)),
        type = 'warning',
        icon = Notifications.icon,
        position = Notifications.position
    })
end)

-- Function to check if slrn_groups is available and enabled
local function isSlrnGroupsEnabled()
    return Config.UseSlrnGroups and GetResourceState('slrn_groups') == 'started'
end

-- Function to create group blip for towing job locations
local function createGroupBlip(coords, blipData, name)
    if not isSlrnGroupsEnabled() then return end
    
    -- Get player's group ID
    local groupId = exports.slrn_groups:GetGroupByMembers(GetPlayerServerId(PlayerId()))
    if groupId then
        local blipInfo = {
            coords = coords,
            sprite = blipData.blipSprite,
            color = blipData.blipColor,
            scale = blipData.blipScale,
            name = blipData.blipName
        }
        exports.slrn_groups:CreateBlipForGroup(groupId, name, blipInfo)
    end
end

-- Function to remove group blip
local function removeGroupBlip(name)
    if not isSlrnGroupsEnabled() then return end
    
    local groupId = exports.slrn_groups:GetGroupByMembers(GetPlayerServerId(PlayerId()))
    if groupId then
        exports.slrn_groups:RemoveBlipForGroup(groupId, name)
    end
end

-- Vehicle repair functions
local missionVehicleNetId = nil
local vehicleIssues = {}

-- Roadwork signs state
local activeSigns = {}

local function kphToMps(kph) return (kph or 0) / 3.6 end
local function mphToMps(mph) return (mph or 0) * 0.44704 end
local function getConfiguredMps()
    if (Config.RoadSignSpeedUnits or 'kph') == 'mph' then
        return mphToMps(Config.RoadSignSpeedValue or 0)
    else
        return kphToMps(Config.RoadSignSpeedValue or 0)
    end
end

local function createVehicleSlowZone(center, radius, mps)
    -- Use scenario/traffic density and road node flags to influence AI speed locally
    -- As a lightweight approach, periodically apply SetDriveTaskMaxCruiseSpeed to nearby vehicles
    local zone = {
        center = center,
        radius = radius,
        mps = mps,
        running = true
    }
    CreateThread(function()
        while zone.running do
            local vehicles = GetGamePool('CVehicle')
            for i = 1, #vehicles do
                local veh = vehicles[i]
                if DoesEntityExist(veh) then
                    local pos = GetEntityCoords(veh)
                    if #(pos - center) <= radius then
                        -- Apply a capped cruise speed to AI drivers (won't affect players)
                        local ped = GetPedInVehicleSeat(veh, -1)
                        if ped ~= 0 and not IsPedAPlayer(ped) then
                            SetDriveTaskMaxCruiseSpeed(ped, zone.mps)
                        end
                    end
                end
            end
            Wait(1500)
        end
    end)
    return zone
end

local function placeRoadSign()
    if not Config.EnableRoadworkSigns then return end
    if #activeSigns >= (Config.RoadSignMaxActive or 2) then
        return lib.notify({ title = Notifications.title, description = 'Maximum active signs reached.', type = 'error', icon = Notifications.icon, position = Notifications.position })
    end
    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local spawn = coords + (forward * 1.2)
    local model = Config.RoadSignModel or 'prop_consign_01b'
    lib.requestModel(model)
    local obj = CreateObject(GetHashKey(model), spawn.x, spawn.y, spawn.z - 1.0, true, true, false)
    SetEntityHeading(obj, GetEntityHeading(ped))
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)

    -- Slow zone
    local mps = getConfiguredMps()
    local zone = createVehicleSlowZone(spawn, Config.RoadSignSlowRadius or 25.0, mps)

    -- Target to pick up
    exports.ox_target:addLocalEntity(obj, {
        {
            name = 'pickup_sign',
            icon = 'fas fa-traffic-cone',
            label = 'Pick up sign',
            onSelect = function()
                -- Remove
                exports.ox_target:removeLocalEntity(obj)
                if DoesEntityExist(obj) then DeleteObject(obj) end
                zone.running = false
                -- Remove from active list
                for i, s in ipairs(activeSigns) do
                    if s.obj == obj then table.remove(activeSigns, i) break end
                end
                lib.notify({ title = Notifications.title, description = 'Sign removed.', type = 'success', icon = Notifications.icon, position = Notifications.position })
            end,
            distance = 2.0
        }
    })

    -- Auto-despawn timer
    local expiresAt = GetGameTimer() + ((Config.RoadSignDuration or 300) * 1000)
    local entry = { obj = obj, zone = zone, expiresAt = expiresAt }
    table.insert(activeSigns, entry)
    lib.notify({ title = Notifications.title, description = 'Sign placed.', type = 'success', icon = Notifications.icon, position = Notifications.position })

    CreateThread(function()
        while true do
            if not DoesEntityExist(obj) then break end
            if GetGameTimer() >= expiresAt then
                exports.ox_target:removeLocalEntity(obj)
                DeleteObject(obj)
                zone.running = false
                break
            end
            Wait(1000)
        end
        -- Cleanup entry
        for i, s in ipairs(activeSigns) do
            if s.obj == obj then table.remove(activeSigns, i) break end
        end
    end)
end

-- Add a context menu option to place a roadwork sign while in service
local function registerRoadSignMenu()
    if not Config.EnableRoadworkSigns then return end
    lib.registerContext({
        id = 'tow_extras_menu',
        title = 'Tow Extras',
        options = {
            {
                title = 'Place Roadwork Sign',
                description = 'Place a temporary sign and slow traffic nearby',
                icon = 'triangle-exclamation',
                onSelect = function()
                    placeRoadSign()
                end
            }
        }
    })
end

-- Function to inspect vehicle for issues
function inspectVehicle()
    if not missionVehicleNetId then return end
    cdbg('inspectVehicle: netId=%s', tostring(missionVehicleNetId))
    
    if lib.progressCircle({
        label = ProgressCircle.inspectVehicleLabel,
        duration = ProgressCircle.inspectVehicleDuration,
        position = ProgressCircle.position,
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'amb@prop_human_parking_meter@female@idle_a',
            clip = 'idle_a'
        },
    }) then
    local issues = lib.callback.await('lation_towtruck:inspectVehicle', false, missionVehicleNetId)
    cdbg('inspectVehicle: got %d issues', issues and (function(t) local n=0 for _ in pairs(t) do n=n+1 end return n end)(issues) or 0)
        vehicleIssues = issues
        
        if next(issues) then
            local issueList = {}
            for issueType, issue in pairs(issues) do
                local status = issue.fixed and "✓ FIXED" or "✗ NEEDS REPAIR"
                local dep = (issue.dependsOn == 'electrical_issues' and issueType == 'engine_damage') and ' (requires Electrical first)' or ''
                table.insert(issueList, string.format("• %s%s - %s", issue.description, dep, status))
            end
            
            lib.notify({
                title = Notifications.title,
                description = "Vehicle Issues Found:\n" .. table.concat(issueList, "\n"),
                type = 'warning',
                icon = Notifications.icon,
                position = Notifications.position,
                duration = 8000
            })
        else
            lib.notify({
                title = Notifications.title,
                description = "No issues found with this vehicle.",
                type = 'success',
                icon = Notifications.icon,
                position = Notifications.position
            })
        end
    end
end

-- Function to repair specific vehicle issue
function repairVehicleIssue(issueType)
    if not missionVehicleNetId or not vehicleIssues[issueType] then return end
    cdbg('repairVehicleIssue: netId=%s issue=%s start', tostring(missionVehicleNetId), tostring(issueType))
    
    local issue = vehicleIssues[issueType]
    if issue.fixed then
        lib.notify({
            title = Notifications.title,
            description = "This issue has already been fixed.",
            type = 'info',
            icon = Notifications.icon,
            position = Notifications.position
        })
        return
    end
    
    -- Optional skill check before/after the progress bar
    local failedSkill = false
    if Config.SkillCheck and Config.SkillCheck.enabled and Config.SkillCheck.issues[issueType] then
        failedSkill = not lib.skillCheck(Config.SkillCheck.issues[issueType])
        if failedSkill and Config.SkillCheck.failPenaltySeconds and Config.SkillCheck.failPenaltySeconds > 0 then
            issue.fixTime = issue.fixTime + (Config.SkillCheck.failPenaltySeconds * 1000)
        end
    end

    if lib.progressCircle({
        label = getRepairLabel(issueType),
        duration = issue.fixTime,
        position = ProgressCircle.position,
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'amb@world_human_hammering@male@base',
            clip = 'base'
        },
    }) then
    local success, result = lib.callback.await('lation_towtruck:repairVehicleIssue', false, missionVehicleNetId, issueType, failedSkill)
    cdbg('repairVehicleIssue: netId=%s issue=%s result success=%s code=%s', tostring(missionVehicleNetId), tostring(issueType), tostring(success), tostring(result))
        
        if success then
            vehicleIssues[issueType].fixed = true
            lib.notify({
                title = Notifications.title,
                description = Notifications.vehicleRepaired,
                type = 'success',
                icon = Notifications.icon,
                position = Notifications.position
            })
            
            -- Check if all issues are fixed
            local allFixed = true
            for _, issue in pairs(vehicleIssues) do
                if not issue.fixed then
                    allFixed = false
                    break
                end
            end
            
            if allFixed then
                lib.notify({
                    title = Notifications.title,
                    description = Notifications.vehicleReadyForDelivery,
                    type = 'success',
                    icon = Notifications.icon,
                    position = Notifications.position
                })
            end
        elseif result == 'missing_items' then
            lib.notify({
                title = Notifications.title,
                description = Notifications.missingRepairItems,
                type = 'error',
                icon = Notifications.icon,
                position = Notifications.position
            })
        elseif result == 'cooldown' then
            lib.notify({
                title = Notifications.title,
                description = Notifications.repairOnCooldown,
                type = 'error',
                icon = Notifications.icon,
                position = Notifications.position
            })
        elseif result == 'dependency' then
            lib.notify({
                title = Notifications.title,
                description = Notifications.dependencyRequired or 'You must repair the Electrical issue before fixing the Engine.',
                type = 'error',
                icon = Notifications.icon,
                position = Notifications.position
            })
        end
    else
        lib.notify({
            title = Notifications.title,
            description = Notifications.repairCancelled,
            type = 'error',
            icon = Notifications.icon,
            position = Notifications.position
        })
    end
end

-- Helper function to get repair progress label
function getRepairLabel(issueType)
    if issueType == 'flat_tires' then
        return ProgressCircle.repairTiresLabel
    elseif issueType == 'engine_damage' then
        return ProgressCircle.repairEngineLabel
    elseif issueType == 'body_damage' then
        return ProgressCircle.repairBodyLabel
    elseif issueType == 'fuel_empty' then
        return ProgressCircle.refuelVehicleLabel
    elseif issueType == 'electrical_issues' then
        return ProgressCircle.repairElectricalLabel
    else
        return 'Repairing vehicle..'
    end
end

-- Function to add repair target options to mission vehicle
function addVehicleRepairTargets(vehicle)
    if not DoesEntityExist(vehicle) then return end
    cdbg('addVehicleRepairTargets: veh=%s', tostring(vehicle))
    
    local targetOptions = {
        {
            icon = Target.inspectVehicleIcon,
            label = Target.inspectVehicle,
            onSelect = function()
                inspectVehicle()
            end,
        }
    }
    
    -- Add repair options based on vehicle issues
    if vehicleIssues['flat_tires'] and not vehicleIssues['flat_tires'].fixed then
        table.insert(targetOptions, {
            icon = Target.repairTiresIcon,
            label = Target.repairTires,
            onSelect = function()
                repairVehicleIssue('flat_tires')
            end,
        })
    end
    
    if vehicleIssues['engine_damage'] and not vehicleIssues['engine_damage'].fixed then
        table.insert(targetOptions, {
            icon = Target.repairEngineIcon,
            label = Target.repairEngine,
            onSelect = function()
                repairVehicleIssue('engine_damage')
            end,
        })
    end
    
    if vehicleIssues['body_damage'] and not vehicleIssues['body_damage'].fixed then
        table.insert(targetOptions, {
            icon = Target.repairBodyIcon,
            label = Target.repairBody,
            onSelect = function()
                repairVehicleIssue('body_damage')
            end,
        })
    end
    
    if vehicleIssues['fuel_empty'] and not vehicleIssues['fuel_empty'].fixed then
        table.insert(targetOptions, {
            icon = Target.refuelVehicleIcon,
            label = Target.refuelVehicle,
            onSelect = function()
                repairVehicleIssue('fuel_empty')
            end,
        })
    end
    
    if vehicleIssues['electrical_issues'] and not vehicleIssues['electrical_issues'].fixed then
        table.insert(targetOptions, {
            icon = Target.repairElectricalIcon,
            label = Target.repairElectrical,
            onSelect = function()
                repairVehicleIssue('electrical_issues')
            end,
        })
    end
    
    -- Ensure each option has a distance for ox_target
    for _, opt in ipairs(targetOptions) do
        opt.distance = opt.distance or Target.distance
    end
    exports.ox_target:addLocalEntity(vehicle, targetOptions)
end

-- Function to remove vehicle repair targets
function removeVehicleRepairTargets(vehicle)
    if DoesEntityExist(vehicle) then
        exports.ox_target:removeLocalEntity(vehicle)
    end
end

local blip = AddBlipForCoord(Config.StartJobLocation.x, Config.StartJobLocation.y, Config.StartJobLocation.z)
SetBlipSprite(blip, Config.Blips.startJob.blipSprite)
SetBlipDisplay(blip, 4)
SetBlipColour(blip, Config.Blips.startJob.blipColor)
SetBlipScale(blip, Config.Blips.startJob.blipScale)
SetBlipAsShortRange(blip, true)
BeginTextCommandSetBlipName("STRING")
AddTextComponentString(Config.Blips.startJob.blipName)
EndTextCommandSetBlipName(blip)

-- Function that spawns the tow truck at the job start location
function spawnTowTruck()
    local nearbyVehicles = lib.getClosestVehicle(Config.SpawnTruckLocation, 3, false)
    if nearbyVehicles == nil then
    lib.requestModel(Config.TowTruckModel)
    local towModelHash = GetHashKey(Config.TowTruckModel)
    vehicle = CreateVehicle(towModelHash, Config.SpawnTruckLocation.x, Config.SpawnTruckLocation.y, Config.SpawnTruckLocation.z, Config.SpawnTruckHeading, true, true)
        Entity(vehicle).state.fuel = 100.0
        local truckPlate = generateTowPlate()
        SetVehicleNumberPlateText(vehicle, truckPlate)
        spawnedVehiclePlate = truckPlate
        exports.wasabi_carlock:GiveKey(truckPlate)
        spawnedVehicle = vehicle
        inService = true
    else
        lib.notify({
            title = Notifications.title,
            description = Notifications.towTruckSpawnOccupied,
            icon = Notifications.icon,
            type = 'error',
            position = Notifications.position
        })
    end
end

-- Prompt asking if players want to continue doing jobs
function startNextJob()
    local confirmNext = lib.alertDialog({
        header = AlertDialog.header,
        content = AlertDialog.content,
        centered = true,
        cancel = true,
        labels = {
            cancel = 'End Job',
            confirm = 'Continue'
        }
    })
    if confirmNext == 'confirm' then
        return lib.notify({ title = Notifications.title, description = Notifications.confirmNextJob, icon = Notifications.icon, type = 'success', position = Notifications.position })
    else
        endJob()
    end
end

-- Function that selects a random car & spawn location from the Config
function selectCarAndLocation()
    local randomLoc = math.random(1, #Config.Locations)
    local selectLoc = Config.Locations[randomLoc]
    local randomCar = math.random(1, #Config.CarModels)
    local selectCar = Config.CarModels[randomCar]
    return selectCar, selectLoc
end

-- Function that spawns the vehicle and sets the waypoint when job is selected (now server-side)
function setWaypoint()
    lib.notify({
        title = Notifications.title,
        description = Notifications.searchingForJob,
        icon = Notifications.icon,
        type = 'warning',
        position = Notifications.position
    })
    
    local missionData = lib.callback.await('lation_towtruck:spawnMissionVehicle', false)
    cdbg('setWaypoint: spawnMissionVehicle returned=%s', missionData and 'ok' or 'nil')
    
    if missionData then
        car = missionData.vehicle
        location = missionData.location
        missionVehPlate = missionData.plate
        missionVehicleNetId = missionData.vehicleNetId
        vehicleIssues = missionData.issues or {}
        missionDeliver = missionData.deliver or nil
        
    -- Set waypoint & create blip
    cdbg('setWaypoint: mission plate=%s netId=%s at %.2f,%.2f,%.2f', tostring(missionVehPlate), tostring(missionVehicleNetId), location.x, location.y, location.z)
        SetNewWaypoint(location.x, location.y)
        targetCarBlip = AddBlipForCoord(location.x, location.y, location.z)
        SetBlipSprite(targetCarBlip, Config.Blips.pickupVehicle.blipSprite)
        SetBlipDisplay(targetCarBlip, 4)
        SetBlipColour(targetCarBlip, Config.Blips.pickupVehicle.blipColor)
        SetBlipScale(targetCarBlip, Config.Blips.pickupVehicle.blipScale)
        SetBlipAsShortRange(targetCarBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.Blips.pickupVehicle.blipName)
        EndTextCommandSetBlipName(targetCarBlip)
        
        -- Create group blip if slrn_groups is enabled
        if isSlrnGroupsEnabled() then
            createGroupBlip(vector3(location.x, location.y, location.z), Config.Blips.pickupVehicle, 'towing_pickup')
            cdbg('setWaypoint: created group pickup blip')
        end
        
        -- Add target options for vehicle inspection and repair
        if Config.EnableVehicleIssues then
            addVehicleRepairTargets(car)
            cdbg('setWaypoint: added repair targets to car=%s', tostring(car))
            
            -- Notify player if vehicle has issues
            if next(vehicleIssues) then
                lib.notify({
                    title = Notifications.title,
                    description = Notifications.vehicleHasIssues,
                    type = 'warning',
                    icon = Notifications.icon,
                    position = Notifications.position
                })
            end
        end
        
    jobAssigned = true
    cdbg('setWaypoint: job assigned')
        lib.notify({
            title = Notifications.title,
            description = Notifications.jobAssigned,
            icon = Notifications.icon,
            type = 'success',
            position = Notifications.position
        })
    else
        lib.notify({
            title = Notifications.title,
            description = 'All locations are currently occupied. Please wait for other jobs to complete.',
            icon = Notifications.icon,
            type = 'warning',
            position = Notifications.position
        })
        -- Try again after a short delay if no locations available
        Wait(5000)
    end
end

-- Function to call when leaving the Towing job and to delete spawned vehicles
function endJob()
    cdbg('endJob: cleaning up')
    DeleteEntity(spawnedVehicle)
    RemoveBlip(targetCarBlip)
    RemoveBlip(dropOffBlip)
    -- Remove any active road signs
    if activeSigns and #activeSigns > 0 then
        for i = #activeSigns, 1, -1 do
            local s = activeSigns[i]
            if s then
                if s.zone then s.zone.running = false end
                if s.obj and DoesEntityExist(s.obj) then
                    exports.ox_target:removeLocalEntity(s.obj)
                    DeleteObject(s.obj)
                end
                table.remove(activeSigns, i)
            end
        end
    end
    
    -- Remove group blips if enabled
    if isSlrnGroupsEnabled() then
        removeGroupBlip('towing_pickup')
        removeGroupBlip('towing_dropoff')
        cdbg('endJob: removed group blips')
    end
    
    -- Remove vehicle repair targets
    if car and Config.EnableVehicleIssues then
        removeVehicleRepairTargets(car)
        cdbg('endJob: removed repair targets from car')
    end
    
    lib.callback.await('lation_towtruck:cleanupMissionVehicle', false)
    if Config.EnableCarKeys then
        -- Example: exports.wasabi_carlock:RemoveKeys(spawnedVehiclePlate, false)
        -- Insert remove car keys export here
    end
    
    -- Reset vehicle repair variables
    missionVehicleNetId = nil
    vehicleIssues = {}
    missionIsUrgent = false
    missionUrgentId = nil
    
    inService = false
    enabledCalls = false
    jobAssigned = false
end

-- Thread that runs and randomly assigns job while player is inService
CreateThread(function()
    while true do
        Wait(2000)
        if enabledCalls then -- checks if "clocked in"
            if inService and not jobAssigned then -- if spawned truck, "clocked in" and no job assigned then assign job
                local jobCall = math.random(Config.MinWaitTime * 60000, Config.MaxWaitTime * 60000)
                Wait(jobCall)
                setWaypoint()
            elseif inService and jobAssigned then -- if spawned truck, "clocked in" and has job then wait
                Wait(10000)
            end
        else -- if not meeting above parameters, just wait
            Wait(10000)
        end
    end
end)

-- Function that attaches the target vehicle to the tow truck
function attachVehicle()
    towVehicle = GetVehiclePedIsIn(cache.ped, true)
    local towTruckModel = GetHashKey(Config.TowTruckModel)
    local isVehicleTowTruck = IsVehicleModel(towVehicle, towTruckModel)
    local ped = GetEntityCoords(cache.ped)
    if isVehicleTowTruck then
        targetVehicle = lib.getClosestVehicle(ped, 5, false)
        targetVehiclePlate = GetVehicleNumberPlateText(targetVehicle)
        if currentlyTowedVehicle == nil then
            if targetVehicle ~= 0 then
                if not IsPedInAnyVehicle(cache.ped, true) then
                    if towVehicle ~= targetVehicle then
                        if lib.progressCircle({
                            label = ProgressCircle.loadVehicleLabel,
                            duration = ProgressCircle.loadVehicleDuration,
                            position = ProgressCircle.position,
                            useWhileDead = false,
                            canCancel = true,
                            disable = {
                                car = true,
                                move = true,
                                combat = true
                            },
                            anim = {
                                dict = 'anim@apt_trans@buzzer', -- or random@mugging4
                                clip = 'buzz_reg' -- or struggle_loop_b_thief
                            },
                        }) then
                            AttachEntityToEntity(targetVehicle, towVehicle, 20, -0.5, -5.0, 1.0, 0.0, 0.0, 0.0, false, false, false, false, 20, true)
                            cdbg('attachVehicle: attached target=%s to tow=%s plate=%s missionPlate=%s', tostring(targetVehicle), tostring(towVehicle), tostring(targetVehiclePlate), tostring(missionVehPlate))
                            currentlyTowedVehicle = targetVehicle
                            if targetVehiclePlate == missionVehPlate then
                                if missionVehicleNetId then
                                    TriggerServerEvent('lation_towtruck:server:markAttached', missionVehicleNetId)
                                    cdbg('attachVehicle: marked mission netId=%s as attached on server', tostring(missionVehicleNetId))
                                end
                                RemoveBlip(targetCarBlip)
                                -- Remove group pickup blip if enabled
                                if isSlrnGroupsEnabled() then
                                    removeGroupBlip('towing_pickup')
                                    cdbg('attachVehicle: removed group pickup blip')
                                end
                                
                                SetVehicleDoorShut(targetVehicle, 4, true)
                                local dest = (missionDeliver and missionDeliver.x) and missionDeliver or { x = Config.DeliverLocation.x, y = Config.DeliverLocation.y, z = Config.DeliverLocation.z }
                                SetNewWaypoint(dest.x, dest.y)
                                dropOffBlip = AddBlipForCoord(dest.x, dest.y, dest.z)
                                SetBlipSprite(dropOffBlip, Config.Blips.dropOff.blipSprite)
                                SetBlipDisplay(dropOffBlip, 4)
                                SetBlipColour(dropOffBlip, Config.Blips.dropOff.blipColor)
                                SetBlipScale(dropOffBlip, Config.Blips.dropOff.blipScale)
                                SetBlipAsShortRange(dropOffBlip, true)
                                BeginTextCommandSetBlipName("STRING")
                                local blipName = Config.Blips.dropOff.blipName
                                if missionDeliver and missionDeliver.index and Config.DeliverLabels and Config.DeliverLabels[missionDeliver.index] then
                                    blipName = Config.DeliverLabels[missionDeliver.index]
                                end
                                AddTextComponentString(blipName)
                                EndTextCommandSetBlipName(dropOffBlip)
                                
                                -- Create group drop-off blip if enabled
                                if isSlrnGroupsEnabled() then
                                    createGroupBlip(Config.DeliverLocation, Config.Blips.dropOff, 'towing_dropoff')
                                    cdbg('attachVehicle: created group dropoff blip')
                                end
                            end
                            lib.notify({
                                title = Notifications.title,
                                description = Notifications.successfulVehicleLoad,
                                type = 'success',
                                icon = Notifications.icon,
                                position = Notifications.position
                            })
                        else
                            lib.notify({
                                title = Notifications.title,
                                description = Notifications.cancelledVehicleLoad,
                                type = 'error',
                                icon = Notifications.icon,
                                position = Notifications.position
                            })
                        end
                    else
                        lib.notify({
                            title = Notifications.title,
                            description = Notifications.notCloseEnough,
                            type = 'error',
                            icon = Notifications.icon,
                            position = Notifications.position
                        })
                    end
                end
            else
                lib.notify({
                    title = Notifications.title,
                    description = Notifications.error,
                    type = 'error',
                    icon = Notifications.icon,
                    position = Notifications.position
                })
            end
        end
    end
end

-- Function that removes the towed vehicle from the tow truck
function detachVehicle()
    if currentlyTowedVehicle == nil then
        return lib.notify({ id = 'noVehicleToUnload', title = Notifications.title, description = Notifications.noVehicleToUnload, icon = Notifications.icon, type = 'warning', position = Notifications.position })
    end
    if lib.progressCircle({
        label = ProgressCircle.unloadVehicleLabel,
        duration = ProgressCircle.unloadVehicleDuration,
        position = ProgressCircle.position,
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'anim@apt_trans@buzzer',
            clip = 'buzz_reg'
        },
    }) then
        AttachEntityToEntity(currentlyTowedVehicle, towVehicle, 20, -0.5, -12.0, 1.0, 0.0, 0.0, 0.0, false, false, false, false, 20, true)
        DetachEntity(currentlyTowedVehicle, true, true)
        if inService then
            if targetVehiclePlate == missionVehPlate then
                local verifyLocation = lib.callback.await('lation_towtruck:checkDistance', false)
                cdbg('detachVehicle: verifyLocation=%s', tostring(verifyLocation))
                if verifyLocation then
                    -- Check if vehicle is ready for delivery (all issues fixed)
                    if Config.EnableVehicleIssues and missionVehicleNetId then
                        local vehicleReady = lib.callback.await('lation_towtruck:checkVehicleReady', false, missionVehicleNetId)
                        cdbg('detachVehicle: mission ready=%s', tostring(vehicleReady))
                        if not vehicleReady then
                            lib.notify({
                                title = Notifications.title,
                                description = "Vehicle still has unrepaired issues! Fix them before delivery.",
                                type = 'error',
                                icon = Notifications.icon,
                                position = Notifications.position
                            })
                            return
                        end
                    end
                    
                    RemoveBlip(dropOffBlip)
                    -- Remove group drop-off blip if enabled
                    if isSlrnGroupsEnabled() then
                        removeGroupBlip('towing_dropoff')
                    end
                    
                    -- Remove vehicle repair targets
                    if car and Config.EnableVehicleIssues then
                        removeVehicleRepairTargets(car)
                    end
                    
                    if missionIsUrgent and missionUrgentId then
                        local ok, err = lib.callback.await('lation_towtruck:completeUrgentTow', false, missionUrgentId, missionVehicleNetId)
                        cdbg('detachVehicle: urgent complete ok=%s err=%s', tostring(ok), tostring(err))
                        if ok then
                            lib.callback.await('lation_towtruck:cleanupMissionVehicle', false, true)
                            lib.notify({
                                title = Notifications.title,
                                description = 'Urgent tow delivered. Await LEO payout to your group.',
                                type = 'success',
                                icon = Notifications.icon,
                                position = Notifications.position
                            })
                            missionIsUrgent = false
                            missionUrgentId = nil
                            missionVehicleNetId = nil
                            vehicleIssues = {}
                            missionDeliver = nil
                            startNextJob()
                            jobAssigned = false
                        else
                            lib.notify({
                                title = Notifications.title,
                                description = 'Urgent tow completion failed: '..tostring(err or 'unknown'),
                                type = 'error',
                                icon = Notifications.icon,
                                position = Notifications.position
                            })
                        end
                    else
                        local success = lib.callback.await('lation_towtruck:payPlayer', false, missionVehicleNetId)
                        cdbg('detachVehicle: pay success=%s', tostring(success))
                        if success then
                            -- Reset vehicle repair variables
                            missionVehicleNetId = nil
                            vehicleIssues = {}
                            startNextJob()
                            jobAssigned = false
                        end
                    end
                else
                    lib.notify({
                        title = Notifications.title,
                        description = Notifications.tooFarToDeliver,
                        type = 'error',
                        icon = Notifications.icon,
                        position = Notifications.position
                    })
                end
            end
        end
        if currentlyTowedVehicle ~= nil then
            lib.notify({
                title = Notifications.title,
                description = Notifications.sucessfulVehicleUnload,
                type = 'success',
                icon = Notifications.icon,
                position = Notifications.position
            })
            currentlyTowedVehicle = nil
        end
    else
        lib.notify({
            title = Notifications.title,
            description = Notifications.cancelledVehicleUnload,
            type = 'error',
            icon = Notifications.icon,
            position = Notifications.position
        })
    end
end

-- Target options to be applied to the tow truck
local towTargetOptions = {
    {
        name = 'loadVehicle',
        icon = Target.loadVehicleIcon,
        label = Target.loadVehicle,
        onSelect = function()
            attachVehicle()
        end,
        distance = Target.distance
    },
    {
        name = 'unloadVehicle',
        icon = Target.unloadVehicleIcon,
        label = Target.unloadVehicle,
        onSelect = function()
            detachVehicle()
        end,
        distance = Target.distance
    }
}

-- Target options on start job ped
local startTowJobOptions = {
    {
        name = 'talkToStart',
        icon = Target.startJobIcon,
        label = Target.startJob,
        onSelect = function()
            openJobMenu()
        end,
        distance = Target.distance
    },
}

-- Function that opens the job menu to start working, etc
function openJobMenu()
    enabledCalls = enabledCalls
    local jobMenu = {
        {
            title = ContextMenu.towTruckTitle,
            description = ContextMenu.towTruckDescription,
            icon = ContextMenu.towTruckIcon,
            onSelect = function()
                spawnTowTruck()
            end
        },
        {
            title = ContextMenu.clockInTitle,
            description = not enabledCalls and ContextMenu.clockInDescription or ContextMenu.clockInDescription2,
            icon = ContextMenu.clockInIcon,
            onSelect = function()
                enabledCalls = true
                lib.notify({
                    title = Notifications.title,
                    description = Notifications.clockedIn,
                    icon = Notifications.icon,
                    type = 'success',
                    position = Notifications.position
                })
            end,
            disabled = not inService and true or enabledCalls and true
        },
        {
            title = ContextMenu.clockOutTitle,
            description = enabledCalls and ContextMenu.clockOutDescription or ContextMenu.clockOutDescription2,
            icon = ContextMenu.clockOutIcon,
            onSelect = function()
                inService = false
                jobAssigned = false
                enabledCalls = false
                endJob()
            end,
            disabled = not enabledCalls and true or enabledCalls and false
        }
    }
    lib.registerContext({
        id = 'towJobStartMenu',
        title = ContextMenu.menuTitle,
        options = jobMenu
    })
    
    -- Check authorization requirements (job and/or group)
    local authCheck = lib.callback.await('lation_towtruck:checkGroupRequirement', false)
    
    if authCheck == 'authorized' then
        lib.showContext('towJobStartMenu')
    elseif authCheck == 'notInGroup' then
        lib.notify({
            title = Notifications.title,
            description = Notifications.notInGroup,
            icon = Notifications.icon,
            type = 'error',
            position = Notifications.position
        })
    elseif authCheck == 'notAuthorized' then
        lib.notify({
            title = Notifications.title,
            description = Notifications.notAuthorized,
            icon = Notifications.icon,
            type = 'error',
            position = Notifications.position
        })
    else
        -- Fallback to old logic if something goes wrong
        if Config.RequireJob then
            local jobCheck = lib.callback.await('lation_towtruck:checkJob', false)
            if jobCheck then
                lib.showContext('towJobStartMenu')
            else
                lib.notify({
                    title = Notifications.title,
                    description = Notifications.notAuthorized,
                    icon = Notifications.icon,
                    type = 'error',
                    position = Notifications.position
                })
            end
        else
            lib.showContext('towJobStartMenu')
        end
    end
end

-- Applies the target options above to the configured tow truck model (ox_target)
exports.ox_target:addModel(Config.TowTruckModel, {
    {
        name = 'loadVehicle',
        icon = Target.loadVehicleIcon,
        label = Target.loadVehicle,
        onSelect = function()
            attachVehicle()
        end,
        distance = Target.distance
    },
    {
        name = 'unloadVehicle',
        icon = Target.unloadVehicleIcon,
        label = Target.unloadVehicle,
        onSelect = function()
            detachVehicle()
        end,
        distance = Target.distance
    },
    {
        name = 'placeRoadSign',
        icon = 'fas fa-traffic-cone',
        label = 'Place Roadwork Sign',
        onSelect = function()
            placeRoadSign()
        end,
        canInteract = function()
            return Config.EnableRoadworkSigns == true
        end,
        distance = 2.5
    }
})

-- Spawns the ped & applies the target to the ped a when player enters the configured radius
function towJobStartLocation:onEnter()
    spawnTowJobNPC()
    exports.ox_target:addLocalEntity(createTowJobNPC, {
        {
            name = 'talkToStart',
            icon = Target.startJobIcon,
            label = Target.startJob,
            onSelect = function()
                openJobMenu()
            end,
            distance = Target.distance
        }
    })
end

-- Deletes the ped & target option when a player leaves the configured radius
function towJobStartLocation:onExit()
    DeleteEntity(createTowJobNPC)
    exports.ox_target:removeLocalEntity(createTowJobNPC)
end

-- Function that handles the actual spawning of the ped, etc
function spawnTowJobNPC()
    lib.requestModel(Config.StartJobPedModel)
    local pedModel = GetHashKey(Config.StartJobPedModel)
    createTowJobNPC = CreatePed(0, pedModel, Config.StartJobLocation.x, Config.StartJobLocation.y, Config.StartJobLocation.z, Config.StartJobPedHeading, false, true)
    FreezeEntityPosition(createTowJobNPC, true)
    SetBlockingOfNonTemporaryEvents(createTowJobNPC, true)
    SetEntityInvincible(createTowJobNPC, true)
end