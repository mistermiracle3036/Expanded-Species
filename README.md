# Expanded Species

Expanded Species is a Gold-only framework for gen1recomp that lets other mods
register new Pokemon after the original 251 instead of replacing an existing
species.

The framework keeps the vanilla species table intact, assigns deterministic
runtime IDs beginning at 252, and integrates custom species with Gold's Pokedex,
party/box icons, palettes, engine-native saves, battles, breeding data, and
extended weighted grass/swimming encounter pools.

## For players

Install `expanded_species-0.2.1.zip` like any other gen1recomp mod, then install
a species pack that declares Expanded Species as a dependency. The framework
does not add Pokemon by itself.

The initial build targets gen1recomp Gold 0.1.79 or newer in the 0.x/1.x line.
It does not support Red.

## For mod makers

Declare this dependency in your manifest:

```json
"dependencies": [
  "expanded_species@>=0.2.0 <1.0.0"
]
```

Then register through the provider-facing API in your own `main.lua`:

```lua
return function(mod)
  local framework = assert(mod.find("expanded_species"),
    "This mod requires Expanded Species")
  local speciesId = "MY_PACK_AURORIX"

  -- Register owned audio before the species that references it.
  mod.content.cries:register(speciesId, {
    file = mod.assets:path("assets/aurorix_cry.ogg"),
  })

  framework.exports.register(mod, {
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
an `index`; Expanded Species assigns it after all content has passed Gold's
one-byte compatibility validation. See [AUTHOR_API.md](AUTHOR_API.md) for the
complete contract, including natural route encounters.

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

### Palettes

Gold battle pictures use four shades. The engine supplies white and black;
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

## Important limits

- Engine-native gen1recomp saves retain custom Pokemon by string ID.
- A physical cartridge `.sav` cannot encode virtual species above 255.
- Gold ROM-script operations that take a one-byte species number cannot name a
  virtual species. Use registry-based encounter and trainer-party APIs instead.
- Link battles require both players to have matching framework and species-pack
  data. Species packs should set `"affects_link": true`.
- Do not disable a species pack while one of its Pokemon is in a party or box.

## License

MIT. See [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
