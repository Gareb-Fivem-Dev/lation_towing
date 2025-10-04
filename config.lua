Config = {}

--[[ General Configs ]]
Config.Framework = 'qbcore' -- 'qbcore'
Config.JobLock = true -- Do you want this to be only for players with a specific job? (True if yes, false if no. You must set framework to 'qbcore' for this feature)
Config.JobName = {'mechanic', 'towtruck', 'ambulance', 'police'} -- The job names allowed if Config.JobLock is true (can be string for single job or table for multiple jobs)
Config.StartJobPedModel = 'a_m_m_business_01' -- The model of the ped that starts the job
Config.StartJobLocation = vec3(1242.0847, -3257.0403, 5.0288) -- The location at which you start the job (and the map blip location)
Config.DeliverLocation = vec3(393.0399, -1617.5004, 29.2920) -- The location at which you deliver vehicles
Config.DeliverRadius = 10 -- The radius at which the player must be within (in relation to DeliverLocation) to get paid for delivering
Config.StartJobRadius = 50 -- The distance at which once a player is within the ped will spawn/be visable
Config.StartJobPedHeading = 272.1205 -- The direction at which the start job ped is facing
Config.SpawnTruckLocation = vector3(1247.0011, -3262.6636, 5.8075) -- The location at which the tow truck spawns to start the job
Config.SpawnTruckHeading = 269.8075 -- The direction the tow truck being spawned is facing
Config.EnableCarKeys = true -- QBCore key system already works
Config.MinWaitTime = 1 -- The minimum wait time in minutes for a new job assignment
Config.MaxWaitTime = 2 -- The maximum wait time in minutes for a new job assignment

--[[ Advanced Features ]]
Config.EnableStreaks = true -- Enable bonus pay for consecutive deliveries
Config.StreakBonus = 50 -- Bonus amount per streak level
Config.MaxStreak = 5 -- Maximum streak level
Config.EnableVehicleVariety = true -- Require different vehicle types to prevent camping one location
Config.PreventSameLocation = true -- Prevent spawning vehicles at the same location consecutively
Config.VehicleVarietyCount = 3 -- Number of different vehicle types before allowing repeats
Config.LocationMemoryCount = 2 -- Number of previous locations to avoid
Config.EnableTimeBonus = true -- Bonus pay for quick deliveries
Config.TimeBonusThreshold = 5 -- Minutes - if delivered faster, get bonus
Config.TimeBonus = 100 -- Bonus amount for quick delivery
Config.EnableDamageSystem = true -- Reduce pay if vehicle is damaged during transport
Config.DamageReduction = 0.1 -- 10% pay reduction per 100 damage points
Config.EnableDistanceBonus = true -- Bonus pay based on delivery distance
Config.DistanceBonusMultiplier = 2 -- Pay per unit distance (dollars per 100 units)
Config.MinDistanceForBonus = 500 -- Minimum distance required for distance bonus
Config.MaxDistanceBonus = 200 -- Maximum distance bonus amount
Config.EnableWeatherBonus = true -- Bonus pay for difficult weather conditions
Config.WeatherBonuses = {
    -- Renewed-Weathersync compatible weather types
    ['RAIN'] = 75,          -- Light rain bonus
    ['THUNDER'] = 150,      -- Thunderstorm bonus (dangerous conditions)
    ['CLEARING'] = 50,      -- Clearing weather bonus
    ['OVERCAST'] = 25,      -- Overcast bonus
    ['CLOUDS'] = 15,        -- Cloudy bonus
    ['FOGGY'] = 100,        -- Fog bonus (reduced visibility)
    ['SMOG'] = 85,          -- Smog bonus (poor visibility)
    ['SNOW'] = 125,         -- Snow bonus (slippery conditions)
    ['BLIZZARD'] = 200,     -- Blizzard bonus (extreme conditions)
    ['SNOWLIGHT'] = 100,    -- Light snow bonus
    ['XMAS'] = 175,         -- Christmas weather bonus (special event)
    ['NEUTRAL'] = 0,        -- Neutral weather (no bonus)
    ['CLEAR'] = 0,          -- Clear weather (no bonus)
    ['EXTRASUNNY'] = 0      -- Extra sunny (no bonus)
}
Config.MaxWeatherBonus = 200 -- Maximum weather bonus cap

--[[ Leveling System ]]
Config.EnableLevelingSystem = true -- Enable experience and leveling system
Config.LevelingSettings = {
    baseExperience = 100,           -- Base XP required for level 1
    experienceMultiplier = 1.5,     -- XP multiplier per level (exponential growth)
    maxLevel = 50,                  -- Maximum level achievable
    experiencePerDelivery = 25,     -- Base XP gained per delivery
    experiencePerRepair = 15,       -- Bonus XP for repairing vehicle disabilities
    experienceMultipliers = {       -- XP multipliers based on conditions
        weatherBonus = 1.2,         -- 20% more XP in bad weather
        streakBonus = 1.1,          -- 10% more XP with delivery streaks
        damageReduction = 0.8,      -- 20% less XP if vehicle damaged
        quickDelivery = 1.3,        -- 30% more XP for fast deliveries
    }
}

Config.LevelRewards = {
    [5] =  { type = 'payBonus', amount = 0.05, message = 'Level 5 Reward: 5% pay increase!' }, -- 5% permanent pay bonus
    [10] = { type = 'payBonus', amount = 0.10, message = 'Level 10 Reward: 10% pay increase!' }, -- 10% permanent pay bonus
    [15] = { type = 'payBonus', amount = 0.15, message = 'Level 15 Reward: 15% pay increase!' }, -- 15% permanent pay bonus
    [20] = { type = 'payBonus', amount = 0.20, message = 'Level 20 Reward: 20% pay increase!' }, -- 20% permanent pay bonus
    [25] = { type = 'payBonus', amount = 0.25, message = 'Level 25 Reward: 25% pay increase!' }, -- 25% permanent pay bonus
    [30] = { type = 'payBonus', amount = 0.30, message = 'Level 30 Reward: 30% pay increase!' }, -- 30% permanent pay bonus
    [35] = { type = 'payBonus', amount = 0.35, message = 'Level 35 Reward: 35% pay increase!' }, -- 35% permanent pay bonus
    [40] = { type = 'payBonus', amount = 0.40, message = 'Level 40 Reward: 40% pay increase!' }, -- 40% permanent pay bonus
    [45] = { type = 'payBonus', amount = 0.45, message = 'Level 45 Reward: 45% pay increase!' }, -- 45% permanent pay bonus
    [50] = { type = 'payBonus', amount = 0.50, message = 'MAX LEVEL ACHIEVED: 50% pay increase - Master Tow Driver!' } -- 50% permanent pay bonus
}

Config.LevelTitles = {
    [1] = 'Rookie Driver',
    [5] = 'Apprentice Operator',
    [10] = 'Skilled Technician',
    [15] = 'Expert Driver',
    [20] = 'Professional Operator',
    [25] = 'Veteran Specialist',
    [30] = 'Master Technician',
    [35] = 'Elite Professional',
    [40] = 'Legendary Operator',
    [45] = 'Grand Master',
    [50] = 'Ultimate Tow Legend'
}

Config.ShowLevelProgress = true -- Show XP progress in notifications
Config.ShowLevelTitle = true -- Show player's current title
Config.LevelUpSound = 'CHECKPOINT_PERFECT' -- Sound to play on level up
Config.EnableNotificationSound = true -- Play sound with notifications
Config.NotificationSoundName = 'CHECKPOINT_PERFECT' -- Sound to play with notifications
Config.ShowJobStats = true -- Show stats like deliveries completed, earnings, etc.

--[[ Quality of Life ]]
Config.ShowDeliveryRoute = true -- Show route to delivery location
Config.EnableGPSMarker = true -- Add GPS markers
Config.ShowETA = true -- Show estimated time to delivery
Config.EnableVehicleInfo = true -- Show vehicle info (model, plate) in notifications
Config.AutoRepairTowTruck = true -- Auto repair tow truck on spawn
Config.TowTruckFuel = 100 -- Fuel level for spawned tow truck

--[[ Pay Conigs ]]
Config.PayPerDelivery = 500 -- How much the player is paid per delivery completed
Config.PayPerDeliveryAccount = 'cash' -- Pay in cash with 'cash' or to the bank with 'bank'
Config.RandomPayPerDelivery = true -- Set true if you want randomized pay, set false for same amount (PayPerDelivery).
Config.MinPayPerDelivery = 350 -- If Config.RandomPayPerDelivery = true then what is the minimum pay? (If RandomPay false, ignore this)
Config.MaxPayPerDelivery = 950 -- If Config.RandomPayPerDelivery = true then what is the maxmimum pay? (If RandomPay false, ignore this)

Config.Blips = {
    startJob = {
        blipSprite = 477, -- https://docs.fivem.net/docs/game-references/blips/
        blipColor = 21, -- https://docs.fivem.net/docs/game-references/blips/#blip-colors
        blipScale = 0.7,
        blipName = 'Towing'
    },
    pickupVehicle = {
        blipSprite = 380,
        blipColor = 1,
        blipScale = 0.7,
        blipName = 'Target Vehicle'
    },
    dropOff = {
        blipSprite = 68,
        blipColor = 2,
        blipScale = 0.7,
        blipName = 'Target Drop Off'
    }
}

--[[ Car Spawns - Must Follow Format ]]
Config.Locations = {
    ['1'] = vector4(1015.3276, -2462.3572, 27.7853, 82.8159),
    ['2'] = vector4(-247.7807, -1687.8434, 33.4754, 178.8647),
    ['3'] = vector4(372.9686, -767.0320, 29.2700, 0.0682),
    ['4'] = vector4(-1276.2042, -556.5905, 30.2092, 219.8612),
    ['5'] = vector4(1205.2948, -708.5202, 59.4169, 9.6660),
    ['6'] = vector4(213.8225, 389.6160, 106.5621, 171.4204),
    ['7'] = vector4(-449.8099, 98.6727, 62.8731, 355.5552),
    ['8'] = vector4(-928.4528, -124.9771, 37.2992, 117.7664),
    ['9'] = vector4(-1772.7124, -519.8768, 38.5269, 299.9457),
    ['10'] = vector4(-2165.7588, -420.4905, 13.0514, 20.4053),
    ['11'] = vector4(-1483.1953, -895.6342, 9.7399, 64.1165)
}

--[[ Vehicle Spawn Settings ]]
Config.VehicleHealth = {
    engine = 200,
    body = 200,
    petrolTank = 200
}
Config.VehicleDirtLevel = 12.0 -- How dirty the spawned vehicles are
Config.RandomizeDamage = true -- Randomize vehicle damage levels
Config.MinDamage = 100 -- Minimum health values when randomizing
Config.MaxDamage = 300 -- Maximum health values when randomizing

--[[ Performance Settings ]]
Config.CleanupDistance = 500 -- Distance to cleanup old mission vehicles
Config.MaxConcurrentJobs = 1 -- Max jobs per player
Config.EnableDebugMode = false -- Show debug information (prints to console)
Config.AutoCleanupTime = 15 -- Minutes before cleaning up abandoned vehicles

-- Advanced Performance Settings
Config.OptimizedCleanup = true -- Use optimized cleanup methods
Config.CleanupOnlyOwnVehicles = true -- Only cleanup vehicles spawned by this script
Config.MaxVehicleAge = 30 -- Maximum age in minutes before vehicle is eligible for cleanup
Config.CleanupInterval = 5 -- How often to run cleanup check (minutes)
Config.EnablePerformanceMonitoring = false -- Log performance metrics

--[[ Debug System ]]
Config.Debug = {
    -- Master Debug Toggle
    enabled = false, -- Master switch for all debug features
    
    -- Client-Side Debug Options
    client = {
        enabled = false, -- Enable client-side debugging
        jobAssignment = false, -- Debug job assignment and vehicle spawning
        vehicleLoading = false, -- Debug vehicle loading/unloading operations
        deliverySystem = false, -- Debug delivery calculations and bonuses
        disabilitySystem = false, -- Debug vehicle disability detection and repairs
        oxTargetSystem = false, -- Debug ox_target interactions and bone targeting
        levelingSystem = false, -- Debug XP calculations and level progression
        paymentSystem = false, -- Debug payment calculations and bonuses
        weatherSystem = false, -- Debug weather detection and bonuses
        streakSystem = false, -- Debug delivery streak calculations
        inventorySystem = false, -- Debug inventory checks and item consumption
        performanceMetrics = false, -- Debug performance timing
        eventHandling = false, -- Debug all client events and callbacks
        uiInteractions = false, -- Debug context menus, notifications, and progress bars
        vehicleManagement = false, -- Debug vehicle spawning, cleanup, and health
        navigationSystem = false, -- Debug GPS, routes, and blip management
        animationSystem = false, -- Debug animations and prop handling
        radialMenu = false -- Debug radial menu interactions and visibility logic
    },
    
    -- Server-Side Debug Options
    server = {
        enabled = false, -- Enable server-side debugging
        jobManagement = false, -- Debug job creation, assignment, and completion
        playerData = false, -- Debug player metadata and experience tracking
        paymentProcessing = false, -- Debug payment calculations and transfers
        locationSystem = false, -- Debug location reservation and management
        vehicleSpawning = false, -- Debug vehicle spawning and health settings
        disabilityGeneration = false, -- Debug random disability assignment
        experienceSystem = false, -- Debug XP gains and level calculations
        performanceTracking = false, -- Debug server performance metrics
        databaseOperations = false, -- Debug any database interactions
        eventProcessing = false, -- Debug all server events and callbacks
        cleanupSystem = false, -- Debug vehicle and data cleanup operations
        validationChecks = false, -- Debug input validation and security checks
        weatherIntegration = false, -- Debug weather detection integration
        frameworkIntegration = false -- Debug QBCore integration and calls
    },
    
    -- Debug Output Settings
    output = {
        useColors = false, -- Use colored console output for better readability
        showTimestamps = false, -- Include timestamps in debug messages
        showPlayerInfo = false, -- Include player ID/name in debug messages
        logLevel = 'error', -- Options: 'error', 'warn', 'info', 'debug', 'trace'
        maxLogLength = 500, -- Maximum characters per debug message
        suppressRepeats = false, -- Suppress repeated identical messages
        saveToFile = false, -- Save debug logs to file (if supported)
    },
    
    -- Performance Debug Settings
    performance = {
        trackExecutionTime = false, -- Track function execution times
        warnSlowOperations = false, -- Warn about operations taking too long
        slowOperationThreshold = 100, -- Milliseconds threshold for slow operation warning
        trackMemoryUsage = false, -- Track memory usage (advanced)
        profileFrequentFunctions = false -- Profile frequently called functions
    },
    
    -- Debug Message Categories
    categories = {
        ['ERROR'] = { enabled = false, color = '^1', prefix = '[ERROR]' }, -- Red
        ['WARN'] = { enabled = false, color = '^3', prefix = '[WARN]' }, -- Yellow
        ['INFO'] = { enabled = false, color = '^4', prefix = '[INFO]' }, -- Blue
        ['SUCCESS'] = { enabled = false, color = '^2', prefix = '[SUCCESS]' }, -- Green
        ['DEBUG'] = { enabled = false, color = '^6', prefix = '[DEBUG]' }, -- Purple
        ['TRACE'] = { enabled = false, color = '^7', prefix = '[TRACE]' }, -- White
        ['PERFORMANCE'] = { enabled = false, color = '^5', prefix = '[PERF]' } -- Pink
    }
}

-- Location Reservation System (Multi-Player Support)
Config.EnableLocationReservation = true -- Enable server-wide location reservation system
Config.LocationReservationTimeout = 20 -- Minutes before unreserved location expires
Config.MaxReservationAttempts = 3 -- Max attempts to find available location before failing
Config.CleanupExpiredReservations = true -- Auto cleanup expired location reservations
Config.ReservationCleanupInterval = 10 -- Minutes between reservation cleanup checks

--[[ Car Disability System ]]
Config.EnableCarDisabilities = true -- Enable random car breakdowns
Config.GlobalDisabilityChance = 100 -- Global percentage chance a spawned car has ANY disability
Config.EnableRepairBonus = true -- Enable bonus pay for fixing disabilities
Config.RepairBonusAmount = 150 -- Bonus amount for repairing a disabled vehicle

-- Multiple Disability Settings
Config.MultipleDisabilities = true -- Allow vehicles to have multiple issues
Config.MultipleDisabilityChance = 25 -- Percent chance of getting multiple issues when a disability occurs
Config.MaxDisabilities = 3 -- Maximum number of disabilities per vehicle

-- ox_target Repair System
Config.UseOxTarget = true -- Enable ox_target for repairs (requires ox_target)
Config.TargetRepairDistance = 2.5 -- Default distance for repair interactions
Config.ShowRepairPrompts = true -- Show repair prompts when near disabled vehicles
Config.RequireRepairTools = true -- Require specific tools/items for repairs

-- Disability Types and Descriptions
Config.CarDisabilities = {
    ['engine_failure'] = {
        enabled = true, -- Enable/disable this specific disability
        chance = 20, -- Individual percentage chance of this disability occurring
        name = 'Engine Failure',
        description = 'Engine overheated and seized - smoking heavily',
        repairTime = 8000, -- milliseconds
        repairAnim = 'WORLD_HUMAN_WELDING',
        repairItem = 'repairkit', -- Set to item name if using inventory items
        keepItem = true, -- true = keep item after use, false = consume item
        targetBone = 'engine', -- Bone for ox_target interaction
        targetOptions = {
            icon = 'fas fa-wrench',
            label = 'Repair Engine',
            distance = 2.5
        },
        effects = {
            engineHealth = 150, -- Very low health causes smoking
            engineOn = false
        }
    },
    ['flat_tire'] = {
        enabled = true,
        chance = 20, -- Most common disability
        name = 'Flat Tire(s)',
        description = 'One or more tires are flat or damaged',
        repairTime = 6000,
        repairAnim = 'WORLD_HUMAN_HAMMERING',
        repairItem = 'sparetire', -- Set to item name if using inventory items
        keepItem = false, -- true = keep item after use, false = consume item
        targetBone = 'tire', -- Special handling for multiple tire bones
        targetBones = { -- Multiple tire bones for ox_target
            'wheel_lf', -- Left Front
            'wheel_rf', -- Right Front  
            'wheel_lr', -- Left Rear
            'wheel_rr'  -- Right Rear
        },
        targetOptions = {
            icon = 'fas fa-tools',
            label = 'Fix Flat Tire',
            distance = 2.0
        },
        effects = {
            tireHealth = 200, -- Low tire health
            tyreBurst = true, -- Will burst tires based on tire damage type
            -- Tire damage options (handled in client script):
            -- 70% chance: Single flat tire (common roadside issue)
            -- 20% chance: 2 flat tires (pothole damage)
            -- 10% chance: All 4 tires flat (severe incident)
            tireDamageType = 'random' -- Options: 'single', 'multiple', 'all', 'random'
        }
    },
    ['fuel_leak'] = {
        enabled = true,
        chance = 20,
        name = 'Major Fuel Leak',
        description = 'Fuel tank ruptured - fuel continuously leaking',
        repairTime = 10000,
        repairAnim = 'WORLD_HUMAN_WELDING',
        repairItem = 'weldingkit', -- Set to item name if using inventory items
        keepItem = true, -- true = keep item after use, false = consume item
        targetBone = 'petrolTank', -- Bone for ox_target interaction
        targetOptions = {
            icon = 'fas fa-gas-pump',
            label = 'Repair Fuel Tank',
            distance = 2.5
        },
        effects = {
            petrolTankHealth = 100, -- Very low tank health
            fuelLevel = 8 -- Low fuel that will keep draining
        }
    },
    ['broken_windows'] = {
        enabled = true,
        chance = 20,
        name = 'Broken Windows',
        description = 'Multiple windows shattered - glass everywhere',
        repairTime = 9000,
        repairAnim = 'WORLD_HUMAN_HAMMERING',
        repairItem = 'glass', -- Set to item name if using inventory items
        keepItem = false, -- true = keep item after use, false = consume item
        targetBone = 'windscreen', -- Bone for ox_target interaction
        targetBones = { -- Multiple window bones for ox_target
            'windscreen',
            'windscreen_r',
            'window_lf',
            'window_rf',
            'window_lr',
            'window_rr'
        },
        targetOptions = {
            icon = 'fas fa-hammer',
            label = 'Replace Windows',
            distance = 2.0
        },
        effects = {
            brokenWindows = true, -- Will break multiple windows
            bodyHealth = 700 -- Some body damage from impact
        }
    },
    ['body_damage'] = {
        enabled = true,
        chance = 100, -- Rarest but most severe
        name = 'Severe Body Damage',
        description = 'Vehicle heavily damaged from collision',
        repairTime = 15000,
        repairAnim = 'WORLD_HUMAN_WELDING',
        repairItem = 'plastic', -- Set to item name if using inventory items
        keepItem = false, -- true = keep item after use, false = consume item
        targetBone = 'bodyshell', -- Bone for ox_target interaction
        targetBones = { -- Multiple body bones for ox_target
            'bodyshell',
            'door_dside_f',
            'door_pside_f',
            'door_dside_r',
            'door_pside_r',
            'bonnet',
            'boot'
        },
        targetOptions = {
            icon = 'fas fa-car-crash',
            label = 'Repair Body Damage',
            distance = 2.5
        },
        effects = {
            bodyHealth = 200, -- Severe body damage
            bodyDamage = true, -- Additional visual damage
            engineHealth = 500 -- Some engine damage from impact
        }
    }
}




--[[ String Configs ]]
Notifications = {
    position = 'top', -- The position of all notifications
    icon = 'truck-ramp-box', -- The icon displayed for all notifications
    title = 'Tow Truck', -- The title for all notifications
    notAuthorized = 'You are not authorized to perform this job - you must have one of the required jobs',
    successfulVehicleLoad = 'You have successfully loaded the vehicle onto the Tow Truck',
    cancelledVehicleLoad = 'You cancelled loading the vehicle',
    notCloseEnough = 'You are not close enough to the vehicle you are trying to tow',
    sucessfulVehicleUnload = 'You have successfully unloaded the vehicle from the Tow Truck',
    cancelledVehicleUnload = 'You cancelled unloading the vehicle',
    error = 'An error has occured - please try again',
    noVehicleToUnload = 'There is no vehicle on the truck to unload',
    towTruckSpawnOccupied = 'The location is currently occupied - please move any vehicles and try again',
    clockedIn = 'You will now start receiving jobs as they become available',
    tooFarToDeliver = 'You are too far from the delivery location to get paid',
    confirmNextJob = 'Great - a new job will be assigned as it becomes available',
    searchingForJob = 'Searching for a new job location..',
    jobAssigned = 'A new job is available - your GPS was updated',
    -- Car Disability Notifications
    vehicleDisabled = 'Vehicle has mechanical issues - repair for bonus pay!',
    repairStarted = 'Attempting to repair vehicle...',
    repairCompleted = 'Vehicle repaired successfully!',
    repairCancelled = 'Repair cancelled',
    repairBonus = 'Repair bonus earned!',
    weatherBonus = 'Weather bonus earned for difficult conditions!',
    noDisabilities = 'This vehicle has no mechanical issues'
}

Target = {
    distance = 2, -- The radius at which target options are visable from the target for all target options
    loadVehicle = 'Load vehicle',
    loadVehicleIcon = 'fas fa-truck-ramp-box',
    unloadVehicle = 'Unload vehicle',
    unloadVehicleIcon = 'fas fa-truck-ramp-box',
    startJob = 'Talk',
    startJobIcon = 'fas fa-truck'
}

ContextMenu = {
    menuTitle = 'Towing',
    towTruckTitle = 'Tow Truck',
    towTruckDescription = 'Receive your Tow Truck then Clock In to begin work',
    towTruckIcon = 'truck',
    clockInTitle = 'Clock In',
    clockInDescription = 'Show yourself as on-duty & ready to receive calls', -- This description displays whilst not clocked in
    clockInDescription2 = 'You are already on-duty & receiving calls', -- This description displays whilst clocked in
    clockInIcon = 'clock',
    clockOutTitle = 'Clock Out',
    clockOutDescription = 'Return your truck and go off-duty', -- This description displays whilst clocked in
    clockOutDescription2 = 'You\'re not clocked in', -- This description displays whilst not clocked in
    clockOutIcon = 'clock'
}

ProgressCircle = {
    position = 'middle', -- The position for all Progress Circles
    loadVehicleLabel = 'Loading vehicle..',
    loadVehicleDuration = 5000,
    unloadVehicleLabel = 'Unloading vehicle..',
    unloadVehicleDuration = 5000
}

AlertDialog = {
    header = 'Towing',
    content = 'Thank you for delivering the vehicle to the impound. Would you like to continue?',
}

--[[ Car Models ]]
Config.CarModels = {
    "blista",
    "panto",
    "brioso",
    "issi2",
    "asea",
    "emperor",
    "ingot",
    "primo",
    "regina",
    "stanier",
    "baller",
    "cavalcade",
    "granger",
    "landstalker",
    "mesa",
    "patriot",
    "seminole",
    "adder",
    "buffalo",
    "comet2",
    "furoregt",
    "kuruma",
    "lynx",
    "neon",
    "pariah",
    "raptor",
    "schafter2",
    "sultan",
    "surano",
    "blade",
    "buccaneer",
    "dominator",
    "phoenix",
    "picador",
    "sabregt",
    "tampa",
    "vigero",
    "bison",
    "minivan",
    "pony",
    "rumpo",
    "youga",
    "dune",
    "bodhi2",

}