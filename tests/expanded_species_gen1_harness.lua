local engineRoot = assert(arg and arg[1], "engine root argument is required")
engineRoot = engineRoot:gsub("\\", "/"):gsub("/$", "")
package.path = engineRoot .. "/?.lua;" .. engineRoot .. "/?/init.lua;"
    .. package.path

love = love or {}
love.math = love.math or {}
love.math.random = love.math.random or function(low, high)
    if high ~= nil then return low end
    return low and 1 or 0
end

local function expect(value, message)
    if not value then error("TEST FAILED: " .. message, 2) end
end

local function equal(actual, expected, message)
    if actual ~= expected then
        error(("TEST FAILED: %s (expected %s, got %s)")
            :format(message, tostring(expected), tostring(actual)), 2)
    end
end

require("src.core.GameVersion").set("red")

local hooks, events = {}, {}
local shownText
local framework = {
    id = "expanded_species",
    exports = {},
    hooks = {},
    events = {},
    log = {},
    game = {
        save = { version = "red" },
    },
}

function framework.hooks:wrap(name, callback) hooks[name] = callback end
function framework.events:on(name, callback) events[name] = callback end
function framework.log:info() end
function framework.log:warn() end

local init = assert(loadfile("main.lua"))()
init(framework)

expect(framework.exports.supports("extendedGrass"), "Gen 1 grass capability")
expect(framework.exports.supports("extendedWater"), "Gen 1 water capability")
expect(framework.exports.supports("runtimeWildBattles"),
    "Gen 1 runtime wild battle capability")
expect(framework.exports.supports("saveGuardian"), "Gen 1 Guardian capability")
for _, name in ipairs({ "customDex", "customPalettes", "cosmeticForms",
        "extendedFishing", "extendedBugContest", "extendedSwarms",
        "gifts", "scriptedStationary", "scriptedTrainers",
        "scriptedTrades", "vanillaTrainerPatches", "goldFormScreens",
        "goldNestScreen" }) do
    expect(not framework.exports.supports(name), name .. " is masked on Gen 1")
end
for _, edition in ipairs({ "red", "blue", "yellow" }) do
    framework.game.save.version = edition
    expect(framework.exports.supports("extendedGrass"),
        edition .. " uses the Gen 1 capability set")
    expect(not framework.exports.supports("cosmeticForms"),
        edition .. " masks Gen 2-only capabilities")
end
framework.game.save.version = "red"

local registered = {}
local encounterRecord = {
    id = "ROUTE_1",
    grass = { rate = 25, slots = {} },
    water = { rate = 10, slots = {} },
}
for i = 1, 10 do
    encounterRecord.grass.slots[i] = { level = 2, species = "RATTATA" }
    encounterRecord.water.slots[i] = { level = 5, species = "MAGIKARP" }
end

local provider = {
    id = "gen1_test_pack",
    content = { pokemon = {}, encounters = {} },
}

function provider.content.pokemon:register(id, definition)
    registered[id] = definition
end

function provider.content.encounters:get(id)
    equal(id, "ROUTE_1", "Gen 1 encounter registry is keyed by map")
    return encounterRecord
end

function provider.content.encounters:patch(id, patch)
    equal(id, "ROUTE_1", "Gen 1 encounter patch targets the map record")
    for kind, row in pairs(patch) do
        local append = row.slots and row.slots.__append or {}
        for _, slot in ipairs(append) do
            encounterRecord[kind].slots[#encounterRecord[kind].slots + 1] = slot
        end
    end
end

local record = framework.exports.register(provider, {
    id = "GEN1_TEST_MON",
    name = "TESTMON",
    baseStats = {
        hp = 50, attack = 60, defense = 40, speed = 70,
        specialAttack = 55, specialDefense = 80,
    },
    levelMoves = {
        { level = 1, move = "TACKLE" },
        { level = 5, move = "GROWL" },
    },
    evolutions = {
        { into = "GEN1_TEST_EVOLUTION", method = "EVOLVE_LEVEL", level = 12 },
        { into = "VULPIX", method = "EVOLVE_HAPPINESS", time = "ANYTIME" },
    },
    spriteFront = "assets/test_front.png",
    spriteBack = "assets/test_back.png",
    picSize = 6,
    icon = { image = "assets/test_icon.png", width = 16, height = 32,
        frames = 2 },
    palette = { normal = {}, shiny = {} },
    forms = { winter = { spriteFront = "assets/winter.png" } },
    dexEntry = {
        kind = "CUSTOM", height = 507, weight = 123,
        text = "Custom dex info.",
    },
})

equal(record.baseStats.special, 80, "higher split Special becomes Gen 1 Special")
equal(record.baseStats.specialAttack, nil, "split Special Attack is removed")
equal(record.baseStats.specialDefense, nil, "split Special Defense is removed")
equal(record.growthRate, "MEDIUM_FAST", "growth-rate id is translated")
equal(record.frontSize, 6, "picSize becomes frontSize")
equal(record.picSize, nil, "Gen 2 picSize is removed")
equal(record.level1Moves[1], "TACKLE", "level-one move is derived")
equal(record.learnset[2].move, "GROWL", "levelMoves become the Gen 1 learnset")
equal(#record.evolutions, 1, "Gen 2-only evolution is skipped")
equal(record.evolutions[1].method, "LEVEL", "level evolution method is translated")
equal(record.evolutions[1].species, "GEN1_TEST_EVOLUTION",
    "evolution target uses Gen 1's species field")
equal(record.palette, nil, "Gen 2 inline palette is omitted")
equal(record.forms, nil, "cosmetic form record is omitted")
equal(record.icon.width, nil, "Gen 2 icon dimensions are omitted")
equal(record.icon.frames, 2, "schema-compatible icon frames are retained")
equal(record.index, nil, "one-byte cartridge index remains unset")
equal(record.dexEntry.heightFt, 5, "packed height feet are translated")
equal(record.dexEntry.heightIn, 7, "packed height inches are translated")

local Schemas = require("src.mods.Schemas")
local schemaOk, schemaError = Schemas.check(
    Schemas.REGISTRIES.pokemon, "pokemon", record.id, record, "register", 1)
expect(schemaOk, "normalized record satisfies Gen 1's schema: "
    .. tostring(schemaError))

framework.exports.addGrassEncounter(provider, {
    map = "ROUTE_1", species = record.id, level = 3, weight = 1,
    times = { "NITE" }, -- accepted but Gen 1 has no time-of-day split
})
framework.exports.addWaterEncounter(provider, {
    map = "ROUTE_1", species = record.id, level = 6, weight = 1,
})
equal(encounterRecord.grass.slots[11].species, record.id,
    "Gen 1 grass registry receives the custom nest row")
equal(encounterRecord.water.slots[11].species, record.id,
    "Gen 1 water registry receives the custom nest row")

local game = {
    data = {
        pokemon = {
            GEN1_TEST_MON = record,
            GEN1_TEST_EVOLUTION = {
                id = "GEN1_TEST_EVOLUTION", name = "EVOTEST", dex = 253,
                types = { "NORMAL" },
                baseStats = { hp = 60, attack = 70, defense = 50,
                    speed = 80, special = 90 },
                catchRate = 45, baseExp = 100,
                level1Moves = { "TACKLE" }, learnset = {},
                growthRate = "MEDIUM_FAST", evolutions = {},
                spriteFront = "assets/evo_front.png",
                spriteBack = "assets/evo_back.png", frontSize = 7,
            },
            RATTATA = { id = "RATTATA", name = "RATTATA" },
            MAGIKARP = { id = "MAGIKARP", name = "MAGIKARP" },
        },
        moves = {
            TACKLE = { pp = 35 }, GROWL = { pp = 40 },
        },
        text = {},
        audio = { cries = {} },
    },
    save = {
        version = "red",
        player = { id = 12345, name = "RED" },
        party = {}, boxes = {}, currentBox = 1,
        pokedex = { seen = {}, owned = {} },
        modData = {},
    },
    world = {},
}
function game.world:showText(text) shownText = text end
local wildSpecies, wildLevel
function game.world:startWildBattle(species, level)
    wildSpecies, wildLevel = species, level
    return true
end
framework.game = game
events["game.ready"]({ game = game })

equal(record.index, nil, "reconcile does not invent a Gen 1 cartridge index")
equal(framework.exports.virtualIndex(record.id), 252,
    "virtual allocation remains available on Gen 1")
equal(game.data.text[record.dexEntry.text], "Custom dex info.",
    "Gen 1 dex text is installed in the text table")

local grass = hooks["encounter.roll"](function()
    return { species = "RATTATA", level = 2 }
end, encounterRecord, {
    mapId = "ROUTE_1", terrain = "grass", rng = function() return 101 end,
})
equal(grass.species, record.id, "Gen 1 grass hook selects the custom species")
equal(grass.level, 3, "Gen 1 grass hook preserves the custom level")

local water = hooks["encounter.roll"](function()
    return { species = "MAGIKARP", level = 5 }
end, { grass = encounterRecord.water }, {
    mapId = "ROUTE_1", terrain = "water", rng = function() return 101 end,
})
equal(water.species, record.id, "Gen 1 water hook selects the custom species")
equal(water.level, 6, "Gen 1 water hook preserves the custom level")

expect(framework.exports.startWildBattle(record.id, 8),
    "Gen 1 runtime wild battle uses WorldAPI")
equal(wildSpecies, record.id, "Gen 1 WorldAPI receives the string species id")
equal(wildLevel, 8, "Gen 1 WorldAPI receives the requested level")

package.loaded["src.battle.BattleState"] = {
    stampOT = function(save, mon)
        mon.ot = save.player.name
        mon.otId = save.player.id
    end,
}
local gift = framework.exports.givePokemon(record.id, 9, {
    nickname = "CUSTOM", moves = { "TACKLE" },
    dvs = { attack = 9, defense = 8, speed = 8, special = 8 },
})
expect(gift.ok, "Gen 1 givePokemon succeeds")
equal(gift.destination, "party", "Gen 1 gift enters the party")
equal(gift.mon.otId, 12345, "Gen 1 gift receives the player's OT id")
equal(gift.mon.dvs.hp, 8, "Gen 1 HP DV is derived from the supplied DVs")
expect(game.save.pokedex.owned[record.id], "Gen 1 gift marks Pokedex owned")

game.data.pokemon[record.id] = nil
local hidden = framework.exports.guardSave(game.save)
equal(hidden.quarantined, 1, "Gen 1 Guardian hides a missing party species")
equal(#game.save.party, 0, "missing species leaves the active party")
equal(framework.exports.missingCount(), 1, "Gen 1 hidden count is reported")

game.data.pokemon[record.id] = record
for i = 1, 6 do game.save.party[i] = { species = "RATTATA", level = 2 } end
local restored = framework.exports.guardSave(game.save)
equal(restored.restored, 1, "Gen 1 Guardian restores an available species")
equal(game.save.boxes[1][1].species, record.id,
    "full-party restoration falls back to a Gen 1 PC box")
equal(game.save.boxes[13], nil, "Guardian never creates a thirteenth Gen 1 box")

game.data.pokemon[record.id] = nil
events["save.loading"]({ raw = game.save })
events["save.loaded"]({ save = game.save })
expect(shownText and shownText:find("\f", 1, true),
    "Gen 1 Guardian notice waits between pages")
expect(not shownText:find("<NEXT>", 1, true),
    "Gen 1 Guardian notice never emits a ROM charmap token")

print("PASS: Gen 1 species schema, encounters, wild battles, gifts, and Guardian")
