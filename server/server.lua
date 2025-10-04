QBCore = exports['qb-core']:GetCoreObject()

-- Enhanced Debug System
local debugActive = false
local debugStartTime = os.clock()

-- Initialize debug system
CreateThread(function()
    Wait(1000) -- Wait for config to load
    debugActive = Config.Debug and Config.Debug.enabled and Config.Debug.server and Config.Debug.server.enabled
end)

-- Debug function with categories and color coding
local function debugPrint(category, message, debugType)
    if not debugActive or not Config.Debug then return end
    
    -- Check if this debug type is enabled
    if debugType and Config.Debug.server[debugType] == false then return end
    
    -- Check if category is enabled
    local categoryConfig = Config.Debug.categories[category]
    if not categoryConfig or not categoryConfig.enabled then return end
    
    -- Build debug message
    local timestamp = ''
    if Config.Debug.output.showTimestamps then
        local currentTime = (os.clock() - debugStartTime) * 1000
        timestamp = string.format('[%02d:%02d.%03d] ', 
            math.floor(currentTime / 60000), 
            math.floor((currentTime % 60000) / 1000), 
            math.floor(currentTime % 1000))
    end
    
    local prefix = categoryConfig.prefix or '[DEBUG]'
    local color = Config.Debug.output.useColors and categoryConfig.color or ''
    local resetColor = Config.Debug.output.useColors and '^7' or ''
    
    -- Limit message length
    local finalMessage = tostring(message)
    if Config.Debug.output.maxLogLength and #finalMessage > Config.Debug.output.maxLogLength then
        finalMessage = finalMessage:sub(1, Config.Debug.output.maxLogLength) .. '...'
    end
    
    print(string.format('%s%s%s%s %s', 
        color, prefix, resetColor, timestamp, finalMessage))
end

-- Performance tracking
local performanceTimers = {}

local function startPerformanceTimer(name)
    if Config.Debug and Config.Debug.performance.trackExecutionTime then
        performanceTimers[name] = os.clock()
    end
end

local function endPerformanceTimer(name, warnIfSlow)
    if not Config.Debug or not Config.Debug.performance.trackExecutionTime then return end
    
    local startTime = performanceTimers[name]
    if not startTime then return end
    
    local executionTime = (os.clock() - startTime) * 1000
    performanceTimers[name] = nil
    
    if warnIfSlow and Config.Debug.performance.warnSlowOperations then
        if executionTime > Config.Debug.performance.slowOperationThreshold then
            debugPrint('PERFORMANCE', string.format('Slow operation detected: %s took %.2fms', name, executionTime))
        end
    end
    
    if Config.Debug.categories.PERFORMANCE.enabled then
        debugPrint('PERFORMANCE', string.format('%s execution time: %.2fms', name, executionTime))
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

-- Create database table if it doesn't exist
CreateThread(function()
    if Config.EnableLocationReservation then
        -- Check if oxmysql is available
        if not exports.oxmysql then
            print('[lation_towing] ERROR: oxmysql is not available! Location reservation system disabled.')
            Config.EnableLocationReservation = false
            return
        end
        local createTableQuery = [[
            CREATE TABLE IF NOT EXISTS `tow_job_locations` (
                `id` int(11) NOT NULL AUTO_INCREMENT,
                `location_key` varchar(50) NOT NULL,
                `citizen_id` varchar(50) NOT NULL,
                `vehicle_net_id` int(11) DEFAULT NULL,
                `vehicle_model` varchar(50) DEFAULT NULL,
                `vehicle_plate` varchar(20) DEFAULT NULL,
                `assigned_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`),
                UNIQUE KEY `location_key` (`location_key`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]]
        
        exports.oxmysql:execute(createTableQuery, {}, function(result)
            debugInfo('Database table check completed - tow_job_locations table ready', 'databaseOperations')
            
            -- First get all vehicle_net_id values before clearing to cleanup vehicles
            local selectAllQuery = "SELECT vehicle_net_id FROM `tow_job_locations` WHERE vehicle_net_id IS NOT NULL"
            exports.oxmysql:execute(selectAllQuery, {}, function(vehicles)
                if vehicles and #vehicles > 0 then
                    debugInfo(string.format('Found %d abandoned vehicles to cleanup from previous session', #vehicles), 'cleanupSystem')
                    
                    -- Delete all abandoned vehicles from the world
                    for _, vehicleData in pairs(vehicles) do
                        local netId = vehicleData.vehicle_net_id
                        if netId then
                            local vehicle = NetworkGetEntityFromNetworkId(netId)
                            if DoesEntityExist(vehicle) then
                                debugTrace(string.format('Deleting abandoned vehicle with NetID: %d', netId), 'cleanupSystem')
                                DeleteEntity(vehicle)
                            end
                        end
                    end
                end
                
                -- Now clear all location reservations from database
                local clearTableQuery = "DELETE FROM `tow_job_locations`"
                exports.oxmysql:execute(clearTableQuery, {}, function(clearResult)
                    if clearResult.affectedRows and clearResult.affectedRows > 0 then
                        debugInfo(string.format('Cleared %d stale location reservations from previous session', clearResult.affectedRows), 'databaseOperations')
                    else
                        debugInfo('No stale location reservations to clear', 'databaseOperations')
                    end
                end)
            end)
        end)
    end
end)

-- Function to clean up duplicate citizen_id entries (keep only the newest)
local function cleanupDuplicateCitizenReservations(citizenId)
    if not Config.EnableLocationReservation then return end
    
    debugTrace(string.format('Cleaning up duplicate reservations for citizen: %s', citizenId), 'databaseOperations')
    
    -- First, get the vehicle_net_id values from entries that will be deleted
    local selectQuery = [[
        SELECT t1.vehicle_net_id FROM `tow_job_locations` t1
        INNER JOIN `tow_job_locations` t2
        WHERE t1.citizen_id = t2.citizen_id
        AND t1.citizen_id = ?
        AND t1.assigned_at < t2.assigned_at
        AND t1.vehicle_net_id IS NOT NULL
    ]]
    
    exports.oxmysql:execute(selectQuery, {citizenId}, function(vehicles)
        if vehicles and #vehicles > 0 then
            debugTrace(string.format('Found %d vehicles to cleanup for citizen: %s', #vehicles, citizenId), 'cleanupSystem')
            
            -- Delete vehicles from the world
            for _, vehicleData in pairs(vehicles) do
                local netId = vehicleData.vehicle_net_id
                if netId then
                    local vehicle = NetworkGetEntityFromNetworkId(netId)
                    if DoesEntityExist(vehicle) then
                        debugInfo(string.format('Deleting abandoned vehicle with NetID: %d for citizen: %s', netId, citizenId), 'cleanupSystem')
                        DeleteEntity(vehicle)
                    else
                        debugTrace(string.format('Vehicle with NetID: %d no longer exists in world', netId), 'cleanupSystem')
                    end
                else
                    debugTrace(string.format('Vehicle with NetID: %d not found in network', netId), 'cleanupSystem')
                end
            end
        end
        
        -- Now delete the database entries
        local cleanupQuery = [[
            DELETE t1 FROM `tow_job_locations` t1
            INNER JOIN `tow_job_locations` t2
            WHERE t1.citizen_id = t2.citizen_id
            AND t1.citizen_id = ?
            AND t1.assigned_at < t2.assigned_at
        ]]
        
        exports.oxmysql:execute(cleanupQuery, {citizenId}, function(result)
            if result.affectedRows and result.affectedRows > 0 then
                debugInfo(string.format('Removed %d older reservation(s) for citizen: %s', result.affectedRows, citizenId), 'databaseOperations')
            end
        end)
    end)
end

-- Function to add location reservation with duplicate cleanup
local function addLocationReservation(citizenId, locationKey, vehicleNetId, vehicleModel, vehiclePlate)
    if not Config.EnableLocationReservation then return end
    
    debugInfo(string.format('Adding location reservation - Citizen: %s, Location: %s', citizenId, locationKey), 'databaseOperations')
    
    -- First, clean up any existing reservations for this citizen
    cleanupDuplicateCitizenReservations(citizenId)
    
    -- Wait a moment for cleanup to complete, then add new reservation
    SetTimeout(100, function()
        local insertQuery = [[
            INSERT INTO `tow_job_locations` (location_key, citizen_id, vehicle_net_id, vehicle_model, vehicle_plate)
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
            citizen_id = VALUES(citizen_id),
            vehicle_net_id = VALUES(vehicle_net_id),
            vehicle_model = VALUES(vehicle_model),
            vehicle_plate = VALUES(vehicle_plate),
            assigned_at = CURRENT_TIMESTAMP
        ]]
        
        exports.oxmysql:execute(insertQuery, {locationKey, citizenId, vehicleNetId, vehicleModel, vehiclePlate}, function(result)
            if result.affectedRows and result.affectedRows > 0 then
                debugSuccess(string.format('Location reservation added - Citizen: %s, Location: %s', citizenId, locationKey), 'databaseOperations')
            else
                debugWarn(string.format('Failed to add location reservation for citizen: %s', citizenId), 'databaseOperations')
            end
        end)
    end)
end

-- Function to remove a specific location reservation and cleanup vehicle
local function removeLocationReservation(citizenId, locationKey)
    if not Config.EnableLocationReservation then return end
    
    debugInfo(string.format('Removing location reservation - Citizen: %s, Location: %s', citizenId, locationKey or 'any'), 'databaseOperations')
    
    -- First get vehicle info before deleting
    local selectQuery
    local params
    
    if locationKey then
        selectQuery = "SELECT vehicle_net_id FROM `tow_job_locations` WHERE citizen_id = ? AND location_key = ?"
        params = {citizenId, locationKey}
    else
        selectQuery = "SELECT vehicle_net_id FROM `tow_job_locations` WHERE citizen_id = ?"
        params = {citizenId}
    end
    
    exports.oxmysql:execute(selectQuery, params, function(vehicles)
        if vehicles and #vehicles > 0 then
            -- Delete vehicles from the world
            for _, vehicleData in pairs(vehicles) do
                local netId = vehicleData.vehicle_net_id
                if netId then
                    local vehicle = NetworkGetEntityFromNetworkId(netId)
                    if DoesEntityExist(vehicle) then
                        debugInfo(string.format('Deleting vehicle with NetID: %d for completed job - Citizen: %s', netId, citizenId), 'cleanupSystem')
                        DeleteEntity(vehicle)
                    end
                end
            end
        end
        
        -- Now delete the database entry
        local deleteQuery
        if locationKey then
            deleteQuery = "DELETE FROM `tow_job_locations` WHERE citizen_id = ? AND location_key = ?"
        else
            deleteQuery = "DELETE FROM `tow_job_locations` WHERE citizen_id = ?"
        end
        
        exports.oxmysql:execute(deleteQuery, params, function(result)
            if result.affectedRows and result.affectedRows > 0 then
                debugSuccess(string.format('Removed location reservation - Citizen: %s, Location: %s', citizenId, locationKey or 'any'), 'databaseOperations')
            else
                debugTrace(string.format('No reservation found to remove for citizen: %s', citizenId), 'databaseOperations')
            end
        end)
    end)
end

-- Function to remove location reservation by vehicle plate (for job completion)
local function removeLocationReservationByPlate(vehiclePlate)
    if not Config.EnableLocationReservation then return end
    
    debugInfo(string.format('Removing location reservation by vehicle plate: %s', vehiclePlate), 'databaseOperations')
    
    -- First get vehicle info and citizen info before deleting
    local selectQuery = "SELECT vehicle_net_id, citizen_id, location_key FROM `tow_job_locations` WHERE vehicle_plate = ?"
    
    exports.oxmysql:execute(selectQuery, {vehiclePlate}, function(reservations)
        if reservations and #reservations > 0 then
            -- Delete vehicles from the world and process each reservation
            for _, reservation in pairs(reservations) do
                local netId = reservation.vehicle_net_id
                local citizenId = reservation.citizen_id
                local locationKey = reservation.location_key
                
                if netId then
                    local vehicle = NetworkGetEntityFromNetworkId(netId)
                    if DoesEntityExist(vehicle) then
                        debugInfo(string.format('Deleting completed job vehicle with NetID: %d, Plate: %s', netId, vehiclePlate), 'cleanupSystem')
                        DeleteEntity(vehicle)
                    end
                end
                
                debugSuccess(string.format('Job completed - Citizen: %s, Location: %s, Plate: %s', citizenId, locationKey, vehiclePlate), 'databaseOperations')
            end
        else
            debugTrace(string.format('No reservation found for vehicle plate: %s', vehiclePlate), 'databaseOperations')
        end
        
        -- Now delete the database entry by plate
        local deleteQuery = "DELETE FROM `tow_job_locations` WHERE vehicle_plate = ?"
        
        exports.oxmysql:execute(deleteQuery, {vehiclePlate}, function(result)
            if result.affectedRows and result.affectedRows > 0 then
                debugSuccess(string.format('Removed %d location reservation(s) for completed job - Plate: %s', result.affectedRows, vehiclePlate), 'databaseOperations')
            end
        end)
    end)
end

-- Server event to handle job completion cleanup
RegisterServerEvent('lation_towing:jobCompleted')
AddEventHandler('lation_towing:jobCompleted', function(vehiclePlate)
    local source = source
    debugInfo(string.format('Job completion cleanup requested by player %d for vehicle: %s', source, vehiclePlate), 'databaseOperations')
    
    -- Clean up the location reservation by plate
    removeLocationReservationByPlate(vehiclePlate)
end)

-- Export the functions for use elsewhere in the script
exports('addLocationReservation', addLocationReservation)
exports('cleanupDuplicateCitizenReservations', cleanupDuplicateCitizenReservations)
exports('removeLocationReservation', removeLocationReservation)
exports('removeLocationReservationByPlate', removeLocationReservationByPlate)

-- ox_inventory item removal event handler
RegisterServerEvent('lation_towing:removeItem')
AddEventHandler('lation_towing:removeItem', function(item, amount)
    local source = source
    debugInfo(string.format('Processing item removal for player %d: %s x%d', source, item, amount), 'inventorySystem')
    
    -- Use ox_inventory server-side export to remove item
    local success = exports.ox_inventory:RemoveItem(source, item, amount or 1)
    
    if success then
        debugSuccess(string.format('Successfully removed %s x%d from player %d', item, amount or 1, source), 'inventorySystem')
    else
        debugWarn(string.format('Failed to remove %s x%d from player %d', item, amount or 1, source), 'inventorySystem')
    end
end)

-- Enhanced payment system with streaks, bonuses, and penalties
lib.callback.register('lation_towtruck:payPlayer', function(source, paymentData)
    startPerformanceTimer('payPlayer')
    debugInfo(string.format('Processing payment for player %d', source), 'paymentProcessing')
    
    local source = source
    local player = QBCore.Functions.GetPlayer(source)
    
    if not player then
        debugError(string.format('Player %d not found in QBCore', source), 'paymentProcessing')
        return false
    end
    
    -- Calculate base payment
    local basePay = Config.RandomPayPerDelivery and 
        math.random(Config.MinPayPerDelivery, Config.MaxPayPerDelivery) or 
        Config.PayPerDelivery
    
    debugTrace(string.format('Base payment calculated: $%d (random: %s)', basePay, tostring(Config.RandomPayPerDelivery)), 'paymentProcessing')
    
    -- Apply bonuses and penalties if payment data provided
    local totalPay = basePay
    local streakBonus = 0
    local timeBonus = 0
    local damagePenalty = 0
    local repairBonus = 0
    local distanceBonus = 0
    local weatherBonus = 0
    
    if paymentData then
        debugTrace('Payment data received, calculating bonuses', 'paymentProcessing')
        streakBonus = paymentData.streakBonus or 0
        timeBonus = paymentData.timeBonus or 0
        damagePenalty = paymentData.damagePenalty or 0
        repairBonus = paymentData.repairBonus or 0
        distanceBonus = paymentData.distanceBonus or 0
        weatherBonus = paymentData.weatherBonus or 0
        
        totalPay = basePay + streakBonus + timeBonus + repairBonus + distanceBonus + weatherBonus - damagePenalty
    end
    
    -- Apply level-based pay multiplier
    local levelBonus = 0
    if Config.EnableLevelingSystem then
        local towingData = player.PlayerData.metadata.towing or { level = 1 }
        local levelMultiplier = 1.0
        
        -- Calculate cumulative pay bonus from levels
        for levelReq, reward in pairs(Config.LevelRewards) do
            if towingData.level >= levelReq and reward.type == 'payBonus' then
                levelMultiplier = levelMultiplier + reward.amount
            end
        end
        
        if levelMultiplier > 1.0 then
            levelBonus = math.floor(totalPay * (levelMultiplier - 1.0))
            totalPay = totalPay + levelBonus
        end
    end
    
    -- Ensure minimum payment
    totalPay = math.max(totalPay, 50)
    debugTrace(string.format('Final payment amount: $%d (minimum enforced)', totalPay), 'paymentProcessing')
    
    player.Functions.AddMoney(Config.PayPerDeliveryAccount, totalPay)
    debugSuccess(string.format('Payment of $%d added to player %d account (%s)', totalPay, source, Config.PayPerDeliveryAccount), 'paymentProcessing')
    
    endPerformanceTimer('payPlayer', true)
    
    return {
        success = true,
        basePay = basePay,
        totalPay = totalPay,
        streakBonus = streakBonus,
        timeBonus = timeBonus,
        damagePenalty = damagePenalty,
        repairBonus = repairBonus,
        distanceBonus = distanceBonus,
        weatherBonus = weatherBonus,
        levelBonus = levelBonus or 0
    }
end)

-- Event that is used to check a players job if Config.JobLock is true
lib.callback.register('lation_towtruck:checkJob', function(source)
    debugTrace(string.format('Checking job authorization for player %d', source), 'frameworkIntegration')
    
    local source = source
    local player = QBCore.Functions.GetPlayer(source)
    
    if not player then
        debugError(string.format('Player %d not found in QBCore for job check', source), 'frameworkIntegration')
        return false
    end
    
    local playerJob = player.PlayerData.job.name
    debugTrace(string.format('Player %d has job: %s', source, playerJob), 'frameworkIntegration')
    
    -- Handle both single job (string) and multiple jobs (table)
    if type(Config.JobName) == 'table' then
        debugTrace('Checking against multiple allowed jobs', 'frameworkIntegration')
        for _, jobName in pairs(Config.JobName) do
            if playerJob == jobName then
                debugSuccess(string.format('Player %d authorized with job: %s', source, jobName), 'frameworkIntegration')
                return true
            end
        end
        debugWarn(string.format('Player %d job %s not in allowed list', source, playerJob), 'frameworkIntegration')
        return false
    else
        -- Single job compatibility
        if playerJob == Config.JobName then
            debugSuccess(string.format('Player %d authorized with job: %s', source, playerJob), 'frameworkIntegration')
            return true
        else
            debugWarn(string.format('Player %d job %s does not match required: %s', source, playerJob, Config.JobName), 'frameworkIntegration')
            return false
        end
    end
end)

-- Event that is used to check a players distance relative to delivery location before payment
lib.callback.register('lation_towtruck:checkDistance', function(source)
    debugTrace(string.format('Checking delivery distance for player %d', source), 'locationSystem')
    
    local player = GetPlayerPed(source)
    local playerPos = GetEntityCoords(player)
    local distance = #(playerPos - Config.DeliverLocation)
    
    debugTrace(string.format('Player %d distance to delivery: %.2f (required: %.2f)', source, distance, Config.DeliverRadius), 'locationSystem')
    
    if distance < Config.DeliverRadius then
        debugSuccess(string.format('Player %d within delivery radius', source), 'locationSystem')
        return true
    else
        debugWarn(string.format('Player %d too far from delivery location (%.2f > %.2f)', source, distance, Config.DeliverRadius), 'locationSystem')
    end
    return false
end)

-- Calculate time bonus for quick deliveries
lib.callback.register('lation_towtruck:calculateTimeBonus', function(source, deliveryTimeMs)
    if not Config.EnableTimeBonus then return 0 end
    
    local deliveryTimeMinutes = deliveryTimeMs / 60000
    if deliveryTimeMinutes <= Config.TimeBonusThreshold then
        return Config.TimeBonus
    end
    return 0
end)

-- Calculate distance bonus for long hauls
lib.callback.register('lation_towtruck:calculateDistanceBonus', function(source, pickupCoords, deliveryCoords)
    if not Config.EnableDistanceBonus then return 0 end
    
    local distance = #(pickupCoords - deliveryCoords)
    
    if distance < Config.MinDistanceForBonus then return 0 end
    
    local bonus = math.floor((distance / 100) * Config.DistanceBonusMultiplier)
    return math.min(bonus, Config.MaxDistanceBonus)
end)

-- Location Reservation System
if Config.EnableLocationReservation then
    -- Reserve a location for a player
    lib.callback.register('lation_towtruck:reserveLocation', function(source, locationKey, vehicleModel, vehicleNetId, vehiclePlate)
        local player = QBCore.Functions.GetPlayer(source)
        if not player then return false end
        
        local citizenId = player.PlayerData.citizenid
        
        -- Try to reserve the location
        local success, result = pcall(function()
            return exports.oxmysql:execute_async('INSERT INTO tow_job_locations (location_key, citizen_id, vehicle_model, vehicle_net_id, vehicle_plate) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE vehicle_net_id = VALUES(vehicle_net_id), vehicle_plate = VALUES(vehicle_plate)', {
                locationKey, citizenId, vehicleModel, vehicleNetId, vehiclePlate
            })
        end)
        
        if success and result then
            if Config.EnableDebugMode then
                print('[lation_towing] Location reserved: ' .. locationKey .. ' for player: ' .. citizenId)
            end
            return true
        else
            if Config.EnableDebugMode then
                print('[lation_towing] Failed to reserve location: ' .. locationKey .. ' - ' .. tostring(result))
            end
            return false
        end
    end)
    
    -- Release a location reservation
    lib.callback.register('lation_towtruck:releaseLocation', function(source, locationKey)
        local player = QBCore.Functions.GetPlayer(source)
        if not player then return false end
        
        local citizenId = player.PlayerData.citizenid
        
        -- Release the location reservation
        local success, result = pcall(function()
            return exports.oxmysql:execute_async('DELETE FROM tow_job_locations WHERE location_key = ? AND citizen_id = ?', {
                locationKey, citizenId
            })
        end)
        
        if Config.EnableDebugMode then
            local status = success and 'successfully' or 'failed to'
            print('[lation_towing] Location ' .. status .. ' released: ' .. locationKey .. ' by player: ' .. citizenId)
        end
        
        return success
    end)
    
    -- Get available locations (not reserved by other players)
    lib.callback.register('lation_towtruck:getAvailableLocations', function(source)
        local player = QBCore.Functions.GetPlayer(source)
        if not player then return {} end
        
        -- Get all reserved locations
        local success, reservedLocations = pcall(function()
            return exports.oxmysql:execute_sync('SELECT location_key FROM tow_job_locations WHERE assigned_at > DATE_SUB(NOW(), INTERVAL ? MINUTE)', {
                Config.LocationReservationTimeout
            })
        end)
        
        if not success then
            reservedLocations = {}
            if Config.EnableDebugMode then
                print('[lation_towing] Failed to get reserved locations: ' .. tostring(reservedLocations))
            end
        end
        
        local reservedKeys = {}
        for _, reservation in pairs(reservedLocations) do
            reservedKeys[reservation.location_key] = true
        end
        
        -- Filter available locations
        local availableLocations = {}
        for key, location in pairs(Config.Locations) do
            if not reservedKeys[key] then
                availableLocations[key] = location
            end
        end
        
        if Config.EnableDebugMode then
            print('[lation_towing] Available locations: ' .. #availableLocations .. ' / ' .. #Config.Locations)
        end
        
        return availableLocations
    end)
    
    -- Update vehicle info for reservation
    lib.callback.register('lation_towtruck:updateVehicleInfo', function(source, locationKey, vehicleNetId, vehiclePlate)
        local player = QBCore.Functions.GetPlayer(source)
        if not player then return false end
        
        local citizenId = player.PlayerData.citizenid
        
        -- Update vehicle information
        local success, result = pcall(function()
            return exports.oxmysql:execute_async('UPDATE tow_job_locations SET vehicle_net_id = ?, vehicle_plate = ? WHERE location_key = ? AND citizen_id = ?', {
                vehicleNetId, vehiclePlate, locationKey, citizenId
            })
        end)
        
        -- Check if update was successful (result should be affected rows count or similar)
        if success and result then
            if type(result) == 'number' then
                return result > 0
            elseif type(result) == 'table' and result.affectedRows then
                return result.affectedRows > 0
            else
                return true -- If we got a result, assume success
            end
        end
        
        return false
    end)
    
    -- Cleanup expired reservations
    CreateThread(function()
        while true do
            Wait(Config.ReservationCleanupInterval * 60000) -- Convert minutes to milliseconds
            
            if Config.CleanupExpiredReservations then
                local success, cleaned = pcall(function()
                    return exports.oxmysql:execute_async('DELETE FROM tow_job_locations WHERE assigned_at < DATE_SUB(NOW(), INTERVAL ? MINUTE)', {
                        Config.LocationReservationTimeout
                    })
                end)
                
                if Config.EnableDebugMode then
                    if success and cleaned then
                        local cleanedCount = 0
                        if type(cleaned) == 'number' then
                            cleanedCount = cleaned
                        elseif type(cleaned) == 'table' and cleaned.affectedRows then
                            cleanedCount = cleaned.affectedRows
                        end
                        
                        if cleanedCount > 0 then
                            print('[lation_towing] Cleaned up ' .. cleanedCount .. ' expired location reservations')
                        end
                    elseif not success then
                        print('[lation_towing] Failed to cleanup expired reservations: ' .. tostring(cleaned))
                    end
                end
            end
        end
    end)
end

-- Leveling System Server Functions
if Config.EnableLevelingSystem then
    -- Helper function to calculate level from experience
    local function calculateLevel(experience)
        local level = 1
        local totalXPNeeded = 0
        
        for i = 1, Config.LevelingSettings.maxLevel do
            local xpForThisLevel = math.floor(Config.LevelingSettings.baseExperience * (Config.LevelingSettings.experienceMultiplier ^ (i - 1)))
            if experience >= totalXPNeeded + xpForThisLevel then
                totalXPNeeded = totalXPNeeded + xpForThisLevel
                level = i
            else
                break
            end
        end
        
        return level
    end
    
    -- Helper function to get level multiplier for pay bonuses
    local function getLevelPayMultiplier(level)
        local multiplier = 1.0
        
        for levelReq, reward in pairs(Config.LevelRewards) do
            if level >= levelReq and reward.type == 'payBonus' then
                multiplier = multiplier + reward.amount
            end
        end
        
        return multiplier
    end
    
    -- Add experience callback
    lib.callback.register('lation_towtruck:addExperience', function(source, experienceGained, conditions)
        local player = QBCore.Functions.GetPlayer(source)
        if not player then return false end
        
        -- Get current towing metadata
        local towingData = player.PlayerData.metadata.towing or {
            experience = 0,
            level = 1,
            totalDeliveries = 0
        }
        
        local oldLevel = towingData.level
        
        -- Add experience
        towingData.experience = towingData.experience + experienceGained
        towingData.totalDeliveries = towingData.totalDeliveries + 1
        
        -- Calculate new level
        local newLevel = calculateLevel(towingData.experience)
        towingData.level = newLevel
        
        -- Save metadata
        player.Functions.SetMetaData('towing', towingData)
        
        if Config.EnableDebugMode then
            print('[lation_towing] Player ' .. player.PlayerData.citizenid .. ' gained ' .. experienceGained .. ' XP (Level: ' .. newLevel .. ')')
        end
        
        -- Trigger level up on client if level increased
        if newLevel > oldLevel then
            TriggerClientEvent('lation_towtruck:levelUp', source, oldLevel, newLevel)
        end
        
        return {
            success = true,
            experience = towingData.experience,
            level = newLevel,
            experienceGained = experienceGained,
            leveledUp = newLevel > oldLevel
        }
    end)
    
    -- Process level reward callback
    lib.callback.register('lation_towtruck:processLevelReward', function(source, level, reward)
        local player = QBCore.Functions.GetPlayer(source)
        if not player then return false end
        
        if reward.type == 'money' then
            player.Functions.AddMoney('cash', reward.amount)
            if Config.EnableDebugMode then
                print('[lation_towing] Awarded $' .. reward.amount .. ' to player ' .. player.PlayerData.citizenid .. ' for reaching level ' .. level)
            end
        elseif reward.type == 'payBonus' then
            -- Pay bonuses are calculated dynamically based on metadata, no need to store separately
            if Config.EnableDebugMode then
                print('[lation_towing] Player ' .. player.PlayerData.citizenid .. ' unlocked ' .. (reward.amount * 100) .. '% pay bonus at level ' .. level)
            end
        end
        
        return true
    end)
    
    -- Get player level info callback
    lib.callback.register('lation_towtruck:getPlayerLevelInfo', function(source)
        local player = QBCore.Functions.GetPlayer(source)
        if not player then return nil end
        
        local towingData = player.PlayerData.metadata.towing or {
            experience = 0,
            level = 1,
            totalDeliveries = 0
        }
        
        local currentLevel = towingData.level
        local currentXP = towingData.experience
        local xpForNextLevel = math.floor(Config.LevelingSettings.baseExperience * (Config.LevelingSettings.experienceMultiplier ^ currentLevel))
        local levelPayMultiplier = getLevelPayMultiplier(currentLevel)
        
        -- Calculate XP progress towards next level
        local levelStartXP = 0
        for i = 1, currentLevel - 1 do
            levelStartXP = levelStartXP + math.floor(Config.LevelingSettings.baseExperience * (Config.LevelingSettings.experienceMultiplier ^ (i - 1)))
        end
        
        local xpProgress = currentXP - levelStartXP
        local xpProgressPercent = currentLevel >= Config.LevelingSettings.maxLevel and 100 or math.floor((xpProgress / xpForNextLevel) * 100)
        
        return {
            level = currentLevel,
            experience = currentXP,
            experienceProgress = xpProgress,
            experienceForNextLevel = xpForNextLevel,
            progressPercent = xpProgressPercent,
            totalDeliveries = towingData.totalDeliveries,
            payMultiplier = levelPayMultiplier,
            title = Config.LevelTitles[currentLevel] or Config.LevelTitles[1] or 'Rookie Driver',
            maxLevel = currentLevel >= Config.LevelingSettings.maxLevel
        }
    end)
end