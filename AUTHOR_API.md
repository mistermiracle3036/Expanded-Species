# Expanded Species author API

API version: `1` (all capabilities are additive and backward-compatible)

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

### Preflight and batch registration

`preflight` does not write content. It applies the safe defaults and returns a
report with `ok`, `errors`, `warnings`, and the completed `definition`:

```lua
local report = expanded.exports.preflight(mod, definition)
if not report.ok then
  for _, issue in ipairs(report.errors) do
    mod.log:error("%s: %s", issue.path, issue.message)
  end
  error("Custom species preflight failed")
end
```

For a larger pack, use `registerAll`. It preflights every row and detects
duplicate IDs before making the first registry write:

```lua
local registered = expanded.exports.registerAll(mod, {
  buildBurgela(mod),
  buildCoinpur(mod),
  buildOrfry(mod),
})
```

This prevents a typo late in the list from leaving only the first half of a
pack registered.

## Required species fields

Gold's Pokemon schema requires these core fields after framework defaults are
applied:

- `id` and `name`
- `baseStats` with `hp`, `attack`, `defense`, `speed`, `specialAttack`, and
  `specialDefense`
- `spriteFront` and `spriteBack`

The framework defaults `types` to `{ "NORMAL" }`, `catchRate` to `45`,
`baseExp` to `100`, `growthRate` to `GROWTH_MEDIUM_FAST`, `levelMoves` and
`evolutions` to empty lists, and `picSize` to `7`. These defaults make a probe
species concise without inventing art, identity, or battle stats. `tmhm`, the
breeding block and held `items` are optional in Gold's current schema; supply
them when the design uses them.

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
| `forms` | Named cosmetic form art used for individual Pokemon. |
| `defaultForm` | Form used when an individual has no explicit form. |

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

Test the normal palette by getting the species into a battle at a known level.
Test the shiny palette with an individual that actually has Gold's shiny DVs;
merely choosing shiny colors in the definition does not make every individual
shiny.

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
local owner = expanded.exports.owner("MY_PACK_AURORIX")
local mine = expanded.exports.byProvider(mod)
local info = expanded.exports.info("MY_PACK_AURORIX")
local report = expanded.exports.diagnose("MY_PACK_AURORIX")
```

`info` returns a protected copy of the live species record plus its owner,
allocated index and Dex number. `diagnose` checks the merged record, both battle
sprites, allocation, Dex row, icon, palette, cry, and evolution targets.

The exported `api_version` remains `1` because every addition so far only adds methods;
existing
species packs keep working unchanged. This is Expanded Species' provider API,
not the separate gen1recomp `"api": 2` value in `manifest.json`.

Do not compare `api_version` with the newest framework release number. Request
the compatible API facade and the named features your pack actually needs:

```lua
local api, apiError = expanded.exports.getApi(1)
assert(api, apiError)

local required, capabilityError = api.requireCapabilities({
  "scriptedTrainers",
  "gifts",
})
assert(required, capabilityError)
```

Use this dependency range in the pack manifest:

```json
"expanded_species@>=0.6.4 <2.0.0"
```

Expanded Species reserves `2.0.0` for a breaking provider API. Compatible
0.x and 1.x releases keep `getApi(1)` available and add optional behavior under
named capabilities. If a future 2.x release adds a new facade, a pack must opt
into it deliberately by changing both its dependency range and `getApi` call.
The legacy `supports(name)` and `capabilities()` queries remain useful for
features that are optional rather than required.

`supportsApi(version)` answers whether a facade number is served at all. It is
the cheap check behind `getApi`, and returns a plain boolean:

```lua
if expanded.exports.supportsApi(1) then ... end
```

### The capability names

These are the exact strings `supports`, `requireCapabilities` and
`capabilities()` understand. **Require the named features your pack uses rather
than comparing release numbers** — that is what keeps a pack working across
future framework versions.

| Capability | What it covers | Main entry points |
|---|---|---|
| `preflight` | Validate a definition without writing content | `preflight` |
| `safeDefaults` | Optional species fields are filled in for you (`types`, `catchRate`, `baseExp`, …) | applied by `preflight` and `register` |
| `batchRegistration` | Register a whole pack, failing before the first write | `registerAll` |
| `capabilityQueries` | This negotiation surface itself | `capabilities`, `supports`, `supportsApi`, `getApi`, `requireCapabilities` |
| `metadataQueries` | Inspect what is registered at runtime | `all`, `info`, `owner`, `byProvider`, `virtualIndex`, `nextIndex` |
| `diagnostics` | Check a merged record, its sprites, allocation, Dex row, icon, palette, cry and evolutions | `diagnose`, `diagnoseTrainerPatches` |
| `customDex` | Custom Pokédex rows for species above #255 | species definition fields |
| `customPalettes` | Per-species battle palettes | species definition fields |
| `localizedSpecies` | Namespaced name, kind and Pokédex text | species definition fields |
| `cosmeticForms` | Per-individual named forms that survive evolution, trade, hatching and save/reload | `setForm`, `getForm`, `forms`, `formInfo` |
| `goldFormScreens` | Gold screen bridges that route form art across battle, Summary, PC, Dex, trade, Hall of Fame, hatch and Photo Studio | `formScreenStatus` |
| `goldNestScreen` | Pokédex AREA nest marker and route-name bridge, for older engines that need it | `nestScreenStatus` |
| `extendedGrass` | Added grass encounters that do not replace a route's vanilla slots | `addGrassEncounter` |
| `extendedWater` | Added surfing encounters | `addWaterEncounter` |
| `extendedSwarms` | Swarm-only grass and water rows | `addSwarmGrassEncounter`, `addSwarmWaterEncounter` |
| `extendedFishing` | Old/Good/Super Rod additions | `addFishingEncounter` |
| `extendedBugContest` | Bug-Catching Contest pool additions | `addBugContestEncounter` |
| `gifts` | One-time gift Pokémon with party-full and full-storage handling | `registerGift` |
| `scriptedStationary` | Stationary encounters with loss retry and completion state | `registerStationaryEncounter` |
| `scriptedTrainers` | Custom trainers with parties, moves, items, forms and dialogue | `registerTrainerEncounter` |
| `scriptedTrades` | NPC trades above #255, preserving nickname, OT, ID, item, DVs and form | `registerTrade` |
| `vanillaTrainerPatches` | Insert, append or replace members of an existing Gold trainer without touching its NPC, dialogue, flags or rewards | `patchVanillaTrainer`, `trainerPatches`, `diagnoseTrainerPatches` |
| `runtimeWildBattles` | Start a custom wild battle or hand over a Pokémon at runtime | `startWildBattle`, `givePokemon` |
| `saveGuardian` | Quarantine and restore Pokémon whose species pack is missing | `guardSave`, `missingCount`, `missingInfo` |
| `checkpointProfiles` | Record and compare the enabled-content set | `checkpointProfile`, `compareCheckpointProfile` |
| `compatibilityReports` | Provider/species compatibility summary | `compatibilityReport`, `formatCompatibilityReport` |

A capability is only ever **added**, never removed or repurposed, for the whole
`getApi(1)` contract. An unknown name simply reports as unsupported, so probing
for a capability this framework has never heard of is safe.

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
    cry = { file = mod.assets:path("assets/burgela_cry.ogg") },
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

local files = {}
for _, name in ipairs(mod:list("species")) do
  if name:match("%.lua$") then files[#files + 1] = "species/" .. name end
end

for _, relative in ipairs(files) do
  local build = loadPackFile(relative)
  assert(type(build) == "function", relative .. " must return a function")

  local species = build(mod)
  mod.content.cries:register(species.id, species.cry)
  expanded.exports.register(mod, species.definition)
end
```

`mod:list("species")` is available in gen1recomp 0.1.94 and returns a sorted,
shallow list from the same folder/ZIP abstraction as `mod:read`. Filter it to
`.lua` files as above; directories and art files should not be compiled. An
explicit ordered list is also valid when load order is intentionally curated.
Keep all `mod.content.*` writes in `main.lua`; the per-species files should
return owned data rather than registering content themselves.

Do not use `loadfile` with a Windows/macOS path for this pattern. It may appear
to work in an unpacked development folder while failing after the pack is
imported. `mod:read` goes through the same filesystem abstraction the loader
uses for folder and packaged mods.

## Extended wild encounter pools

Expanded Species adds new rows to an existing Gold grass or swimming
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

The helper records grass and water appends through the calling pack's official
encounter registry. This preserves ownership/unload behavior and makes the
extra rows visible to registry consumers such as the Pokedex area listing. It
also uses the official `encounter.roll` hook for selection.

Gold 0.1.94's nest finder already reads the merged `gen2Encounters` tables, but
its AREA renderer looks up the resulting index in the wrong landmark field.
Expanded Species supplies the correct `gen2Landmarks` table only while that
screen draws, and only on engines that need it. **Current gen1recomp releases
read `gen2Landmarks` directly**, in which case the bridge delegates untouched
and `installed` may be false with nothing wrong — treat it as informational
rather than asserting on it in a pack. Author tools can check after
`game.ready`:

```lua
local status = expanded.exports.nestScreenStatus()
-- informational: on a current engine the bridge is unnecessary
mod.log:info("nest bridge installed=%s", tostring(status.installed))
```

The `goldNestScreen` capability advertises that this correction is available.
It affects grass and swimming nests only, matching Gold's original rules;
fishing, Headbutt, Rock Smash, Bug Contest and swarm-only placements do not
create Pokédex nests.

### Swarm-only grass and water

Use the swarm helpers when a custom Pokemon should appear only while Gold has
substituted the map's swarm encounter table:

```lua
expanded.exports.addSwarmGrassEncounter(mod, {
  map = "ROUTE_35",
  time = "DAY",
  species = speciesId,
  level = 12,
  weight = 5,
})

expanded.exports.addSwarmWaterEncounter(mod, {
  map = "ROUTE_32",
  species = speciesId,
  level = 20,
  weight = 3,
})
```

The map must already have the corresponding Gold swarm-grass or swarm-water
table. The added row is dormant during the map's normal encounter table. Swarm
entries use the same base-table weight of 100 and the same ownership and
duplicate rules as ordinary grass and water additions.

### Fishing

```lua
expanded.exports.addFishingEncounter(mod, {
  map = "ROUTE_32",
  rods = { "GOOD_ROD", "SUPER_ROD" }, -- or rod = "GOOD_ROD"
  species = speciesId,
  level = 15,
  weight = 10,
})
```

Rod IDs are `OLD_ROD`, `GOOD_ROD`, and `SUPER_ROD`; `old`, `good`, and `super`
are accepted aliases. The map must already have a non-`NONE` fishing group so
Gold reaches its fishing hook. The original fishing result has total weight
100, and all matching custom entries are added to that weighted choice.

### Bug-Catching Contest

```lua
expanded.exports.addBugContestEncounter(mod, {
  species = speciesId,
  minLevel = 12,
  maxLevel = 16,
  weight = 5,
})
```

This is a global Contest pool rather than a route placement. `level` can be
used instead of `minLevel` for a fixed level. The original Contest table has
total weight 100; matching custom rows are weighted beside it.

Gold 0.1.94 does not expose safe live encounter hooks for Headbutt or Rock
Smash, and its three roaming slots are fixed save structures. Expanded Species
therefore does not offer helpers for those systems. Do not patch their numeric
ROM-style species operands with a virtual index; ask for the planned upstream
registry-based seams instead.

## Trainer and scripted encounter helpers

Gold's original `givepoke`, `loadwildmon`, `loadtrainer`, and trade table use
cartridge-sized numeric operands. Do not feed a virtual index above 255 into
those commands. Expanded Species registers provider-owned mod commands whose
species fields remain registry string IDs.

Each registration returns one ready-to-use Gold VM row. A custom runtime NPC
can use it directly as its `scriptKey`:

```lua
local giftRow = expanded.exports.registerGift(mod, {
  id = "aurorix_gift",
  species = "MY_PACK_AURORIX",
  level = 10,
  introText = "Please care for this POKéMON.",
  receivedText = "AURORIX joined you!",
  alreadyText = "How is AURORIX doing?",
})

local giftNpc
mod.events:on("map.entered", function(ev)
  if ev.mapId == "NEW_BARK_TOWN" and not giftNpc then
    giftNpc = assert(mod.world:spawnNpc("NEW_BARK_TOWN", {
      sprite = "SPRITE_GRAMPS",
      x = 8,
      y = 6,
      movement = "SPRITEMOVEDATA_STANDING_DOWN",
      scriptKey = { giftRow },
    }))
  end
end)
```

Runtime objects are not serialized. Keep their returned handle for the running
session and respawn them once after a full launch. These rows can also be used
inside another Gold VM script integration owned by the species pack. The
helpers do not silently replace an original map object's ROM-derived script.

### Gifts

```lua
local row = expanded.exports.registerGift(mod, {
  id = "burgela_gift",
  species = "MY_PACK_BURGELA",
  level = 5,
  shiny = false,
  item = "MIRACLE_SEED",       -- optional
  nickname = "VINEY",         -- optional
  form = "winter",             -- optional cosmetic form
  allowBox = true,             -- default: party, then any available box
  once = true,                 -- default
})
```

The received mon gets the player's OT, marks seen/caught Dex state, and goes to
the party or an available box. If both are full, it is not created and the
one-time flag is not set. Set `fullText` to customize that refusal.

### Stationary wild encounters

```lua
local row = expanded.exports.registerStationaryEncounter(mod, {
  id = "aurorix_shrine",
  species = "MY_PACK_AURORIX",
  level = 40,
  shiny = true,                -- uses Gold's real shiny DV pattern
  form = "winter",             -- optional cosmetic form
  introText = "The frozen statue moved!",
  afterText = "The shrine became quiet.",
  hideObject = true,
  once = true,
})
```

Running away or catching the mon completes a normal one-shot stationary
encounter, matching Gold's static battle scripts. Losing does not set the
provider flag. `hideObject` removes the talking object from the live map after
the battle; use the helper completion query when deciding whether to respawn a
runtime object on a later launch.

### Custom trainers

```lua
local row, class = expanded.exports.registerTrainerEncounter(mod, {
  id = "aurora_researcher",
  className = "RESEARCHER",
  trainerName = "MIRA",
  picFallback = "SCIENTIST",
  baseMoney = 40,
  party = {
    { species = "MY_PACK_AURORIX", level = 18, form = "winter" },
    { species = "MY_PACK_BURGELA", level = 20,
      moves = { "VINE_WHIP", "BIND" } },
  },
  trainerType = "TRAINERTYPE_MOVES",
  introText = "Show me what you discovered!",
  afterText = "That result was fascinating!",
  once = true,
})
```

The helper owns a new Gold trainer class in the calling pack's trainers
registry. The class intentionally has no numeric `index`; the helper passes its
roster directly to Gold's trainer builder. `pic` may point at owned custom art,
or `picFallback` can reuse a vanilla portrait and palette without
redistributing it. Party rows support `item` and `moves` using the ordinary
Gold trainer schema. They may also set `form`; Expanded Species keeps that
cosmetic value outside the vanilla trainer registry and applies it to the
built battle Pokemon.

### Add custom Pokemon to existing vanilla trainers

`patchVanillaTrainer` decorates the battle-local party returned by Gold's
public `trainer.party` hook. It does not rewrite the trainer's extracted roster
or byte-sized `loadtrainer` operands, so the vanilla NPC, dialogue, sight
engagement, defeated flag, portrait, music, base reward, phone calls, and
rematch scripts stay in control. Gold calculates the final payout from the
last composed party member's level, so appending after the original final
member can intentionally change the amount.

```lua
local patch = expanded.exports.patchVanillaTrainer(mod, {
  id = "joey_custom_party",
  class = "YOUNGSTER",
  member = "JOEY1",
  changes = {
    -- Insert before the current lead.
    { action = "insert", position = 1,
      species = "MY_PACK_BURGELA", level = 6 },

    -- Positions use the party produced by every earlier change. This now
    -- inserts into position 3 of that evolving party.
    { action = "insert", position = 3,
      species = "MY_PACK_COINPUR", level = 7,
      moves = { "SCRATCH", "GROWL" } },

    -- No party-size knowledge is needed for an append.
    { action = "append",
      species = "MY_PACK_AURORIX", level = 8,
      item = "BERRY", form = "winter" },
  },
})
```

Insertion positions are one-based and are evaluated in declaration order
against the currently composed party:

- `position = 1` inserts a new lead.
- Any position through the current size inserts between existing members.
- Current size plus one inserts after the current final member.
- `action = "append"` always chooses current size plus one.
- `action = "replace"` changes the specified position without changing size.

An insertion or append that would create a seventh member is skipped. Use
`replace` when the target already has six Pokemon. For example:

```lua
expanded.exports.patchVanillaTrainer(mod, {
  id = "replace_last_member",
  class = "YOUR_TARGET_CLASS",
  member = "YOUR_TARGET_MEMBER",
  changes = {
    { action = "replace", position = 6,
      species = "MY_PACK_AURORIX", level = 42 },
  },
})
```

Use Gold's exact symbolic class and member IDs. Different rematch rosters are
different members, so Joey's `JOEY1`, `JOEY2`, and `JOEY3` must be decorated
separately when all three should change.

Expanded Species calls the next `trainer.party` hook first, then applies its
registered patches in stable provider-ID, patch-ID, and declared-change order.
Other independent hook subscribers still compose according to the engine's
normal wrapper order. Expanded Species insertions and appends compose with one
another. If two registered packs replace the same composed position, the first
stable claim is kept and the later replacement is skipped with a diagnostic
rather than silently winning by pack load order.

These queries return protected copies and a live validation report:

```lua
local patches = expanded.exports.trainerPatches("YOUNGSTER", "JOEY1")
local report = expanded.exports.diagnoseTrainerPatches("YOUNGSTER", "JOEY1")
assert(report.ok, report.errors[1] and report.errors[1].message)
```

The diagnostic verifies the target, custom species, composed positions,
replacement collisions, and six-member limit after `game.ready`. Every custom
member is built through Gold's normal trainer builder, including its standard
trainer DVs, level moves, optional held item, and optional explicit move list.

### NPC trades

```lua
local row = expanded.exports.registerTrade(mod, {
  id = "burgela_for_coinpur",
  give = "MY_PACK_BURGELA",
  get = "MY_PACK_COINPUR",
  nickname = "LUCKY",
  otName = "MIRA",
  otId = 3036,
  gender = "either",           -- either, male, or female
  dvs = { attack = 9, defense = 8, speed = 8, special = 8 },
  item = "AMULET_COIN",
  form = "winter",             -- optional form for the received Pokemon
})
```

Both `give` and `get` may be vanilla or custom string IDs. `shiny = true` is a
shortcut for Gold's shiny DV bytes; otherwise supply two raw DV bytes or the
named four-DV form above. The normal Gold party picker, validation, trade
animation, OT data, cry, and one-time conversation are retained. Completion is
mirrored into the provider's stable `mod.save` key, so a changed set of other
mods cannot make a saved numeric trade slot refer to the wrong pack.

### Runtime and completion helpers

Developer tools may call these after `game.ready`:

```lua
local result = expanded.exports.givePokemon(speciesId, 20, {
  shiny = true,
  form = "winter",
  allowBox = true,
})

local ok, err = expanded.exports.startWildBattle(speciesId, 20, {
  shiny = true,
  form = "winter",
})
```

One-time state can be queried when spawning actors, and reset by a pack's own
developer option:

```lua
local done = expanded.exports.helperComplete(mod, "stationary", "aurorix_shrine")
expanded.exports.resetHelper(mod, "stationary", "aurorix_shrine")
```

## Cosmetic forms and variants

Forms are alternate art attached to one registered species. They do not spend
another virtual index or Pokedex number. Declare them on the species record:

```lua
expanded.exports.register(mod, {
  id = speciesId,
  -- normal species fields and base art
  forms = {
    winter = {
      spriteFront = mod.assets:path("assets/aurorix_winter_front.png"),
      spriteBack = mod.assets:path("assets/aurorix_winter_back.png"),
      icon = mod.assets:path("assets/aurorix_winter_icon.png"),
      trueColor = true,
    },
  },
  defaultForm = "winter", -- optional
})
```

The chosen form is stored on the individual Pokemon as `expandedForm`, so it
survives native gen1recomp saves and Save Guardian quarantine/restoration.
Authors and developer tools can query or change it through protected helpers:

```lua
local available = expanded.exports.forms(speciesId)
local current = expanded.exports.getForm(mon)
assert(expanded.exports.setForm(mon, "winter"))
local details = expanded.exports.formInfo(mon)
```

`setForm(mon, nil)` clears the explicit form and returns the individual to its
species `defaultForm`, or to base art when no default is declared. Gift,
stationary, custom-trainer, vanilla-trainer-patch, `givePokemon`, and
`startWildBattle` options all accept `form`. An Egg carrying `expandedForm`
passes that field to the rebuilt hatchling record, so both the reveal and the
resulting party Pokemon retain the explicit named form.

On Gold 0.1.94, per-individual form routing works in battle front/back art,
Summary, the selected PC preview, evolution, NPC-trade art and icon, Hall of
Fame front/back art, the egg-hatch reveal, Cianwood Photo Studio, and party
icons. Expanded Species also copies `expandedForm` into the temporary trade
animation record and the persistent Hall of Fame roster record. The Pokedex
has no individual Pokemon record, so it uses the species' `defaultForm`; it
shows base art when no default is declared.

Gold's palette and cry selectors still receive only a species ID, not the
individual Pokemon. A form cannot select its own `palette` table or cry yet.
However, `trueColor = true` form PNGs bypass palette remapping on all bridged
screens, so authored colors display correctly. Evolution retains Gold's
blackout silhouette while its flash phase is active.

The bridge uses the framework's declared `engine_internals` permission because
these Gold 0.1.94 screens do not yet call the engine's official `Sprites.path`
resolver. It activates only when the displayed Pokemon selects an Expanded
Species form; vanilla Pokemon and custom species without forms stay on their
original Gold paths. Developer tools can inspect installation health after
`game.ready`:

```lua
local status = expanded.exports.formScreenStatus()
assert(status.installed and next(status.errors) == nil,
  "Gold form screen bridge did not install completely")
```

The `goldFormScreens` capability advertises this coverage. Native all-screen
routing and per-individual palette/cry contexts remain tracked for upstream.

## Localization

Expanded Species translates a custom species' name and Pokedex strings during
`game.ready`. Translation packs can override the exact source text with a
stable, namespaced context:

```lua
mod.content.strings:override(
  "expanded_species.MY_PACK_AURORIX.name|AURORIX", "AURORIX-LOCALIZED")
mod.content.strings:override(
  "expanded_species.MY_PACK_AURORIX.dex.kind|Frost Pokemon",
  "LOCALIZED FROST KIND")
mod.content.strings:override(
  "expanded_species.MY_PACK_AURORIX.dex.text|It follows the northern lights.",
  "LOCALIZED DEX TEXT")
```

The registry key is `context|original source string`. Contexts are:

- `expanded_species.<SPECIES_ID>.name`
- `expanded_species.<SPECIES_ID>.dex.kind`
- `expanded_species.<SPECIES_ID>.dex.text`
- `expanded_species.<SPECIES_ID>.dex.text2`

Keep a released species ID and its source strings stable so translation packs
continue to match. A language mod may register these through
`mod.content.strings` or provide the equivalent entries in its normal
`lang/strings.lua` catalog. Missing translations simply leave the pack's
source text in place.

## Compatibility reports and checkpoint profiles

Developer menus can give authors a copyable report for one species pack:

```lua
local text, report = expanded.exports.formatCompatibilityReport(mod)
mod.log:info("%s", text)
assert(report.ok, "Expanded Species compatibility report needs attention")
```

`compatibilityReport(mod)` returns the same structured data: framework and
engine versions, the pack's species diagnoses, encounter placements, vanilla
trainer patches, hidden missing-Pokemon summaries, form/nest screen adapter
health, and the current content profile. Run it after `game.ready` because
allocation and merged registries do not exist earlier.

A checkpoint tool can store a deterministic sidecar beside its checkpoint and
compare it before offering a restore:

```lua
local savedProfile = expanded.exports.checkpointProfile()
-- Store savedProfile with the checkpoint metadata.

local comparison = expanded.exports.compareCheckpointProfile(savedProfile)
if not comparison.ok then
  -- Show comparison.missing/changed, or its unknown-format warning.
end
```

After any successful engine checkpoint restore, Expanded Species automatically
runs Save Guardian again. Gold 0.1.94 emits no pre-restore event, so the
framework cannot transparently stop or inspect a checkpoint before the engine
has applied it. The sidecar comparison must be performed by the checkpoint
tool itself; a general pre-restore validation seam is tracked for upstream.

## Disabled-pack Save Guardian

No extra registration is required. Expanded Species records the provider
owner and stable string ID for live custom species. During Gold's `save.loading`
event, a Pokemon whose definition is unavailable is removed from active engine
tables and retained as a complete record under Expanded Species' own `modData`
bucket. This private **MISSING** storage is not a PC box and has no player edit,
withdraw, release, battle, trade, or breeding surface.

When the species definition returns, the framework restores the record to its
original party, box, Day-Care, pending-egg, or active Bug-Catching Contest
location when available. It otherwise uses the first box with room. Party MAIL
is preserved separately and forces restoration to wait for a free party slot,
because Gold has no legal boxed MAIL representation.

Tools can inspect summary metadata without gaining access to edit hidden mon
records:

```lua
local count = expanded.exports.missingCount()
for _, row in ipairs(expanded.exports.missingInfo()) do
  mod.log:warn("missing %s from %s", row.species, row.provider or "unknown pack")
end
```

Guarding normally runs itself on Gold's `save.loading` event. `guardSave(save)`
runs the same pass on demand — omit the argument to use the live save — and is
intended for tools and tests rather than ordinary pack code:

```lua
expanded.exports.guardSave()          -- the live save
expanded.exports.guardSave(someSave)  -- an explicit one
```

The `saveGuardian` capability advertises this behavior. Authors must still keep
species IDs permanent after release. Changing `MY_PACK_OLD_NAME` to
`MY_PACK_NEW_NAME` looks like a removed species until the planned alias and
migration API exists; restoring the old registration ID is the non-destructive
recovery. Do not ask players to edit `modData` manually.

This protection requires Expanded Species itself to load. gen1recomp 0.1.94
does not expose a mod-disable/update veto, so disabling or removing the
framework cannot be intercepted by a provider pack.

## Compatibility boundary

Virtual indices are an engine-runtime extension, not an alteration to the Game
Boy save or scripting formats. Avoid paths that serialize species as one byte:

- importing/exporting custom Pokemon through a cartridge `.sav`
- ROM-script commands whose species operand is an 8-bit number
- ROM routines that translate through the original species-index table

Normal gen1recomp party/box saves, direct battles, registry-based encounters,
Pokedex seen/caught state, and link fingerprints use string species IDs.

Gold 0.1.94 also lacks safe registry-based seams for Headbutt, Rock Smash,
additional roaming slots, checkpoint pre-restore validation, per-individual
form palettes/cries, and native form routing in every legacy screen. Expanded
Species bridges the confirmed Gold form screens for its own records, while the
remaining engine boundaries are not author-facing slots that should be patched.

## Pack testing checklist

Test with Expanded Species and your pack enabled, then fully quit and relaunch
Gold. Several steps need a specific Pokemon on demand — a developer spawn tool
makes that quick, but any route that reliably produces the individual you want
works just as well:

1. Spawn the species and confirm its front sprite, palette, name, level and cry.
2. Catch it, lead the party with it, and start another battle to confirm its
   back sprite and player-side cry.
3. Open its party summary and Pokedex entry; confirm the cry plays from both.
4. Verify its stats, moves, party/box icon, normal palette and shiny palette.
5. Place a normal individual and a shiny one directly into the party or a box,
   then test back sprites and every declared evolution method.
6. Deposit and withdraw it, save, fully quit, and reload the native save.
7. Test at least one allocation above #255, either by providing five species or
   by testing alongside another pack.
8. If the pack adds a natural placement, encounter it in every declared time,
   terrain, rod, swarm state, or Contest range. Check grass/water registry
   placements in the Pokedex area page.
9. Run every registered gift, stationary encounter, trainer, and trade twice;
   the first should complete and the second should use its already-done path.
10. For each vanilla trainer patch, test insertion at the beginning, middle or
    end that the pack uses; verify full parties stay capped at six and exercise
    every separately targeted rematch member.
11. With a backup save, disable the species pack while its Pokemon occupy the
    party, a box, and the Day-Care. Confirm the in-game protection notice, that
    no MISSING box appears in the PC, then re-enable the pack and confirm every
    record restores with nickname, held item, MAIL, stats, and custom fields.
12. Keep Expanded Species enabled during that test; the framework cannot guard
    a save when it is itself disabled or unable to load.
13. For link play, use identical framework and species-pack versions on both
   devices and declare `"affects_link": true` in the species-pack manifest.
14. Test each cosmetic form in battle, Summary, party icons, selected PC
    preview, evolution, NPC trade, Hall of Fame, egg hatching, and Photo Studio.
    Confirm the Pokedex uses `defaultForm`, or base art when none is declared.
    For `trueColor` forms, verify the authored colors are not palette-remapped.
15. Save a checkpoint profile, change the enabled species-pack set, and verify
    the comparison reports added or missing IDs before restoring. Then run and
    save the pack's formatted compatibility report.
