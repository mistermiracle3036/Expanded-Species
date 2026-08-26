# Expanded Species

Expanded Species is a cross-generation framework for gen1recomp that lets
other mods register new Pokemon after the original roster instead of replacing
an existing species.

The framework keeps the vanilla species table intact, assigns deterministic
runtime IDs beginning at 252, and integrates custom species with
engine-native saves and battles in Red, Blue, Yellow, Gold, Silver, and
Crystal. Gen 1 supports species records, grass and swimming additions, direct
gifts and wild battles, diagnostics, and Save Guardian. Gen 2 additionally
supports the expanded Pokedex, palettes, breeding data, swarms, fishing, Bug
Contest, scripted encounter/trainer/trade helpers, vanilla-trainer patches,
cosmetic forms, and the shared Gen 2 screen bridges.

## For players

**Expanded Species does not add any Pokemon by itself.** It is the framework
that species packs are built on. Install it, then install a pack that declares
Expanded Species as a dependency — the pack supplies the Pokemon.

### Installation

1. Download `expanded_species-<version>.zip` from the
   [latest release](../../releases/latest).
2. In the launcher: **MODS → Import mod .zip**. On iOS, delete any older
   downloaded copy of the zip from Files first.
3. Fully quit and relaunch.

**Pokemon Red, Blue, Yellow, Gold, Silver, and Crystal.** Requires gen1recomp
**0.1.94 or newer** in the 0.x/1.x line. Version 0.7.0 is source-audited
against engine 0.2.24. Crystal passed the complete 0.6.6 device suite; the new
Gen 1 paths are under phone testing in 0.7.0.

## For mod makers

Declare this dependency in your manifest:

```json
"dependencies": [
  "expanded_species@>=0.7.0 <2.0.0"
]
```

Expanded Species reserves `2.0.0` for a breaking provider API change. The
exported `api_version` stays `1` throughout the current contract; negotiate
optional features by name instead of requiring that scalar to increase.

Then register through the provider-facing API in your own `main.lua`:

```lua
return function(mod)
  local framework = assert(mod.find("expanded_species"),
    "This mod requires Expanded Species")
  local api = assert(framework.exports.getApi(1))
  api = assert(api.requireCapabilities({ "safeDefaults", "runtimeWildBattles" }))
  local speciesId = "MY_PACK_AURORIX"

  -- Register owned audio before the species that references it.
  mod.content.cries:register(speciesId, {
    file = mod.assets:path("assets/aurorix_cry.ogg"),
  })

  api.register(mod, {
    id = speciesId,
    name = "AURORIX",
    types = { "ICE", "PSYCHIC" },
    baseStats = {
      hp = 80,
      attack = 65,
      defense = 75,
      speed = 95,
      specialAttack = 110,
      specialDefense = 100,
    },
    catchRate = 45,
    baseExp = 210,
    growthRate = "GROWTH_MEDIUM_SLOW",
    levelMoves = {
      { level = 1, move = "TACKLE" },
      { level = 7, move = "POWDER_SNOW" },
    },
    tmhm = {},
    evolutions = {},
    eggGroups = { "EGG_GROUND", "EGG_GROUND" },
    eggGroupsRaw = 0x55,
    eggMoves = {},
    eggSteps = 20,
    genderRatio = 127,
    items = {},
    spriteFront = mod.assets:path("assets/aurorix_front.png"),
    spriteBack = mod.assets:path("assets/aurorix_back.png"),
    picSize = 6,
    cry = speciesId,
    dexEntry = {
      kind = "AURORA",
      heightFt = 5,
      heightIn = 7,
      weightLbs = 132.3,
      text = "It paints the sky<NEXT>with icy light.",
      text2 = "Its thoughts shine<NEXT>like an aurora.",
    },
    iconFallback = "ESPEON",
    paletteFallback = "ESPEON",
  })
end
```

Use a globally namespaced string ID, such as `MY_PACK_AURORIX`. Do not provide
an `index`; Expanded Species assigns it after all content has passed Gen 2's
one-byte compatibility validation. See [AUTHOR_API.md](AUTHOR_API.md) for the
complete contract, including natural route encounters.

For larger packs, `preflight` returns all authoring errors at once and
`registerAll` validates the whole list before it writes any species:

```lua
local report = framework.exports.preflight(mod, aurorix)
assert(report.ok, report.errors[1] and report.errors[1].message)

framework.exports.registerAll(mod, { aurorix, burgela, coinpur })
```

The framework supplies safe defaults for `types`, `catchRate`, `baseExp`,
`growthRate`, `levelMoves`, `evolutions`, and `picSize`. Authors still provide
identity, all six base stats, and owned front/back sprite paths.

To add the registered species to an existing grass zone without replacing any
of its seven vanilla rows:

```lua
framework.exports.addGrassEncounter(mod, {
  map = "ROUTE_29",
  times = { "MORN", "DAY", "NITE" },
  species = speciesId,
  level = 4,
  weight = 1,
})
```

The vanilla pool has weight 100. One custom entry with weight 1 therefore has
a 1/101 chance when an encounter triggers; it does not change how often steps
trigger battles.

On older Gen 2 builds, Expanded Species also repairs the Pokédex AREA renderer
so grass and water placements display their flashing nest marker and route
name. **Current gen1recomp releases fix this natively**, and the bridge stands
itself down when they do — it is only there so the AREA page still works on the
engine versions this mod supports. Either way the encounter lookup is Gen 2's
own; the bridge never replaces it.

gen1recomp 0.1.94 also has safe helpers for fishing, active swarm tables, and the
Bug-Catching Contest:

```lua
api.addFishingEncounter(mod, {
  map = "ROUTE_32",
  rods = { "GOOD_ROD", "SUPER_ROD" },
  species = speciesId,
  level = 15,
  weight = 10,
  time = "NITE", -- optional: DAY/MORN or NITE/DARK
})

api.addBugContestEncounter(mod, {
  species = speciesId,
  minLevel = 12,
  maxLevel = 16,
  weight = 5,
})
```

Omit `time` for an all-day addition. Crystal's fishing tables distinguish a
day sub-slot (`MORN` and `DAY`) from a night sub-slot (`NITE` and `DARK`);
Expanded Species applies the same grouping. Existing registrations without a
time remain unchanged on Gold, Silver, and Crystal.

`addSwarmGrassEncounter` and `addSwarmWaterEncounter` use the same fields as
their normal counterparts and are considered only while that map's swarm table
is active. Headbutt, Rock Smash, and extra roaming slots still need upstream
encounter hooks and are not altered.

### Gifts, stationary encounters, trainers and trades

Each helper registers one provider-owned command and returns a ready-to-use
Gen 2 VM row. Put that row in a custom runtime NPC's `scriptKey`, or call the
same provider command from a Gen 2 script integration owned by your pack.

```lua
local giftRow = framework.exports.registerGift(mod, {
  id = "aurorix_gift",
  species = speciesId,
  level = 10,
  receivedText = "AURORIX joined you!",
})

local stationaryRow = framework.exports.registerStationaryEncounter(mod, {
  id = "aurorix_shrine",
  species = speciesId,
  level = 40,
  introText = "An icy presence appeared!",
  hideObject = true,
})
```

Trainer rosters and both sides of an NPC trade also take registry string IDs,
including custom species above #255. Completion state lives in the calling
pack's own `mod.save` namespace. See [AUTHOR_API.md](AUTHOR_API.md) for complete
examples and custom NPC wiring.

### Add custom Pokemon to vanilla trainers

Expanded Species can decorate an existing Gen 2 trainer without replacing its NPC,
dialogue, defeated flag, rematch logic, portrait, music, or reward rules:

```lua
api = assert(api.requireCapabilities({ "vanillaTrainerPatches" }))

api.patchVanillaTrainer(mod, {
  id = "joey_adds_aurorix",
  class = "YOUNGSTER",
  member = "JOEY1",
  changes = {
    { action = "insert", position = 1,
      species = speciesId, level = 6 },
  },
})
```

Insertion positions are one-based. Position `1` becomes the lead, any position
through the current party size inserts between members, and current size plus
one inserts at the end. Use `action = "append"` when the current size is not
known, or `action = "replace"` to change a member without increasing party
size. Gen 2's six-Pokemon limit is always enforced. Gen 2 calculates the payout
from the final composed party member's level, so appending a different-level
member can change the amount while retaining the trainer's normal base reward.
See
[AUTHOR_API.md](AUTHOR_API.md) for multi-change ordering, rematches, diagnostics,
and multi-pack conflict behavior.

### Cosmetic forms

A species can declare persistent per-Pokemon art variants. The chosen form is
stored on the Pokemon record and survives normal saves:

```lua
forms = {
  winter = {
    spriteFront = mod.assets:path("assets/aurorix_winter_front.png"),
    spriteBack = mod.assets:path("assets/aurorix_winter_back.png"),
    icon = mod.assets:path("assets/aurorix_winter_icon.png"),
    trueColor = true,
  },
},
```

Pass `form = "winter"` to a gift, stationary encounter, custom trainer member,
vanilla-trainer insertion, or custom NPC trade, or call
`api.setForm(mon, "winter")`. On gen1recomp 0.1.94, Expanded Species routes the live
form through battles, Summary, the selected PC preview, evolution, NPC-trade
art and icons, Hall of Fame, egg hatching, Cianwood Photo Studio, and party
icons. The Pokedex has no individual Pokemon record, so it displays the
species' `defaultForm` when one is declared. True-color form art bypasses the
legacy screens' palette remapping. Per-form palette tables and cries are not
yet engine-supported.

### Palettes

Gen 2 battle pictures use four shades. The engine supplies white and black;
species-pack authors supply the two middle RGB colors for both the normal and
shiny forms:

```lua
palette = {
  normal = {
    { 168, 232, 120 },
    { 64, 152, 56 },
  },
  shiny = {
    { 232, 216, 112 },
    { 152, 120, 40 },
  },
},
```

Put `palette` inside the record passed to `framework.exports.register`. Each
color is an `{ red, green, blue }` triple using values from 0 through 255. To
reuse a vanilla palette instead, set `paletteFallback = "TANGELA"`. Omitting
both falls back to Ditto. See [AUTHOR_API.md](AUTHOR_API.md) for sprite-shade,
true-color, shiny-testing, and multi-file species-pack guidance.

### Localization and compatibility checks

Expanded Species resolves custom names and Dex text through Gen 2's strings
catalog at `game.ready`. Translation add-ons can use namespaced keys such as
`expanded_species.MY_PACK_AURORIX.name|AURORIX` and
`expanded_species.MY_PACK_AURORIX.dex.text|It paints the sky<NEXT>with icy light.`
The plain English source key remains a fallback.

Before publishing a pack, print or log a focused report:

```lua
local text, report = api.formatCompatibilityReport(mod)
mod.log:info("\n%s", text)
assert(report.ok, "Custom species pack needs attention")
```

The report includes both `formScreens` and `nestScreen` adapter health. A tool
can query the nest adapter directly with `api.nestScreenStatus()` after
`game.ready`.

Checkpoint tools can store `api.checkpointProfile()` beside a persistent
checkpoint and call `api.compareCheckpointProfile(savedProfile)` before asking
the engine to restore it. Expanded Species also re-runs Save Guardian after a
successful checkpoint restoration. gen1recomp 0.1.94 has no pre-restore mod event,
so the sidecar comparison is required for early refusal; full engine-owned
checkpoint preflight remains an upstream request.

### Crystal caught data

Crystal individuals can carry `caughtLevel`, `caughtLocation`,
`caughtTime`, and `caughtByGender`. Read these fields by presence rather
than checking the edition name: `if mon.caughtLevel ~= nil then ... end`.
Gifts created through Expanded Species use the engine's official Crystal
gift-data helper when that capability exists. Ordinary wild and Contest
capture stamping remains owned by the engine and must be included in Crystal
device testing.

### Disabled-pack save safety

Expanded Species protects a Gen 2 save when a species pack is disabled, removed, or
temporarily fails to load. Before the game opens the world, custom Pokemon whose
species definitions are unavailable are removed from active engine tables and
kept intact in Expanded Species' private save data. The player cannot see or
interact with this internal **MISSING** storage through the PC.

When the pack returns, the framework automatically restores each Pokemon to
its original party slot, box position, Day-Care side, pending egg slot, or
active Bug-Catching Contest location when possible. If that location became
occupied, it uses the first legal ordinary box. A Pokemon carrying party MAIL
stays protected until a party slot is available because boxed Pokemon cannot
legally retain a party MAIL record. No Pokemon is deleted, converted into a
vanilla species, or assigned a different species ID.

Keep Expanded Species itself enabled. The current gen1recomp 0.1.94 mod manager
does not offer mods a pre-disable/update veto, so a framework that is itself
disabled, removed, or unable to load cannot run its guardian. An engine-level
disable/update guard is still the complete long-term solution.

## Important limits

- Engine-native gen1recomp saves retain custom Pokemon by string ID.
- Renaming or removing a shipped species ID is not yet an automatic migration;
  restore the old ID or wait for the planned alias/migration API.
- A physical cartridge `.sav` cannot encode virtual species above 255.
- Gen 2 ROM-script operations that take a one-byte species number cannot name a
  virtual species. Use the registry, trainer-decoration, and script helpers
  instead.
- gen1recomp 0.1.94 does not expose safe Headbutt, Rock Smash, extra-roamer,
  per-form-palette/cry, native all-screen form routing, or checkpoint preflight
  seams. Expanded Species supplies narrowly scoped Gen 2 screen bridges
  for its own cosmetic forms and the Pokédex nest landmark lookup.
- Link battles require both players to have matching framework and species-pack
  data. Species packs should set `"affects_link": true`.
- Keep Expanded Species enabled so its missing-pack guardian can run.

## License

MIT. See [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
