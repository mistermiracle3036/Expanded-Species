## [0.8.2] — 2026-10-14

**Updating from 0.6.6?** Red, Blue and Yellow can now use custom species too
(0.7.0). A mod that adds new Pokemon can carry them on its own, and two mods
bringing the same Pokemon give you one (0.8.0). And on current versions of
the game, those Pokemon now load and have their cries (below).

### Fixed

- **Shared Pokemon load on the current game again.** Gold, Silver and
  Crystal now show Pokedex heights and weights in metres and kilograms, and
  the shared Pokemon still described theirs in feet and pounds, so the game
  turned every one of them away. They are converted for you now, with the
  same numbers on every mod that carries them.
- **Shared Pokemon have cries.** Each one now cries with the voice its
  catalog entry names (Aggron borrows Rhyhorn's, for example); before, they
  were silent.

## [0.8.1] — 2026-10-12

**Updating from 0.6.6?** Red, Blue and Yellow can now use custom species too
(0.7.0). And a mod that adds new Pokemon can now carry them on its own -- you
no longer need Expanded Species installed just because another mod brings,
say, Ralts, and two mods bringing the same Pokemon give you one, with the
same data whichever loads first (0.8.0, below).

### Fixed

- A mod carrying the shared species runtime now steps aside when an older
  Expanded Species (before 0.8.0) is installed, instead of running beside
  it: one set of numbers and one save protection, and an error asking you
  to update Expanded Species.

## [0.8.0] — 2026-10-12 (not released)

**Updating from 0.6.6?** Red, Blue and Yellow can now use custom species too
(0.7.0, below). And from this version, a mod that adds new Pokemon can carry
them on its own: you no longer have to install Expanded Species just because
another mod brings, say, Ralts -- and when two mods bring the same Pokemon,
the game has one Ralts with the same data whichever loads first.

### Added

- **Shared runtime.** This framework's own code can now be embedded inside
  another mod (`lib/expanded_species_runtime.lua`, loaded with
  `{ embedded = true }`). When several copies load, exactly one runs the
  Pokedex, sprites, numbering and save protection; the others stand aside.
  If Expanded Species itself is installed it is always the one that runs.
- **`registerShared(providerMod, definition)`** (capability `sharedIdentity`)
  for species in the portfolio's shared catalog: the first mod registers it,
  a mod carrying identical data shares it, and a mod carrying different data
  is refused with a visible error instead of silently replacing it.

### Changed

- Save protection keeps its data under `expanded_species` whichever copy is
  running, so hidden Pokemon are still restored if you later switch between
  the framework and a mod that embeds it. Existing saves are unchanged.

### Compatibility

- API version stays 1; every existing call and capability is unchanged when
  Expanded Species is installed. An embedded copy offers species registration,
  queries and save protection only -- encounters, gifts, trainers and trades
  still need Expanded Species installed, and say so if called.

## [0.7.0] — 2026-08-26

### Added

- Added Red, Blue, and Yellow support for custom species registration using
  Gen 1's five-stat, move-list, sprite-size, evolution, and growth-rate record
  shapes. Cross-generation definitions may continue using the existing Gen 2
  author shape; Expanded Species converts the supported fields on Gen 1.
- Added Gen 1 grass and surfing additions without replacing vanilla slots or
  changing a map's base encounter rate.
- Added Gen 1 runtime wild battles and direct party/box gifts through the
  engine's generation-specific public Pokémon builders.
- Extended Save Guardian quarantine and restoration to Gen 1's 12 PC boxes,
  party, and Day Care while retaining Gen 2's 14-box, MAIL, breeding, and Bug
  Contest behavior.

### Fixed

- Save Guardian notices now use real `\f` A-button page breaks and fit every
  page into the 18-column, two-line text box. The old `<NEXT>` token rendered
  as text and allowed the notice to scroll past unreadably.
- Capability queries now report Gen 2-only forms, palettes, Pokédex expansion,
  swarms, fishing, Bug Contest, scripted helpers, trainer patches, and screen
  bridges as unavailable on Red, Blue, and Yellow instead of advertising paths
  those runtimes cannot serve.

### Compatibility

- The API facade remains version 1. Existing Gold, Silver, and Crystal species
  packs and all current Gen 2 behavior are unchanged.
- Gen 1 packs should depend on `expanded_species@>=0.7.0 <2.0.0` and branch on
  named capabilities for optional Gen 2 features.
- Source-audited against gen1recomp 0.2.24. The existing complete Gen 2 harness
  and the new Gen 1 schema/encounter/battle/gift/Guardian harness both pass.

## [0.6.6] — 2026-08-24

### Added

- Migrated the framework manifest from Gold-only to `gen2`, allowing Gold,
  Silver, and Crystal to load the same API 1 framework. Crystal is now the
  primary target.
- Added optional `time`/`times` filtering to
  `addFishingEncounter`. Crystal's `MORN`/`DAY` values share
  its native day sub-slot, and `NITE`/`DARK` share its night
  sub-slot. Existing all-day registrations are unchanged.
- Added Crystal gift caught-data stamping through the engine's
  `Mon.hasCaughtData` and `Mon.setGiftCaughtData` capabilities.
- Compatibility reports now identify the active Gen 2 edition instead of
  always reporting Gold.

### Audited

- Confirmed species, trainers, scripts, sprites, palettes, saves, and the
  Bug-Catching Contest use shared Gen 2 runtime modules.
- Confirmed the framework does not allocate item slots, use numeric map IDs, or
  modify the fixed roamer save structures. Crystal's four repurposed item IDs,
  20 additional maps, absent `ECRUTEAK_TIN_TOWER_BACK_ENTRANCE`, and
  Raikou/Entei-only roamer table therefore do not collide with framework state.
- Retained `goldFormScreens` and `goldNestScreen` as legacy API 1
  capability names while documenting that their adapters target shared Gen 2
  screens.
- Source-audited against gen1recomp 0.2.21. Crystal device-tested 2026-08-25:
  framework, probe harness, fishing (time slots and swarms), roamers,
  caught-data helpers, and all 444 Bug Contest checks passed.

### Updating from 0.6.5

No provider API break is required. Existing species and encounter packs continue
to load unchanged. Packs that require Crystal day/night fishing should depend
on `expanded_species@>=0.6.6 <2.0.0`. Authors should read Crystal caught
metadata by field presence, not by comparing the edition string.

### Upstream follow-up

- gen1recomp 0.2.21 defines Crystal caught-data helpers and preserves those
  fields through evolution and breeding, but ordinary wild/Contest capture
  completion does not currently call the stamping helper. Expanded Species
  does not patch that battle-screen path; it remains an engine issue to report
  after release testing.

## [0.6.5] — 2026-08-16

Documentation only. No behaviour changes; the mod code is identical to 0.6.4.

### Fixed

- The Pokédex AREA nest bridge is now described as what it is: a fallback for
  older Gold builds. Current gen1recomp releases resolve nest landmarks through
  `gen2Landmarks` themselves, and the bridge stands down when they do. The
  README, FAQ and author API previously described the repair as a current
  feature.
- **Author-facing correction worth a release on its own:** the author API's nest
  example asserted on `nestScreenStatus().installed`. On a current engine the
  bridge is correctly not installed, so a pack following that example would fail
  an assertion for no reason. It is now an informational log.

The form screen bridge is unaffected — it is still required, and asserting that
it installed remains correct.

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
