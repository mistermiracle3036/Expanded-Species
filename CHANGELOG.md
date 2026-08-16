# Changelog

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
