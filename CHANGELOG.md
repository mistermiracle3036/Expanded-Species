# Changelog

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
