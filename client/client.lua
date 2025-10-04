-- Enhanced Debug System
local debugActive = false
local debugStartTime = GetGameTimer()

-- Initialize debug system
CreateThread(function()
    Wait(1000) -- Wait for config to load
    if Config and Config.Debug and Config.Debug.enabled and Config.Debug.client and Config.Debug.client.enabled then
        debugActive = true
    end
end)

-- Debug function with categories and color coding
local function debugPrint(category, message, debugType)
    if not debugActive or not Config or not Config.Debug then return end
    
    -- Check if this debug type is enabled
    if debugType and Config.Debug.client and Config.Debug.client[debugType] == false then return end
    
    -- Check if category is enabled
    local categoryConfig = Config.Debug.categories and Config.Debug.categories[category]
    if not categoryConfig or not categoryConfig.enabled then return end
    
    -- Build debug message
    local timestamp = ''
    if Config.Debug.output and Config.Debug.output.showTimestamps then
        local currentTime = GetGameTimer() - debugStartTime
        timestamp = string.format('[%02d:%02d.%03d] ', 
            math.floor(currentTime / 60000), 
            math.floor((currentTime % 60000) / 1000), 
            currentTime % 1000)
    end
    
    local playerInfo = ''
    if Config.Debug.output and Config.Debug.output.showPlayerInfo then
        local playerId = PlayerId()
        local playerName = GetPlayerName(playerId)
        playerInfo = string.format('[%s(%d)] ', playerName or 'Unknown', playerId)
    end
    
    local prefix = categoryConfig.prefix or '[DEBUG]'
    local color = (Config.Debug.output and Config.Debug.output.useColors) and categoryConfig.color or ''
    local resetColor = (Config.Debug.output and Config.Debug.output.useColors) and '^7' or ''
    
    -- Limit message length
    local finalMessage = tostring(message)
    if Config.Debug.output and Config.Debug.output.maxLogLength and #finalMessage > Config.Debug.output.maxLogLength then
        finalMessage = finalMessage:sub(1, Config.Debug.output.maxLogLength) .. '...'
    end
    
    print(string.format('%s%s%s%s %s%s', 
        color, prefix, resetColor, timestamp, playerInfo, finalMessage))
end

-- Performance tracking
local performanceTimers = {}

local function startPerformanceTimer(name)
    if Config and Config.Debug and Config.Debug.performance and Config.Debug.performance.trackExecutionTime then
        performanceTimers[name] = GetGameTimer()
    end
end

local function endPerformanceTimer(name, warnIfSlow)
    if not Config or not Config.Debug or not Config.Debug.performance or not Config.Debug.performance.trackExecutionTime then return end
    
    local startTime = performanceTimers[name]
    if not startTime then return end
    
    local executionTime = GetGameTimer() - startTime
    performanceTimers[name] = nil
    
    if warnIfSlow and Config.Debug.performance.warnSlowOperations and Config.Debug.performance.slowOperationThreshold then
        if executionTime > Config.Debug.performance.slowOperationThreshold then
            debugPrint('PERFORMANCE', string.format('Slow operation detected: %s took %dms', name, executionTime))
        end
    end
    
    if Config.Debug and Config.Debug.categories and Config.Debug.categories.PERFORMANCE and Config.Debug.categories.PERFORMANCE.enabled then
        debugPrint('PERFORMANCE', string.format('%s execution time: %dms', name, executionTime))
    end
end

-- Convenience debug functions for different categories
local function debugError(message, debugType)
    debugPrint('ERROR', message, debugType)
end

local function debugWarn(message, debugType)
    debugPrint('WARN', message, debugType)
end

local function debugInfo(message, debugType)
    debugPrint('INFO', message, debugType)
end

local function debugSuccess(message, debugType)
    debugPrint('SUCCESS', message, debugType)
end

local function debugTrace(message, debugType)
    debugPrint('TRACE', message, debugType)
end

-- ox_target initialization
local ox_target = exports.ox_target

-- Item checking function for ox_inventory
local function hasRequiredItem(item)
    debugTrace(string.format('Checking for required item: %s', item or 'nil'), 'inventorySystem')
    
    if not item then 
        debugInfo('No item required for this action', 'inventorySystem')
        return true 
    end -- No item required
    
    -- Use ox_inventory export to check for item
    local itemCount = exports.ox_inventory:Search('count', item)
    
    if itemCount and itemCount > 0 then
        debugSuccess(string.format('Found required item: %s (count: %d)', item, itemCount), 'inventorySystem')
        return true
    end
    
    debugWarn(string.format('Required item not found or count is 0: %s', item), 'inventorySystem')
    return false
end

-- Remove item function for ox_inventory
local function removeRequiredItem(item)
    debugTrace(string.format('Attempting to remove item: %s', item or 'nil'), 'inventorySystem')
    
    if not item then 
        debugInfo('No item to remove', 'inventorySystem')
        return true 
    end -- No item to remove
    
    debugInfo(string.format('Removing item from inventory: %s', item), 'inventorySystem')
    
    -- ox_inventory uses server-side removal - trigger server event
    TriggerServerEvent('lation_towing:removeItem', item, 1)
    debugSuccess(string.format('Triggered server-side item removal: %s', item), 'inventorySystem')
    
    return true
end

-- Forward declarations for ox_target functions
local addVehicleRepairTargets, removeVehicleRepairTargets

-- Stuff
local qtarget = exports.qtarget
local towJobStartLocation = lib.points.new(Config.StartJobLocation, Config.StartJobRadius)
local targetVehicle, currentlyTowedVehicle, towVehicle, inService, spawnedVehicle, spawnedVehiclePlate
local jobAssigned, enabledCalls, car, location, locationKey, targetCarBlip, dropOffBlip

-- New Feature Variables
local currentStreak = 0
local vehicleInitialHealth = {}
local vehicleDisabilities = {} -- Stores disabilities for each vehicle by plate
local repairedDisabilities = {} -- Tracks repaired disabilities for bonus calculation
local jobStartTime = 0
local currentJobs = 0 -- Track concurrent jobs for performance monitoring
local lastCleanupTime = 0 -- Track cleanup timing
local playerStats = {
    totalDeliveries = 0,
    totalEarnings = 0,
    bestStreak = 0,
    avgDeliveryTime = 0,
    successRate = 100
}

-- Function definitions (moved to top to prevent nil value errors)
local function applyDisabilityEffects(vehicle, disability)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    
    local effects = disability.effects
    
    -- Engine failure effects
    if effects.engineHealth then
        SetVehicleEngineHealth(vehicle, effects.engineHealth)
        -- Make engine smoking and stuttering
        if effects.engineHealth < 300 then
            SetVehicleEngineOn(vehicle, false, true, true)
            -- Add engine smoke
            CreateThread(function()
                while DoesEntityExist(vehicle) and GetVehicleEngineHealth(vehicle) < 300 do
                    local coords = GetEntityCoords(vehicle)
                    local engineCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, 2.5, 0.5)
                    -- Smoke effect
                    SetParticleFxNonLoopedColour(0.3, 0.3, 0.3)
                    RequestNamedPtfxAsset("core")
                    UseParticleFxAssetNextCall("core")
                    StartParticleFxNonLoopedAtCoord("exp_grd_bzgas_smoke", engineCoords.x, engineCoords.y, engineCoords.z, 0.0, 0.0, 0.0, 0.3, false, false, false)
                    Wait(2000 + math.random(1000, 3000))
                end
            end)
        end
    end
    
    if effects.engineOn == false then
        SetVehicleEngineOn(vehicle, false, true, true)
        -- Disable engine starting
        SetVehicleUndriveable(vehicle, true)
    end
    
    -- Tire damage effects
    if effects.tireHealth then
        for i = 0, 7 do -- All wheels
            SetVehicleWheelHealth(vehicle, i, effects.tireHealth)
            if effects.tireHealth < 500 then
                -- Make tire look damaged
                SetVehicleWheelHealth(vehicle, i, effects.tireHealth * 0.5)
            end
        end
    end
    
    if effects.tyreBurst then
        local tireDamageType = effects.tireDamageType or 'random'
        local numTiresToBurst = 1
        
        -- Determine tire damage scenario
        if tireDamageType == 'random' then
            local damageRoll = math.random(100)
            if damageRoll <= 70 then
                numTiresToBurst = 1 -- 70% chance: Single flat tire
            elseif damageRoll <= 90 then
                numTiresToBurst = 2 -- 20% chance: Two flat tires
            else
                numTiresToBurst = 4 -- 10% chance: All four tires flat
            end
        elseif tireDamageType == 'single' then
            numTiresToBurst = 1
        elseif tireDamageType == 'multiple' then
            numTiresToBurst = math.random(2, 3)
        elseif tireDamageType == 'all' then
            numTiresToBurst = 4
        end
        
        -- Apply tire damage
        local burstTires = {}
        local attempts = 0
        local maxAttempts = 10 -- Prevent infinite loops
        
        while #burstTires < numTiresToBurst and attempts < maxAttempts do
            attempts = attempts + 1
            local tireIndex = math.random(0, 3) -- Only main tires (0-3)
            
            if not burstTires[tireIndex] then
                SetVehicleTyreBurst(vehicle, tireIndex, true, 1000.0)
                burstTires[tireIndex] = true
            end
        end
        
        -- Visual feedback based on severity
        if numTiresToBurst >= 3 then
            -- Multiple tire failure - more dramatic
            lib.notify({
                title = 'Vehicle Issues',
                description = '⚠️ Multiple tire failure detected - severe damage!',
                type = 'warning',
                icon = 'exclamation-triangle',
                position = Notifications.position,
                duration = 5000
            })
        elseif numTiresToBurst == 2 then
            lib.notify({
                title = 'Vehicle Issues',
                description = '⚠️ Two tires are flat - handle with care',
                type = 'warning',
                icon = 'exclamation-circle',
                position = Notifications.position,
                duration = 4000
            })
        end
    end
    
    -- Fuel system effects
    if effects.petrolTankHealth then
        SetVehiclePetrolTankHealth(vehicle, effects.petrolTankHealth)
        -- If tank is damaged, create fuel leak effect
        if effects.petrolTankHealth < 500 then
            CreateThread(function()
                while DoesEntityExist(vehicle) and GetVehiclePetrolTankHealth(vehicle) < 500 do
                    local coords = GetEntityCoords(vehicle)
                    local fuelCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -2.0, -0.5)
                    -- Fuel drip effect
                    RequestNamedPtfxAsset("core")
                    UseParticleFxAssetNextCall("core")
                    StartParticleFxNonLoopedAtCoord("liquid_splash_oil", fuelCoords.x, fuelCoords.y, fuelCoords.z, 0.0, 0.0, 0.0, 0.5, false, false, false)
                    -- Slowly drain fuel
                    local currentFuel = GetVehicleFuelLevel(vehicle)
                    if currentFuel > 5.0 then
                        SetVehicleFuelLevel(vehicle, currentFuel - 0.5)
                    end
                    Wait(5000)
                end
            end)
        end
    end
    
    if effects.fuelLevel then
        SetVehicleFuelLevel(vehicle, effects.fuelLevel)
    end
    
    -- Broken windows effects
    if effects.brokenWindows then
        -- Break multiple windows randomly
        local windowsToBreak = math.random(2, 4) -- Break 2-4 windows
        local brokenWindows = {}
        
        for i = 1, windowsToBreak do
            local windowIndex = math.random(0, 7) -- Windows 0-7
            if not brokenWindows[windowIndex] then
                SmashVehicleWindow(vehicle, windowIndex)
                brokenWindows[windowIndex] = true
            end
        end
        
        -- Add some glass particle effects
        CreateThread(function()
            local coords = GetEntityCoords(vehicle)
            for i = 1, 3 do
                local glassCoords = GetOffsetFromEntityInWorldCoords(vehicle, math.random(-2, 2), math.random(-2, 2), 1.0)
                RequestNamedPtfxAsset("core")
                UseParticleFxAssetNextCall("core")
                StartParticleFxNonLoopedAtCoord("glass_smash", glassCoords.x, glassCoords.y, glassCoords.z, 0.0, 0.0, 0.0, 0.5, false, false, false)
                Wait(500)
            end
        end)
    end
    
    -- Body damage effects
    if effects.bodyDamage then
        -- Apply severe visual deformation
        SetVehicleBodyHealth(vehicle, effects.bodyHealth or 200)
        
        -- Create multiple damage points
        for i = 1, 6 do
            local damageCoords = vector3(
                math.random(-2, 2) * 1.0,
                math.random(-3, 3) * 1.0,
                math.random(-1, 1) * 0.5
            )
            SetVehicleDamage(vehicle, damageCoords.x, damageCoords.y, damageCoords.z, 500.0, 100.0, true)
        end
        
        -- Make doors potentially fall off
        if math.random(100) < 30 then -- 30% chance
            local doorIndex = math.random(0, 5)
            SetVehicleDoorBroken(vehicle, doorIndex, true)
        end
        
        -- Damage bumpers
        SetVehicleDamage(vehicle, 0.0, 3.0, 0.0, 300.0, 50.0, true) -- Front
        SetVehicleDamage(vehicle, 0.0, -3.0, 0.0, 300.0, 50.0, true) -- Rear
        
        -- Create smoke from damage
        CreateThread(function()
            for i = 1, 5 do
                local coords = GetEntityCoords(vehicle)
                local smokeCoords = GetOffsetFromEntityInWorldCoords(vehicle, math.random(-2, 2), math.random(-2, 2), 0.5)
                RequestNamedPtfxAsset("core")
                UseParticleFxAssetNextCall("core")
                StartParticleFxNonLoopedAtCoord("exp_grd_bzgas_smoke", smokeCoords.x, smokeCoords.y, smokeCoords.z, 0.0, 0.0, 0.0, 0.2, false, false, false)
                Wait(1000)
            end
        end)
    end
end

local function repairDisabilityEffects(vehicle, disability)
    local effects = disability.effects
    
    -- Repair engine systems
    if effects.engineHealth then
        SetVehicleEngineHealth(vehicle, 1000.0)
        SetVehicleEngineOn(vehicle, true, true, false)
        SetVehicleUndriveable(vehicle, false)
    end
    
    if effects.engineOn == false then
        SetVehicleEngineOn(vehicle, true, true, false)
        SetVehicleUndriveable(vehicle, false)
    end
    
    -- Repair tire systems
    if effects.tireHealth or effects.tyreBurst then
        -- Repair all tires completely
        for i = 0, 7 do
            SetVehicleWheelHealth(vehicle, i, 1000.0)
            SetVehicleTyreFixed(vehicle, i)
        end
    end
    
    -- Repair fuel system
    if effects.petrolTankHealth then
        SetVehiclePetrolTankHealth(vehicle, 1000.0)
    end
    
    if effects.fuelLevel then
        SetVehicleFuelLevel(vehicle, 75.0) -- Good fuel level after repair
    end
    

    
    -- Repair broken windows
    if effects.brokenWindows then
        -- Fix all windows
        for i = 0, 7 do
            FixVehicleWindow(vehicle, i)
        end
    end
    
    -- Repair body damage
    if effects.bodyDamage or effects.bodyHealth then
        SetVehicleBodyHealth(vehicle, 1000.0)
        -- Fix all doors (using SetVehicleFixed will handle this)
    end
    
    -- General cleanup - fix any remaining issues
    SetVehicleFixed(vehicle)
    SetVehicleDeformationFixed(vehicle)
    SetVehicleDirtLevel(vehicle, 0.0)
    
    -- Small celebration effect
    local coords = GetEntityCoords(vehicle)
    RequestNamedPtfxAsset("core")
    UseParticleFxAssetNextCall("core")
    StartParticleFxNonLoopedAtCoord("ent_sht_steam", coords.x, coords.y, coords.z + 1.0, 0.0, 0.0, 0.0, 0.8, false, false, false)
end

-- Additional essential functions (moved to top to prevent nil value errors)
local function updateStreak(success)
    if success then
        currentStreak = currentStreak + 1
        if currentStreak > playerStats.bestStreak then
            playerStats.bestStreak = currentStreak
        end
    else
        currentStreak = 0
    end
end

local function getStreakBonus()
    if not Config.EnableStreaks or currentStreak <= 1 then return 0 end
    local bonus = math.min(currentStreak - 1, Config.MaxStreak - 1) * Config.StreakBonus
    return bonus
end

local function calculateDamagePenalty(vehicle)
    if not Config.EnableDamageSystem or not vehicle then return 0 end
    local plate = GetVehicleNumberPlateText(vehicle)
    local initial = vehicleInitialHealth[plate]
    if not initial then return 0 end
    
    local current = {
        engine = GetVehicleEngineHealth(vehicle),
        body = GetVehicleBodyHealth(vehicle),
        petrolTank = GetVehiclePetrolTankHealth(vehicle)
    }
    
    local totalDamage = (initial.engine - current.engine) + 
                       (initial.body - current.body) + 
                       (initial.petrolTank - current.petrolTank)
    
    local penalty = math.floor(totalDamage * Config.DamageReduction)
    return math.max(0, penalty)
end

local function calculateRepairBonus(plate)
    if not Config.EnableRepairBonus then return 0 end
    local repaired = repairedDisabilities[plate]
    if not repaired then return 0 end
    
    local bonusCount = 0
    for _ in pairs(repaired) do
        bonusCount = bonusCount + 1
    end
    
    return bonusCount * Config.RepairBonusAmount
end

local function updateStats(earnings, deliveryTime, success)
    if not Config.ShowJobStats then return end
    
    playerStats.totalDeliveries = playerStats.totalDeliveries + 1
    playerStats.totalEarnings = playerStats.totalEarnings + earnings
    
    -- Update average delivery time
    local totalTime = playerStats.avgDeliveryTime * (playerStats.totalDeliveries - 1) + deliveryTime
    playerStats.avgDeliveryTime = totalTime / playerStats.totalDeliveries
    
    -- Update success rate
    local successCount = math.floor(playerStats.successRate * (playerStats.totalDeliveries - 1) / 100)
    if success then successCount = successCount + 1 end
    playerStats.successRate = (successCount / playerStats.totalDeliveries) * 100
end

local function showDeliveryNotification(earnings, streakBonus, damagePenalty, deliveryTime, repairBonus, distanceBonus, weatherBonus, levelBonus, timeBonus)
    debugInfo(string.format('Showing delivery notification - Base: $%d, Streak: $%d, Time: $%d, Repair: $%d, Distance: $%d, Weather: $%d, Level: $%d, Damage: -$%d', 
        earnings, streakBonus or 0, timeBonus or 0, repairBonus or 0, distanceBonus or 0, weatherBonus or 0, levelBonus or 0, damagePenalty or 0), 'paymentSystem')
    
    local title = 'Delivery Complete!'
    local description = string.format('💰 Earned: $%d', earnings)
    
    if streakBonus > 0 then
        description = description .. string.format(' (+$%d streak)', streakBonus)
        debugTrace('Added streak bonus to notification', 'paymentSystem')
    end
    
    if timeBonus and timeBonus > 0 then
        description = description .. string.format(' (+$%d time)', timeBonus)
        debugTrace('Added time bonus to notification', 'paymentSystem')
    end
    
    if repairBonus > 0 then
        description = description .. string.format(' (+$%d repair)', repairBonus)
        debugTrace('Added repair bonus to notification', 'paymentSystem')
    end
    
    if distanceBonus > 0 then
        description = description .. string.format(' (+$%d distance)', distanceBonus)
        debugTrace('Added distance bonus to notification', 'paymentSystem')
    end
    
    if weatherBonus > 0 then
        description = description .. string.format(' (+$%d weather)', weatherBonus)
        debugTrace('Added weather bonus to notification', 'paymentSystem')
    end
    
    if levelBonus and levelBonus > 0 then
        description = description .. string.format(' (+$%d level)', levelBonus)
        debugTrace('Added level bonus to notification', 'paymentSystem')
    end
    
    if damagePenalty > 0 then
        description = description .. string.format(' (-$%d damage)', damagePenalty)
        debugTrace('Added damage penalty to notification', 'paymentSystem')
    end
    
    if Config.ShowJobStats then
        description = description .. string.format('\n📊 Deliveries: %d | Streak: %d', 
            playerStats.totalDeliveries, currentStreak)
    end
    
    lib.notify({
        title = title,
        description = description,
        type = 'success',
        icon = 'truck',
        position = Notifications.position,
        duration = 5000
    })
    
    -- Play notification sound
    if Config.EnableNotificationSound then
        PlaySoundFrontend(-1, Config.NotificationSoundName or 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
        debugPrint('Played notification sound: ' .. (Config.NotificationSoundName or 'CHECKPOINT_PERFECT'))
    end
end

-- Weather bonus calculation function
local function calculateWeatherBonus()
    if not Config.EnableWeatherBonus then return 0 end
    
    -- Only use Renewed-Weathersync
    if GetResourceState('Renewed-Weathersync') ~= 'started' then
        debugPrint('Renewed-Weathersync not found - weather bonuses disabled')
        return 0
    end
    
    local currentWeather = 'CLEAR' -- Default fallback
    
    -- Get weather from Renewed-Weathersync
    local success, weather = pcall(function()
        return exports['Renewed-Weathersync']:getCurrentWeather()
    end)
    
    if success and weather then
        if type(weather) == 'string' then
            currentWeather = weather:upper()
        elseif type(weather) == 'table' and weather.weather then
            currentWeather = weather.weather:upper()
        else
            -- Try the alternative export
            local success2, weatherType = pcall(function()
                return exports['Renewed-Weathersync']:getCurrentWeatherType()
            end)
            if success2 and weatherType then
                currentWeather = weatherType:upper()
            end
        end
        debugPrint('Got weather from Renewed-Weathersync: ' .. currentWeather)
    else
        debugPrint('Failed to get weather from Renewed-Weathersync - no weather bonus applied')
        return 0
    end
    
    -- Get bonus for current weather
    local bonus = Config.WeatherBonuses[currentWeather] or 0
    
    -- Apply maximum bonus cap
    if bonus > Config.MaxWeatherBonus then
        bonus = Config.MaxWeatherBonus
    end
    
    -- Debug information
    if Config.EnableDebugMode then
        if bonus > 0 then
            debugPrint('Weather bonus applied: $' .. bonus .. ' for ' .. currentWeather .. ' weather conditions')
        else
            debugPrint('No weather bonus for ' .. currentWeather .. ' weather (clear conditions)')
        end
        
        -- Show available weather types for debugging
        local availableTypes = {}
        for weatherType, bonusAmount in pairs(Config.WeatherBonuses) do
            if bonusAmount > 0 then
                table.insert(availableTypes, weatherType .. '($' .. bonusAmount .. ')')
            end
        end
        debugPrint('Available weather bonuses: ' .. table.concat(availableTypes, ', '))
    end
    
    return bonus
end

-- Leveling System Functions
local function calculateExperienceRequired(level)
    if not Config.EnableLevelingSystem or level <= 1 then return 0 end
    return math.floor(Config.LevelingSettings.baseExperience * (Config.LevelingSettings.experienceMultiplier ^ (level - 1)))
end

local function calculateExperienceGained(baseXP, conditions)
    if not Config.EnableLevelingSystem then return 0 end
    
    local totalXP = baseXP
    local multipliers = Config.LevelingSettings.experienceMultipliers
    
    -- Apply condition-based multipliers
    if conditions.hasWeatherBonus and multipliers.weatherBonus then
        totalXP = totalXP * multipliers.weatherBonus
    end
    
    if conditions.hasStreakBonus and multipliers.streakBonus then
        totalXP = totalXP * multipliers.streakBonus
    end
    
    if conditions.hasDamage and multipliers.damageReduction then
        totalXP = totalXP * multipliers.damageReduction
    end
    
    if conditions.isQuickDelivery and multipliers.quickDelivery then
        totalXP = totalXP * multipliers.quickDelivery
    end
    
    return math.floor(totalXP)
end

local function getPlayerLevel(experience)
    if not Config.EnableLevelingSystem then return 1 end
    
    local level = 1
    local totalXPNeeded = 0
    
    for i = 1, Config.LevelingSettings.maxLevel do
        local xpForThisLevel = calculateExperienceRequired(i)
        if experience >= totalXPNeeded + xpForThisLevel then
            totalXPNeeded = totalXPNeeded + xpForThisLevel
            level = i
        else
            break
        end
    end
    
    return level
end

local function getPlayerTitle(level)
    if not Config.EnableLevelingSystem then return '' end
    
    -- Find the highest title for the player's level
    local title = Config.LevelTitles[1] or 'Rookie Driver'
    
    for levelReq, titleName in pairs(Config.LevelTitles) do
        if level >= levelReq then
            title = titleName
        end
    end
    
    return title
end

local function checkLevelUp(oldLevel, newLevel)
    if not Config.EnableLevelingSystem or newLevel <= oldLevel then return end
    
    -- Play level up sound
    if Config.LevelUpSound then
        PlaySoundFrontend(-1, Config.LevelUpSound, 'HUD_MINI_GAME_SOUNDSET', true)
    end
    
    -- Show level up notification
    local title = getPlayerTitle(newLevel)
    lib.notify({
        title = '🎉 LEVEL UP! 🎉',
        description = string.format('You are now level %d!\n%s', newLevel, title),
        type = 'success',
        icon = 'star',
        position = Notifications.position,
        duration = 8000
    })
    
    -- Check for level rewards
    local reward = Config.LevelRewards[newLevel]
    if reward then
        -- Trigger server-side reward processing
        lib.callback.await('lation_towtruck:processLevelReward', false, newLevel, reward)
        
        lib.notify({
            title = '🎁 Level Reward!',
            description = reward.message,
            type = 'success',
            icon = 'gift',
            position = Notifications.position,
            duration = 6000
        })
    end
    
    debugPrint('Player leveled up from ' .. oldLevel .. ' to ' .. newLevel .. ' (' .. title .. ')')
end

-- Exported function to handle vehicle pickup and set delivery waypoint
local function handleVehiclePickup(plate, missionPlate, vehicle)
    -- Use provided parameters or fall back to internal variables
    local checkPlate = plate or targetVehiclePlate
    local checkMissionPlate = missionPlate or missionVehPlate
    local checkVehicle = vehicle or targetVehicle
    
    if checkPlate == checkMissionPlate then
        RemoveBlip(targetCarBlip)
        if checkVehicle and DoesEntityExist(checkVehicle) then
            SetVehicleDoorShut(checkVehicle, 4, true)
        end
        -- Quality of Life: Set delivery route
        if Config.ShowDeliveryRoute then
            SetNewWaypoint(Config.DeliverLocation.x, Config.DeliverLocation.y)
            debugPrint('Set GPS route to delivery location')
        end
        
        dropOffBlip = AddBlipForCoord(Config.DeliverLocation.x, Config.DeliverLocation.y, Config.DeliverLocation.z)
        SetBlipSprite(dropOffBlip, Config.Blips.dropOff.blipSprite)
        SetBlipDisplay(dropOffBlip, 4)
        SetBlipColour(dropOffBlip, Config.Blips.dropOff.blipColor)
        SetBlipScale(dropOffBlip, Config.Blips.dropOff.blipScale)
        SetBlipAsShortRange(dropOffBlip, true)
        
        -- Quality of Life: Enhanced GPS for delivery
        if Config.EnableGPSMarker then
            SetBlipRoute(dropOffBlip, true)
            SetBlipRouteColour(dropOffBlip, Config.Blips.dropOff.blipColor)
            debugPrint('Enabled GPS route to delivery location')
        end
        
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.Blips.dropOff.blipName)
        EndTextCommandSetBlipName(dropOffBlip)
        return true
    end
    return false
end
exports('handleVehiclePickup', handleVehiclePickup)

-- Exported function to handle vehicle delivery and payment
local function handleVehicleDelivery(vehicle)
    local success, result = pcall(function()
        if not inService then
            return false
        end
        
        -- Use provided vehicle or fall back to internal variable
        local checkVehicle = vehicle or currentlyTowedVehicle
        local checkPlate = checkVehicle and GetVehicleNumberPlateText(checkVehicle) or targetVehiclePlate
        
        if not checkPlate or checkPlate == '' then
            return false
        end
        
        if checkPlate == missionVehPlate then
            local verifyLocation = lib.callback.await('lation_towtruck:checkDistance', false)
            if verifyLocation then
                -- Remove blip safely and clear GPS route
                if dropOffBlip and DoesBlipExist(dropOffBlip) then
                    if Config.EnableGPSMarker then
                        SetBlipRoute(dropOffBlip, false) -- Clear GPS route
                        debugPrint('Cleared GPS route')
                    end
                    RemoveBlip(dropOffBlip)
                end
                
                -- Calculate delivery time safely
                local deliveryTime = jobStartTime > 0 and (GetGameTimer() - jobStartTime) or 0
                
                -- Calculate bonuses and penalties with error handling
                local streakBonus = 0
                local timeBonus = 0
                local damagePenalty = 0
                local repairBonus = 0
                
                if getStreakBonus then
                    streakBonus = getStreakBonus() or 0
                end
                
                if Config.EnableTimeBonus then
                    local timeBonusResult = lib.callback.await('lation_towtruck:calculateTimeBonus', false, deliveryTime)
                    timeBonus = timeBonusResult or 0
                end
                
                if calculateDamagePenalty and checkVehicle then
                    damagePenalty = calculateDamagePenalty(checkVehicle) or 0
                end
                
                -- Calculate repair bonus for fixed disabilities
                if calculateRepairBonus and checkPlate then
                    repairBonus = calculateRepairBonus(checkPlate) or 0
                end
                
                -- Calculate distance bonus if enabled
                local distanceBonus = 0
                if Config.EnableDistanceBonus and location then
                    local pickupCoords = vec3(location.x, location.y, location.z)
                    local deliveryCoords = Config.DeliverLocation
                    distanceBonus = lib.callback.await('lation_towtruck:calculateDistanceBonus', false, pickupCoords, deliveryCoords) or 0
                end
                
                -- Calculate weather bonus
                local weatherBonus = 0
                if calculateWeatherBonus then
                    weatherBonus = calculateWeatherBonus() or 0
                end
                
                -- Prepare payment data
                local paymentData = {
                    streakBonus = streakBonus,
                    timeBonus = timeBonus,
                    damagePenalty = damagePenalty,
                    repairBonus = repairBonus,
                    distanceBonus = distanceBonus,
                    weatherBonus = weatherBonus
                }
                
                -- Process payment with enhanced system
                local paymentResult = lib.callback.await('lation_towtruck:payPlayer', false, paymentData)
                
                if paymentResult and paymentResult.success then
                    -- Update streak and stats safely
                    if updateStreak then
                        updateStreak(true)
                    end
                    
                    if updateStats then
                        updateStats(paymentResult.totalPay, deliveryTime, true)
                    end
                    
                    -- Process experience and leveling
                    if Config.EnableLevelingSystem then
                        local baseXP = Config.LevelingSettings.experiencePerDelivery
                        
                        -- Add repair bonus XP
                        if paymentResult.repairBonus > 0 then
                            baseXP = baseXP + Config.LevelingSettings.experiencePerRepair
                        end
                        
                        -- Calculate experience conditions
                        local conditions = {
                            hasWeatherBonus = (paymentResult.weatherBonus or 0) > 0,
                            hasStreakBonus = (paymentResult.streakBonus or 0) > 0,
                            hasDamage = (paymentResult.damagePenalty or 0) > 0,
                            isQuickDelivery = deliveryTime <= (Config.TimeBonusThreshold * 60000) -- Convert minutes to milliseconds
                        }
                        
                        local experienceGained = calculateExperienceGained(baseXP, conditions)
                        
                        -- Send experience to server for processing
                        lib.callback.await('lation_towtruck:addExperience', false, experienceGained, conditions)
                    end
                    
                    -- Show enhanced notification safely
                    if showDeliveryNotification then
                        showDeliveryNotification(
                            paymentResult.basePay,
                            paymentResult.streakBonus, 
                            paymentResult.damagePenalty,
                            deliveryTime,
                            paymentResult.repairBonus,
                            paymentResult.distanceBonus,
                            paymentResult.weatherBonus,
                            paymentResult.levelBonus,
                            paymentResult.timeBonus
                        )
                    else
                        -- Fallback notification
                        lib.notify({
                            title = Notifications.title,
                            description = string.format('Job completed! Payment: $%d', paymentResult.totalPay),
                            type = 'success',
                            icon = Notifications.icon,
                            position = Notifications.position
                        })
                    end
                    
                    -- Trigger job completion cleanup by plate
                    if checkPlate and checkPlate ~= '' then
                        debugPrint(string.format('Triggering job completion cleanup for plate: %s', checkPlate), 'database')
                        TriggerServerEvent('lation_towing:jobCompleted', checkPlate)
                    end
                    
                    -- Clean up vehicle
                    if checkVehicle and DoesEntityExist(checkVehicle) then
                        DeleteEntity(checkVehicle)
                    end
                    
                    -- Update internal variable if we used external vehicle
                    if vehicle then
                        currentlyTowedVehicle = nil
                    end
                    
                    -- Clean up health tracking safely
                    if vehicleInitialHealth and checkPlate then
                        vehicleInitialHealth[checkPlate] = nil
                    end
                    
                    -- Clean up disability tracking
                    if vehicleDisabilities and checkPlate then
                        vehicleDisabilities[checkPlate] = nil
                    end
                    if repairedDisabilities and checkPlate then
                        repairedDisabilities[checkPlate] = nil
                    end
                    
                    -- Release location reservation
                    if Config.EnableLocationReservation and locationKey then
                        lib.callback.await('lation_towtruck:releaseLocation', false, locationKey)
                        debugPrint('Released location reservation: ' .. locationKey)
                        locationKey = nil
                    end
                    
                    -- Continue with next job if function exists
                    if startNextJob then
                        startNextJob()
                    end
                    jobAssigned = false
                    currentJobs = math.max(0, currentJobs - 1) -- Decrement current jobs
                    debugPrint('Job completed. Current jobs: ' .. currentJobs)
                end
                return true
            else
                lib.notify({
                    title = Notifications.title,
                    description = Notifications.tooFarToDeliver,
                    type = 'error',
                    icon = Notifications.icon,
                    position = Notifications.position
                })
                return false
            end
        end
        return false
    end)
    
    if not success then
        print('[lation_towing] handleVehicleDelivery error: ' .. tostring(result))
        return false
    end
    
    return result
end
exports('handleVehicleDelivery', handleVehicleDelivery)

-- Simple fallback version without advanced features
local function handleVehicleDeliverySimple(vehicle)
    local success, result = pcall(function()
        if not inService then
            return false
        end
        
        local checkVehicle = vehicle or currentlyTowedVehicle
        local checkPlate = checkVehicle and GetVehicleNumberPlateText(checkVehicle) or targetVehiclePlate
        
        if not checkPlate or checkPlate == '' or checkPlate ~= missionVehPlate then
            return false
        end
        
        local verifyLocation = lib.callback.await('lation_towtruck:checkDistance', false)
        if verifyLocation then
            -- Remove blip safely
            if dropOffBlip and DoesBlipExist(dropOffBlip) then
                RemoveBlip(dropOffBlip)
            end
            
            -- Simple payment without bonuses
            local paymentResult = lib.callback.await('lation_towtruck:payPlayer', false)
            
            if paymentResult then
                -- Basic notification
                lib.notify({
                    title = Notifications.title,
                    description = 'Job completed! Payment received.',
                    type = 'success',
                    icon = Notifications.icon,
                    position = Notifications.position
                })
                
                -- Trigger job completion cleanup by plate
                if checkPlate and checkPlate ~= '' then
                    debugPrint(string.format('Triggering job completion cleanup for plate: %s', checkPlate), 'database')
                    TriggerServerEvent('lation_towing:jobCompleted', checkPlate)
                end
                
                -- Clean up vehicle
                if checkVehicle and DoesEntityExist(checkVehicle) then
                    DeleteEntity(checkVehicle)
                end
                
                if vehicle then
                    currentlyTowedVehicle = nil
                end
                
                -- Continue with next job if function exists
                if startNextJob then
                    startNextJob()
                end
                jobAssigned = false
                return true
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
        return false
    end)
    
    if not success then
        print('[lation_towing] handleVehicleDeliverySimple error: ' .. tostring(result))
        return false
    end
    
    return result
end

exports('handleVehicleDeliverySimple', handleVehicleDeliverySimple)

-- Track if towing menu is registered
local towingMenuRegistered = false
local hasTowingMenuItem = false

-- Function to check if player has the required job
local function hasRequiredJob()
    -- Handle different JobName formats
    local requiredJobs = {}
    if type(Config.JobName) == 'string' then
        table.insert(requiredJobs, Config.JobName)
    elseif type(Config.JobName) == 'table' then
        -- Handle array of job names
        for _, job in ipairs(Config.JobName) do
            if type(job) == 'string' then
                table.insert(requiredJobs, job)
            end
        end
        -- Handle single job object format
        if Config.JobName.name then
            table.insert(requiredJobs, Config.JobName.name)
        end
    end
    
    if #requiredJobs == 0 then
        debugTrace('No job restriction set - showing menu to everyone', 'radialMenu')
        return true -- If no job restriction, show to everyone
    end
    
    debugTrace('Checking job requirements: ' .. table.concat(requiredJobs, ', '), 'radialMenu')
    
    -- QBCore job checking only
    if Config.Framework == 'qbcore' then
        local success, QBCore = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        
        if success and QBCore then
            local playerData = QBCore.Functions.GetPlayerData()
            if playerData and playerData.job then
                debugTrace('Player job (QBCore): ' .. (playerData.job.name or 'none'), 'radialMenu')
                
                -- Check if player's job matches any of the required jobs
                for _, requiredJob in ipairs(requiredJobs) do
                    if playerData.job.name == requiredJob then
                        debugTrace('Job match found: ' .. requiredJob, 'radialMenu')
                        return true
                    end
                end
                debugTrace('Player job does not match any required jobs', 'radialMenu')
                return false
            end
        else
            debugWarn('QBCore not available - showing menu to everyone', 'radialMenu')
            return true
        end
    else
        debugWarn('Unknown framework or no framework set - showing menu to everyone', 'radialMenu')
        return true
    end
    
    debugWarn('Job check failed - hiding menu', 'radialMenu')
    return false
end

-- Function to manage the main towing menu item
local function manageTowingMenuItem()
    local shouldShowForJob = hasRequiredJob()
    local shouldShowForService = inService -- Only show menu when actually in service
    local shouldShow = shouldShowForJob and shouldShowForService
    
    if shouldShow and not hasTowingMenuItem then
        -- Add the main towing menu item
        lib.addRadialItem({
            id = 'towing_main',
            label = 'Towing\nService options',
            icon = 'truck',
            menu = 'towing_menu'
        })
        hasTowingMenuItem = true
        -- Safe JobName display for debug
        local jobNameForDebug = 'any'
        if type(Config.JobName) == 'string' then
            jobNameForDebug = Config.JobName
        elseif type(Config.JobName) == 'table' then
            jobNameForDebug = table.concat(Config.JobName, ', ')
        end
        debugTrace('Added main towing menu item for job: ' .. jobNameForDebug, 'radialMenu')
        
        -- Update submenu items
        -- updateTowingSubmenu()
        
    elseif not shouldShow and hasTowingMenuItem then
        -- Remove the main towing menu item if job doesn't match or not in service
        lib.removeRadialItem('towing_main')
        hasTowingMenuItem = false
        debugTrace('Removed main towing menu item (wrong job or not in service)', 'radialMenu')
        
    elseif shouldShow and hasTowingMenuItem then
        -- Menu is showing and conditions match - no need to constantly update
        -- Only update submenu when explicitly requested (via /towmenu command)
        debugTrace('Towing menu already active and conditions valid - no update needed', 'radialMenu')
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
    startPerformanceTimer('spawnTowTruck')
    debugInfo('Attempting to spawn tow truck', 'vehicleManagement')
    
    local nearbyVehicles = lib.getClosestVehicle(Config.SpawnTruckLocation, 3, false)
    if nearbyVehicles == nil then
        debugTrace('No nearby vehicles blocking spawn location', 'vehicleManagement')
        lib.requestModel('flatbed')
        debugTrace('Requested flatbed model', 'vehicleManagement')
        
        vehicle = CreateVehicle('flatbed', Config.SpawnTruckLocation.x, Config.SpawnTruckLocation.y, Config.SpawnTruckLocation.z, Config.SpawnTruckHeading, true, true)
        debugSuccess(string.format('Tow truck spawned with entity ID: %d', vehicle), 'vehicleManagement')
        
        -- Quality of Life: Auto repair and fuel level
        if Config.AutoRepairTowTruck then
            SetVehicleFixed(vehicle)
            SetVehicleDeformationFixed(vehicle)
            SetVehicleDirtLevel(vehicle, 0.0)
            debugTrace('Auto-repaired tow truck on spawn', 'vehicleManagement')
        end
        
        -- Set custom fuel level
        Entity(vehicle).state.fuel = Config.TowTruckFuel or 100.0
        debugTrace(string.format('Set tow truck fuel to: %d', Config.TowTruckFuel or 100), 'vehicleManagement')
        
        local truckPlate = GetVehicleNumberPlateText(vehicle)
        debugTrace(string.format('Tow truck plate: %s', truckPlate), 'vehicleManagement')
        
        if Config.Framework == 'qbcore' then
            TriggerEvent('qb-vehiclekeys:client:AddKeys', truckPlate)
            debugTrace('Added QBCore vehicle keys', 'frameworkIntegration')
        end
        if Config.EnableCarKeys then
            spawnedVehiclePlate = truckPlate
            
            exports.wasabi_carlock:GiveKey(spawnedVehiclePlate)
            debugTrace('Gave car keys via wasabi_carlock', 'frameworkIntegration')
            -- Example: exports.wasabi_carlock:GiveKey(spawnedVehiclePlate)
            -- Insert give car keys export here
        end
        spawnedVehicle = vehicle
        inService = true
        
        -- Update radial menu to show towing options when in service
        manageTowingMenuItem()
        
        endPerformanceTimer('spawnTowTruck', true)
        debugSuccess('Tow truck spawn completed successfully', 'vehicleManagement')
    else
        debugWarn('Spawn location occupied by nearby vehicles', 'vehicleManagement')
        lib.notify({
            title = Notifications.title,
            description = Notifications.towTruckSpawnOccupied,
            icon = Notifications.icon,
            type = 'error',
            position = Notifications.position
        })
        endPerformanceTimer('spawnTowTruck', true)
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
        inService = false
        jobAssigned = false
        enabledCalls = false
        endJob()
       
    end
end

-- Cache location keys for better performance
local locationKeys = {}
for key, _ in pairs(Config.Locations) do
    table.insert(locationKeys, key)
end

-- Advanced Features: Vehicle Variety and Location Prevention
local recentVehicles = {} -- Track recent vehicle types
local recentLocations = {} -- Track recent locations

-- Streak System Functions
local function updateStreak(success)
    if success then
        currentStreak = currentStreak + 1
        if currentStreak > playerStats.bestStreak then
            playerStats.bestStreak = currentStreak
        end
    else
        currentStreak = 0
    end
end

local function getStreakBonus()
    if not Config.EnableStreaks or currentStreak <= 1 then return 0 end
    local bonus = math.min(currentStreak - 1, Config.MaxStreak - 1) * Config.StreakBonus
    return bonus
end

-- Vehicle Damage System Functions
local function recordVehicleHealth(vehicle)
    if not Config.EnableDamageSystem or not vehicle then return end
    local plate = GetVehicleNumberPlateText(vehicle)
    vehicleInitialHealth[plate] = {
        engine = GetVehicleEngineHealth(vehicle),
        body = GetVehicleBodyHealth(vehicle),
        petrolTank = GetVehiclePetrolTankHealth(vehicle)
    }
end

local function calculateDamagePenalty(vehicle)
    if not Config.EnableDamageSystem or not vehicle then return 0 end
    local plate = GetVehicleNumberPlateText(vehicle)
    local initial = vehicleInitialHealth[plate]
    if not initial then return 0 end
    
    local current = {
        engine = GetVehicleEngineHealth(vehicle),
        body = GetVehicleBodyHealth(vehicle),
        petrolTank = GetVehiclePetrolTankHealth(vehicle)
    }
    
    local totalDamage = (initial.engine - current.engine) + 
                       (initial.body - current.body) + 
                       (initial.petrolTank - current.petrolTank)
    
    local penalty = math.floor(totalDamage * Config.DamageReduction)
    return math.max(0, penalty)
end

-- Car Disability System Functions
local function generateRandomDisabilities(vehicle)
    if not Config.EnableCarDisabilities then return {} end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    local disabilities = {}
    
    -- Check if this vehicle should have ANY disabilities
    if math.random(100) > Config.GlobalDisabilityChance then
        return disabilities
    end
    
    -- Get available disability types (only enabled ones)
    local availableDisabilities = {}
    for disabilityType, disabilityConfig in pairs(Config.CarDisabilities) do
        if disabilityConfig.enabled then
            table.insert(availableDisabilities, {
                type = disabilityType,
                chance = disabilityConfig.chance,
                config = disabilityConfig
            })
        end
    end
    
    if #availableDisabilities == 0 then
        return disabilities
    end
    
    -- Determine if vehicle gets multiple disabilities
    local allowMultiple = Config.MultipleDisabilities and math.random(100) <= Config.MultipleDisabilityChance
    local maxDisabilities = allowMultiple and Config.MaxDisabilities or 1
    
    -- Apply disabilities based on individual chances
    local appliedDisabilities = {}
    local attempts = 0
    local maxAttempts = #availableDisabilities * 2 -- Prevent infinite loops
    
    while #appliedDisabilities < maxDisabilities and attempts < maxAttempts do
        attempts = attempts + 1
        
        -- Select a random disability type
        local randomIndex = math.random(1, #availableDisabilities)
        local disabilityData = availableDisabilities[randomIndex]
        local disabilityType = disabilityData.type
        local disabilityChance = disabilityData.chance
        local disabilityConfig = disabilityData.config
        
        -- Skip if already applied
        if appliedDisabilities[disabilityType] then
            goto continue
        end
        
        -- Prevent broken_windows and body_damage from being applied together
        if disabilityType == 'broken_windows' and appliedDisabilities['body_damage'] then
            goto continue
        end
        if disabilityType == 'body_damage' and appliedDisabilities['broken_windows'] then
            goto continue
        end
        
        -- Check individual disability chance
        if math.random(100) <= disabilityChance then
            -- Apply disability effects to vehicle
            applyDisabilityEffects(vehicle, disabilityConfig)
            
            -- Store disability info
            disabilities[disabilityType] = {
                name = disabilityConfig.name,
                description = disabilityConfig.description,
                repaired = false
            }
            
            appliedDisabilities[disabilityType] = true
            
            -- If not allowing multiple, break after first one
            if not allowMultiple then
                break
            end
        end
        
        ::continue::
    end
    
    vehicleDisabilities[plate] = disabilities
    return disabilities
end

local function getVehicleDisabilities(vehicle)
    if not vehicle then 
        debugTrace('getVehicleDisabilities: No vehicle provided', 'disabilitySystem')
        return {} 
    end
    local plate = GetVehicleNumberPlateText(vehicle)
    local disabilities = vehicleDisabilities[plate] or {}
    
    debugTrace(string.format('getVehicleDisabilities: Vehicle %d (plate: %s) has %d disabilities', 
        vehicle, plate, disabilities and (function() local count = 0; for _ in pairs(disabilities) do count = count + 1 end; return count end)() or 0), 'disabilitySystem')
    
    return disabilities
end

local function repairVehicleDisability(vehicle, disabilityType)
    startPerformanceTimer('repairVehicleDisability')
    debugInfo(string.format('Attempting to repair disability: %s', disabilityType), 'disabilitySystem')
    
    if not vehicle or not DoesEntityExist(vehicle) then 
        debugError('Vehicle does not exist for repair', 'disabilitySystem')
        return false 
    end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    local disabilities = vehicleDisabilities[plate]
    
    debugTrace(string.format('Checking disabilities for vehicle %s', plate), 'disabilitySystem')
    
    if not disabilities or not disabilities[disabilityType] then 
        debugWarn(string.format('Disability %s not found for vehicle %s', disabilityType, plate), 'disabilitySystem')
        return false 
    end
    
    local disability = Config.CarDisabilities[disabilityType]
    if not disability then 
        debugError(string.format('Disability config not found for type: %s', disabilityType), 'disabilitySystem')
        return false 
    end
    
    -- Check for required repair item
    if Config.RequireRepairTools and disability.repairItem then
        debugTrace(string.format('Checking for required repair item: %s', disability.repairItem), 'disabilitySystem')
        if not hasRequiredItem(disability.repairItem) then
            debugWarn(string.format('Player missing required repair item: %s', disability.repairItem), 'disabilitySystem')
            lib.notify({
                title = Notifications.title,
                description = 'You need a ' .. disability.repairItem .. ' to repair this!',
                type = 'error',
                icon = 'times',
                position = Notifications.position
            })
            return false
        end
        debugSuccess(string.format('Player has required repair item: %s', disability.repairItem), 'disabilitySystem')
    end
    
    -- Calculate repair time based on severity (for tire repairs)
    local repairTime = disability.repairTime
    if disabilityType == 'flat_tire' then
        -- Count how many tires are actually burst to adjust repair time
        local burstCount = 0
        for i = 0, 3 do
            if IsVehicleTyreBurst(vehicle, i, false) then
                burstCount = burstCount + 1
            end
        end
        
        if burstCount >= 4 then
            repairTime = repairTime * 2.5 -- All 4 tires takes much longer
        elseif burstCount >= 2 then
            repairTime = repairTime * 1.5 -- Multiple tires takes longer
        end
    end
    
    -- Show repair progress
    lib.notify({
        title = Notifications.title,
        description = Notifications.repairStarted,
        type = 'info',
        icon = 'wrench',
        position = Notifications.position
    })
    
    -- Start repair animation
    local success = lib.progressCircle({
        label = 'Repairing ' .. disability.name .. '...',
        duration = repairTime,
        position = 'middle',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            scenario = disability.repairAnim
        }
    })
    
    if success then
        -- Remove required item if repair tools are enabled and keepItem is false
        if Config.RequireRepairTools and disability.repairItem and not disability.keepItem then
            removeRequiredItem(disability.repairItem)
        end
        
        -- Apply repair effects (opposite of disability effects)
        repairDisabilityEffects(vehicle, disability)
        
        -- Mark as repaired
        disabilities[disabilityType].repaired = true
        
        -- Track for bonus calculation
        if not repairedDisabilities[plate] then
            repairedDisabilities[plate] = {}
        end
        repairedDisabilities[plate][disabilityType] = true
        
        lib.notify({
            title = Notifications.title,
            description = Notifications.repairCompleted,
            type = 'success',
            icon = 'check',
            position = Notifications.position
        })
        
        -- Refresh ox_target options (remove repaired items)
        removeVehicleRepairTargets(vehicle)
        addVehicleRepairTargets(vehicle)
        
        endPerformanceTimer('repairVehicleDisability', true)
        debugSuccess(string.format('Vehicle disability %s repaired successfully', disabilityType), 'disabilitySystem')
        return true
    else
        debugWarn('Vehicle repair cancelled by player', 'disabilitySystem')
        lib.notify({
            title = Notifications.title,
            description = Notifications.repairCancelled,
            type = 'error',
            icon = 'times',
            position = Notifications.position
        })
        endPerformanceTimer('repairVehicleDisability', true)
        return false
    end
end

local function calculateRepairBonus(plate)
    if not Config.EnableRepairBonus then return 0 end
    
    local repaired = repairedDisabilities[plate]
    if not repaired then return 0 end
    
    local bonusCount = 0
    for _ in pairs(repaired) do
        bonusCount = bonusCount + 1
    end
    
    return bonusCount * Config.RepairBonusAmount
end

-- ox_target functions for vehicle repairs
addVehicleRepairTargets = function(vehicle)
    debugTrace('Adding ox_target repair targets', 'oxTargetSystem')
    
    if not Config.UseOxTarget then 
        debugTrace('ox_target disabled in config', 'oxTargetSystem')
        return 
    end
    if not vehicle or not DoesEntityExist(vehicle) then 
        debugWarn('Vehicle does not exist for ox_target setup', 'oxTargetSystem')
        return 
    end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    local disabilities = vehicleDisabilities[plate]
    
    debugTrace(string.format('Setting up ox_target for vehicle %s', plate), 'oxTargetSystem')
    
    if not disabilities then 
        debugTrace(string.format('No disabilities found for vehicle %s', plate), 'oxTargetSystem')
        return 
    end
    
    local targetOptions = {}
    
    for disabilityType, disabilityData in pairs(disabilities) do
        if not disabilityData.repaired then
            local config = Config.CarDisabilities[disabilityType]
            if config and config.targetOptions then
                debugTrace(string.format('Adding ox_target option for disability: %s', disabilityType), 'oxTargetSystem')
                
                -- Check if item is required and available
                local canRepair = true
                local itemText = ""
                
                if Config.RequireRepairTools and config.repairItem then
                    canRepair = hasRequiredItem(config.repairItem)
                    if canRepair then
                        itemText = config.keepItem and " (Uses: " .. config.repairItem .. ")" or ""
                    else
                        itemText = " (Need: " .. config.repairItem .. ")"
                    end
                end
                
                if config.targetBones then
                    -- Multiple bones (like tires, windows, body parts)
                    for _, bone in pairs(config.targetBones) do
                        -- For flat tires, only show option if that specific tire is flat
                        local showOption = true
                        if disabilityType == 'flat_tire' then
                            local tireIndex = nil
                            if bone == 'wheel_lf' then tireIndex = 0
                            elseif bone == 'wheel_rf' then tireIndex = 1
                            elseif bone == 'wheel_lr' then tireIndex = 2
                            elseif bone == 'wheel_rr' then tireIndex = 3
                            end
                            
                            if tireIndex then
                                showOption = IsVehicleTyreBurst(vehicle, tireIndex, false)
                                debugTrace(string.format('Tire %d (%s) burst status: %s', tireIndex, bone, tostring(showOption)), 'oxTargetSystem')
                            else
                                debugWarn(string.format('Unknown tire bone: %s', bone), 'oxTargetSystem')
                            end
                        end
                        
                        if showOption then
                            debugTrace(string.format('Adding ox_target option for bone: %s (disability: %s)', bone, disabilityType), 'oxTargetSystem')
                            table.insert(targetOptions, {
                                bones = {bone},
                                label = config.targetOptions.label .. itemText,
                                icon = config.targetOptions.icon,
                                distance = config.targetOptions.distance,
                                canInteract = function(entity, distance, coords, name, bone)
                                    debugTrace(string.format('ox_target canInteract check - bone: %s, canRepair: %s', bone or 'nil', tostring(canRepair)), 'oxTargetSystem')
                                    return canRepair
                                end,
                                onSelect = function(data)
                                    debugInfo(string.format('ox_target selected for %s repair', disabilityType), 'oxTargetSystem')
                                    repairVehicleDisability(vehicle, disabilityType)
                                end
                            })
                        else
                            debugTrace(string.format('Skipping ox_target option for bone: %s (not needed)', bone), 'oxTargetSystem')
                        end
                    end
                else
                    -- Single bone
                    debugTrace(string.format('Adding ox_target option for single bone: %s (disability: %s)', config.targetBone, disabilityType), 'oxTargetSystem')
                    table.insert(targetOptions, {
                        bones = {config.targetBone},
                        label = config.targetOptions.label .. itemText,
                        icon = config.targetOptions.icon,
                        distance = config.targetOptions.distance,
                        canInteract = function(entity, distance, coords, name, bone)
                            debugTrace(string.format('ox_target canInteract check - bone: %s, canRepair: %s', bone or 'nil', tostring(canRepair)), 'oxTargetSystem')
                            return canRepair
                        end,
                        onSelect = function(data)
                            debugInfo(string.format('ox_target selected for %s repair', disabilityType), 'oxTargetSystem')
                            repairVehicleDisability(vehicle, disabilityType)
                        end
                    })
                end
            end
        end
    end
    
    if #targetOptions > 0 then
        debugSuccess(string.format('Adding %d ox_target options to vehicle', #targetOptions), 'oxTargetSystem')
        -- Use the correct ox_target method - addLocalEntity works for all entities including vehicles
        exports.ox_target:addLocalEntity(vehicle, targetOptions)
    else
        debugWarn('No ox_target options to add', 'oxTargetSystem')
    end
end

removeVehicleRepairTargets = function(vehicle)
    debugTrace('Removing ox_target repair targets', 'oxTargetSystem')
    
    if not Config.UseOxTarget then 
        debugTrace('ox_target disabled in config', 'oxTargetSystem')
        return 
    end
    if not vehicle or not DoesEntityExist(vehicle) then 
        debugWarn('Vehicle does not exist for ox_target removal', 'oxTargetSystem')
        return 
    end
    
    debugTrace('Removing ox_target options from vehicle', 'oxTargetSystem')
    exports.ox_target:removeLocalEntity(vehicle)
end

-- Statistics Functions
local function updateStats(earnings, deliveryTime, success)
    playerStats.totalDeliveries = playerStats.totalDeliveries + 1
    if success then
        playerStats.totalEarnings = playerStats.totalEarnings + earnings
    end
    
    -- Update average delivery time
    local totalTime = playerStats.avgDeliveryTime * (playerStats.totalDeliveries - 1) + deliveryTime
    playerStats.avgDeliveryTime = totalTime / playerStats.totalDeliveries
    
    -- Update success rate (simplified)
    -- In a real implementation, you'd track failures too
end

-- Stats Display Function
local function showPlayerStats()
    local avgMinutes = math.floor(playerStats.avgDeliveryTime / 60)
    local avgSeconds = math.floor(playerStats.avgDeliveryTime % 60)
    
    local statsText = string.format(
        'Towing Statistics:\n' ..
        'Total Deliveries: %d\n' ..
        'Total Earnings: $%d\n' ..
        'Current Streak: %d\n' ..
        'Best Streak: %d\n' ..
        'Avg Delivery Time: %dm %ds\n' ..
        'Success Rate: %.1f%%',
        playerStats.totalDeliveries,
        playerStats.totalEarnings,
        currentStreak,
        playerStats.bestStreak,
        avgMinutes,
        avgSeconds,
        playerStats.successRate
    )
    
    lib.notify({
        title = 'Towing Stats',
        description = statsText,
        icon = 'chart-bar',
        type = 'info',
        position = Notifications.position,
        duration = 10000
    })
end

-- Export stats function
exports('showTowingStats', showPlayerStats)

-- Register command to show stats
RegisterCommand('towstats', function()
    showPlayerStats()
end, false)

-- Function to update towing submenu items
local function updateTowingSubmenu()
    debugTrace('Updating towing submenu items', 'radialMenu')
    
    -- Initialize submenu items array
    local submenuItems = {}
    
    if inService then
        local playerCoords = GetEntityCoords(cache.ped)
        local vehicle = lib.getClosestVehicle(playerCoords, 10, false)
        
        -- Get vehicle disabilities for all menu checks
        local disabilities = {}
        local hasDisabilities = false
        local unrepairedCount = 0
        
        if vehicle and vehicle ~= 0 then
            disabilities = getVehicleDisabilities(vehicle)
            hasDisabilities = disabilities and next(disabilities) ~= nil
            
            -- Count unrepaired disabilities
            if hasDisabilities then
                for _, disability in pairs(disabilities) do
                    if not disability.repaired then
                        unrepairedCount = unrepairedCount + 1
                    end
                end
            end
        end
        
        -- Vehicle repair and inspection options
        if vehicle and vehicle ~= 0 then
            -- Add repair vehicle option
            table.insert(submenuItems, {
                label = 'Repair Vehicle',
                icon = 'wrench',
                onSelect = function()
                    debugInfo('Radial submenu: Opening repair menu', 'radialMenu')
                    
                    -- Get fresh disability data when callback is executed
                    local playerCoords = GetEntityCoords(cache.ped)
                    local currentVehicle = lib.getClosestVehicle(playerCoords, 10, false)
                    
                    if currentVehicle and currentVehicle ~= 0 then
                        local currentDisabilities = getVehicleDisabilities(currentVehicle)
                        local currentHasDisabilities = currentDisabilities and next(currentDisabilities) ~= nil
                        
                        debugTrace(string.format('Repair callback - Vehicle: %d, Disabilities found: %s', 
                            currentVehicle, tostring(currentHasDisabilities)), 'radialMenu')
                        
                        if currentHasDisabilities then
                            showRepairMenu(currentVehicle, currentDisabilities)
                        else
                            lib.notify({
                                title = Notifications.title,
                                description = 'This vehicle has no issues to repair',
                                type = 'info',
                                icon = 'check',
                                position = Notifications.position
                            })
                        end
                    else
                        lib.notify({
                            title = Notifications.title,
                            description = 'No vehicle found nearby to repair.',
                            type = 'error',
                            icon = 'exclamation-triangle',
                            position = Notifications.position
                        })
                    end
                end
            })
            
            -- Add vehicle inspection option
            table.insert(submenuItems, {
                label = 'Check condition',
                icon = 'search',
                onSelect = function()
                    debugInfo('Radial submenu: Inspecting vehicle', 'radialMenu')
                    
                    -- Get fresh disability data when callback is executed
                    local playerCoords = GetEntityCoords(cache.ped)
                    local currentVehicle = lib.getClosestVehicle(playerCoords, 10, false)
                    
                    if currentVehicle and currentVehicle ~= 0 then
                        local currentDisabilities = getVehicleDisabilities(currentVehicle)
                        local currentHasDisabilities = currentDisabilities and next(currentDisabilities) ~= nil
                        
                        debugTrace(string.format('Inspection callback - Vehicle: %d, Disabilities found: %s', 
                            currentVehicle, tostring(currentHasDisabilities)), 'radialMenu')
                        
                        if currentHasDisabilities then
                            showVehicleInspection(currentVehicle, currentDisabilities)
                        else
                            lib.notify({
                                title = '🔍 Inspection Report',
                                description = 'Vehicle Inspection Report:\n\nNo issues detected!\nVehicle is in good condition.',
                                type = 'success',
                                icon = 'clipboard-check',
                                position = Notifications.position,
                                duration = 5000
                            })
                        end
                    else
                        lib.notify({
                            title = '🔍 Inspection Report',
                            description = 'No vehicle found nearby to inspect.',
                            type = 'error',
                            icon = 'exclamation-triangle',
                            position = Notifications.position,
                            duration = 3000
                        })
                    end
                end
            })
        end
        
        -- Job management options
        table.insert(submenuItems, {
            label = 'Job Statistics',
            icon = 'chart-bar',
            onSelect = function()
                debugInfo('Radial submenu: Showing job statistics', 'radialMenu')
                showPlayerStats()
            end
        })
        
        table.insert(submenuItems, {
            label = '🚪 Stop towing service',
            icon = 'sign-out-alt',
                onSelect = function()
                    debugInfo('Radial submenu: Ending job', 'radialMenu')
                    local confirm = lib.alertDialog({
                        header = 'End Towing Job',
                        content = 'Are you sure you want to end your current towing job? This will return your truck and reset your streak.',
                        centered = true,
                        cancel = true,
                        labels = {
                            cancel = 'Cancel',
                            confirm = 'End Job'
                        }
                    })
                    
                    if confirm == 'confirm' then
                        inService = false
                        jobAssigned = false
                        enabledCalls = false
                        endJob()
                     
                        lib.notify({
                            title = Notifications.title,
                            description = 'Towing job ended successfully',
                            type = 'success',
                            icon = 'check',
                            position = Notifications.position
                        })
                    end
                end
            })
    end -- end if inService
    
    -- Add general help option if no other options available
    if #submenuItems == 0 then
        table.insert(submenuItems, {
            label = 'No Actions Available',
            icon = 'info-circle'
        })
    end
    
    -- Register/update the submenu
    lib.registerRadial({
        id = 'towing_menu',
        items = submenuItems
    })
    
    towingMenuRegistered = true
    debugTrace(string.format('Updated towing submenu with %d items', #submenuItems), 'radialMenu')
end

-- Function to show towing radial menu (now just manages the menu)
local function showTowingRadialMenu()
    debugTrace('Managing towing radial menu', 'radialMenu')
    manageTowingMenuItem()
end

-- Register command to manually refresh towing radial menu
-- RegisterCommand('towmenu', function()
--     debugTrace('Towing radial menu command executed', 'radialMenu')
--     showTowingRadialMenu()
--     -- Force update submenu content when manually requested
--     if hasTowingMenuItem then
--         updateTowingSubmenu()
--         debugTrace('Forced submenu update via /towmenu command', 'radialMenu')
--     end
--     lib.notify({
--         title = 'Towing Menu',
--         description = 'Towing options updated in radial menu (F1/Z)',
--         type = 'info',
--         icon = 'truck',
--         position = 'top-right',
--         duration = 3000
--     })
-- end, false)

-- Debug command to check towing menu status
RegisterCommand('towdebug', function()
    local hasJob = hasRequiredJob()
    
    -- Get current player job for display
    local currentJob = 'unknown'
    if Config.Framework == 'qbcore' then
        local success, QBCore = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if success and QBCore then
            local playerData = QBCore.Functions.GetPlayerData()
            if playerData and playerData.job then
                currentJob = playerData.job.name or 'none'
            end
        end
    end
    
    -- Safely handle JobName for display
    local jobNameDisplay = 'none'
    if type(Config.JobName) == 'string' then
        jobNameDisplay = Config.JobName
    elseif type(Config.JobName) == 'table' then
        jobNameDisplay = table.concat(Config.JobName, ', ')
    else
        jobNameDisplay = 'type: ' .. type(Config.JobName)
    end
    
    local status = string.format(
        'Towing Menu Debug:\nFramework: %s\nRequired Jobs: %s\nCurrent Job: %s\nHas Required Job: %s\nMenu Item Added: %s',
        Config.Framework or 'none',
        jobNameDisplay,
        currentJob,
        tostring(hasJob),
        tostring(hasTowingMenuItem)
    )
    
    lib.notify({
        title = 'Towing Debug',
        description = status,
        type = 'info',
        icon = 'bug',
        position = 'top-right',
        duration = 8000
    })
    
    print('=== TOWING DEBUG ===')
    print(status)
    print('==================')
end, false)

-- Initialize towing radial menu system
CreateThread(function()
    Wait(2000) -- Wait for ox_lib and framework to initialize
    
    debugInfo('Initializing towing radial menu system...', 'radialMenu')
    debugInfo('Framework: ' .. (Config.Framework or 'none'), 'radialMenu')
    debugInfo('Required Job: ' .. (type(Config.JobName) == 'string' and Config.JobName or 'table/other'), 'radialMenu')
    
    -- Force initial menu setup
    manageTowingMenuItem()
    
    debugInfo('Towing radial menu system initialized - accessible via /towmenu command', 'radialMenu')
end)

-- Listen for QBCore job changes to update menu when needed
if Config.Framework == 'qbcore' then
    RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
        debugTrace('Job changed, updating towing menu', 'radialMenu')
        manageTowingMenuItem()
    end)
end

-- Export the radial menu function
exports('showTowingRadialMenu', showTowingRadialMenu)

-- Remove the automatic thread that was causing menu flashing
-- The menu is now managed only when needed (job changes, manual refresh, etc.)



-- Function to show vehicle inspection
function showVehicleInspection(vehicle, disabilities)
    local inspectionText = 'Vehicle Inspection Report:\n\n'
    local totalRepairBonus = 0
    local issueCount = 0
    
    for disabilityType, disability in pairs(disabilities) do
        issueCount = issueCount + 1
        local status = disability.repaired and '✅ REPAIRED' or '❌ NEEDS REPAIR'
        inspectionText = inspectionText .. string.format('%d. %s - %s\n', issueCount, disability.name, status)
        
        if not disability.repaired then
            totalRepairBonus = totalRepairBonus + Config.RepairBonusAmount
        end
    end
    
    if totalRepairBonus > 0 then
        inspectionText = inspectionText .. '\nPotential Repair Bonus: $' .. totalRepairBonus
    else
        inspectionText = inspectionText .. '\nAll issues resolved!'
    end
    
    lib.notify({
        title = '🔍 Inspection Report',
        description = inspectionText,
        type = 'info',
        icon = 'clipboard-list',
        position = Notifications.position,
        duration = 8000
    })
end

-- Function to show repair menu
function showRepairMenu(vehicle, disabilities)
    local repairOptions = {}
    
    for disabilityType, disability in pairs(disabilities) do
        if not disability.repaired then
            local disabilityConfig = Config.CarDisabilities[disabilityType]
            table.insert(repairOptions, {
                title = '🔧 ' .. disability.name,
                description = disability.description .. ' (+$' .. Config.RepairBonusAmount .. ' bonus)',
                icon = 'wrench',
                onSelect = function()
                    repairVehicleDisability(vehicle, disabilityType)
                end
            })
        end
    end
    
    if #repairOptions == 0 then
        lib.notify({
            title = Notifications.title,
            description = 'All issues have already been repaired',
            type = 'info',
            icon = Notifications.icon,
            position = Notifications.position
        })
        return
    end
    
    -- Add inspect option
    table.insert(repairOptions, 1, {
        title = '🔍 Inspect Vehicle',
        description = 'Check what issues this vehicle has',
        icon = 'search',
        onSelect = function()
            showVehicleInspection(vehicle, disabilities)
        end
    })
    
    lib.registerContext({
        id = 'vehicleRepairMenu',
        title = '🚗 Vehicle Repair',
        options = repairOptions
    })
    
    lib.showContext('vehicleRepairMenu')
end

-- Export repair functions
exports('repairVehicle', repairVehicleDisability)
exports('inspectVehicle', showVehicleInspection)
exports('getVehicleDisabilities', getVehicleDisabilities)

-- Function that selects a random car & spawn location from available locations
function selectCarAndLocation()
    if Config.EnableLocationReservation then
        -- Get available locations from server
        local availableLocations = lib.callback.await('lation_towtruck:getAvailableLocations', false)
        
        if not availableLocations or next(availableLocations) == nil then
            debugPrint('No available locations found!')
            return nil, nil, nil
        end
        
        -- Convert to array for random selection
        local availableKeys = {}
        for key, _ in pairs(availableLocations) do
            table.insert(availableKeys, key)
        end
        
        -- Try to reserve a location (with retry logic)
        for attempt = 1, Config.MaxReservationAttempts do
            local randomIndex = math.random(1, #availableKeys)
            local selectedKey = availableKeys[randomIndex]
            local selectedLocation = availableLocations[selectedKey]
            local selectedCar = Config.CarModels[math.random(1, #Config.CarModels)]
            
            -- Attempt to reserve this location
            local reserved = lib.callback.await('lation_towtruck:reserveLocation', false, selectedKey, selectedCar)
            
            if reserved then
                debugPrint('Successfully reserved location: ' .. selectedKey)
                return selectedCar, selectedLocation, selectedKey
            else
                debugPrint('Failed to reserve location: ' .. selectedKey .. ', attempt ' .. attempt)
                -- Remove this location from available list and try again
                table.remove(availableKeys, randomIndex)
                if #availableKeys == 0 then
                    break
                end
            end
        end
        
        debugPrint('Failed to reserve any location after ' .. Config.MaxReservationAttempts .. ' attempts')
        return nil, nil, nil
    else
        -- Advanced selection with vehicle variety and location prevention
        local availableLocations = {}
        local availableVehicles = {}
        
        -- Filter locations (prevent same location)
        if Config.PreventSameLocation then
            for _, locKey in pairs(locationKeys) do
                local isRecent = false
                for i = 1, math.min(#recentLocations, Config.LocationMemoryCount or 2) do
                    if recentLocations[i] == locKey then
                        isRecent = true
                        break
                    end
                end
                if not isRecent then
                    table.insert(availableLocations, locKey)
                end
            end
        else
            availableLocations = locationKeys
        end
        
        -- Filter vehicles (ensure variety)
        if Config.EnableVehicleVariety then
            for _, vehicle in pairs(Config.CarModels) do
                local isRecent = false
                for i = 1, math.min(#recentVehicles, Config.VehicleVarietyCount or 3) do
                    if recentVehicles[i] == vehicle then
                        isRecent = true
                        break
                    end
                end
                if not isRecent then
                    table.insert(availableVehicles, vehicle)
                end
            end
        else
            availableVehicles = Config.CarModels
        end
        
        -- Fallback if no available options
        if #availableLocations == 0 then availableLocations = locationKeys end
        if #availableVehicles == 0 then availableVehicles = Config.CarModels end
        
        -- Select random from filtered options
        local randomLocKey = availableLocations[math.random(1, #availableLocations)]
        local selectLoc = Config.Locations[randomLocKey]
        local selectCar = availableVehicles[math.random(1, #availableVehicles)]
        
        -- Update recent tracking
        table.insert(recentLocations, 1, randomLocKey)
        table.insert(recentVehicles, 1, selectCar)
        
        -- Trim tracking arrays
        if #recentLocations > (Config.LocationMemoryCount or 2) then
            table.remove(recentLocations)
        end
        if #recentVehicles > (Config.VehicleVarietyCount or 3) then
            table.remove(recentVehicles)
        end
        
        debugPrint('Selected variety-filtered car: ' .. selectCar .. ' at location: ' .. randomLocKey)
        return selectCar, selectLoc, randomLocKey
    end
end

-- Function that spawns the vehicle and sets the waypoint when job is selected
function setWaypoint()
    local carModel, location, locationKey = selectCarAndLocation()
    
    -- Check if location selection failed
    if not carModel or not location then
        lib.notify({
            title = Notifications.title,
            description = 'No available locations at the moment. Please try again later.',
            icon = Notifications.icon,
            type = 'error',
            position = Notifications.position
        })
        return false
    end
    
    -- Extract coordinates from vector4
    local x, y, z, h = location.x, location.y, location.z, location.w
    local nearbyVehicles = lib.getClosestVehicle(vec3(x, y, z), 5, false)
    if nearbyVehicles == nil then
        lib.requestModel(carModel)
        vehicle = CreateVehicle(carModel, x, y, z, h, true, true)
        SetVehicleDoorOpen(vehicle, 4, false, false)
        
        -- Apply vehicle health settings
        local engineHealth = Config.RandomizeDamage and math.random(Config.MinDamage, Config.MaxDamage) or Config.VehicleHealth.engine
        local bodyHealth = Config.RandomizeDamage and math.random(Config.MinDamage, Config.MaxDamage) or Config.VehicleHealth.body
        SetVehicleEngineHealth(vehicle, engineHealth)
        SetVehicleBodyHealth(vehicle, bodyHealth)
        SetVehicleDirtLevel(vehicle, Config.VehicleDirtLevel)
        
        missionVehPlate = GetVehicleNumberPlateText(vehicle)
        car = vehicle -- Keep for compatibility with existing code
        
        -- Update vehicle info in location reservation
        if Config.EnableLocationReservation and locationKey then
            local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
            lib.callback.await('lation_towtruck:updateVehicleInfo', false, locationKey, vehicleNetId, missionVehPlate)
            debugPrint('Updated vehicle info for location: ' .. locationKey .. ', plate: ' .. missionVehPlate)
        end
        
        -- Record initial health for damage tracking
        recordVehicleHealth(vehicle)
        
        -- Generate random disabilities for the vehicle
        local disabilities = generateRandomDisabilities(vehicle)
        
        -- Add ox_target options for repairs
        addVehicleRepairTargets(vehicle)
        
        -- Start job timer
        jobStartTime = GetGameTimer()
        
        -- Quality of Life: Show delivery route
        if Config.ShowDeliveryRoute then
            SetNewWaypoint(x, y)
            debugPrint('Set GPS route to pickup location')
        end
        
        -- Create pickup blip
        targetCarBlip = AddBlipForCoord(x, y, z)
        SetBlipSprite(targetCarBlip, Config.Blips.pickupVehicle.blipSprite)
        SetBlipDisplay(targetCarBlip, 4)
        SetBlipColour(targetCarBlip, Config.Blips.pickupVehicle.blipColor)
        SetBlipScale(targetCarBlip, Config.Blips.pickupVehicle.blipScale)
        SetBlipAsShortRange(targetCarBlip, true)
        
        -- Quality of Life: Enhanced GPS markers
        if Config.EnableGPSMarker then
            SetBlipRoute(targetCarBlip, true)
            SetBlipRouteColour(targetCarBlip, Config.Blips.pickupVehicle.blipColor)
            debugPrint('Enabled GPS route to pickup vehicle')
        end
        
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.Blips.pickupVehicle.blipName)
        EndTextCommandSetBlipName(targetCarBlip)
        jobAssigned = true
        
        -- Enhanced notification with vehicle info
        local vehicleModelHash = GetHashKey(carModel)
        local vehicleGXTLabel = GetDisplayNameFromVehicleModel(vehicleModelHash)
        local vehicleDisplayName = GetLabelText(vehicleGXTLabel)
        
        -- Fallback if label text is not found
        if vehicleDisplayName == "NULL" or vehicleDisplayName == "" or vehicleDisplayName == vehicleGXTLabel then
            vehicleDisplayName = carModel:upper() -- Use the model name as fallback
        end
        
        local notificationDesc = Notifications.jobAssigned
        
        if Config.EnableVehicleInfo then
            notificationDesc = notificationDesc .. '\nVehicle: ' .. vehicleDisplayName .. ' (Plate: ' .. missionVehPlate .. ')'
        end
        
        if Config.EnableStreaks and currentStreak > 0 then
            notificationDesc = notificationDesc .. '\nCurrent Streak: ' .. currentStreak
        end
        
        -- Quality of Life: Show ETA to pickup location
        if Config.ShowETA then
            local playerCoords = GetEntityCoords(cache.ped)
            local distance = #(playerCoords - vec3(x, y, z))
            local estimatedTime = math.ceil(distance / 50) -- Rough estimate: 50 units per minute
            notificationDesc = notificationDesc .. '\n📍 ETA: ~' .. estimatedTime .. ' min'
            debugPrint('Calculated ETA to pickup: ' .. estimatedTime .. ' minutes')
        end
        
        -- Add disability information
        if Config.EnableCarDisabilities and disabilities then
            local disabilityCount = 0
            local disabilityList = {}
            for disabilityType, disability in pairs(disabilities) do
                disabilityCount = disabilityCount + 1
                table.insert(disabilityList, disability.name)
            end
            
            if disabilityCount > 0 then
                notificationDesc = notificationDesc .. '\n🔧 Issues: ' .. table.concat(disabilityList, ', ')
                notificationDesc = notificationDesc .. '\nRepair for +$' .. (disabilityCount * Config.RepairBonusAmount) .. ' bonus!'
            end
        end
        
        -- Play notification sound if enabled
        if Config.EnableNotificationSound then
            PlaySoundFrontend(-1, Config.NotificationSoundName or 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
            debugPrint('Played notification sound: ' .. (Config.NotificationSoundName or 'CHECKPOINT_PERFECT'))
        end
        
        lib.notify({
            title = Notifications.title,
            description = notificationDesc,
            icon = Notifications.icon,
            type = 'success',
            position = Notifications.position
        })
    else
        lib.notify({
            title = Notifications.title,
            description = Notifications.searchingForJob,
            icon = Notifications.icon,
            type = 'warning',
            position = Notifications.position
        })
    end
end

-- Function that runs when the job is ended (remove waypoint, delete vehicles, remove keys, etc)
function endJob()
    DeleteWaypoint()
    
    -- Clean up all blips and GPS routes
    if targetCarBlip and DoesBlipExist(targetCarBlip) then
        if Config.EnableGPSMarker then
            SetBlipRoute(targetCarBlip, false) -- Clear GPS route
            debugPrint('Cleared GPS route from pickup blip')
        end
        RemoveBlip(targetCarBlip)
        debugPrint('Removed pickup blip')
        targetCarBlip = nil
    end
    
    if dropOffBlip and DoesBlipExist(dropOffBlip) then
        if Config.EnableGPSMarker then
            SetBlipRoute(dropOffBlip, false) -- Clear GPS route
            debugPrint('Cleared GPS route from delivery blip')
        end
        RemoveBlip(dropOffBlip)
        debugPrint('Removed delivery blip')
        dropOffBlip = nil
    end
    
    -- Remove ox_target options before deleting vehicles
    removeVehicleRepairTargets(spawnedVehicle)
    removeVehicleRepairTargets(car)
    
    -- Delete vehicles
    DeleteEntity(spawnedVehicle)
    DeleteEntity(car)
    
    -- Remove car keys
    if Config.EnableCarKeys then
        -- Example: exports.wasabi_carlock:RemoveKey(spawnedVehiclePlate)
        -- Insert remove car keys export here
        exports.wasabi_carlock:RemoveKey(spawnedVehiclePlate)
    end
    
    -- Reset streak on job end
    updateStreak(false)
    
    -- Clean up vehicle health tracking
    vehicleInitialHealth = {}
    
    -- Clean up disability tracking
    vehicleDisabilities = {}
    repairedDisabilities = {}
    
    -- Release location reservation
    if Config.EnableLocationReservation and locationKey then
        lib.callback.await('lation_towtruck:releaseLocation', false, locationKey)
        debugPrint('Released location reservation on job end: ' .. locationKey)
        locationKey = nil
    end
    
    -- Reset performance counters
    currentJobs = 0
    debugPrint('Job ended. Reset job counter to 0')
    
    inService = false
    enabledCalls = false
    jobAssigned = false
    
    -- Update radial menu to hide towing options when not in service
    manageTowingMenuItem()

end

-- Performance monitoring
-- (currentJobs and lastCleanupTime moved to top of file)

-- Vehicle cleanup thread
CreateThread(function()
    while true do
        Wait(Config.AutoCleanupTime * 60000) -- Convert minutes to milliseconds
        
        if Config.EnableDebugMode then
            debugPrint('Running automatic vehicle cleanup...')
        end
        
        -- Clean up abandoned mission vehicles
        local playerCoords = GetEntityCoords(cache.ped)
        local cleanedCount = 0
        
        if Config.OptimizedCleanup then
            -- Optimized cleanup: Only check vehicles we're tracking
            local vehiclesToCheck = {}
            
            -- Add current mission vehicles to check list
            if car and DoesEntityExist(car) then table.insert(vehiclesToCheck, car) end
            if spawnedVehicle and DoesEntityExist(spawnedVehicle) then table.insert(vehiclesToCheck, spawnedVehicle) end
            
            -- Check tracked vehicles from health system
            for plate, _ in pairs(vehicleInitialHealth) do
                local allVehicles = GetGamePool('CVehicle')
                for _, vehicle in pairs(allVehicles) do
                    if DoesEntityExist(vehicle) and GetVehicleNumberPlateText(vehicle) == plate then
                        table.insert(vehiclesToCheck, vehicle)
                        break
                    end
                end
            end
            
            -- Clean up distant tracked vehicles
            for _, vehicle in pairs(vehiclesToCheck) do
                if DoesEntityExist(vehicle) then
                    local vehicleCoords = GetEntityCoords(vehicle)
                    local distance = #(playerCoords - vehicleCoords)
                    
                    if distance > Config.CleanupDistance and vehicle ~= car and vehicle ~= spawnedVehicle then
                        local plate = GetVehicleNumberPlateText(vehicle)
                        if Config.CleanupOnlyOwnVehicles and vehicleInitialHealth[plate] then
                            removeVehicleRepairTargets(vehicle)
                            DeleteEntity(vehicle)
                            cleanedCount = cleanedCount + 1
                            vehicleInitialHealth[plate] = nil
                            debugPrint('Optimized cleanup: Removed tracked vehicle: ' .. plate)
                        end
                    end
                end
            end
        else
            -- Original cleanup method
            local allVehicles = GetGamePool('CVehicle')
            
            for _, vehicle in pairs(allVehicles) do
                if DoesEntityExist(vehicle) then
                    local vehicleCoords = GetEntityCoords(vehicle)
                    local distance = #(playerCoords - vehicleCoords)
                    
                    -- Clean up vehicles that are far away and not the current mission vehicle
                    if distance > Config.CleanupDistance and vehicle ~= car and vehicle ~= spawnedVehicle then
                        local plate = GetVehicleNumberPlateText(vehicle)
                        -- Only clean up vehicles that might be from towing missions
                        if plate and (plate == missionVehPlate or vehicleInitialHealth[plate]) then
                            removeVehicleRepairTargets(vehicle)
                            DeleteEntity(vehicle)
                            cleanedCount = cleanedCount + 1
                            debugPrint('Standard cleanup: Removed vehicle: ' .. plate)
                        end
                    end
                end
            end
        end
        
        if Config.EnableDebugMode and cleanedCount > 0 then
            debugPrint('Cleanup complete. Removed ' .. cleanedCount .. ' vehicles.')
        end
    end
end)

-- Thread that runs and randomly assigns job while player is inService
CreateThread(function()
    while true do
        Wait(2000)
        if enabledCalls then -- checks if "clocked in"
            -- Check max concurrent jobs limit
            if currentJobs >= Config.MaxConcurrentJobs then
                debugPrint('Max concurrent jobs reached: ' .. currentJobs)
                Wait(10000)
            elseif inService and not jobAssigned then -- if spawned truck, "clocked in" and no job assigned then assign job
                local jobCall = math.random(Config.MinWaitTime * 60000, Config.MaxWaitTime * 60000)
                debugPrint('Next job assignment in ' .. math.floor(jobCall / 1000) .. ' seconds')
                Wait(jobCall)
                currentJobs = currentJobs + 1
                debugPrint('Starting new job. Current jobs: ' .. currentJobs)
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
    -- Get current tow truck
    towVehicle = GetVehiclePedIsIn(cache.ped, true)
    if towVehicle == 0 then
        towVehicle = GetVehiclePedIsIn(cache.ped, false) -- Try current vehicle if not last vehicle
    end
    
    local towTruckModel = GetHashKey('flatbed')
    local isVehicleTowTruck = IsVehicleModel(towVehicle, towTruckModel)
    local pedCoords = GetEntityCoords(cache.ped)
    
    if not isVehicleTowTruck then
        lib.notify({
            title = Notifications.title,
            description = 'You need to be near a flatbed tow truck',
            type = 'error',
            icon = Notifications.icon,
            position = Notifications.position
        })
        return
    end
    
    if currentlyTowedVehicle ~= nil then
        lib.notify({
            title = Notifications.title,
            description = 'You already have a vehicle loaded',
            type = 'warning',
            icon = Notifications.icon,
            position = Notifications.position
        })
        return
    end
    
    -- Find closest vehicle (exclude the tow truck itself)
    targetVehicle = lib.getClosestVehicle(pedCoords, 8, false)
    
    if not targetVehicle or targetVehicle == 0 or targetVehicle == towVehicle then
        lib.notify({
            title = Notifications.title,
            description = Notifications.notCloseEnough,
            type = 'error',
            icon = Notifications.icon,
            position = Notifications.position
        })
        return
    end
    
    -- Get vehicle plate for tracking
    targetVehiclePlate = GetVehicleNumberPlateText(targetVehicle)
    
    -- Check if player is in the target vehicle
    if IsPedInVehicle(cache.ped, targetVehicle, false) then
        lib.notify({
            title = Notifications.title,
            description = 'Exit the vehicle before loading it',
            type = 'error',
            icon = Notifications.icon,
            position = Notifications.position
        })
        return
    end
    
    -- Start loading progress
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
            dict = 'anim@apt_trans@buzzer',
            clip = 'buzz_reg'
        },
    }) then
        -- Successfully completed progress - attach vehicle
        AttachEntityToEntity(targetVehicle, towVehicle, 20, -0.5, -5.0, 1.0, 0.0, 0.0, 0.0, false, false, false, false, 20, true)
        currentlyTowedVehicle = targetVehicle
        
        -- Call pickup handler
        handleVehiclePickup()
        
        lib.notify({
            title = Notifications.title,
            description = Notifications.successfulVehicleLoad,
            type = 'success',
            icon = Notifications.icon,
            position = Notifications.position
        })
    else
        -- Progress was cancelled
        lib.notify({
            title = Notifications.title,
            description = Notifications.cancelledVehicleLoad,
            type = 'error',
            icon = Notifications.icon,
            position = Notifications.position
        })
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
        handleVehicleDelivery()
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


function forceradiomenu()
    Wait(1000)
      showTowingRadialMenu()
       Wait(1000)
    updateTowingSubmenu()
end


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
                inService = true
                enabledCalls = true
                showTowingRadialMenu()
              
        
             
                    forceradiomenu()
                
             
                lib.notify({
                    title = Notifications.title,
                    description = Notifications.clockedIn,
                    icon = Notifications.icon,
                    type = 'success',
                    position = Notifications.position
                })
            end,
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
    if Config.JobLock then
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

-- Applies the target options above to the flatbed model
qtarget:AddTargetModel('flatbed', {
    options = {
        {
            name = 'loadVehicle',
            icon = Target.loadVehicleIcon,
            label = Target.loadVehicle,
            action = function()
                attachVehicle()
            end,
            distance = Target.distance
        },
        {
            name = 'unloadVehicle',
            icon = Target.unloadVehicleIcon,
            label = Target.unloadVehicle,
            action = function()
                detachVehicle()
            end,
            distance = Target.distance
        }
    }
})

-- Spawns the ped & applies the target to the ped a when player enters the configured radius
function towJobStartLocation:onEnter()
    spawnTowJobNPC()
    qtarget:AddTargetEntity(createTowJobNPC, {
        options = {
            {
                name = 'talkToStart',
                icon = Target.startJobIcon,
                label = Target.startJob,
                action = function()
                    openJobMenu()
                end,
                distance = Target.distance
            }
        }
    })
end

-- Deletes the ped & target option when a player leaves the configured radius
function towJobStartLocation:onExit()
    DeleteEntity(createTowJobNPC)
    qtarget:RemoveTargetEntity(createTowJobNPC, nil)
end

-- Function that handles the actual spawning of the ped, etc
function spawnTowJobNPC()
    lib.RequestModel(Config.StartJobPedModel)
    createTowJobNPC = CreatePed(0, Config.StartJobPedModel, Config.StartJobLocation.x, Config.StartJobLocation.y, Config.StartJobLocation.z, Config.StartJobPedHeading, false, true)
    FreezeEntityPosition(createTowJobNPC, true)
    SetBlockingOfNonTemporaryEvents(createTowJobNPC, true)
    SetEntityInvincible(createTowJobNPC, true)
end

-- Export functions for external use (Renewed-Weathersync only)
exports('testWeatherBonus', function()
    if GetResourceState('Renewed-Weathersync') ~= 'started' then
        return {
            bonus = 0,
            weatherSystem = 'Renewed-Weathersync (NOT FOUND)',
            debugMode = Config.EnableDebugMode,
            error = 'Renewed-Weathersync resource not started'
        }
    end
    
    local bonus = calculateWeatherBonus()
    return {
        bonus = bonus,
        weatherSystem = 'Renewed-Weathersync',
        debugMode = Config.EnableDebugMode
    }
end)

exports('getCurrentWeatherInfo', function()
    if GetResourceState('Renewed-Weathersync') ~= 'started' then
        return {
            fullWeather = nil,
            weatherType = nil,
            resourceActive = false,
            error = 'Renewed-Weathersync not started'
        }
    end
    
    local success, weather = pcall(function()
        return exports['Renewed-Weathersync']:getCurrentWeather()
    end)
    
    local success2, weatherType = pcall(function()
        return exports['Renewed-Weathersync']:getCurrentWeatherType()
    end)
    
    return {
        fullWeather = success and weather or nil,
        weatherType = success2 and weatherType or nil,
        resourceActive = true
    }
end)

-- Leveling System Client Events
if Config.EnableLevelingSystem then
    RegisterNetEvent('lation_towtruck:levelUp', function(oldLevel, newLevel)
        checkLevelUp(oldLevel, newLevel)
    end)
end

-- Additional leveling exports
exports('getPlayerLevelInfo', function()
    if not Config.EnableLevelingSystem then 
        return { error = 'Leveling system disabled' } 
    end
    
    return lib.callback.await('lation_towtruck:getPlayerLevelInfo', false)
end)

exports('showLevelProgress', function()
    if not Config.EnableLevelingSystem then 
        lib.notify({
            title = 'Leveling System',
            description = 'Leveling system is disabled',
            type = 'error',
            position = Notifications.position
        })
        return 
    end
    
    local levelInfo = lib.callback.await('lation_towtruck:getPlayerLevelInfo', false)
    if levelInfo then
        local progressText = levelInfo.maxLevel and 'MAX LEVEL' or 
            string.format('%d/%d XP (%d%%)', levelInfo.experienceProgress, levelInfo.experienceForNextLevel, levelInfo.progressPercent)
        
        lib.notify({
            title = string.format('🏆 Level %d - %s', levelInfo.level, levelInfo.title),
            description = string.format('Experience: %s\nTotal Deliveries: %d\nPay Bonus: +%d%%', 
                progressText, 
                levelInfo.totalDeliveries, 
                math.floor((levelInfo.payMultiplier - 1) * 100)
            ),
            type = 'info',
            icon = 'star',
            position = Notifications.position,
            duration = 8000
        })
    end
end)