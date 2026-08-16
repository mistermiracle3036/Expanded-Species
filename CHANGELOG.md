## [0.6.4] — 2026-08-16

**First public release.**

Expanded Species is a framework for Pokemon Gold. On its own it adds no
Pokemon — it is the foundation species packs are built on, and a pack that
declares it as a dependency supplies the content.

What it gives pack authors:

- Custom species above #255, with their own sprites, icons, cries, palettes and
  Pokedex entries.
- Wild encounters that **add** to a route rather than replacing it — grass,
  surfing, all three fishing rods, swarm-only rows, and the Bug-Catching
  Contest. A route's vanilla species and base encounter rate are untouched.
- Custom Pokemon placed into **existing** Gold trainers without disturbing their
  NPC, dialogue, defeated flag, rematches, music or rewards.
- Gifts, stationary encounters, custom trainers and NPC trades, all one-time and
  save-aware.
- Per-individual named forms that survive evolution, trading, egg hatching and
  save/reload.
- A **Save Guardian**: if a species pack is removed or fails to load, its
  Pokemon are quarantined intact and restored when the pack comes back, rather
  than corrupting the save.

Requires gold gen1recomp 0.1.94 or newer. Gold only.

Authors: `AUTHOR_API.md` documents the full provider API, every capability name
and a pack testing checklist. Request features by capability rather than by
version number — `api_version` stays `1` for the whole current contract.

# Changelog

## [0.6.3] — 2026-08-16

### Fixed

- Preserved an Egg's explicit `expandedForm` when Gold rebuilds it as the
  hatched party record, so the hatch reveal and resulting Pokemon retain the
  same named form rather than falling back to the species' base art.

## [0.6.2] — 2026-08-16

### Fixed

- Restored Gold Pokédex AREA-page nest markers and route names for custom and
  vanilla grass/water encounters. Gold 0.1.94 finds the correct nests but its
  renderer reads the Gen 1 landmark field instead of `gen2Landmarks`.
- Cleared an AREA screen's stale empty landmark cache when the corrected Gold
  registry becomes available, including after a mod reload.

### Compatibility

- Added the `goldNestScreen` capability and `nestScreenStatus()` diagnostic.
  The compatibility alias exists only for the duration of the AREA draw and is
  restored even if that draw errors. It stays dormant when the engine supplies
  a native compatible landmark table.
- Kept the underlying one-line Gold renderer correction on the upstream engine
  request list; this bridge can be removed after the engine owns the fix.

## [0.6.1] — 2026-08-15

### Fixed

- Routed Expanded Species cosmetic forms through Gold 0.1.94's PC preview,
  Summary, evolution, NPC-trade animation and icon, Hall of Fame, egg-hatch
  reveal, and Cianwood Photo Studio screens. These screens previously read the
  species' base sprite fields without calling the engine's live sprite hook.
- Made the Pokedex use a species' `defaultForm`, since a Dex entry has no
  individual Pokemon record from which to select a form.
- Preserved `expandedForm` in Gold's projected NPC-trade animation and Hall of
  Fame records, and added `form` to custom NPC trade definitions.
- Bypassed legacy palette remapping for `trueColor` form art on the bridged
  screens while retaining Gold's blackout silhouette during evolution.

### Compatibility

- Added the `goldFormScreens` capability and `formScreenStatus()` diagnostic.
  The bridge only intercepts Pokemon that actually select an Expanded Species
  form; vanilla Pokemon and custom species without forms stay on Gold's
  original rendering paths.
- Kept the upstream request for native all-screen `Sprites.path` routing and
  per-individual palette/cry contexts. The 0.6.1 bridge is isolated behind the
  already-declared `engine_internals` permission.

## [0.6.0] — 2026-08-15

### Added

- Added weighted `addFishingEncounter`, `addBugContestEncounter`,
  `addSwarmGrassEncounter`, and `addSwarmWaterEncounter` author helpers. They
  compose through Gold 0.1.94's public encounter hooks and registries and go
  dormant automatically when their species definition is absent.
- Added persistent cosmetic forms through `forms`, `defaultForm`, `setForm`,
  `getForm`, `formInfo`, and `forms`. Gifts, stationary battles, custom
  trainers, and vanilla-trainer insertions accept `form`.
- Added namespaced localization for custom species names and Pokedex kind/text
  fields through Gold's official strings catalog.
- Added deterministic checkpoint content profiles and compatibility comparison
  helpers, plus a post-restore Save Guardian pass after successful overworld
  checkpoint restoration.
- Added structured and formatted pack compatibility reports covering species
  diagnostics, encounter placements, trainer patches, hidden missing records,
  engine/API metadata, and the current checkpoint profile.

### Compatibility

- Kept the public facade at API 1. New functionality is negotiated through the
  `extendedFishing`, `extendedBugContest`, `extendedSwarms`, `cosmeticForms`,
  `localizedSpecies`, `checkpointProfiles`, and `compatibilityReports`
  capabilities.
- Gold 0.1.94 has no safe public seam for Headbutt, Rock Smash, additional
  roaming slots, per-mon form palettes/cries, or checkpoint validation before
  reconstruction. Those remain explicitly unsupported instead of being
  implemented with fragile engine overrides.
- Gold 0.1.94 routes battle, summary, and party-icon art through the live form
  hooks. PC, trade, evolution, Hall of Fame, and Pokedex screens still use a
  species' default art; full routing is tracked for an upstream request.

## [0.5.0] — 2026-08-15

- Added the Gold Save Guardian for species packs that are disabled, removed,
  or temporarily unavailable after an engine update.
- Missing custom Pokemon are moved before the world loads into framework-owned
  hidden save storage; this is not a visible or interactive PC box.
- Re-enabling the defining pack automatically restores complete Pokemon records
  to their original party, box, Day-Care, or active Bug-Catching Contest
  location when that location remains available.
- Party MAIL and arbitrary mod-authored Pokemon fields are preserved. A safe
  fallback box is used when an original location is occupied; a Pokemon remains
  hidden when no legal destination exists.
- Added in-game quarantine/restoration notices plus read-only `missingCount`,
  `missingInfo`, and `guardSave` diagnostics under the stable API 1 contract.

## [0.4.0] — 2026-08-15

- Added provider-owned `patchVanillaTrainer` decorations for adding custom
  species to Gold's existing trainer battles without changing their scripts.
- Trainer changes can insert before any party position, append after the final
  member, or replace an existing position while preserving the six-mon limit.
- Multiple packs compose in deterministic provider/patch order; conflicting
  replacements, invalid positions, missing species and overflow are diagnosed
  instead of silently producing a malformed trainer party.
- Vanilla trainer decorations use Gold 0.1.94's public `trainer.party` hook and
  normal trainer builder, keeping string species IDs safe above #255.

## [0.3.0] — 2026-08-15

- Added preflight reports, low-risk species defaults and up-front batch
  validation for larger packs without breaking the existing API 1 contract.
- Added capability, owner, provider, metadata and live diagnostic queries.
- Added `getApi`, `supportsApi` and `requireCapabilities` negotiation so packs
  can depend on stable API 1 through all non-breaking releases below 2.0.
- Added provider-owned Gold script helpers for one-time gifts, stationary wild
  battles, custom trainer rosters and full in-game NPC trades.
- Custom trainer parties and trades use string species IDs, so they work above
  #255 without passing through Gold's one-byte script operands.
- Added runtime gift and wild-battle helpers for developer tools, including
  forced shiny DVs and automatic party-to-box fallback.
- Updated the modular-pack guidance for 0.1.94's ZIP-safe `mod:list` API.

## [0.2.1] — 2026-08-15

- Documented custom normal and shiny palette assignment, Gold's two supplied
  middle colors, vanilla palette fallbacks and the `trueColor` opt-out.
- Added a ZIP-safe `mod:read` pattern for splitting larger species packs into
  one Lua definition file per custom Pokemon.

## [0.2.0] — 2026-08-15

- Added provider-owned `addGrassEncounter` and `addWaterEncounter` APIs.
- Custom weighted entries can extend Gold's original seven grass slots or
  three swimming slots without overwriting them.
- Preserved vanilla encounter rates and the original relative probabilities
  whenever a weighted roll selects the vanilla pool.
- Documented route placement, weights, composition and natural-encounter
  testing for species-pack authors.

## [0.1.2] — 2026-08-15

- Updated the species-pack author guide to use a bundled custom cry instead of
  presenting a borrowed Ditto cry as the default approach.
- Added custom-audio requirements and an author testing checklist.

## [0.1.1] — 2026-08-15

- Made custom icon IDs collision-safe and hardened invalid icon/palette
  fallbacks to Ditto.

## [0.1.0] — 2026-08-15

- Added a Gold-only provider API for registering custom Pokemon without
  replacing the original 251.
- Added deterministic contiguous runtime species allocation beginning at 252.
- Added Gold Pokedex rows and order integration for custom species.
- Added custom or fallback party/box icons and battle palettes.
- Documented engine-native save support and the cartridge-byte compatibility
  boundary.
