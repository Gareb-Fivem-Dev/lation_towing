Locale = {
    Notifications = {
        position = 'top',
        icon = 'truck-ramp-box',
        title = 'Abschleppdienst',
        notAuthorized = 'Du bist nicht berechtigt, diesen Job auszuführen.',
        notInGroup = 'Du musst in einer Gruppe sein, um den Abschleppjob zu machen.',
        groupJobAssigned = 'Eurer Gruppe wurde ein Abschleppauftrag zugewiesen! Prüfe dein GPS für den Abholort.',
        groupPayment = 'Abschleppauftrag abgeschlossen! Die Zahlung wurde unter den Gruppenmitgliedern aufgeteilt.',
        groupJobCancelled = 'Der Abschleppauftrag wurde abgebrochen.',
        successfulVehicleLoad = 'Du hast das Fahrzeug erfolgreich auf den Abschleppwagen geladen.',
        cancelledVehicleLoad = 'Du hast das Beladen abgebrochen.',
        notCloseEnough = 'Du bist nicht nah genug am zu schleppenden Fahrzeug.',
        sucessfulVehicleUnload = 'Du hast das Fahrzeug erfolgreich abgeladen.',
        cancelledVehicleUnload = 'Du hast das Abladen abgebrochen.',
        error = 'Ein Fehler ist aufgetreten – bitte versuche es erneut.',
        noVehicleToUnload = 'Es befindet sich kein Fahrzeug auf dem Laster zum Abladen.',
        towTruckSpawnOccupied = 'Der Platz ist derzeit belegt – bitte räume die Fahrzeuge und versuche es erneut.',
        clockedIn = 'Du wirst nun Aufträge erhalten, sobald sie verfügbar sind.',
        tooFarToDeliver = 'Du bist zu weit vom Ablieferpunkt entfernt, um bezahlt zu werden.',
        confirmNextJob = 'Super – ein neuer Auftrag wird zugewiesen, sobald er verfügbar ist.',
        searchingForJob = 'Suche nach einem neuen Auftragsort..',
        allLocationsOccupied = 'Alle Orte sind derzeit belegt. Bitte warte, bis andere Aufträge abgeschlossen sind.',
        jobAssigned = 'Ein neuer Auftrag ist verfügbar – dein GPS wurde aktualisiert.',
        vehicleHasIssues = 'Dieses Fahrzeug hat Probleme, die vor der Ablieferung behoben werden müssen!',
        vehicleRepaired = 'Fahrzeugproblem erfolgreich behoben!',
        vehicleReadyForDelivery = 'Alle Probleme behoben! Fahrzeug ist bereit zur Ablieferung.',
        missingRepairItems = 'Du benötigst die erforderlichen Gegenstände, um dieses Problem zu beheben.',
        repairCancelled = 'Fahrzeugreparatur wurde abgebrochen.',
        repairOnCooldown = 'Bitte warte einen Moment, bevor du eine weitere Reparatur versuchst.',
        inspectVehicle = 'Untersuche das Fahrzeug, um zu sehen, was repariert werden muss.',
        dependencyRequired = 'Du musst zuerst die Elektrik reparieren, bevor du den Motor reparierst.'
    },

    Target = {
        distance = 2,
        loadVehicle = 'Fahrzeug laden',
        loadVehicleIcon = 'fas fa-truck-ramp-box',
        unloadVehicle = 'Fahrzeug entladen',
        unloadVehicleIcon = 'fas fa-truck-ramp-box',
        startJob = 'Sprechen',
        startJobIcon = 'fas fa-truck',
        inspectVehicle = 'Fahrzeug prüfen',
        inspectVehicleIcon = 'fas fa-search',
        repairTires = 'Reifen reparieren',
        repairTiresIcon = 'fas fa-tools',
        repairEngine = 'Motor reparieren',
        repairEngineIcon = 'fas fa-wrench',
        repairBody = 'Karosserie reparieren',
        repairBodyIcon = 'fas fa-hammer',
        refuelVehicle = 'Fahrzeug betanken',
        refuelVehicleIcon = 'fas fa-gas-pump',
        repairElectrical = 'Elektrik reparieren',
        repairElectricalIcon = 'fas fa-bolt'
    },

    ContextMenu = {
        menuTitle = 'Abschleppdienst',
        towTruckTitle = 'Abschleppwagen',
        towTruckDescription = 'Hole deinen Abschleppwagen und stempel dich ein, um mit der Arbeit zu beginnen',
        towTruckIcon = 'truck',
        clockInTitle = 'Einstempeln',
        clockInDescription = 'Melde dich als im Dienst & bereit für Aufträge',
        clockInDescription2 = 'Du bist bereits im Dienst & erhältst Aufträge',
        clockInIcon = 'clock',
        clockOutTitle = 'Ausstempeln',
        clockOutDescription = 'Gib deinen Laster zurück und geh außer Dienst',
        clockOutDescription2 = 'Du bist nicht eingestempelt',
        clockOutIcon = 'clock'
    },

    ProgressCircle = {
        position = 'middle',
        loadVehicleLabel = 'Fahrzeug wird geladen..',
        loadVehicleDuration = 5000,
        unloadVehicleLabel = 'Fahrzeug wird entladen..',
        unloadVehicleDuration = 5000,
        repairTiresLabel = 'Reifen werden repariert..',
        repairEngineLabel = 'Motor wird repariert..',
        repairBodyLabel = 'Karosserie wird repariert..',
        refuelVehicleLabel = 'Fahrzeug wird betankt..',
        repairElectricalLabel = 'Elektrik wird repariert..',
        inspectVehicleLabel = 'Fahrzeug wird untersucht..',
        inspectVehicleDuration = 3000
    },

    AlertDialog = {
        header = 'Abschleppdienst',
        content = 'Danke für die Ablieferung des Fahrzeugs. Möchtest du weitermachen?'
    }
    ,

    OfficerUI = {
        title = 'Dringender Abschlepp-Abgabeort',
        useWaypoint = 'Wegpunkt verwenden',
        snapDepot = 'Zum nächstgelegenen Depot schnappen',
        snapRoad = 'Zur nächsten Straße schnappen'
    }
}

-- Expose language-specific alias for loader
Locale_de = Locale
