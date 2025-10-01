Locale = {
    Notifications = {
        position = 'top', -- The position of all notifications
        icon = 'truck-ramp-box', -- The icon displayed for all notifications
        title = 'Tow Truck', -- The title for all notifications
        notAuthorized = 'You are not authorized to perform this job.',
        notInGroup = 'You must be in a group to access the towing job.',
        groupJobAssigned = 'Your group has been assigned a towing job! Check your GPS for the pickup location.',
        groupPayment = 'Towing job completed! Payment has been distributed among group members.',
        groupJobCancelled = 'The towing job has been cancelled.',
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
        allLocationsOccupied = 'All locations are currently occupied. Please wait for other jobs to complete.',
        jobAssigned = 'A new job is available - your GPS was updated',
        vehicleHasIssues = 'This vehicle has issues that need to be fixed before delivery!',
        vehicleRepaired = 'Vehicle issue repaired successfully!',
        vehicleReadyForDelivery = 'All issues fixed! Vehicle is ready for delivery.',
        missingRepairItems = 'You need the required items to fix this issue.',
        repairCancelled = 'Vehicle repair was cancelled.',
        repairOnCooldown = 'Please wait a moment before attempting another repair.',
        inspectVehicle = 'Inspect the vehicle to see what needs to be fixed.',
        dependencyRequired = 'You must fix the Electrical issue before repairing the Engine.'
    },

    Target = {
        distance = 2, -- The radius at which target options are visible from the target for all target options
        loadVehicle = 'Load vehicle',
        loadVehicleIcon = 'fas fa-truck-ramp-box',
        unloadVehicle = 'Unload vehicle',
        unloadVehicleIcon = 'fas fa-truck-ramp-box',
        startJob = 'Talk',
        startJobIcon = 'fas fa-truck',
        inspectVehicle = 'Inspect Vehicle',
        inspectVehicleIcon = 'fas fa-search',
        repairTires = 'Repair Tires',
        repairTiresIcon = 'fas fa-tools',
        repairEngine = 'Repair Engine',
        repairEngineIcon = 'fas fa-wrench',
        repairBody = 'Repair Body',
        repairBodyIcon = 'fas fa-hammer',
        refuelVehicle = 'Refuel Vehicle',
        refuelVehicleIcon = 'fas fa-gas-pump',
        repairElectrical = 'Fix Electrical',
        repairElectricalIcon = 'fas fa-bolt'
    },

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
    },

    ProgressCircle = {
        position = 'middle', -- The position for all Progress Circles
        loadVehicleLabel = 'Loading vehicle..',
        loadVehicleDuration = 5000,
        unloadVehicleLabel = 'Unloading vehicle..',
        unloadVehicleDuration = 5000,
        repairTiresLabel = 'Repairing tires..',
        repairEngineLabel = 'Repairing engine..',
        repairBodyLabel = 'Repairing body damage..',
        refuelVehicleLabel = 'Refueling vehicle..',
        repairElectricalLabel = 'Fixing electrical issues..',
        inspectVehicleLabel = 'Inspecting vehicle..',
        inspectVehicleDuration = 3000
    },

    AlertDialog = {
        header = 'Towing',
        content = 'Thank you for delivering the vehicle to the impound. Would you like to continue?',
    }
    ,

    OfficerUI = {
        title = 'Urgent Tow Drop-off',
        useWaypoint = 'Use waypoint location',
        snapDepot = 'Snap to nearest depot',
        snapRoad = 'Snap to nearest road'
    }
}

-- Expose language-specific alias for loader
Locale_en = Locale