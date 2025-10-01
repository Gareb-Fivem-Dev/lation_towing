Config = {}

--[[ General Configs ]]
Config.Framework = 'qbcore' -- QBCore or QBox supported; detected automatically at runtime
Config.Locale = 'en' -- Language code: 'en' (English), 'de' (German)
Config.ClientDebug = true -- Enable client debug prints
Config.ServerDebug = true -- Enable server debug prints
Config.RequireJob = true -- Do you want this to be only for players with a specific job? (True if yes, false if no)
Config.JobName = {'mechanic', 'towtruck', 'police', 'ambulance'} -- The job names required if Config.RequireJob is true (can be multiple jobs)
Config.UseSlrnGroups = true -- Enable slrn_groups integration for group-based towing jobs (requires slrn_groups resource)
Config.SlrnGroupsJobType = 'towing' -- The job type to set when a group starts a towing job (only used if UseSlrnGroups is true)
Config.StartJobPedModel = 'a_m_m_business_01' -- The model of the ped that starts the job
Config.StartJobLocation = vec3(1242.0847, -3257.0403, 5.0288) -- The location at which you start the job (and the map blip location)
Config.DeliverLocation = vec3(393.0399, -1617.5004, 29.2920) -- Default/fallback delivery location (if no list below)
-- Optional: a list of random delivery locations to choose from per job
Config.DeliverLocations = {
    vec3(393.0399, -1617.5004, 29.2920), -- Davis Depot
    vec3(408.8619, -1623.0880, 29.2919), -- Davis Depot (alt)
    vec3(-179.3554, -1161.8463, 23.6896), -- Little Seoul impound
    vec3(478.2103, -1316.4548, 29.2070), -- Mission Row back lot
    vec3(800.9758, -2147.0920, 28.7649)  -- La Mesa yard
}
-- Optional human-friendly labels for drop-off depots, aligned by index with DeliverLocations
Config.DeliverLabels = {
    'Davis Depot',
    'Davis Depot (Alt)',
    'Little Seoul Impound',
    'Mission Row Back Lot',
    'La Mesa Yard'
}
Config.DeliverRadius = 10 -- The radius at which the player must be within (in relation to DeliverLocation) to get paid for delivering
Config.StartJobRadius = 50 -- The distance at which once a player is within the ped will spawn/be visable
Config.StartJobPedHeading = 272.1205 -- The direction at which the start job ped is facing
Config.SpawnTruckLocation = vector3(1247.0011, -3262.6636, 5.8075) -- The location at which the tow truck spawns to start the job
Config.SpawnTruckHeading = 269.8075 -- The direction the tow truck being spawned is facing
Config.TowTruckModel = 'flatbed' -- Model name for the tow truck
Config.EnableCarKeys = false -- QBCore key system already works
Config.MinWaitTime = 1 -- The minimum wait time in minutes for a new job assignment
Config.MaxWaitTime = 2 -- The maximum wait time in minutes for a new job assignment

--[[ Urgent LEO Tow Calls ]]
-- Allows police (job.type 'leo') to dispatch urgent tow requests for lane-blocking vehicles.
-- Towing groups can accept these calls; payment is done by police via business account command.
Config.EnableUrgentLEOTow = true
Config.LEOJobNames = { 'police', 'bcso', 'sasp', 'gamewarden' } -- Jobs allowed to create urgent calls
Config.UrgentTowTimeLimit = 600 -- seconds to clear for full pay (SLA). Faster => more bonus
Config.UrgentTowBasePay = 700 -- Base suggested pay for an urgent tow (paid by police business)
Config.UrgentTowFastBonus = 400 -- Extra if cleared within 50% of SLA
Config.UrgentTowPayPerMember = false -- If true, pay amount is per member; else split among members
Config.UrgentTowBusiness = 'police' -- Renewed-Banking business name for payment (if used)
Config.UseRenewedBanking = true -- Use Renewed-Banking for business payouts; if false, fallback to framework society accounts if configured

--[[ Pay Conigs ]]
Config.PayPerDelivery = 500 -- How much the player is paid per delivery completed
Config.PayPerDeliveryAccount = 'money' -- Pay in cash with 'money' or to the bank with 'bank'
Config.RandomPayPerDelivery = true -- Set true if you want randomized pay, set false for same amount (PayPerDelivery).
Config.MinPayPerDelivery = 350 -- If Config.RandomPayPerDelivery = true then what is the minimum pay? (If RandomPay false, ignore this)
Config.MaxPayPerDelivery = 950 -- If Config.RandomPayPerDelivery = true then what is the maxmimum pay? (If RandomPay false, ignore this)

--[[ Vehicle Issues Configs ]]
Config.EnableVehicleIssues = true -- Enable random vehicle issues that need to be fixed before delivery
Config.VehicleIssueChance = 75 -- Percentage chance (0-100) that a spawned vehicle will have issues
Config.MaxIssuesPerVehicle = 2 -- Maximum number of different issues a single vehicle can have
Config.RepairBonusPay = 100 -- Extra payment per issue fixed (added to base payment)
Config.AllowPublicRepairsBeforeAttach = true -- If true, anyone can repair a mission vehicle BEFORE it is attached to the tow truck; after attach, only owner/group can
Config.RepairCooldownMs = 2000 -- Milliseconds between repair attempts per player to prevent spam

--[[ Roadwork Signs Configs ]]
Config.EnableRoadworkSigns = true -- Enable placeable temporary roadwork signs
Config.RoadSignModel = 'prop_consign_01b' -- Prop model for the roadwork sign
Config.RoadSignDuration = 300 -- Seconds before a placed sign auto-despawns
Config.RoadSignSlowRadius = 25.0 -- Radius (meters) where AI drivers slow down around the sign
Config.RoadSignSpeedValue = 15 -- Target speed value for AI near the sign (interpreted by RoadSignSpeedUnits)
Config.RoadSignSpeedUnits = 'mph' -- 'kph' or 'mph' (converted to m/s internally for AI speed zones)
Config.RoadSignMaxActive = 2 -- Max active signs a player can place at once

--[[ Skill Checks & Realism ]]
Config.SkillCheck = {
    enabled = true,
    -- Keys to apply skill checks to; label->ox_lib skill check preset
    issues = {
        flat_tires = {'easy', 'easy', 'medium'},
        engine_damage = {'medium', 'medium', 'hard'},
        body_damage = {'easy', 'medium'},
        electrical_issues = {'medium', 'hard'}
    },
    failPenaltySeconds = 4, -- add seconds on fail
    extraConsumptionOnFail = true -- if issue.remove=true and fail, consume one extra item (if available)
}

-- Chained issue dependencies: when true, sometimes electrical must be fixed before engine
Config.IssueDependencies = {
    electricalBeforeEngine = true,
    chance = 40 -- percent chance to enforce dependency for a spawned vehicle
}

-- Weather/time modifiers (requires Renewed-Weathersync for weather; time from game clock)
Config.WeatherModifiers = {
    enabled = true,
    useRenewedWeathersync = true, -- if true, read weather via Renewed-Weathersync export; else fallback to GetPrevWeatherTypeHashName()
    repairDurationMultiplier = {
        night = 1.15, -- 15% longer at night
        rain = 1.25   -- 25% longer in rain
    },
    issueChanceBoost = {
        rain = {
            electrical_issues = 12, -- +12% chance
            flat_tires = 8          -- +8% chance
        },
        night = {
            electrical_issues = 5
        }
    },
    payBonusPercent = {
        rain = 7,  -- +7% pay
        night = 4  -- +4% pay
    }
}

-- Available vehicle issues and their configurations
Config.VehicleIssues = {
    flat_tires = {
        enabled = true,
        chance = 40, -- Percentage chance this specific issue will occur
        description = 'Vehicle has flat tires that need to be repaired',
        fixTime = 8000, -- Time in milliseconds to fix this issue
        requiresItems = true, -- Set to true if you want to require specific items
        remove = true, -- If true, consume listed items on successful repair
        items = {'sparetire'}, -- Items needed to fix (e.g., {'tire_repair_kit'})
    },
    engine_damage = {
        enabled = true,
        chance = 35,
        description = 'Vehicle engine is damaged and needs repair',
        fixTime = 10000,
        requiresItems = true,
        remove = false,
        items = {'repair_kit'}, -- e.g., {'engine_repair_kit'}
    },
    body_damage = {
        enabled = true,
        chance = 30,
        description = 'Vehicle body is heavily damaged',
        fixTime = 6000,
        requiresItems = true,
        remove = true,
        items = {'body_repair_kit'}, -- e.g., {'body_repair_kit'}
    },
    fuel_empty = {
        enabled = true,
        chance = 25,
        description = 'Vehicle is out of fuel',
        fixTime = 5000,
        requiresItems = true,
        remove = true,
        items = {'jerry_can'}, -- e.g., {'jerry_can'}
    },
    electrical_issues = {
        enabled = true,
        chance = 20,
        description = 'Vehicle has electrical problems',
        fixTime = 7000,
        requiresItems = true,
        remove = true,
        items = {'electrical_repair_kit'}, -- e.g., {'electrical_repair_kit'}
    }
}

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
    [1] = { vector4(1015.3276, -2462.3572, 27.7853, 82.8159) },    -- Port of Los Santos
    [2] = { vector4(-247.7807, -1687.8434, 33.4754, 178.8647) },   -- Near Downtown
    [3] = { vector4(372.9686, -767.0320, 29.2700, 0.0682) },       -- Pillbox Hill
    [4] = { vector4(-1276.2042, -556.5905, 30.2092, 219.8612) },   -- Del Perro
    [5] = { vector4(1205.2948, -708.5202, 59.4169, 9.6660) },      -- Mirror Park
    [6] = { vector4(213.8225, 389.6160, 106.5621, 171.4204) },     -- Vinewood Hills
    [7] = { vector4(-449.8099, 98.6727, 62.8731, 355.5552) },      -- Rockford Hills
    [8] = { vector4(-928.4528, -124.9771, 37.2992, 117.7664) },    -- West Vinewood
    [9] = { vector4(-1772.7124, -519.8768, 38.5269, 299.9457) },   -- Del Perro Beach
    [10] = { vector4(-2165.7588, -420.4905, 13.0514, 20.4053) },   -- Pacific Bluffs
    [11] = { vector4(-1483.1953, -895.6342, 9.7399, 64.1165) }     -- Vespucci Beach
}

--[[ Car Models ]]
Config.CarModels = {
    'felon',
    'prairie',
    'baller',
    'sentinel',
    'zion',
    'ruiner',
    'asea',
    'ingot',
    'intruder',
    'primo',
    'stratum',
    'tailgater'
}

