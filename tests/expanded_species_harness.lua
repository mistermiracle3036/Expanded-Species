local function fail(message)
    error("TEST FAILED: " .. message, 2)
end

local function expect(condition, message)
    if not condition then
        fail(message)
    end
end

local function expectEqual(actual, expected, message)
    if actual ~= expected then
        fail(string.format("%s (expected %s, got %s)",
            message, tostring(expected), tostring(actual)))
    end
end

local readyCallback
local encounterRollHook
local logs = {}
local framework = {
    id = "expanded_species",
    exports = {},
    events = {},
    hooks = {},
    log = {},
}

function framework.events:on(eventName, callback)
    expectEqual(eventName, "game.ready", "framework should subscribe to game.ready")
    readyCallback = callback
end

function framework.log:info(formatString, ...)
    logs[#logs + 1] = string.format(formatString, ...)
end

function framework.log:warn(formatString, ...)
    logs[#logs + 1] = string.format(formatString, ...)
end

function framework.hooks:wrap(hookName, callback)
    expectEqual(hookName, "encounter.roll", "framework encounter hook")
    encounterRollHook = callback
end

local init = assert(loadfile("main.lua"))()
init(framework)

expectEqual(framework.exports.api_version, 1, "API version")
expect(type(readyCallback) == "function", "game.ready callback was not registered")
expect(type(encounterRollHook) == "function", "encounter.roll hook was not registered")

local registered = {}
local function vanillaSlots(count, prefix)
    local slots = {}
    for index = 1, count do
        slots[index] = { level = index + 1, species = prefix .. index }
    end
    return slots
end

local encounterTables = {
    grass = {
        ROUTE_29 = {
            rates = { MORN = 25, DAY = 25, NITE = 25 },
            slots = {
                MORN = vanillaSlots(7, "MORN_"),
                DAY = vanillaSlots(7, "DAY_"),
                NITE = vanillaSlots(7, "NITE_"),
            },
        },
    },
    water = {
        ROUTE_30 = {
            rate = 15,
            slots = vanillaSlots(3, "WATER_"),
        },
    },
}

local provider = {
    id = "test_species_pack",
    content = {
        pokemon = {},
        encounters = {},
    },
}

function provider.content.pokemon:register(speciesId, definition)
    expect(registered[speciesId] == nil, "provider tried to overwrite a species")
    registered[speciesId] = definition
end

function provider.content.encounters:get(kind)
    return encounterTables[kind]
end

local function applyListPatch(target, patch)
    if patch.__append then
        for _, row in ipairs(patch.__append) do
            target[#target + 1] = row
        end
    end
end

function provider.content.encounters:patch(kind, partial)
    for mapId, mapPatch in pairs(partial) do
        local target = assert(encounterTables[kind][mapId])
        if kind == "grass" then
            for time, slotsPatch in pairs(mapPatch.slots or {}) do
                applyListPatch(target.slots[time], slotsPatch)
            end
        else
            applyListPatch(target.slots, mapPatch.slots)
        end
    end
end

local function speciesDefinition(speciesId, requestedDex)
    return {
        id = speciesId,
        name = speciesId,
        dex = requestedDex,
        index = requestedDex,
        types = { "NORMAL" },
        baseStats = {
            hp = 70,
            attack = 70,
            defense = 70,
            speed = 70,
            specialAttack = 70,
            specialDefense = 70,
        },
        catchRate = 100,
        baseExp = 100,
        growthRate = "MEDIUM_FAST",
        levelMoves = {},
        tmhm = {},
        evolutions = {},
        eggGroups = { "FIELD" },
        eggMoves = {},
        eggSteps = 5120,
        genderRatio = 127,
        items = {},
        spriteFront = "assets/front.png",
        spriteBack = "assets/back.png",
        picSize = 7,
        dexEntry = {
            kind = "TEST",
            heightFt = 3,
            heightIn = 4,
            weightLbs = 55.5,
            text = "Harness Pokemon.",
            text2 = "It tests IDs.",
        },
    }
end

local ids = {
    "TEST_PACK_THETA",
    "TEST_PACK_ALPHA",
    "TEST_PACK_ETA",
    "TEST_PACK_BETA",
    "TEST_PACK_ZETA",
    "TEST_PACK_GAMMA",
    "TEST_PACK_EPSILON",
    "TEST_PACK_DELTA",
}

for position, speciesId in ipairs(ids) do
    local requested = position == 1 and 260 or nil
    local definition = speciesDefinition(speciesId, requested)
    if speciesId == "TEST_PACK_ALPHA" then
        definition.icon = {
            image = "mods/test_species_pack/assets/icon.png",
            width = 16,
            height = 32,
            frames = 2,
        }
        definition.palette = {
            normal = { { 240, 120, 80 }, { 120, 40, 20 } },
            shiny = { { 100, 220, 240 }, { 20, 80, 120 } },
        }
    end
    local normalized = framework.exports.register(
        provider,
        definition
    )
    expectEqual(normalized.index, nil, "helper must strip byte-sized index")
    expectEqual(normalized.expandedSpecies.provider, provider.id, "provider ownership marker")
end

framework.exports.addGrassEncounter(provider, {
    map = "ROUTE_29",
    species = "TEST_PACK_ALPHA",
    level = 4,
    weight = 10,
})
framework.exports.addWaterEncounter(provider, {
    map = "ROUTE_30",
    species = "TEST_PACK_BETA",
    level = 12,
    weight = 25,
})

for _, time in ipairs({ "MORN", "DAY", "NITE" }) do
    expectEqual(#encounterTables.grass.ROUTE_29.slots[time], 8,
        "grass placement appends beyond seven slots for " .. time)
end
expectEqual(#encounterTables.water.ROUTE_30.slots, 4,
    "water placement appends beyond three slots")

local vanillaEncounter = { species = "VANILLA_001", level = 2, slot = 1 }
local nextCalls = 0
local function vanillaRoll()
    nextCalls = nextCalls + 1
    return vanillaEncounter
end

local customGrass = encounterRollHook(vanillaRoll, encounterTables, {
    mapId = "ROUTE_29",
    terrain = "grass",
    daytime = "MORN",
    rng = function(total)
        expectEqual(total, 110, "grass weighted total")
        return 101
    end,
})
expectEqual(customGrass.species, "TEST_PACK_ALPHA", "custom grass selection")
expectEqual(customGrass.level, 4, "custom grass level")
expectEqual(customGrass.slot, 8, "custom grass virtual slot")

local customWater = encounterRollHook(vanillaRoll, encounterTables, {
    mapId = "ROUTE_30",
    terrain = "water",
    rng = function(total)
        expectEqual(total, 125, "water weighted total")
        return 101
    end,
})
expectEqual(customWater.species, "TEST_PACK_BETA", "custom water selection")
expectEqual(customWater.slot, 4, "custom water virtual slot")

local preservedVanilla = encounterRollHook(vanillaRoll, encounterTables, {
    mapId = "ROUTE_29",
    terrain = "grass",
    daytime = "DAY",
    rng = function() return 100 end,
})
expectEqual(preservedVanilla, vanillaEncounter, "vanilla weighted branch")
local unrelatedRoute = encounterRollHook(vanillaRoll, encounterTables, {
    mapId = "ROUTE_31",
    terrain = "grass",
    daytime = "DAY",
})
expectEqual(unrelatedRoute, vanillaEncounter, "unpatched route remains vanilla")
local unloadedProvider = encounterRollHook(vanillaRoll, encounterTables, {
    mapId = "ROUTE_29",
    terrain = "grass",
    daytime = "DAY",
    data = { pokemon = {} },
    rng = function() fail("dormant provider must not consume a weighted roll") end,
})
expectEqual(unloadedProvider, vanillaEncounter,
    "provider placement is dormant when its species unloads")
expectEqual(nextCalls, 5, "encounter hook must preserve the wrapped roll")

if arg and arg[1] then
    local engineRoot = arg[1]:gsub("\\", "/"):gsub("/$", "")
    package.path = engineRoot .. "/?.lua;" .. engineRoot .. "/?/init.lua;" .. package.path
    local Schemas = require("src.mods.Schemas")
    local sample = registered.TEST_PACK_ALPHA
    local ok, schemaError = Schemas.check(
        Schemas.REGISTRIES.pokemon,
        "pokemon",
        sample.id,
        sample,
        "register",
        2
    )
    expect(ok, "normalized species must satisfy Gold's real schema: "
        .. tostring(schemaError))
end

local pokemon = {}
local entries = {}
local newOrder = {}
for index = 1, 251 do
    local speciesId = index == 132 and "DITTO" or string.format("VANILLA_%03d", index)
    pokemon[speciesId] = {
        id = speciesId,
        name = speciesId,
        dex = index,
        index = index,
    }
    entries[speciesId] = {
        id = speciesId,
        dex = index,
        kind = "VANILLA",
        height = 100,
        weight = 100,
        text = "Vanilla.",
        text2 = "Vanilla.",
    }
    newOrder[#newOrder + 1] = speciesId
end

for speciesId, definition in pairs(registered) do
    pokemon[speciesId] = definition
end

pokemon.TEST_PACK_DIRECT = speciesDefinition("TEST_PACK_DIRECT", 999)
pokemon.TEST_PACK_DIRECT.index = nil

local data = {
    pokemon = pokemon,
    gen2Pokedex = {
        entries = entries,
        newOrder = newOrder,
        alphabeticalOrder = {},
    },
    gen2Icons = {
        icons = {
            MON_ICON = {
                id = "MON_ICON",
                image = "vanilla.png",
                width = 16,
                height = 32,
                frames = 2,
            },
        },
        species = {
            DITTO = "MON_ICON",
        },
    },
    gen2Palettes = {
        pokemon = {
            DITTO = {
                normal = { { 255, 255, 255 }, { 120, 120, 120 } },
                shiny = { { 255, 255, 255 }, { 80, 80, 180 } },
            },
        },
    },
}

readyCallback({ game = { data = data } })

local allocatedIds = framework.exports.all()
expectEqual(#allocatedIds, 9, "all custom species should be allocated")
expectEqual(framework.exports.nextIndex(), 261, "next index should cross the byte ceiling")

local used = {}
for _, speciesId in ipairs(allocatedIds) do
    local index = framework.exports.virtualIndex(speciesId)
    expect(index >= 252 and index <= 260, "custom runtime index should be contiguous")
    expect(not used[index], "custom runtime indices should be unique")
    used[index] = speciesId
    expectEqual(pokemon[speciesId].dex, index, "Pokedex number should match runtime index")
    expectEqual(pokemon[speciesId].index, index, "runtime index should be installed")
    expectEqual(data.gen2Pokedex.entries[speciesId].dex, index, "Pokedex row should be installed")
    if speciesId == "TEST_PACK_ALPHA" then
        local iconId = data.gen2Icons.species[speciesId]
        expect(iconId:match("^ICON_EXPANDED_SPECIES_"), "custom icon ID")
        expectEqual(data.gen2Icons.icons[iconId].image,
            "mods/test_species_pack/assets/icon.png", "custom icon image")
        expectEqual(data.gen2Palettes.pokemon[speciesId].normal[1][1], 240,
            "custom palette")
    else
        expectEqual(data.gen2Icons.species[speciesId], "MON_ICON", "Ditto icon fallback")
        expect(data.gen2Palettes.pokemon[speciesId] ~= nil, "Ditto palette fallback")
    end
end

expect(used[256] ~= nil, "allocation must prove species 256 is usable")
expect(used[260] ~= nil, "allocation must prove species above 255 are usable")
expectEqual(pokemon.VANILLA_001.index, 1, "vanilla species index must not change")
expectEqual(pokemon.DITTO.index, 132, "vanilla Ditto index must not change")
expectEqual(data.gen2Pokedex.entries.TEST_PACK_ALPHA.height, 304,
    "Pokedex height convenience conversion")
expectEqual(data.gen2Pokedex.entries.TEST_PACK_ALPHA.weight, 555,
    "Pokedex weight convenience conversion")
expectEqual(#data.gen2Pokedex.newOrder, 260, "new-order Pokedex should contain every species once")
expectEqual(#data.gen2Pokedex.alphabeticalOrder, 260,
    "alphabetical Pokedex should contain every species once")

readyCallback({ game = { data = data } })
expectEqual(#data.gen2Pokedex.newOrder, 260, "hot reload must not duplicate Pokedex rows")
expectEqual(#data.gen2Pokedex.alphabeticalOrder, 260,
    "hot reload must not duplicate alphabetical rows")

print(string.format(
    "PASS: allocated %d custom Gold species at IDs 252-260, including 256+",
    #allocatedIds
))
