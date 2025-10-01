# Release Notes — v1.1 (2025-10-01)

This release modernizes targeting, deepens gameplay with repair systems and realism, and adds an officer-driven urgent tow flow.

Credits
- Built on the upstream project by IamLation
  - Repository: https://github.com/IamLation/lation_towing
  - Upstream baseline: v1.0.3

## Highlights
- ox_target-only interactions (qtarget removed)
- QBCore and QBox runtime bridges (players, jobs, items, money)
- ox_inventory integration (auto-detected) for item checks and removal
- Localization (English/German) with a proper locale loader
- Configurable tow truck model (`Config.TowTruckModel`)
- Temporary roadwork signs with AI slow-zone and auto-despawn
- Urgent LEO Tow Calls
  - Commands: `/towcall`, `/towaccept <id>`, `/towpay <id> [amount]`
  - Group broadcast via slrn_groups; SLA/bonus; optional Renewed-Banking business payouts
  - Officer drop-off selection UI: Use waypoint, Nearest depot (label-aware), or Nearest road
- Per-mission drop-off
  - `Config.DeliverLocations` (+ optional `Config.DeliverLabels`) with fallback to `Config.DeliverLocation`
- Repair skill checks (ox_lib), failure penalty, optional extra item consumption
- Issue dependencies (e.g., Engine requires Electrical first with configurable chance)
- Weather/time modifiers (rain/night) affecting issue chance, repair time, and pay bonus (optional Renewed-Weathersync)

## Breaking changes
- Targeting: qtarget removed; ox_target is required
- Many strings moved into locales; ensure `Config.Locale` is set and locales are loaded in fxmanifest
- New/changed config keys:
  - Urgent LEO: `EnableUrgentLEOTow`, `LEOJobNames`, `UrgentTowTimeLimit`, `UrgentTowBasePay`, `UrgentTowFastBonus`, `UrgentTowPayPerMember`, `UrgentTowBusiness`, `UseRenewedBanking`
  - Delivery: `DeliverLocations`, `DeliverLabels`, `DeliverRadius`
  - Realism: `SkillCheck`, `IssueDependencies`, `WeatherModifiers`
  - Other: `TowTruckModel`, `AllowPublicRepairsBeforeAttach`, `RepairCooldownMs`

## Upgrade checklist
1) Dependencies
   - Ensure `ox_lib`, `ox_target`, and your framework (`qb-core` or `qbx-core`) are started
   - Optional: `slrn_groups` (groups), `ox_inventory` (inventory), `Renewed-Banking` (urgent payouts), `Renewed-Weathersync` (weather)
2) fxmanifest
   - Include `@ox_lib/init.lua` and load `locales/*.lua` via `shared_scripts`
   - Confirm version is `1.1`
3) Config
   - Set `Config.Locale = 'en' | 'de'` and review new sections for Urgent/SkillCheck/Weather/DeliverLocations/DeliverLabels
   - Verify inventory items exist for repair issues (qb-core shared items or ox_inventory items)
4) Urgent flow usage
   - Officers: set a waypoint; run `/towcall`; choose destination in the prompt
   - Groups: `/towaccept <id>`, attach, deliver to selected drop-off
   - Officers: `/towpay <id> [amount]` to pay group (uses Renewed-Banking if enabled)

## Notes and known behavior
- Lint warnings like "Undefined global lib/cache" are expected with ox_lib and safe to ignore at runtime
- Distance checks for urgent drop-off resolve ground Z automatically when using a waypoint
- Payment splits remainder to the member who completes the delivery

## Links
- README: ./README.md
- Changelog: ./CHANGELOG.md
- Upstream project (credit): https://github.com/IamLation/lation_towing