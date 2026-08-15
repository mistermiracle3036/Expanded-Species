# Expanded Species author API

API version: `1`

## Contract

Call `expanded.exports.register(mod, definition)` during your mod's entry point.
Passing your own `mod` object is important: it makes the species belong to your
pack, so gen1recomp can validate, diagnose, and unload content under the correct
owner.

The helper returns the normalized registry record. It removes `index` before
schema validation and tags the record for deterministic allocation during
`game.ready`.

The framework never overrides an existing registry key. A duplicate string ID
is rejected by gen1recomp's normal content registry.

## Required species fields

Gold's Pokemon schema requires these core fields:

- `id`, `name`, and `types`
- `baseStats` with `hp`, `attack`, `defense`, `speed`, `specialAttack`, and
  `specialDefense`
- `catchRate`, `baseExp`, and `growthRate`
- `levelMoves`, `tmhm`, and `evolutions`
- `eggGroups`, `eggMoves`, `eggSteps`, and `genderRatio`
- `items`, `spriteFront`, `spriteBack`, and `picSize`

An owned cry is strongly recommended. Register it in `mod.content.cries`
before the species record, use the same globally namespaced ID for both, and
set the species record's `cry` field to that ID.

The paths in `spriteFront`, `spriteBack`, and a custom icon's `image` are owned
by the species pack. Keep those assets inside that mod and resolve them with
`mod.assets:path(...)`.

## Framework fields

These optional convenience fields are copied into the framework marker:

| Field | Purpose |
| --- | --- |
| `dex` | Requested ordering hint at or above 252; final IDs are contiguous. |
| `dexEntry` | Gold Pokedex kind, height, weight, and text. |
| `icon` | Custom 16x32, two-frame party/box icon definition or image path. |
| `iconFallback` | Vanilla species whose party/box icon should be reused. |
| `palette` | Custom Gold normal/shiny battle palette definition. |
| `paletteFallback` | Vanilla species whose battle palette should be reused. |

`dexEntry.height` uses Gold's packed decimal display form (`507` means 5'07").
You may instead supply `heightFt` and `heightIn`. `dexEntry.weight` is tenths of
a pound; `weightLbs` is accepted as a convenience.

Custom icon form:

```lua
icon = {
  image = mod.assets:path("assets/aurorix_icon.png"),
  width = 16,
  height = 32,
  frames = 2,
}
```

If no icon or palette is supplied, the framework uses Ditto. Set the matching
fallback field to reuse a closer vanilla species instead.

## Battle palettes

Gold battle pictures use four color indices. The engine supplies pure white
for index 0 and pure black for index 3. A species palette supplies the two
middle colors for its normal and shiny forms:

```lua
expanded.exports.register(mod, {
  id = speciesId,
  -- the remaining required species fields
  palette = {
    normal = {
      { 168, 232, 120 }, -- light middle shade
      { 64, 152, 56 },   -- dark middle shade
    },
    shiny = {
      { 232, 216, 112 },
      { 152, 120, 40 },
    },
  },
})
```

Each color is an `{ red, green, blue }` triple with integer channels from 0
through 255. Supply exactly two triples per form. The framework copies this
record into Gold's live palette table under the custom species string ID, so
the same palette follows that species into front and back battle pictures and
the Gold screens that render species colors. The engine chooses `shiny` when
the individual Pokemon has shiny DVs.

Design the front and back sprite art as a four-shade image whose pixels mean
white, light middle, dark middle and black. Normal and shiny forms share the
same art and swap only the two middle colors. If the species sets
`trueColor = true`, Gold deliberately bypasses this palette remapping and draws
the PNG's own colors instead.

To borrow an existing Gold palette, omit `palette` and use:

```lua
paletteFallback = "TANGELA"
```

An unknown fallback safely falls through to Ditto. If both fields are omitted,
Ditto is also the default. A supplied custom `palette` always wins over
`paletteFallback`.

Test the normal palette by spawning the species through Battle Spawner. Test
the shiny palette with an individual that actually has Gold's shiny DVs; merely
choosing shiny colors in the definition does not make every individual shiny.

## Custom cries

Bundle an authored sound inside the species pack and resolve its path through
the owning mod:

```lua
local speciesId = "MY_PACK_AURORIX"

mod.content.cries:register(speciesId, {
  file = mod.assets:path("assets/aurorix_cry.ogg"),
})

expanded.exports.register(mod, {
  id = speciesId,
  -- the remaining required species fields
  cry = speciesId,
})
```

`.ogg` and `.wav` are supported engine patterns. Keep the cry short, edit it to
its final pitch and duration before packaging, and include it inside the mod
ZIP. A file-backed cry cannot use the chip cry's `pitch` or `length` fields.

The engine loads file cries as static audio and caches them under the species
ID. The same registration is therefore used by battles, the Pokedex, the
Summary screen, trades, and other normal cry call sites. A missing or invalid
file is silent and creates one error attributed to the owning mod.

Authors who deliberately want a Game Boy-style sound may instead register an
authored `ChipAsm` program or derive a vanilla chip program with `base`, but a
bundled owned recording is the recommended species-pack example. `ChipAsm`
requires the `engine_internals` permission.

## Deterministic allocation

At `game.ready`, all marked species are sorted by requested `dex`, then by
string ID. They receive contiguous `dex` and runtime `index` values beginning
at 252. Contiguous assignment keeps Gold's national Pokedex traversal valid and
ensures every player with identical content computes the same mapping.

Direct registry registration remains compatible: a complete Gold species with
`dex >= 252` and no `index` is automatically adopted. The helper is preferred
because it preserves author intent and strips an out-of-range index before
schema validation.

## Runtime queries

After `game.ready`:

```lua
local index = expanded.exports.virtualIndex("MY_PACK_AURORIX")
local allIds = expanded.exports.all()
local nextFree = expanded.exports.nextIndex()
```

The exported `api_version` is `1`. Check it if your species pack depends on a
newer contract.

## Organizing a larger species pack

Yes, custom Pokemon definitions can be split out of `main.lua`. A useful pack
layout is:

```text
main.lua
species/
  burgela.lua
  coinpur.lua
  orfry.lua
assets/
  burgela_front.png
  burgela_back.png
  ...
```

Keep `main.lua` as the coordinator that finds Expanded Species and owns the
registry calls. Let each species file return its own data factory. For example,
`species/burgela.lua` can use this shape (the required stats/moves are shortened
here only to keep the example readable):

```lua
return function(mod)
  local id = "MY_PACK_BURGELA"
  return {
    id = id,
    cry = { base = "TANGELA" },
    definition = {
      id = id,
      name = "BURGELA",
      -- types, baseStats, moves, breeding data, and other required fields
      spriteFront = mod.assets:path("assets/burgela_front.png"),
      spriteBack = mod.assets:path("assets/burgela_back.png"),
      cry = id,
      paletteFallback = "TANGELA",
    },
  }
end
```

The public `mod:read(relative)` helper reads a file through gen1recomp's mod
filesystem, including an imported ZIP. Compile that returned source rather
than relying on a desktop filesystem path:

```lua
local function loadPackFile(relative)
  local source, readError = mod:read(relative)
  assert(source, readError or ("Could not read " .. relative))

  local compile = assert(loadstring or load, "No Lua compiler is available")
  local chunk, compileError = compile(source, "@" .. mod.path .. "/" .. relative)
  assert(chunk, compileError)

  local ok, result = pcall(chunk)
  assert(ok, result)
  return result
end

local files = {
  "species/burgela.lua",
  "species/coinpur.lua",
  "species/orfry.lua",
}

for _, relative in ipairs(files) do
  local build = loadPackFile(relative)
  assert(type(build) == "function", relative .. " must return a function")

  local species = build(mod)
  mod.content.cries:register(species.id, species.cry)
  expanded.exports.register(mod, species.definition)
end
```

Use an explicit ordered file list. The public mod surface provides `read`, not
directory enumeration, and a written list makes registration order and missing
files diagnosable. Keep all `mod.content.*` writes in `main.lua`; the per-species
files should return owned data rather than registering content themselves.

Do not use `loadfile` with a Windows/macOS path for this pattern. It may appear
to work in an unpacked development folder while failing after the pack is
imported. `mod:read` goes through the same filesystem abstraction the loader
uses for folder and packaged mods.

## Extended wild encounter pools

Expanded Species 0.2.0 adds new rows to an existing Gold grass or swimming
zone without replacing its seven grass slots or three water slots. Register
the species first, then call the placement helper from the same entry point:

```lua
expanded.exports.addGrassEncounter(mod, {
  map = "ROUTE_29",
  times = { "MORN", "DAY", "NITE" }, -- or time = "NITE"
  species = speciesId,
  level = 4,
  weight = 1,
})

expanded.exports.addWaterEncounter(mod, {
  map = "ROUTE_30",
  species = speciesId,
  level = 10,
  weight = 2,
})
```

Required placement fields are `map`, `species`, `level`, and `weight`. Level
must be an integer from 1 through 100. Weight must be a positive integer.
Grass accepts `time = "MORN"`, `"DAY"`, or `"NITE"`, or a `times` list;
omitting both places the species in all three lists. `DARK` is accepted as an
alias for `NITE`.

The map must already have the requested kind of encounter table. The helper
fails with the map ID in its error instead of silently creating a zone with no
rate or incomplete data.

### How weights work

The entire original slot table has weight 100. Each custom entry adds its own
weight, so its probability after a battle-triggering step is:

```text
entry weight / (100 + total custom weight for that map and time)
```

For example, one weight-1 species is 1/101 (about 0.99%). Five species with
weight 4 each are individually 4/120 (3.33%) and collectively 20/120 (16.67%).
When the vanilla branch wins, Gold's original 30/30/20/10/5/4/1 grass split or
60/30/10 water split runs unchanged. The map's encounter rate is also
unchanged.

There is no framework slot-count ceiling: multiple packs can append any number
of rows, subject only to practical load-time and memory limits. Use small
weights; very large totals offer no useful precision. Duplicate placements by
the same provider, kind, map, time, species, and level are rejected loudly.

The helper records the append through the calling pack's official encounter
registry. This preserves ownership/unload behavior and makes the extra rows
visible to registry consumers such as the Pokedex area listing. It also uses
the official `encounter.roll` hook for selection. Fishing, Headbutt, Rock Smash
and Bug-Catching Contest tables already use variable-length chance rows and do
not need this 7/3-slot extension.

## Compatibility boundary

Virtual indices are an engine-runtime extension, not an alteration to the Game
Boy save or scripting formats. Avoid paths that serialize species as one byte:

- importing/exporting custom Pokemon through a cartridge `.sav`
- ROM-script commands whose species operand is an 8-bit number
- ROM routines that translate through the original species-index table

Normal gen1recomp party/box saves, direct battles, registry-based encounters,
Pokedex seen/caught state, and link fingerprints use string species IDs.

## Pack testing checklist

Test with Expanded Species and Battle Spawner enabled, then fully quit and
relaunch Gold:

1. Spawn the species and confirm its front sprite, palette, name, level and cry.
2. Catch it, lead the party with it, and start another battle to confirm its
   back sprite and player-side cry.
3. Open its party summary and Pokedex entry; confirm the cry plays from both.
4. Verify its stats, moves, party/box icon, normal palette and shiny palette.
5. Deposit and withdraw it, save, fully quit, and reload the native save.
6. Test at least one allocation above #255, either by providing five species or
   by testing alongside another pack.
7. If the pack adds a natural placement, encounter it in every declared time
   or terrain and check that the Pokedex area page lists the route.
8. Never disable the pack while one of its species remains in a party or box.
9. For link play, use identical framework and species-pack versions on both
   devices and declare `"affects_link": true` in the species-pack manifest.
