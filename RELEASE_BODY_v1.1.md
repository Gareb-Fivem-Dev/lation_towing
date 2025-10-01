## lation_towing v1.1 — Modernized towing with urgent LEO flow

This release updates targeting, adds officer-driven urgent tows, and deepens gameplay with repairs, skill checks, and realism.

Highlights
- ox_target-only interactions (qtarget removed)
- QBCore + QBox bridges; ox_inventory integration
- Locales (EN/DE) with loader; Config.TowTruckModel
- Temporary roadwork signs (AI slow zone, pickup, auto-despawn)
- Urgent LEO tows: `/towcall`, `/towaccept <id>`, `/towpay <id> [amount]`
  - Officer drop-off selector: Use waypoint, Nearest depot (label-aware), Nearest road
  - Group broadcast via slrn_groups; SLA + bonus; Renewed-Banking payouts (optional)
- Per-mission drop-off with optional depot labels (`Config.DeliverLabels`)
- Repair skill checks (ox_lib), fail penalties, optional extra item consumption
- Issue dependency (Engine requires Electrical, configurable)
- Weather/time modifiers for issue chance, repair durations, pay bonus (optional Renewed-Weathersync)

Breaking changes
- qtarget removed ➜ requires ox_target
- Many strings moved to locales ➜ ensure `Config.Locale` and `locales/*.lua` are loaded in fxmanifest
- New/changed config keys (Urgent/Delivery/Realism/Other)

Upgrade quickstart
1) Ensure dependencies: `ox_lib`, `ox_target`, and your framework; optional: `slrn_groups`, `ox_inventory`, `Renewed-Banking`, `Renewed-Weathersync`
2) fxmanifest: include `@ox_lib/init.lua`, load `locales/*.lua`, confirm `version '1.1'`
3) Config: set `Config.Locale`, review new sections (`UrgentLEO`, `SkillCheck`, `WeatherModifiers`, `DeliverLocations`, `DeliverLabels`); verify repair items exist
4) Urgent usage:
   - Officers: set waypoint ➜ `/towcall` ➜ choose destination
   - Groups: `/towaccept <id>` ➜ attach ➜ deliver
   - Officers: `/towpay <id> [amount]` (Renewed-Banking optional)

Credits
- Built on upstream by IamLation (baseline v1.0.3): https://github.com/IamLation/lation_towing

Links
- Full notes: ./RELEASE_NOTES_1.1.md
- Changelog: ./CHANGELOG.md
- README: ./README.md
