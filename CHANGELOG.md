# Changelog

All notable changes to this resource will be documented here.
This project follows Keep a Changelog conventions with semantic groupings (Added/Changed/Fixed/Breaking/Upgrade) and Semantic Versioning.

This work builds upon and credits the original upstream project by IamLation:
- Upstream repository: https://github.com/IamLation/lation_towing
- Upstream baseline version used: 1.0.3

## [1.1] - 2025-10-01

### Added
- ox_target-only targeting (removed qtarget). All interactions now use ox_target.
- Framework bridge for qb-core and qbx-core with wrapper helpers (players, jobs, items, money).
- ox_inventory integration (auto-detected) for item checks and removal when `remove=true`.
- Config-driven tow truck model: `Config.TowTruckModel` used across spawn/detection/targets.
- Localization loader with English and German locales (`locales/en.lua`, `locales/de.lua`).
- Temporary roadwork signs feature:
  - Placeable prop, AI slow-zone around the sign, pickup, auto-despawn, and cleanup.
- Urgent LEO Tow Calls:
  - Commands: `/towcall` (LEO), `/towaccept <id>` (group), `/towpay <id> [amount]` (LEO payout from business).
  - Group broadcast via slrn_groups, SLA/bonus logic, and optional Renewed-Banking business payouts.
- Per-mission random drop-off:
  - `Config.DeliverLocations` list and per-job selection with fallback to `Config.DeliverLocation`.
  - Optional `Config.DeliverLabels` to name depots; drop-off blip shows the label when available.
- Repair skill checks (ox_lib):
  - Configurable by issue type via `Config.SkillCheck.issues` with fail penalty seconds and optional extra item consumption on fail.
- Issue dependencies:
  - Optional chaining where Engine repair requires Electrical fix first (`Config.IssueDependencies`).
- Weather/time realism modifiers:
  - Adjust issue chances and repair durations, and add pay bonus based on rain/night.
  - Optional Renewed-Weathersync integration for weather state.
- Officer drop-off selection UI for urgent calls:
  - Use current waypoint, snap to nearest depot (with label), or snap to nearest road; selected destination is used for delivery.
- Documentation updates:
  - README sections for random drop-offs, urgent LEO flow, officer selection UI, and visual flow placeholders (GIFs/screenshots).

### Changed
- Mission spawn now stores per-mission environment and deliver location (including for urgent missions).
- Payment flow:
  - Adds repair bonus per fixed issue and optional rain/night pay bonus; splits fairly among group members (remainder to deliverer).
- Callback return shapes:
  - `lation_towtruck:spawnMissionVehicle` returns `{ vehicleNetId, plate, location, deliver, issues }`.
  - Distance checks use per-mission `deliver` when available.
- Client repair/inspection UX shows dependency hint (engine requires electrical when applicable).

### Fixed
- Reduced noisy warnings by adding a "silent" cleanup path on urgent completion.
- Ground Z resolution for officer waypoint to improve distance checks when z=0.
- Minor native usage/sig correctness in various places.

### Breaking
- Targeting: qtarget removed; requires ox_target.
- Localization: several hard-coded strings moved into locale files; ensure `Config.Locale` is set and locale files are loaded in fxmanifest.
- New/updated config keys you may need to review:
  - Urgent LEO: `EnableUrgentLEOTow`, `LEOJobNames`, `UrgentTowTimeLimit`, `UrgentTowBasePay`, `UrgentTowFastBonus`, `UrgentTowPayPerMember`, `UrgentTowBusiness`, `UseRenewedBanking`.
  - Delivery: `DeliverLocations` (optional list) and `DeliverLabels` (optional names), `DeliverRadius`.
  - Realism: `SkillCheck`, `IssueDependencies`, `WeatherModifiers`.
  - Others: `TowTruckModel`, `AllowPublicRepairsBeforeAttach`, `RepairCooldownMs`.
- Server/client rely on ox_lib callbacks/events; ensure `@ox_lib/init.lua` is present in `fxmanifest.lua`.

### Upgrade notes
1) Dependencies: ensure `ox_lib`, `ox_target`, and your framework (`qb-core` or `qbx-core`) are started before this resource.
   - Optional: `slrn_groups` (groups), `ox_inventory` (inventory), `Renewed-Banking` (urgent payouts), `Renewed-Weathersync` (weather).
2) fxmanifest:
   - Load `locales/*.lua` via `shared_scripts` and include `@ox_lib/init.lua`.
3) Config:
   - Set `Config.Locale`, review/adjust new sections for Urgent/SkillCheck/Weather/DeliverLocations/DeliverLabels.
   - Add or verify required items for issue repairs in your inventory system.
4) Urgent LEO flow:
   - Officers must set a waypoint before `/towcall`. They will pick the drop-off in a prompt.
   - Groups accept with `/towaccept <id>` and deliver to the officer-selected destination.
   - Payout is via `/towpay <id> [amount]` (supports Renewed-Banking business debit when enabled).

---

Historically, this resource used qtarget and had a simpler delivery/payment flow. The above changes modernize targeting, deepen gameplay with repairs and environmental modifiers, add LEO-driven urgent dispatch, and improve configurability/localization.

## [1.0.3] - Upstream baseline
Credits: IamLation (https://github.com/IamLation/lation_towing)

Summary (upstream): Initial public release baseline this fork built upon, featuring a core towing job for QBCore/QBox, random pickups, and delivery payment flow prior to the enhancements listed in 1.1.
