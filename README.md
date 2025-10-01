# lation_towing

[![Release](https://img.shields.io/github/v/release/Gareb-Fivem-Dev/lation_towing?sort=semver)](https://github.com/Gareb-Fivem-Dev/lation_towing/releases)
[![Changelog](https://img.shields.io/badge/Changelog-1.1-blue.svg)](https://github.com/Gareb-Fivem-Dev/lation_towing/blob/main/CHANGELOG.md)
[![Release Notes](https://img.shields.io/badge/Release%20Notes-v1.1-brightgreen.svg)](https://github.com/Gareb-Fivem-Dev/lation_towing/blob/main/RELEASE_NOTES_1.1.md)

Advanced towing job for QBCore/QBox with optional group play (slrn_groups) and immersive vehicle repair tasks.

## Overview

lation_towing adds a clock-in towing job where players receive random pickup locations, tow vehicles to a depot, and get paid. Optional integration with slrn_groups lets groups take the job together and share payouts. Vehicles can spawn with random issues that must be inspected and repaired before delivery, with optional item requirements/consumption.

## Releases

- Latest: v1.1 — https://github.com/Gareb-Fivem-Dev/lation_towing/releases/tag/v1.1
- Full list: https://github.com/Gareb-Fivem-Dev/lation_towing/releases
- Notes: see [RELEASE_NOTES_1.1.md](https://github.com/Gareb-Fivem-Dev/lation_towing/blob/main/RELEASE_NOTES_1.1.md) and [CHANGELOG.md](https://github.com/Gareb-Fivem-Dev/lation_towing/blob/main/CHANGELOG.md)

## Features

- QBCore/QBox towing job with random pickup locations and payments
- Optional job restriction to specific jobs (mechanic/tow etc.)
- Optional slrn_groups integration:
  - Group-required mode and shared payments
  - Group blips for pickup/drop-off
  - Interactive group prompt with street name, location index, and Set Waypoint button
- Random drop-off location per job (uses Config.DeliverLocations with fallback)
- Vehicle Issues system:
  - Random issues (tires/engine/body/fuel/electrical)
  - Inspect and repair, with configurable items and consumption
  - Bonus pay per issue fixed
  - Restrict repairs to mission vehicle; ownership enforced (owner/group)
  - Optional public repairs allowed before the vehicle is attached
  - Per-player repair cooldown to prevent spam
- Urgent LEO tow calls (group-only), with SLA timer and business payout
- Debug flags for detailed server/client logs

## Requirements

- QBCore (qb-core) or QBox (qbx-core)
- ox_lib (ensure `@ox_lib/init.lua` is in fxmanifest shared_scripts)
- ox_target (for interaction targets; this script uses ox_target only)
- Optional: slrn_groups (for group integration)
 - Optional: ox_inventory (auto-detected for item checks/removal)
 - Optional: Renewed-Banking (for urgent tow business payouts)

## Installation

1. Place the `lation_towing` folder in your resources directory.
2. Ensure required dependencies are started before this resource (`ox_lib`, `qb-core/qbx_core`, `ox_target`).
3. If using groups, install and start `slrn_groups`.
4. Add `ensure lation_towing` in your server.cfg after the dependencies.

## Configuration

All settings are in `lation_towing/config.lua`.

- Framework and toggles
  - `Config.Framework = 'qbcore'` (detected automatically at runtime; qbx-core also supported)
  - `Config.RequireJob = false` and `Config.JobName = { 'mechanic', 'tow', 'police', 'ambulance' }`
  - `Config.UseSlrnGroups = false` and `Config.SlrnGroupsJobType = 'towing'`
  - `Config.ClientDebug = false`, `Config.ServerDebug = false`

- Start/delivery
  - `Config.StartJobLocation` (vec3), `Config.StartJobRadius`, `Config.StartJobPedModel`, `Config.StartJobPedHeading`
  - `Config.SpawnTruckLocation` (vector3), `Config.SpawnTruckHeading`
  - `Config.TowTruckModel` (string) — model name to spawn for the tow truck (e.g., `flatbed`, `flatbed3`)
  - `Config.DeliverLocation` (vec3, fallback)
  - `Config.DeliverLocations` (table of vec3) — optional list used to pick a random drop-off per job
  - `Config.DeliverRadius`
  - `Config.MinWaitTime`, `Config.MaxWaitTime` (minutes between jobs)

- Pay
  - `Config.RandomPayPerDelivery`, `Config.MinPayPerDelivery`, `Config.MaxPayPerDelivery`
  - or fixed `Config.PayPerDelivery`; `Config.PayPerDeliveryAccount = 'money' | 'bank'`

- Vehicle Issues
  - `Config.EnableVehicleIssues = true`
  - `Config.VehicleIssueChance` (0–100), `Config.MaxIssuesPerVehicle`
  - `Config.RepairBonusPay` (bonus per fixed issue)
  - `Config.AllowPublicRepairsBeforeAttach` (public can repair before the vehicle is attached)
  - `Config.RepairCooldownMs` (per-player cooldown)
  - Per-issue config (example):
    ```lua
    Config.VehicleIssues = {
      flat_tires = {
        enabled = true,
        chance = 40,
        description = 'Vehicle has flat tires that need to be repaired',
        fixTime = 8000,
        requiresItems = true,
        remove = true, -- consume items on success
        items = { 'sparetire' },
      },
      -- engine_damage, body_damage, fuel_empty, electrical_issues...
    }
    ```

- Locations and Vehicles
  - `Config.Locations` list of vector4 spawn points; index is referenced in group prompts
  - `Config.CarModels` list of model names to spawn as targets

- UI strings
  - `Notifications`, `Target`, `ContextMenu`, `ProgressCircle`, `AlertDialog`

### Localization

- Set the language in `config.lua`:
  - `Config.Locale = 'en'` (English) or `Config.Locale = 'de'` (German)
- Translations live in `locales/<lang>.lua` and provide the same tables used by the client:
  - `Notifications`, `Target`, `ContextMenu`, `ProgressCircle`, `AlertDialog`
- Adding a new language:
  1) Create `locales/es.lua` (for example) that defines `Locale = { ... }`
  2) Optionally also set `Locale_es = Locale` at the end of the file for explicit selection
  3) Set `Config.Locale = 'es'`
  The loader maps the selected locale into the existing globals, so no other code changes are needed.

### Roadwork Signs (optional)

Allow tow operators to place temporary roadwork signs that slightly slow nearby AI drivers and auto-despawn after a short time.

- Config (in `config.lua`):
  - `Config.EnableRoadworkSigns = true` — enable/disable the feature
  - `Config.RoadSignModel = 'prop_consign_01b'` — the prop to spawn
  - `Config.RoadSignDuration = 300` — lifetime in seconds before auto-despawn
  - `Config.RoadSignSlowRadius = 25.0` — radius (meters) for AI slow-down
  - `Config.RoadSignSpeedValue = 40` — target speed value interpreted by units below
  - `Config.RoadSignSpeedUnits = 'kph'` — 'kph' or 'mph' (converted to m/s internally)
  - `Config.RoadSignMaxActive = 2` — per-player active signs cap

- Usage:
  - Target the tow truck and select “Place Roadwork Sign.”
  - Pick up a sign by targeting it and choosing “Pick up sign,” or let it auto-despawn.
  - Nearby AI drivers are gently capped to the configured speed while in the radius.

## Usage

1. Go to the start ped and clock in.
2. Wait for a job; a blip and waypoint will be set to the pickup.
3. If Vehicle Issues are enabled, inspect and repair the target vehicle (targets appear on the vehicle).
4. Attach to the flatbed and drive to the delivery point.
5. Detach within the radius to get paid; bonus is added per fixed issue.

### Group Flow (slrn_groups)

- When a group has a job, all members receive:
  - A group blip to the pickup and drop-off
  - An interactive prompt: shows the location number and street; “Set Waypoint” button
- Payment is split evenly among online group members; remainder goes to the person who completes the delivery.

### Urgent LEO Tow Calls (optional)

Enable group-only urgent tows for “blocking lane” situations. Requires `slrn_groups`.
#### Try it (admin quickstart)

1) Ensure dependencies are running: `ox_lib`, `ox_target`, your framework (`qb-core` or `qbx-core`), and `slrn_groups`.
2) In `config.lua`, set:
  - `Config.EnableUrgentLEOTow = true`
  - Ensure your LEO jobs are listed in `Config.LEOJobNames`
  - If using Renewed-Banking for payouts, set `Config.UseRenewedBanking = true` and `Config.UrgentTowBusiness` to a valid business.
3) As a LEO on the server, set a waypoint on the map and stand near the blocking vehicle.
4) Run `/towcall`.
5) Choose a drop-off option in the prompt (Waypoint / Nearest Depot / Nearest Road).
6) On a tow group, run `/towaccept <id>` to take the job.
7) Attach, drive to the selected drop-off, detach to complete.
8) As LEO, run `/towpay <id> [amount]` to pay the group from the configured business.


- Enable: `Config.EnableUrgentLEOTow = true`
- LEO detection: any job with `job.type == 'leo'` or job name in `Config.LEOJobNames`
- Time limit: `Config.UrgentTowTimeLimit` seconds; fast clearance bonus: `Config.UrgentTowFastBonus`
- Suggested base pay: `Config.UrgentTowBasePay`
- Business account for payout: `Config.UrgentTowBusiness` (default 'police')
- Use Renewed-Banking for automatic business debits: `Config.UseRenewedBanking = true`

Commands:
- `/towcall` (LEO) — Mark the vehicle in front of you for urgent tow; notifies all groups.
- `/towaccept <id>` (Group) — Accept the specific urgent call.
- `/towpay <id> [amount]` (LEO) — Pay the completing group from the police business account. If amount is omitted, a suggested payout is calculated based on SLA/bonus.

Flow:
1) Officer sets a map waypoint at the intended drop-off location, then uses `/towcall` near the blocking vehicle.
2) When prompted, the officer picks one of the following drop-off options:
  - Use waypoint location (exact map waypoint)
  - Snap to nearest depot (nearest entry in `Config.DeliverLocations`; label shown if `Config.DeliverLabels` is set)
  - Snap to nearest road (closest vehicle road node near the waypoint)
  If no waypoint is set, the officer is asked to set one and try `/towcall` again.
3) A group accepts with `/towaccept <id>` and receives the pickup waypoint. After attaching the target vehicle, the drop-off waypoint/blip is set to the officer-selected destination.
4) Group tows and delivers the vehicle; the job is marked complete and awaits payout.
5) Officer completes `/towpay <id> [amount]`; funds debit from business via Renewed-Banking (if enabled) and distribute to the group.

Notes:
- If the officer chose “nearest depot,” the selected depot index is propagated so the drop-off blip can be named using `Config.DeliverLabels[index]` when available. Otherwise, the default drop-off blip name is used.
- Waypoint/road selections do not carry a depot label and will use the default drop-off name.

### Officer Flow (visual)

Below is a short visual walkthrough of the urgent tow officer flow:

1. Set a map waypoint for the intended drop-off location.
2. Stand near the blocking vehicle and run `/towcall`.
3. Select the destination type in the menu (Waypoint / Nearest Depot / Nearest Road).
4. Wait for a group to accept and complete the tow; finalize payment with `/towpay`.

Media placeholder (replace this with your capture):

![Officer Urgent Tow Flow](docs/officer-urgent-tow.gif)

Tips for creating the GIF:
- Use OBS Studio to record a short 10–20s clip; export to MP4.
- Convert MP4 to GIF using an online tool or ffmpeg.
- Place the resulting file at `lation_towing/docs/officer-urgent-tow.gif`.

Optional UI screenshots:

![Officer Drop-off Selection UI](docs/officer-dropoff-ui.png)
![Group Job Prompt](docs/group-job-prompt.png)

Place your PNGs in `lation_towing/docs/` with the names above.

### Tow Group Flow (visual)

Short visual from the tow group perspective:

1. Receive group notification and accept with `/towaccept <id>`.
2. Drive to pickup, attach the vehicle.
3. Follow the drop-off waypoint to the officer-selected destination.
4. Detach within the radius to mark completion and await payout.

Media placeholder (replace this with your capture):

![Tow Group Urgent Tow Flow](docs/tow-group-urgent-tow.gif)

Tips:
- Keep it short (10–20s) showing accept → attach → deliver.
- Place the file at `lation_towing/docs/tow-group-urgent-tow.gif`.

## Debugging

Flip these in `config.lua` as needed:

- `Config.ServerDebug = true` → logs mission spawn, issues generation, authorization results, repairs (incl. cooldown and items), payment, cleanup
- `Config.ClientDebug = true` → logs mission receipt, target setup, attach/detach, readiness and pay checks, and group UI events

## Events & Callbacks (internal)

- Server callbacks (ox_lib):
  - `lation_towtruck:spawnMissionVehicle` → returns { vehicleNetId, plate, location, deliver, issues }
  - `lation_towtruck:cleanupMissionVehicle`
  - `lation_towtruck:inspectVehicle(vehicleNetId)` → table of issues
  - `lation_towtruck:repairVehicleIssue(vehicleNetId, issueType)` → success, reason
  - `lation_towtruck:checkVehicleReady(vehicleNetId)` → boolean
  - `lation_towtruck:checkDistance()` → boolean
  - `lation_towtruck:payPlayer(vehicleNetId)` → boolean
  - `lation_towtruck:checkGroupRequirement()` → 'authorized' | 'notAuthorized' | 'notInGroup'

- Server events:
  - `lation_towtruck:server:markAttached(vehicleNetId)` → marks mission vehicle as attached (restricts repairs to owner/group)

- Group broadcast:
  - `exports.slrn_groups:triggerGroupEvent('lation_towing:client:groupJobAssigned', groupId, coords, locationIndex)`
  - `exports.slrn_groups:triggerGroupEvent('lation_towing:client:startUrgentMission', groupId, data)` — data includes coords, vehicleNetId, plate, urgentId, timeLimit, and deliver
  - Client handler shows street name, location index, and a “Set Waypoint” button

## Troubleshooting

- “Undefined global lib/cache” in lint: ox_lib provides these at runtime; ensure `@ox_lib/init.lua` is loaded.
- No interactive group UI: ensure `slrn_groups` is started and `Config.UseSlrnGroups = true`.
  - Note: Urgent LEO tow calls require `slrn_groups` enabled to receive group broadcasts.
- Items not found/removed: verify item names exist in your inventory (qb-core/shared items or ox_inventory definitions). Set `requiresItems`/`remove` per issue as desired.
  - Note: If ox_inventory is installed, the script uses it automatically for item checks/removal.
- “No interaction targets”: ensure `ox_target` is installed and started; this resource uses ox_target only.
 - Urgent payouts: If using Renewed-Banking, ensure the business account (e.g., 'police') exists and has funds; otherwise disable banking integration and pay players directly.
- Keys: The example uses `exports.wasabi_carlock:GiveKey(plate)` on tow truck spawn. If you use a different key resource, replace or remove that line. There’s a placeholder in `endJob()` for removing keys.
- Can’t repair a vehicle: only mission vehicles can be repaired; before attach, public repairs are allowed if enabled, after attach only the owner or group can repair.

## License

See LICENSE.

## Credits

- Built upon the upstream project by IamLation (baseline v1.0.3): https://github.com/IamLation/lation_towing

## Required Items (examples)

If you enable item requirements in `Config.VehicleIssues`, make sure these items exist in your inventory system. Below are examples matching the default config items.

### qb-core (shared/items.lua)

Add entries like:

```lua
-- Tires
['sparetire'] = {
    name = 'sparetire', label = 'Spare Tire', weight = 5000, type = 'item', image = 'sparetire.png', unique = false, useable = true, shouldClose = true, description = 'A spare tire to get you rolling again.'
},

-- Engine repair
['repair_kit'] = {
    name = 'repair_kit', label = 'Repair Kit', weight = 3000, type = 'item', image = 'repairkit.png', unique = false, useable = true, shouldClose = true, description = 'Basic vehicle repair kit.'
},

-- Body repair
['body_repair_kit'] = {
    name = 'body_repair_kit', label = 'Body Repair Kit', weight = 3500, type = 'item', image = 'bodyrepairkit.png', unique = false, useable = true, shouldClose = true, description = 'Panel beating essentials.'
},

-- Fuel
['jerry_can'] = {
    name = 'jerry_can', label = 'Jerry Can', weight = 7000, type = 'item', image = 'jerrycan.png', unique = false, useable = true, shouldClose = true, description = 'Portable fuel can.'
},

-- Electrical
['electrical_repair_kit'] = {
    name = 'electrical_repair_kit', label = 'Electrical Kit', weight = 2500, type = 'item', image = 'electricalkit.png', unique = false, useable = true, shouldClose = true, description = 'Fuses, wire, and tools for electrical fixes.'
},
```

Images are just examples; adjust to your inventory UI assets. Names must match `Config.VehicleIssues.*.items`.

### ox_inventory (data/items.lua)

Define items similarly:

```lua

  sparetire = {
    label = 'Spare Tire',
    weight = 5000,
    stack = true,
    close = true,
    description = 'A spare tire to get you rolling again.',
    client = { image = 'sparetire.png' }
  },
  repair_kit = {
    label = 'Repair Kit',
    weight = 3000,
    stack = true,
    close = true,
    description = 'Basic vehicle repair kit.',
    client = { image = 'repairkit.png' }
  },
  body_repair_kit = {
    label = 'Body Repair Kit',
    weight = 3500,
    stack = true,
    close = true,
    description = 'Panel beating essentials.',
    client = { image = 'bodyrepairkit.png' }
  },
  jerry_can = {
    label = 'Jerry Can',
    weight = 7000,
    stack = true,
    close = true,
    description = 'Portable fuel can.',
    client = { image = 'jerrycan.png' }
  },
  electrical_repair_kit = {
    label = 'Electrical Kit',
    weight = 2500,
    stack = true,
    close = true,
    description = 'Fuses, wire, and tools for electrical fixes.',
    client = { image = 'electricalkit.png' }
  },

```

Notes
- If `requiresItems = true` but `remove = false`, the script checks for the items but does not consume them.
- If `remove = true`, one of each item listed is consumed on a successful repair.
- You can customize item names per issue; just keep `Config.VehicleIssues.*.items` in sync with your item definitions.
