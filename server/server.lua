-- Framework bridge: support qb-core and qbx-core
local QBCore
local Framework
if GetResourceState('qb-core') == 'started' then
    Framework = 'qb'
    QBCore = exports['qb-core']:GetCoreObject()
elseif GetResourceState('qbx-core') == 'started' then
    Framework = 'qbx'
    -- qbx-core exposes a compatible core object
    QBCore = exports['qb-core']:GetCoreObject()
else
    Framework = 'unknown'
end

-- Wrapper helpers to abstract framework differences
local function fwGetPlayer(src)
    if not QBCore then return nil end
    -- qbx-core often exposes GetPlayer at root, qb-core under Functions
    if Framework == 'qbx' and QBCore.GetPlayer then
        return QBCore.GetPlayer(src)
    end
    return QBCore.Functions and QBCore.Functions.GetPlayer and QBCore.Functions.GetPlayer(src) or nil
end

local function fwGetJobName(player)
    if not player then return nil end
    -- Prefer qb/qbx PlayerData path; fallback to direct .job
    local job = (player.PlayerData and player.PlayerData.job) or player.job
    return job and job.name or nil
end

local function fwGetJobType(player)
    if not player then return nil end
    local job = (player.PlayerData and player.PlayerData.job) or player.job
    return job and (job.type or job.isLeo and 'leo' or nil) or nil
end

local function fwHasItem(player, item)
    if not player then return false end
    if player.Functions and player.Functions.GetItemByName then
        return player.Functions.GetItemByName(item) ~= nil
    end
    if player.Functions and player.Functions.HasItem then
        return player.Functions.HasItem(item) and true or false
    end
    return false
end

local function fwRemoveItem(player, item, count)
    if not player then return false end
    if player.Functions and player.Functions.RemoveItem then
        return player.Functions.RemoveItem(item, count or 1)
    end
    return false
end

local function fwAddMoney(player, account, amount)
    if not player then return false end
    if player.Functions and player.Functions.AddMoney then
        return player.Functions.AddMoney(account, amount)
    end
    return false
end

-- Inventory bridge: prefer ox_inventory when present
local hasOxInventory = (GetResourceState('ox_inventory') == 'started')

local function invHasItem(src, item, count)
    if hasOxInventory then
        local qty = exports.ox_inventory:Search(src, 'count', item) or 0
        return qty >= (count or 1)
    end
    local player = fwGetPlayer(src)
    return fwHasItem(player, item)
end

local function invRemoveItem(src, item, count)
    if hasOxInventory then
        local removed = exports.ox_inventory:RemoveItem(src, item, count or 1)
        return (removed or 0) ~= 0
    end
    local player = fwGetPlayer(src)
    return fwRemoveItem(player, item, count)
end

-- Store active mission vehicles
local activeMissionVehicles = {}
-- Track occupied locations to prevent conflicts
local occupiedLocations = {}
-- Store vehicle issues for each mission vehicle
local vehicleIssues = {}
-- Reverse lookup: mission vehicleNetId -> owner source id
local vehicleOwnerByNetId = {}
-- Track whether mission vehicle is attached to a tow truck
local vehicleAttached = {}
-- Simple per-player repair cooldown
local lastRepairAttempt = {}

-- Urgent LEO tow calls state
local urgentCalls = {}
local urgentByVehicleNetId = {}
local urgentIdSeq = 1000

local function nextUrgentId()
    urgentIdSeq = urgentIdSeq + 1
    return urgentIdSeq
end

local hasRenewedBanking = (GetResourceState('Renewed-Banking') == 'started')
local hasWeatherSync = (GetResourceState('Renewed-Weathersync') == 'started')

-- Environment detection: night/rain
local function getServerEnv()
    local hour = GetClockHours and GetClockHours() or 12
    local night = (hour < 6 or hour >= 20)
    local rain = false
    if hasWeatherSync and Config.WeatherModifiers and Config.WeatherModifiers.useRenewedWeathersync then
        -- Try a few common export names defensively
        local ok, data = pcall(function()
            return exports['Renewed-Weathersync'] and (exports['Renewed-Weathersync']:GetWeather() or exports['Renewed-Weathersync']:getWeather() or exports['Renewed-Weathersync']:GetWeatherData())
        end)
        if ok and data then
            local w = (type(data) == 'table' and (data.weather or data.name)) or data
            if type(w) == 'string' then
                local s = w:upper()
                rain = (s:find('RAIN') or s:find('THUNDER')) and true or false
            end
        end
    else
        local rl = GetRainLevel and GetRainLevel() or 0.0
        rain = (rl or 0.0) > 0.01
    end
    return { night = night, rain = rain }
end

-- Debug helper
local function sdbg(fmt, ...)
    if not Config.ServerDebug then return end
    local ok, msg = pcall(string.format, fmt, ...)
    print(('[lation_towing][server] %s'):format(ok and msg or tostring(fmt)))
end

-- Function to check if slrn_groups is available and enabled
local function isSlrnGroupsEnabled()
    return Config.UseSlrnGroups and GetResourceState('slrn_groups') == 'started'
end

-- Function to get group ID from player source
local function getPlayerGroupId(source)
    if not isSlrnGroupsEnabled() then return nil end
    return exports.slrn_groups:GetGroupByMembers(source)
end

-- Function to check if player is group leader
local function isGroupLeader(source, groupId)
    if not isSlrnGroupsEnabled() or not groupId then return false end
    return exports.slrn_groups:isGroupLeader(source, groupId)
end

-- Function to notify group members
local function notifyGroup(groupId, message, type)
    if not isSlrnGroupsEnabled() or not groupId then return end
    exports.slrn_groups:NotifyGroup(groupId, message, type or 'success')
end

-- Function to set group job status
local function setGroupJobStatus(groupId, status, stages)
    if not isSlrnGroupsEnabled() or not groupId then return end
    exports.slrn_groups:setJobStatus(groupId, status, stages)
end

-- Function to generate random vehicle issues
local function generateVehicleIssues(vehicleNetId, env)
    if not Config.EnableVehicleIssues then return {} end
    
    local issues = {}
    local issueCount = 0
    
    -- Check if vehicle should have issues
    local roll = math.random(1, 100)
    if roll > Config.VehicleIssueChance then
        sdbg('generateVehicleIssues: netId=%s roll=%d > chance=%d -> no issues', tostring(vehicleNetId), roll, Config.VehicleIssueChance)
        return issues -- No issues
    end
    sdbg('generateVehicleIssues: netId=%s roll=%d <= chance=%d -> generating', tostring(vehicleNetId), roll, Config.VehicleIssueChance)
    
    -- Generate random issues
    for issueType, issueConfig in pairs(Config.VehicleIssues) do
        if issueConfig.enabled and issueCount < Config.MaxIssuesPerVehicle then
            local iroll = math.random(1, 100)
            local effChance = issueConfig.chance
            if Config.WeatherModifiers and Config.WeatherModifiers.enabled and env then
                local boosts = Config.WeatherModifiers.issueChanceBoost or {}
                if env.rain and boosts.rain and boosts.rain[issueType] then effChance = effChance + boosts.rain[issueType] end
                if env.night and boosts.night and boosts.night[issueType] then effChance = effChance + boosts.night[issueType] end
                if effChance > 100 then effChance = 100 end
            end
            if iroll <= effChance then
                issues[issueType] = {
                    fixed = false,
                    description = issueConfig.description,
                    fixTime = (function()
                        local t = issueConfig.fixTime
                        if Config.WeatherModifiers and Config.WeatherModifiers.enabled and env and Config.WeatherModifiers.repairDurationMultiplier then
                            local mult = 1.0
                            if env.rain and Config.WeatherModifiers.repairDurationMultiplier.rain then mult = mult * Config.WeatherModifiers.repairDurationMultiplier.rain end
                            if env.night and Config.WeatherModifiers.repairDurationMultiplier.night then mult = mult * Config.WeatherModifiers.repairDurationMultiplier.night end
                            t = math.floor(t * mult)
                        end
                        return t
                    end)(),
                    requiresItems = issueConfig.requiresItems,
                    remove = issueConfig.remove,
                    items = issueConfig.items
                }
                issueCount = issueCount + 1
                sdbg('generateVehicleIssues: selected issue=%s (roll=%d <= %d)', issueType, iroll, issueConfig.chance)
            else
                sdbg('generateVehicleIssues: skipped issue=%s (roll=%d > %d)', issueType, iroll, issueConfig.chance)
            end
        end
    end
    -- Dependency: sometimes electrical must be fixed before engine
    if Config.IssueDependencies and Config.IssueDependencies.electricalBeforeEngine and math.random(1,100) <= (Config.IssueDependencies.chance or 0) then
        if issues['engine_damage'] and issues['electrical_issues'] then
            issues['engine_damage'].dependsOn = 'electrical_issues'
        end
    end
    
    sdbg('generateVehicleIssues: netId=%s totalIssues=%d', tostring(vehicleNetId), issueCount)
    return issues
end

-- Function to apply vehicle issues (visual and mechanical)
local function applyVehicleIssues(vehicle, issues)
    if not DoesEntityExist(vehicle) then return end
    
    for issueType, _ in pairs(issues) do
        sdbg('applyVehicleIssues: applying issue=%s to veh=%s', tostring(issueType), tostring(vehicle))
        if issueType == 'flat_tires' then
            -- Pop all tires
            for i = 0, 7 do
                SetVehicleTyreBurst(vehicle, i, true, 1000.0)
            end
        elseif issueType == 'engine_damage' then
            -- Damage engine
            SetVehicleEngineHealth(vehicle, 150.0)
        elseif issueType == 'body_damage' then
            -- Damage body
            SetVehicleBodyHealth(vehicle, 300.0)
            -- Add some visual damage
            for i = 0, 5 do
                SetVehicleDoorBroken(vehicle, i, true)
            end
        elseif issueType == 'fuel_empty' then
            -- Empty fuel tank
            Entity(vehicle).state.fuel = 0.0
        elseif issueType == 'electrical_issues' then
            -- Turn off engine and lights
            SetVehicleEngineOn(vehicle, false, true, true)
        end
    end
end

-- Function to check if vehicle has any unfixed issues
local function vehicleHasUnfixedIssues(vehicleNetId)
    if not vehicleIssues[vehicleNetId] then return false end
    
    for _, issue in pairs(vehicleIssues[vehicleNetId]) do
        if not issue.fixed then
            return true
        end
    end
    return false
end

-- Helper: get mission record by vehicleNetId
local function getMissionByNet(vehicleNetId)
    local owner = vehicleOwnerByNetId[vehicleNetId]
    if not owner then return nil, nil end
    return owner, activeMissionVehicles[owner]
end

-- Helper: verify if a player can interact (inspect/repair/pay) with a mission vehicle
local function isInteractionAllowed(src, vehicleNetId)
    if not vehicleNetId then return false end
    local owner, mission = getMissionByNet(vehicleNetId)
    if not mission then return false end
    -- If public pre-attach repairs are allowed and vehicle is not attached, allow anyone
    if Config.AllowPublicRepairsBeforeAttach and not vehicleAttached[vehicleNetId] then
        sdbg('isInteractionAllowed: src=%d netId=%s allowed pre-attach public', src, tostring(vehicleNetId))
        return true
    end
    if owner == src then return true end
    if isSlrnGroupsEnabled() and mission.groupId then
        local playerGroup = getPlayerGroupId(src)
        if playerGroup and playerGroup == mission.groupId then
            sdbg('isInteractionAllowed: src=%d netId=%s allowed (same group)', src, tostring(vehicleNetId))
            return true
        end
    end
    sdbg('isInteractionAllowed: src=%d netId=%s denied', src, tostring(vehicleNetId))
    return false
end

-- Mark vehicle as attached (called from client via a new event if desired) – also expose a server-side function
RegisterNetEvent('lation_towtruck:server:markAttached', function(vehicleNetId)
    local src = source
    local allowed = isInteractionAllowed(src, vehicleNetId) or (Config.AllowPublicRepairsBeforeAttach and not vehicleAttached[vehicleNetId])
    if not allowed then return end
    vehicleAttached[vehicleNetId] = true
    sdbg('markAttached: src=%d netId=%s marked attached', src, tostring(vehicleNetId))
end)

-- New callback to check if player needs to be in a group and provide specific error message
lib.callback.register('lation_towtruck:checkGroupRequirement', function(source)
    -- If slrn_groups is enabled and UseSlrnGroups is true, check group membership
    if isSlrnGroupsEnabled() then
        local groupId = getPlayerGroupId(source)
        if not groupId then
            sdbg('checkGroupRequirement: src=%d not in group -> notInGroup', source)
            return 'notInGroup' -- Player needs to be in a group
        end
    end
    
    -- If we reach here, either groups aren't required or player is in a group
    -- Now check job requirements
    if Config.RequireJob then
        local player = fwGetPlayer(source)
        local playerJob = fwGetJobName(player)
        
        -- If player is in a group and groups are enabled, bypass job check
        if isSlrnGroupsEnabled() and getPlayerGroupId(source) then
            sdbg('checkGroupRequirement: src=%d groups enabled, bypassing job -> authorized', source)
            return 'authorized'
        end
        
        -- Check individual job requirements
        for i = 1, #Config.JobName do
            if playerJob == Config.JobName[i] then
                sdbg('checkGroupRequirement: src=%d job=%s authorized', source, playerJob)
                return 'authorized'
            end
        end
        sdbg('checkGroupRequirement: src=%d job=%s not authorized', source, playerJob)
        return 'notAuthorized' -- Wrong job
    end
    
    sdbg('checkGroupRequirement: src=%d authorized (no restrictions)', source)
    return 'authorized' -- No restrictions
end)

-- Helper: check if source has LEO job
local function isLEO(src)
    local ply = fwGetPlayer(src)
    if not ply then return false end
    local jtype = fwGetJobType(ply)
    if jtype and jtype == 'leo' then return true end
    local jname = fwGetJobName(ply)
    if not jname then return false end
    for _, name in ipairs(Config.LEOJobNames or {}) do
        if jname == name then return true end
    end
    return false
end

-- Helper: find vehicle in front of player
local function findPlayerTargetVehicle(src)
    local ped = GetPlayerPed(src)
    if not ped or ped <= 0 then return nil end
    local pos = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)
    local start = pos + (fwd * 0.5)
    local dest = pos + (fwd * 8.0)
    local ray = StartShapeTestLosProbe(start.x, start.y, start.z, dest.x, dest.y, dest.z, 10, ped, 0)
    local _, hit, _, _, entity = GetShapeTestResult(ray)
    if hit == 1 and DoesEntityExist(entity) and IsEntityAVehicle(entity) then
        return entity
    end
    -- fallback to closest vehicle
    local veh = GetClosestVehicle(pos.x, pos.y, pos.z, 6.0, 0, 70)
    if veh ~= 0 and DoesEntityExist(veh) then return veh end
    return nil
end

-- Start an urgent mission for a group using an existing vehicle
local function pickDeliverLocation()
    local list = Config.DeliverLocations
    if type(list) == 'table' and #list > 0 then
        local idx = math.random(1, #list)
        local v = list[idx]
        return vector3(v.x, v.y, v.z), idx
    end
    local v = Config.DeliverLocation
    return vector3(v.x, v.y, v.z), nil
end

local function startUrgentMissionForGroup(urgent, acceptorSrc, groupId)
    local veh = NetworkGetEntityFromNetworkId(urgent.vehicleNetId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false, 'no_vehicle' end
    local x, y, z = table.unpack(GetEntityCoords(veh))
    local h = GetEntityHeading(veh)
    local plate = GetVehicleNumberPlateText(veh)

    -- Bind mission ownership to accepting source (group members can interact via existing checks)
    -- Use officer-specified deliver if provided, otherwise fallback to global default
    local deliverVec3
    local deliverIndex = nil
    if urgent.deliver and urgent.deliver.x then
        deliverVec3 = vector3(urgent.deliver.x, urgent.deliver.y, urgent.deliver.z)
        deliverIndex = urgent.deliver.index -- may be nil if officer chose waypoint/road
    else
        local v = Config.DeliverLocation
        deliverVec3 = vector3(v.x, v.y, v.z)
    end

    activeMissionVehicles[acceptorSrc] = {
        vehicle = veh,
        plate = plate,
        location = { x = x, y = y, z = z, h = h },
        locationIndex = nil,
        vehicleNetId = urgent.vehicleNetId,
        groupId = groupId,
        isUrgent = true,
            deliver = { x = deliverVec3.x, y = deliverVec3.y, z = deliverVec3.z, index = deliverIndex }
    }
    vehicleOwnerByNetId[urgent.vehicleNetId] = acceptorSrc
    vehicleIssues[urgent.vehicleNetId] = {} -- no issues for urgent by default
    vehicleAttached[urgent.vehicleNetId] = false

    -- Set group job status and notify
    if isSlrnGroupsEnabled() and groupId then
        setGroupJobStatus(groupId, Config.SlrnGroupsJobType, { 'Urgent Pickup', 'Deliver Vehicle' })
        notifyGroup(groupId, ("Urgent tow accepted! ID #%d. Check your GPS."):format(urgent.id), 'success')
        local coords = vector3(x, y, z)
        exports.slrn_groups:triggerGroupEvent('lation_towing:client:startUrgentMission', groupId, {
            coords = coords,
            vehicleNetId = urgent.vehicleNetId,
            plate = plate,
            urgentId = urgent.id,
            createdAt = urgent.createdAt,
            timeLimit = Config.UrgentTowTimeLimit or 600,
            deliver = activeMissionVehicles[acceptorSrc].deliver
        })
    end
    return true
end

-- Command: /towcall (LEO only) to mark a blocking vehicle and notify all groups
lib.addCommand('towcall', {
    help = 'Create an urgent tow call for a blocking vehicle (LEO only)'
}, function(source, args, raw)
    if not Config.EnableUrgentLEOTow then return end
    if not isLEO(source) then return end

    if not isSlrnGroupsEnabled() then
        return print(('[lation_towing] towcall rejected: slrn_groups disabled'))
    end

    local veh = findPlayerTargetVehicle(source)
    if not veh then
        return notifyGroup(getPlayerGroupId(source), 'No vehicle found ahead to mark for tow.', 'error')
    end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    if urgentByVehicleNetId[netId] then
        return notifyGroup(getPlayerGroupId(source), 'This vehicle is already marked for urgent tow.', 'warning')
    end

    -- Ask officer client for desired drop-off (waypoint). If none set, instruct and abort.
    local dropoff = lib.callback.await('lation_towing:getOfficerDropoff', source)
    if not dropoff or not dropoff.x then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Tow Truck',
            description = 'Set a map waypoint for the desired drop-off location, then run /towcall again.',
            type = 'error',
            position = 'top',
            icon = 'truck-ramp-box'
        })
        return
    end

    local id = nextUrgentId()
    local coords = GetEntityCoords(veh)
    urgentCalls[id] = {
        id = id,
        vehicleNetId = netId,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        createdBy = source,
        createdAt = os.time(),
        status = 'open',
        deliver = { x = dropoff.x, y = dropoff.y, z = dropoff.z, index = dropoff.index }
    }
    urgentByVehicleNetId[netId] = id

    -- Notify all groups about the urgent tow
    local groups = exports.slrn_groups:getAllGroups()
    if groups then
        for _, g in ipairs(groups) do
            exports.slrn_groups:NotifyGroup(g.id, ("URGENT Tow #%d: Blocking lane reported. Use /towaccept %d to take the job."):format(id, id), 'warning')
        end
    end

    sdbg('towcall: src=%d created urgent id=%d netId=%s', source, id, tostring(netId))
end)

-- Command: /towaccept [id] for groups to accept the urgent call
lib.addCommand('towaccept', {
    help = 'Accept an urgent tow call by ID (must be in a group)',
    params = { { name = 'id', type = 'number', help = 'Urgent Call ID' } }
}, function(source, args)
    if not Config.EnableUrgentLEOTow then return end
    if not isSlrnGroupsEnabled() then return end
    local groupId = getPlayerGroupId(source)
    if not groupId then return end
    local id = tonumber(args.id)
    local urgent = id and urgentCalls[id]
    if not urgent or urgent.status ~= 'open' then return end

    urgent.status = 'accepted'
    urgent.acceptedBy = source
    urgent.acceptedGroup = groupId
    urgent.acceptedAt = os.time()

    local ok, err = startUrgentMissionForGroup(urgent, source, groupId)
    if not ok then
        urgent.status = 'open'
        urgent.acceptedBy, urgent.acceptedGroup, urgent.acceptedAt = nil, nil, nil
        return notifyGroup(groupId, 'Failed to assign urgent tow: vehicle not available.', 'error')
    end

    -- Inform all groups the call has been taken
    local groups = exports.slrn_groups:getAllGroups()
    if groups then
        for _, g in ipairs(groups) do
            exports.slrn_groups:NotifyGroup(g.id, ("URGENT Tow #%d has been accepted by a group."):format(id), 'info')
        end
    end

    sdbg('towaccept: src=%d accepted urgent id=%d group=%s', source, id, tostring(groupId))
end)

-- Callback: mark completion of urgent tow on delivery (no payment here)
lib.callback.register('lation_towtruck:completeUrgentTow', function(source, urgentId, vehicleNetId)
    local urgent = urgentCalls[tonumber(urgentId or 0)]
    if not urgent then return false, 'invalid' end
    if urgent.status ~= 'accepted' then return false, 'not_accepted' end
    if vehicleNetId ~= urgent.vehicleNetId then return false, 'mismatch' end

    -- Verify the group/source matches
    local groupId = getPlayerGroupId(source)
    if not groupId or groupId ~= urgent.acceptedGroup then return false, 'not_group' end

    urgent.status = 'completed'
    urgent.completedAt = os.time()
    urgent.completedBy = source
    urgent.completedGroup = groupId

    -- Clear mission ownership but do not delete vehicle entity
    local owner = vehicleOwnerByNetId[vehicleNetId]
    if owner and activeMissionVehicles[owner] then
        -- mark paid/completed via isUrgent flag; cleanup will avoid deletion
        activeMissionVehicles[owner].completedUrgent = true
    end

    -- Notify group
    notifyGroup(groupId, ("Urgent tow #%d delivered. Awaiting officer payout."):format(urgent.id), 'success')
    setGroupJobStatus(groupId, 'DONE', {})
    return true
end)

-- Command: /towpay [id] [amount?] (LEO only) to pay the completing group from business
lib.addCommand('towpay', {
    help = 'Pay an urgent tow from police business funds (LEO only)',
    params = {
        { name = 'id', type = 'number', help = 'Urgent Call ID' },
        { name = 'amount', type = 'number', help = 'Amount to pay (optional)' }
    }
}, function(source, args)
    if not Config.EnableUrgentLEOTow then return end
    if not isLEO(source) then return end
    local id = tonumber(args.id)
    local urgent = id and urgentCalls[id]
    if not urgent then return end
    if urgent.status ~= 'completed' then return end
    local groupId = urgent.completedGroup
    if not groupId then return end

    -- Calculate suggested pay
    local amount = tonumber(args.amount)
    if not amount then
        local base = Config.UrgentTowBasePay or 700
        local bonus = 0
        if urgent.acceptedAt and urgent.completedAt then
            local elapsed = urgent.completedAt - urgent.acceptedAt
            local limit = Config.UrgentTowTimeLimit or 600
            if elapsed <= math.floor(limit / 2) then
                bonus = Config.UrgentTowFastBonus or 400
            end
        end
        amount = base + bonus
    end

    -- Remove from business
    local business = Config.UrgentTowBusiness or 'police'
    if Config.UseRenewedBanking and hasRenewedBanking then
        local ok = exports['Renewed-Banking']:removeAccountMoney(business, amount)
        if not ok then
            return print(('[lation_towing] towpay failed: insufficient business funds in %s for %d'):format(business, amount))
        end
        -- Optional: log transaction
        exports['Renewed-Banking']:handleTransaction(business, 'Urgent Tow Payout', amount, ('Tow ID #%d payout to group %s'):format(id, tostring(groupId)), 'Police Department', 'Tow Group', 'withdraw')
    else
        -- Fallback: no business debit (admin should ensure funds manually)
        print(('[lation_towing] towpay: Renewed-Banking disabled; paying players without debiting business'))
    end

    -- Distribute to group members
    local members = exports.slrn_groups:getGroupMembers(groupId) or {}
    if #members == 0 then return end
    if Config.UrgentTowPayPerMember then
        for _, sid in ipairs(members) do
            local ply = fwGetPlayer(sid)
            if ply then fwAddMoney(ply, 'bank', amount) end
        end
    else
        local per = math.floor(amount / #members)
        local rem = amount % #members
        for _, sid in ipairs(members) do
            local ply = fwGetPlayer(sid)
            if ply then fwAddMoney(ply, 'bank', per + (sid == urgent.completedBy and rem or 0)) end
        end
    end

    urgent.status = 'paid'
    urgent.paidAmount = amount
    urgent.paidBy = source
    urgent.paidAt = os.time()

    notifyGroup(groupId, ("Urgent tow #%d paid: $%d"):format(id, amount), 'success')
    sdbg('towpay: src=%d paid urgent id=%d amount=%d to group=%s', source, id, amount, tostring(groupId))
end)

-- Callback to inspect vehicle issues
lib.callback.register('lation_towtruck:inspectVehicle', function(source, vehicleNetId)
    if not isInteractionAllowed(source, vehicleNetId) then return {} end
    if not vehicleIssues[vehicleNetId] then return {} end
    sdbg('inspectVehicle: src=%d netId=%s issues=%d', source, tostring(vehicleNetId), vehicleIssues[vehicleNetId] and #({pairs(vehicleIssues[vehicleNetId])}) or 0)
    return vehicleIssues[vehicleNetId]
end)

-- Callback to repair vehicle issue
lib.callback.register('lation_towtruck:repairVehicleIssue', function(source, vehicleNetId, issueType, failedSkillCheck)
    -- Cooldown check
    local now = GetGameTimer()
    local last = lastRepairAttempt[source] or 0
    if now - last < (Config.RepairCooldownMs or 0) then
        sdbg('repairVehicleIssue: src=%d netId=%s issue=%s blocked by cooldown (%dms remaining)', source, tostring(vehicleNetId), tostring(issueType), (Config.RepairCooldownMs or 0) - (now - last))
        return false, 'cooldown'
    end
    lastRepairAttempt[source] = now

    if not isInteractionAllowed(source, vehicleNetId) then
        sdbg('repairVehicleIssue: src=%d netId=%s issue=%s not allowed', source, tostring(vehicleNetId), tostring(issueType))
        return false
    end
    if not vehicleIssues[vehicleNetId] or not vehicleIssues[vehicleNetId][issueType] then
        sdbg('repairVehicleIssue: src=%d netId=%s issue=%s not found', source, tostring(vehicleNetId), tostring(issueType))
        return false
    end
    
    local issue = vehicleIssues[vehicleNetId][issueType]
    -- Enforce dependency: engine requires electrical first if set
    if issueType == 'engine_damage' and issue.dependsOn == 'electrical_issues' then
        local dep = vehicleIssues[vehicleNetId]['electrical_issues']
        if dep and not dep.fixed then
            return false, 'dependency'
        end
    end

    
    -- Check if player has required items (if needed). Items are only consumed if `issue.remove` is true.
    if issue.requiresItems and #issue.items > 0 then
        for _, item in ipairs(issue.items) do
            if not invHasItem(source, item, 1) then
                sdbg('repairVehicleIssue: src=%d missing item=%s', source, tostring(item))
                return false, 'missing_items'
            end
        end
        
        if issue.remove then
            -- Remove items if configured to do so
            for _, item in ipairs(issue.items) do
                invRemoveItem(source, item, 1)
                sdbg('repairVehicleIssue: src=%d removed item=%s', source, tostring(item))
            end
            -- Extra consumption on failed skill check
            if failedSkillCheck and Config.SkillCheck and Config.SkillCheck.extraConsumptionOnFail then
                for _, item in ipairs(issue.items) do
                    if invHasItem(source, item, 1) then
                        invRemoveItem(source, item, 1)
                        sdbg('repairVehicleIssue: extra consumption item=%s for failed skill', tostring(item))
                    end
                end
            end
        end
    end
    
    -- Mark issue as fixed
    vehicleIssues[vehicleNetId][issueType].fixed = true
    
    -- Apply fix to the vehicle
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if DoesEntityExist(vehicle) then
        if issueType == 'flat_tires' then
            -- Fix all tires
            for i = 0, 7 do
                SetVehicleTyreFixed(vehicle, i)
            end
        elseif issueType == 'engine_damage' then
            -- Repair engine
            SetVehicleEngineHealth(vehicle, 1000.0)
        elseif issueType == 'body_damage' then
            -- Repair body
            SetVehicleBodyHealth(vehicle, 1000.0)
            SetVehicleFixed(vehicle)
        elseif issueType == 'fuel_empty' then
            -- Refuel vehicle
            Entity(vehicle).state.fuel = 100.0
        elseif issueType == 'electrical_issues' then
            -- Fix electrical
            SetVehicleEngineOn(vehicle, true, true, false)
        end
    end
    
    sdbg('repairVehicleIssue: src=%d netId=%s issue=%s repaired', source, tostring(vehicleNetId), tostring(issueType))
    return true, 'repaired'
end)

-- Callback to check if vehicle is ready for delivery
lib.callback.register('lation_towtruck:checkVehicleReady', function(source, vehicleNetId)
    if not isInteractionAllowed(source, vehicleNetId) then
        return false
    end
    local ready = not vehicleHasUnfixedIssues(vehicleNetId)
    sdbg('checkVehicleReady: src=%d netId=%s ready=%s', source, tostring(vehicleNetId), tostring(ready))
    return ready
end)

-- Event that is used to pay a player for a successful job
lib.callback.register('lation_towtruck:payPlayer', function(source, vehicleNetId)
    local source = source
    local player = fwGetPlayer(source)
    if not isInteractionAllowed(source, vehicleNetId) then
        sdbg('payPlayer: src=%d netId=%s not allowed', source, tostring(vehicleNetId))
        return false
    end
    
    local payAmount
    if Config.RandomPayPerDelivery then
        payAmount = math.random(Config.MinPayPerDelivery, Config.MaxPayPerDelivery)
    else
        payAmount = Config.PayPerDelivery
    end
    
    -- Add bonus pay for each issue that was fixed
    local bonusPay = 0
    if vehicleNetId and vehicleIssues[vehicleNetId] then
        for _, issue in pairs(vehicleIssues[vehicleNetId]) do
            if issue.fixed then
                bonusPay = bonusPay + Config.RepairBonusPay
            end
        end
    end
    
    payAmount = payAmount + bonusPay
    -- Weather/time pay bonus
    if Config.WeatherModifiers and Config.WeatherModifiers.enabled and vehicleNetId then
        local owner, mission = getMissionByNet(vehicleNetId)
        local env = mission and mission.env
        if env then
            local pct = 0
            local pb = Config.WeatherModifiers.payBonusPercent or {}
            if env.rain and pb.rain then pct = pct + pb.rain end
            if env.night and pb.night then pct = pct + pb.night end
            if pct > 0 then
                payAmount = payAmount + math.floor(payAmount * (pct/100))
            end
        end
    end
    
    -- Check if player is in a group for payment distribution
    local groupId = getPlayerGroupId(source)
    if groupId then
        local groupMembers = exports.slrn_groups:getGroupMembers(groupId)
        if groupMembers and #groupMembers > 0 then
            -- Distribute payment among all group members
            local payPerMember = math.floor(payAmount / #groupMembers)
            local remainder = payAmount % #groupMembers
            sdbg('payPlayer: src=%d groupId=%s total=%d members=%d perMember=%d remainder=%d (bonus=%d)', source, tostring(groupId), payAmount, #groupMembers, payPerMember, remainder, bonusPay)
            
            for i, memberId in ipairs(groupMembers) do
                local memberPlayer = fwGetPlayer(memberId)
                if memberPlayer then
                    local memberPay = payPerMember
                    -- Give remainder to the person who completed the job
                    if memberId == source then
                        memberPay = memberPay + remainder
                    end
                    fwAddMoney(memberPlayer, Config.PayPerDeliveryAccount, memberPay)
                end
            end
            
            -- Create detailed payment notification
            local paymentMessage = string.format('Towing job completed! Each member received $%d', payPerMember)
            
            -- Add repair bonus information if applicable
            if bonusPay > 0 then
                local totalRepairBonus = bonusPay
                local repairBonusPerMember = math.floor(totalRepairBonus / #groupMembers)
                paymentMessage = paymentMessage .. string.format('\n• Base Pay: $%d\n• Repair Bonus: $%d', payPerMember - repairBonusPerMember, repairBonusPerMember)
                
                -- Add information about which issues were fixed
                if vehicleNetId and vehicleIssues[vehicleNetId] then
                    local fixedIssues = {}
                    for issueType, issue in pairs(vehicleIssues[vehicleNetId]) do
                        if issue.fixed then
                            table.insert(fixedIssues, '• ' .. issue.description)
                        end
                    end
                    if #fixedIssues > 0 then
                        paymentMessage = paymentMessage .. '\n\nRepaired Issues:\n' .. table.concat(fixedIssues, '\n')
                    end
                end
            end
            
            -- Notify group about payment
            notifyGroup(groupId, paymentMessage, 'success')
            
            -- Reset group job status
            setGroupJobStatus(groupId, 'none', {})
            
            return true
        end
    end
    
    -- Fallback to individual payment if not in group
    fwAddMoney(player, Config.PayPerDeliveryAccount, payAmount)
    sdbg('payPlayer: src=%d paid individually amount=%d (bonus=%d)', source, payAmount, bonusPay)
    return true
end)

-- Event that is used to check a players job if Config.RequireJob is true
lib.callback.register('lation_towtruck:checkJob', function(source)
    local source = source
    local player = fwGetPlayer(source)
    local playerJob = fwGetJobName(player)
    
    -- If slrn_groups is enabled and UseSlrnGroups is true, require group membership
    if isSlrnGroupsEnabled() then
        local groupId = getPlayerGroupId(source)
        if groupId then
            -- Player is in a group, allow them to do towing job
            sdbg('checkJob: src=%d in group -> allowed', source)
            return true
        else
            -- Player is not in a group but slrn_groups is enabled and required
            sdbg('checkJob: src=%d not in group -> denied', source)
            return false
        end
    end
    
    -- If Config.RequireJob is false, allow anyone
    if not Config.RequireJob then
        sdbg('checkJob: src=%d no job requirement -> allowed', source)
        return true
    end
    
    -- Check if player job is in the allowed jobs table (fallback for individual players when slrn_groups is disabled)
    for i = 1, #Config.JobName do
        if playerJob == Config.JobName[i] then
            sdbg('checkJob: src=%d job=%s allowed', source, playerJob)
            return true
        end
    end
    sdbg('checkJob: src=%d job=%s denied', source, playerJob)
    return false
end)

-- Event that is used to check a players distance relative to delivery location before payment
lib.callback.register('lation_towtruck:checkDistance', function(source)
    local player = GetPlayerPed(source)
    local playerPos = GetEntityCoords(player)
    local mission = activeMissionVehicles[source]
    local target
    if mission and mission.deliver then
        target = vector3(mission.deliver.x, mission.deliver.y, mission.deliver.z)
    else
        target = Config.DeliverLocation
    end
    local distance = #(playerPos - target)
    if distance < Config.DeliverRadius then
        sdbg('checkDistance: src=%d dist=%.2f within=%d -> true', source, distance, Config.DeliverRadius)
        return true
    end
    sdbg('checkDistance: src=%d dist=%.2f within=%d -> false', source, distance, Config.DeliverRadius)
    return false
end)

-- Server-side function to spawn mission vehicle
lib.callback.register('lation_towtruck:spawnMissionVehicle', function(source)
    local function selectCarAndLocation()
        local availableLocations = {}
        
        -- Filter out occupied locations
        for i = 1, #Config.Locations do
            local locationOccupied = false
            for occupiedIndex, _ in pairs(occupiedLocations) do
                if occupiedIndex == i then
                    locationOccupied = true
                    break
                end
            end
            
            if not locationOccupied then
                table.insert(availableLocations, {index = i, location = Config.Locations[i][1]})
            end
        end
        
        -- If no locations available, return nil
        if #availableLocations == 0 then
            sdbg('spawnMissionVehicle: no available locations')
            return nil, nil, nil
        end
        
        -- Select random available location
        local randomAvailableLoc = math.random(1, #availableLocations)
    local selectedLocation = availableLocations[randomAvailableLoc]
        local locationIndex = selectedLocation.index
        local location = selectedLocation.location
        
        -- Select random car
        local randomCar = math.random(1, #Config.CarModels)
        local selectCar = Config.CarModels[randomCar]
        sdbg('spawnMissionVehicle: selected car=%s at locationIndex=%d', tostring(selectCar), locationIndex)
        
        return selectCar, location, locationIndex
    end
    
    local carModel, location, locationIndex = selectCarAndLocation()
    
    -- If no available locations, return false
    if not carModel or not location or not locationIndex then
        sdbg('spawnMissionVehicle: selection failed')
        return false
    end
    
    -- Mark location as occupied
    occupiedLocations[locationIndex] = source
    
    -- Extract coordinates from vector4
    local x, y, z, h = location.x, location.y, location.z, location.w
    local vehicle = CreateVehicle(GetHashKey(carModel), x, y, z, h, true, true)
    sdbg('spawnMissionVehicle: creating vehicle model=%s at %.2f,%.2f,%.2f h=%.1f', tostring(carModel), x, y, z, h)
    
    -- Wait for vehicle to be created
    while not DoesEntityExist(vehicle) do
        Wait(10)
    end
    
    -- Configure the vehicle
    SetVehicleDoorOpen(vehicle, 4, false, false)
    SetVehicleEngineHealth(vehicle, 200.0)
    SetVehicleBodyHealth(vehicle, 200.0)
    SetVehicleDirtLevel(vehicle, 12.0)
    
    local plate = GetVehicleNumberPlateText(vehicle)
    local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
    sdbg('spawnMissionVehicle: created plate=%s netId=%s', tostring(plate), tostring(vehicleNetId))
    
    -- Generate and apply vehicle issues with environment modifiers
    local env = getServerEnv()
    local issues = generateVehicleIssues(vehicleNetId, env)
    vehicleIssues[vehicleNetId] = issues
    applyVehicleIssues(vehicle, issues)
    local countIssues = 0
    for _ in pairs(issues) do countIssues = countIssues + 1 end
    sdbg('spawnMissionVehicle: issues applied count=%d', countIssues)
    
    -- Determine groupId for mission ownership
    local missionGroupId = isSlrnGroupsEnabled() and getPlayerGroupId(source) or nil

    -- Check if player is in a group and handle group notifications
    if isSlrnGroupsEnabled() then
        local groupId = missionGroupId
        if groupId then
            -- Set group job status to active towing job
            setGroupJobStatus(groupId, Config.SlrnGroupsJobType, {'Pickup Vehicle', 'Deliver Vehicle'})
            
            -- Create detailed notification message
            local notificationMessage = 'New towing job assigned! Check your GPS for the pickup location.'
            
            -- Add vehicle issues information if enabled and issues exist
            if Config.EnableVehicleIssues and next(issues) then
                local issueList = {}
                for issueType, issue in pairs(issues) do
                    table.insert(issueList, '• ' .. issue.description)
                end
                notificationMessage = notificationMessage .. '\n\nVehicle Issues Found:\n' .. table.concat(issueList, '\n')
            elseif Config.EnableVehicleIssues then
                notificationMessage = notificationMessage .. '\n\nVehicle Status: No issues found - ready for delivery!'
            end
            
            -- Notify all group members about the new job with issues info
            notifyGroup(groupId, notificationMessage, 'success')

            -- Also trigger an interactive prompt on all group members with coords and location index
            local coords = vector3(location.x, location.y, location.z)
            exports.slrn_groups:triggerGroupEvent('lation_towing:client:groupJobAssigned', groupId, coords, locationIndex)
            sdbg('spawnMissionVehicle: triggered client groupJobAssigned event (group=%s, index=%d)', tostring(groupId), locationIndex)
            sdbg('spawnMissionVehicle: notified group=%s about job', tostring(groupId))
        end
    end
    
    -- Store the mission vehicle data
    local deliverVec3, deliverIndex = pickDeliverLocation()

    activeMissionVehicles[source] = {
        vehicle = vehicle,
        plate = plate,
        location = {x = x, y = y, z = z, h = h},
        locationIndex = locationIndex,
        vehicleNetId = vehicleNetId,
        groupId = missionGroupId,
        deliver = { x = deliverVec3.x, y = deliverVec3.y, z = deliverVec3.z, index = deliverIndex },
        env = env
    }
    vehicleOwnerByNetId[vehicleNetId] = source
    sdbg('spawnMissionVehicle: stored mission for src=%d netId=%s locIndex=%d', source, tostring(vehicleNetId), locationIndex)
    
    return {
        vehicle = vehicle,
        plate = plate,
        location = {x = x, y = y, z = z, h = h},
        vehicleNetId = vehicleNetId,
        issues = issues,
        deliver = activeMissionVehicles[source].deliver
    }
end)

-- Server-side function to clean up mission vehicle
lib.callback.register('lation_towtruck:cleanupMissionVehicle', function(source, silent)
    if activeMissionVehicles[source] then
        local vehicleData = activeMissionVehicles[source]
        if DoesEntityExist(vehicleData.vehicle) then
            DeleteEntity(vehicleData.vehicle)
        end
        
        -- Free up the location
        if vehicleData.locationIndex and occupiedLocations[vehicleData.locationIndex] == source then
            occupiedLocations[vehicleData.locationIndex] = nil
        end
        
        -- Reset group job status if player is in a group
        local groupId = getPlayerGroupId(source)
        if groupId then
            setGroupJobStatus(groupId, 'none', {})
            if not silent then
                notifyGroup(groupId, 'Towing job has been cancelled.', 'warning')
            end
            sdbg('cleanupMissionVehicle: src=%d group=%s reset job status + notified', source, tostring(groupId))
        end
        
        -- Clean up vehicle issues
        if vehicleData.vehicleNetId and vehicleIssues[vehicleData.vehicleNetId] then
            vehicleIssues[vehicleData.vehicleNetId] = nil
        end
        if vehicleData.vehicleNetId and vehicleOwnerByNetId[vehicleData.vehicleNetId] then
            vehicleOwnerByNetId[vehicleData.vehicleNetId] = nil
        end
        
        activeMissionVehicles[source] = nil
        sdbg('cleanupMissionVehicle: src=%d cleaned mission', source)
        return true
    end
    return false
end)

-- Clean up player's mission vehicle when they disconnect
AddEventHandler('playerDropped', function(reason)
    local source = source
    if activeMissionVehicles[source] then
        local vehicleData = activeMissionVehicles[source]
        if DoesEntityExist(vehicleData.vehicle) then
            DeleteEntity(vehicleData.vehicle)
        end
        
        -- Free up the location
        if vehicleData.locationIndex and occupiedLocations[vehicleData.locationIndex] == source then
            occupiedLocations[vehicleData.locationIndex] = nil
        end
        
        -- Handle group cleanup if player was in a group
        local groupId = getPlayerGroupId(source)
        if groupId then
            -- Check if there are other group members online to take over
            local groupMembers = exports.slrn_groups:getGroupMembers(groupId)
            local remainingMembers = 0
            
            if groupMembers then
                for _, memberId in ipairs(groupMembers) do
                    if memberId ~= source and GetPlayerPed(memberId) then
                        remainingMembers = remainingMembers + 1
                    end
                end
            end
            
            if remainingMembers == 0 then
                -- No other group members online, reset job status
                setGroupJobStatus(groupId, 'none', {})
            else
                -- Notify remaining group members
                notifyGroup(groupId, 'A group member disconnected during the towing job.', 'warning')
            end
        end
        
        -- Clean up vehicle issues
        if vehicleData.vehicleNetId and vehicleIssues[vehicleData.vehicleNetId] then
            vehicleIssues[vehicleData.vehicleNetId] = nil
        end
        if vehicleData.vehicleNetId and vehicleOwnerByNetId[vehicleData.vehicleNetId] then
            vehicleOwnerByNetId[vehicleData.vehicleNetId] = nil
        end
        
        activeMissionVehicles[source] = nil
        sdbg('playerDropped: src=%d cleaned mission and state', source)
    end
end)