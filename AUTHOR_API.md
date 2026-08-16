# Expanded Species author API

API version: `1` (0.3 through 0.5 additions are backward-compatible capabilities)

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
local owner = expanded.exports.owner("MY_PACK_AURORIX")
local mine = expanded.exports.byProvider(mod)
local info = expanded.exports.info("MY_PACK_AURORIX")
local report = expanded.exports.diagnose("MY_PACK_AURORIX")
```

`info` returns a protected copy of the live species record plus its owner,
allocated index and Dex number. `diagnose` checks the merged record, both battle
sprites, allocation, Dex row, icon, palette, cry, and evolution targets.

The exported `api_version` remains `1` because 0.3 through 0.5 only add methods;
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
"expanded_species@>=0.5.0 <2.0.0"
```

Expanded Species reserves `2.0.0` for a breaking provider API. Compatible
0.x and 1.x releases keep `getApi(1)` available and add optional behavior under
named capabilities. If a future 2.x release adds a new facade, a pack must opt
into it deliberately by changing both its dependency range and `getApi` call.
The legacy `supports(name)` and `capabilities()` queries remain useful for
features that are optional rather than required.

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

The helper records the append through the calling pack's official encounter
registry. This preserves ownership/unload behavior and makes the extra rows
visible to registry consumers such as the Pokedex area listing. It also uses
the official `encounter.roll` hook for selection. Fishing, Headbutt, Rock Smash
and Bug-Catching Contest tables already use variable-length chance rows and do
not need this 7/3-slot extension.

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
    { species = "MY_PACK_AURORIX", level = 18 },
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
Gold trainer schema.

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
      item = "BERRY" },
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
  allowBox = true,
})

local ok, err = expanded.exports.startWildBattle(speciesId, 20, {
  shiny = true,
})
```

One-time state can be queried when spawning actors, and reset by a pack's own
developer option:

```lua
local done = expanded.exports.helperComplete(mod, "stationary", "aurorix_shrine")
expanded.exports.resetHelper(mod, "stationary", "aurorix_shrine")
```

## Disabled-pack Save Guardian

No extra registration is required. Expanded Species 0.5 records the provider
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

## Pack testing checklist

Test with Expanded Species and Battle Spawner enabled, then fully quit and
relaunch Gold:

1. Spawn the species and confirm its front sprite, palette, name, level and cry.
2. Catch it, lead the party with it, and start another battle to confirm its
   back sprite and player-side cry.
3. Open its party summary and Pokedex entry; confirm the cry plays from both.
4. Verify its stats, moves, party/box icon, normal palette and shiny palette.
5. Use Battle Spawner 0.4.0 `ACTION = GIVE MON` to place normal and shiny
   individuals, then test back sprites and every declared evolution method.
6. Deposit and withdraw it, save, fully quit, and reload the native save.
7. Test at least one allocation above #255, either by providing five species or
   by testing alongside another pack.
8. If the pack adds a natural placement, encounter it in every declared time
   or terrain and check that the Pokedex area page lists the route.
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
