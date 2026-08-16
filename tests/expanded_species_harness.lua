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
local trainerPartyHook
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
    if hookName == "encounter.roll" then
        encounterRollHook = callback
    elseif hookName == "trainer.party" then
        trainerPartyHook = callback
    else
        fail("unexpected framework hook " .. tostring(hookName))
    end
end

local init = assert(loadfile("main.lua"))()
init(framework)

expectEqual(framework.exports.api_version, 1, "additive API remains backward-compatible")
expect(framework.exports.supportsApi(1), "API 1 negotiation")
expectEqual(framework.exports.getApi(1), framework.exports, "API 1 facade")
expectEqual(framework.exports.getApi(2), nil, "unknown API facade is refused")
expectEqual(framework.exports.requireCapabilities({ "scriptedTrainers", "gifts" }),
    framework.exports, "capability negotiation")
expect(framework.exports.supports("scriptedTrainers"), "trainer capability")
expect(framework.exports.supports("batchRegistration"), "batch capability")
expect(framework.exports.supports("vanillaTrainerPatches"),
    "vanilla trainer patch capability")
expect(type(readyCallback) == "function", "game.ready callback was not registered")
expect(type(encounterRollHook) == "function", "encounter.roll hook was not registered")
expect(type(trainerPartyHook) == "function", "trainer.party hook was not registered")

local registered = {}
local registeredCommands = {}
local registeredTrainers = {}
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
        commands = {},
        trainers = {},
    },
    save = { values = {} },
}

function provider.content.pokemon:register(speciesId, definition)
    expect(registered[speciesId] == nil, "provider tried to overwrite a species")
    registered[speciesId] = definition
end


function provider.content.commands:register(commandId, handler)
    expect(registeredCommands[commandId] == nil, "provider command must register once")
    registeredCommands[commandId] = handler
end


function provider.content.trainers:register(classId, definition)
    expect(registeredTrainers[classId] == nil, "provider trainer class must be unique")
    registeredTrainers[classId] = definition
end


function provider.save:get(key, default)
    local value = self.values[key]
    if value == nil then return default end
    return value
end


function provider.save:set(key, value)
    self.values[key] = value
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

local definitions = {}
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
    definitions[#definitions + 1] = definition
end

local invalidReport = framework.exports.preflight(provider, {
    id = "BROKEN_SPECIES",
    name = "BROKEN",
})
expect(not invalidReport.ok, "preflight should reject missing stats and sprites")
expect(#invalidReport.errors >= 3, "preflight should return actionable errors")

local normalizedBatch = framework.exports.registerAll(provider, definitions)
expectEqual(#normalizedBatch, #ids, "batch registration count")
for _, normalized in ipairs(normalizedBatch) do
    expectEqual(normalized.index, nil, "helper must strip byte-sized index")
    expectEqual(normalized.expandedSpecies.provider, provider.id, "provider ownership marker")
end

local minimal = speciesDefinition("TEST_PACK_DEFAULTS", nil)
minimal.types = nil
minimal.catchRate = nil
minimal.baseExp = nil
minimal.growthRate = nil
minimal.levelMoves = nil
minimal.evolutions = nil
minimal.picSize = nil
local defaultsReport = framework.exports.preflight(provider, minimal)
expect(defaultsReport.ok, "safe defaults should complete low-risk fields")
expectEqual(defaultsReport.definition.types[1], "NORMAL", "default type")
expectEqual(defaultsReport.definition.catchRate, 45, "default catch rate")

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

local giftRow = framework.exports.registerGift(provider, {
    id = "alpha_gift",
    species = "TEST_PACK_ALPHA",
    level = 10,
})
local stationaryRow = framework.exports.registerStationaryEncounter(provider, {
    id = "beta_statue",
    species = "TEST_PACK_BETA",
    level = 18,
    shiny = true,
    hideObject = true,
})
local trainerRow, trainerClass = framework.exports.registerTrainerEncounter(provider, {
    id = "alpha_tester",
    className = "TESTER",
    trainerName = "ADA",
    picFallback = "YOUNGSTER",
    party = {
        { species = "TEST_PACK_ALPHA", level = 15 },
        { species = "TEST_PACK_BETA", level = 16 },
    },
})
local tradeRow = framework.exports.registerTrade(provider, {
    id = "alpha_for_beta",
    give = "TEST_PACK_ALPHA",
    get = "TEST_PACK_BETA",
    nickname = "BETATEST",
    shiny = true,
    otName = "QA",
    otId = 3036,
})
local trainerPatch = framework.exports.patchVanillaTrainer(provider, {
    id = "joey_custom_party",
    class = "YOUNGSTER",
    member = "JOEY1",
    changes = {
        { action = "insert", position = 1,
          species = "TEST_PACK_ALPHA", level = 6 },
        { action = "insert", position = 3,
          species = "TEST_PACK_BETA", level = 7,
          moves = { "TACKLE", "GROWL" } },
        { action = "replace", position = 2,
          species = "TEST_PACK_GAMMA", level = 8 },
        { action = "insert", position = 5,
          species = "TEST_PACK_DELTA", level = 9 },
        { action = "append",
          species = "TEST_PACK_ZETA", level = 10 },
    },
})
local secondProvider = { id = "zzz_species_pack" }
framework.exports.patchVanillaTrainer(secondProvider, {
    id = "joey_conflicting_replace",
    class = "YOUNGSTER",
    member = "JOEY1",
    changes = {
        { action = "replace", position = 2,
          species = "TEST_PACK_EPSILON", level = 10 },
    },
})
framework.exports.patchVanillaTrainer(provider, {
    id = "full_party_guard",
    class = "ACE_TRAINER",
    member = "FULL1",
    changes = {
        { action = "insert", position = 1,
          species = "TEST_PACK_ALPHA", level = 30 },
    },
})

expectEqual(giftRow[1], "test_species_pack:expanded_species", "gift command verb")
expectEqual(giftRow[2], "gift", "gift command kind")
expectEqual(stationaryRow[2], "stationary", "stationary command kind")
expectEqual(trainerRow[2], "trainer", "trainer command kind")
expectEqual(tradeRow[2], "trade", "trade command kind")
expectEqual(trainerClass.trainers[1].party[2].species, "TEST_PACK_BETA",
    "trainer party keeps custom string ids")
expectEqual(registeredCommands["test_species_pack:expanded_species"] ~= nil, true,
    "one provider-owned script command")
expectEqual(trainerPatch.changes[2].position, 3,
    "trainer patch keeps arbitrary insertion position")

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
    local trainerOk, trainerError = Schemas.check(
        Schemas.REGISTRIES.trainers,
        "trainers",
        trainerClass.id,
        trainerClass,
        "register",
        2
    )
    expect(trainerOk, "custom trainer must satisfy Gold's real schema: "
        .. tostring(trainerError))
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

registeredTrainers.YOUNGSTER = {
    id = "YOUNGSTER",
    index = 16,
    name = "YOUNGSTER",
    trainers = {
        {
            id = "JOEY1",
            index = 1,
            name = "JOEY",
            party = {
                { species = "VANILLA_019", level = 4 },
                { species = "VANILLA_020", level = 5 },
            },
        },
    },
}
registeredTrainers.ACE_TRAINER = {
    id = "ACE_TRAINER",
    index = 17,
    name = "ACE TRAINER",
    trainers = {
        {
            id = "FULL1",
            index = 1,
            name = "FULL",
            party = vanillaSlots(6, "VANILLA_"),
        },
    },
}

local data = {
    pokemon = pokemon,
    moves = {
        TACKLE = { id = "TACKLE", pp = 35 },
        GROWL = { id = "GROWL", pp = 40 },
    },
    audio = { cries = {} },
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
        trainers = {
            YOUNGSTER = { { 248, 200, 120 }, { 120, 72, 32 } },
        },
    },
    gen2Trainers = { classes = registeredTrainers },
    gen2MenuGfx = {
        battleHud = {
            trainerPics = { YOUNGSTER = "vanilla_youngster.png" },
        },
    },
}

for speciesId in pairs(registered) do data.audio.cries[speciesId] = {} end

local battleStarted
local battleDone
local disappearedObject
local game = {
    data = data,
    save = {
        party = {
            { species = "DITTO", level = 20, hp = 40, stats = { hp = 40 } },
        },
        boxes = {},
        currentBox = 1,
        player = { name = "TESTER", id = 1234 },
        pokedex = { seen = {}, caught = {} },
        tradeFlags = {},
    },
    world = {
        eventTables = { trades = { {}, {}, {}, {}, {}, {} } },
    },
}
function game.world:startBattle(opts, onDone)
    battleStarted = opts
    battleDone = onDone
    return true
end
function game.world:disappearObject(objectId)
    disappearedObject = objectId
end
framework.game = game

readyCallback({ game = game })

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
expectEqual(framework.exports.owner("TEST_PACK_ALPHA"), provider.id,
    "owner query")
expectEqual(#framework.exports.byProvider(provider), 8,
    "provider query excludes directly adopted species")
expectEqual(framework.exports.info("TEST_PACK_ALPHA").virtualIndex,
    framework.exports.virtualIndex("TEST_PACK_ALPHA"), "metadata query")
local diagnostic = framework.exports.diagnose("TEST_PACK_ALPHA")
expect(diagnostic.ok, "registered custom species diagnostic should pass")
expectEqual(data.gen2Trainers.classes[trainerClass.id].pic,
    "vanilla_youngster.png", "trainer portrait fallback")
expect(data.gen2Palettes.trainers[trainerClass.id] ~= nil,
    "trainer palette fallback")
expectEqual(#game.world.eventTables.trades, 7,
    "custom trade appends after six vanilla trades")

package.loaded["src.battle.gen2.Mon"] = {
    new = function(_, species, level, opts)
        opts = opts or {}
        return {
            species = species,
            name = species,
            level = level,
            hp = 30,
            stats = { hp = 30 },
            dvs = opts.dvs,
            shiny = opts.shiny or (opts.dvs and opts.dvs.attack == 14),
            nickname = opts.nickname,
            item = opts.item,
            moves = opts.moves or {},
        }
    end,
    stampOT = function(save, mon)
        mon.ot = save.player.name
        mon.otId = save.player.id
        return mon
    end,
}
if not (arg and arg[1]) then
    package.loaded["src.world.gen2.Trainers"] = {
        party = function(_, entry)
            local out = {}
            for _, row in ipairs(entry.roster or {}) do
                out[#out + 1] = {
                    species = row.species,
                    level = row.level,
                    item = row.item,
                    moves = row.moves or {},
                    hp = 30,
                    stats = { hp = 30 },
                    dvs = { attack = 9, defense = 8, speed = 8, special = 8 },
                    trainerBuilt = true,
                }
            end
            return out
        end,
    }
else
    package.loaded["src.world.gen2.Trainers"] = nil
end
package.loaded["src.pokemon.Party"] = {
    add = function(party, mon)
        if #party >= 6 then return false end
        party[#party + 1] = mon
        return true
    end,
    firstHealthy = function(party)
        for _, mon in ipairs(party or {}) do
            if (mon.hp or 0) > 0 then return mon end
        end
    end,
}
package.loaded["src.pokemon.Boxes"] = {
    deposit = function(save, mon)
        save.boxes[1] = save.boxes[1] or {}
        if #save.boxes[1] >= 20 then return nil end
        save.boxes[1][#save.boxes[1] + 1] = mon
        return 1
    end,
}
package.loaded["src.core.gen2.Unown"] = { registerCatch = function() end }

local trainerDiagnostic = framework.exports.diagnoseTrainerPatches(
    "YOUNGSTER", "JOEY1")
expect(not trainerDiagnostic.ok,
    "two providers replacing the same trainer position must be diagnosed")
expectEqual(trainerDiagnostic.baseSize, 2, "trainer diagnostic base size")
expectEqual(trainerDiagnostic.composedSize, 6, "trainer diagnostic composed size")
expectEqual(#framework.exports.trainerPatches("YOUNGSTER", "JOEY1"), 2,
    "trainer patch query lists both providers")

local vanillaTrainerParty = {
    { species = "VANILLA_019", level = 4 },
    { species = "VANILLA_020", level = 5 },
}
local trainerNextCalls = 0
local composedTrainerParty = trainerPartyHook(function(classId, memberId, party)
    trainerNextCalls = trainerNextCalls + 1
    expectEqual(classId, "YOUNGSTER", "trainer hook class id")
    expectEqual(memberId, "JOEY1", "trainer hook member id")
    expectEqual(party, vanillaTrainerParty, "trainer hook receives vanilla party")
    return party
end, "YOUNGSTER", "JOEY1", vanillaTrainerParty)
expectEqual(trainerNextCalls, 1, "trainer hook preserves the wrapped hook")
expectEqual(#vanillaTrainerParty, 2, "trainer patch must not mutate wrapped party")
expectEqual(#composedTrainerParty, 6, "trainer inserts respect the six-mon limit")
expectEqual(composedTrainerParty[1].species, "TEST_PACK_ALPHA",
    "trainer insert can use the first position")
expectEqual(composedTrainerParty[2].species, "TEST_PACK_GAMMA",
    "trainer replacement uses the current composed position")
expectEqual(composedTrainerParty[3].species, "TEST_PACK_BETA",
    "trainer insert can use a middle position")
expectEqual(composedTrainerParty[4].species, "VANILLA_020",
    "trainer insert preserves later vanilla members")
expectEqual(composedTrainerParty[5].species, "TEST_PACK_DELTA",
    "trainer insert can use the final position")
expectEqual(composedTrainerParty[6].species, "TEST_PACK_ZETA",
    "trainer patch can append without knowing the final position")
expectEqual(composedTrainerParty[3].dvs.attack, 9,
    "custom trainer member uses Gold's fixed trainer DVs")
local secondTrainerMove = composedTrainerParty[3].moves[2]
expectEqual(type(secondTrainerMove) == "table" and secondTrainerMove.id
        or secondTrainerMove,
    "GROWL", "custom trainer member keeps explicit moves")

local untouchedParty = { { species = "VANILLA_010", level = 3 } }
expectEqual(trainerPartyHook(function(_, _, party) return party end,
        "BUG_CATCHER", "DON", untouchedParty),
    untouchedParty, "unregistered vanilla trainer party remains identical")

local fullParty = vanillaSlots(6, "FULL_")
local guardedParty = trainerPartyHook(function(_, _, party) return party end,
    "ACE_TRAINER", "FULL1", fullParty)
expectEqual(#guardedParty, 6, "trainer insert cannot create a seventh member")
expectEqual(guardedParty[1].species, "FULL_1",
    "full-party guard keeps the original order")
expect(not framework.exports.diagnoseTrainerPatches("ACE_TRAINER", "FULL1").ok,
    "full-party overflow is diagnosed")

local helper = registeredCommands["test_species_pack:expanded_species"]
local shown = {}
local vm = {
    showRaw = function(_, text) shown[#shown + 1] = text end,
}
helper({ vm = vm }, "gift", "alpha_gift")
expectEqual(#game.save.party, 2, "gift adds custom species to party")
expectEqual(game.save.party[2].species, "TEST_PACK_ALPHA", "gift species")
expect(game.save.pokedex.caught.TEST_PACK_ALPHA, "gift marks caught dex state")
helper({ vm = vm }, "gift", "alpha_gift")
expectEqual(#game.save.party, 2, "one-time gift cannot duplicate")

local stationaryCo
local stationaryVm = {}
function stationaryVm:resume(outcome)
    local ok, err = coroutine.resume(stationaryCo, outcome)
    expect(ok, "stationary command resume: " .. tostring(err))
end
stationaryCo = coroutine.create(function()
    helper({ vm = stationaryVm, object = 9 }, "stationary", "beta_statue")
end)
local stationaryOk, stationaryRequest = coroutine.resume(stationaryCo)
expect(stationaryOk, "stationary command should yield")
expectEqual(stationaryRequest.kind, "expanded_species_battle",
    "stationary command blocks the script")
expectEqual(battleStarted.wild.species, "TEST_PACK_BETA", "stationary species")
expectEqual(battleStarted.wild.dvs.attack, 14, "stationary shiny DVs")
battleDone("win")
expectEqual(coroutine.status(stationaryCo), "dead", "stationary resumes after battle")
expectEqual(disappearedObject, 9, "stationary helper hides its object")
expect(framework.exports.helperComplete(provider, "stationary", "beta_statue"),
    "stationary completion uses provider save")

local trainerCo = coroutine.create(function()
    helper({ vm = {} }, "trainer", "alpha_tester")
end)
local trainerOk, trainerRequest = coroutine.resume(trainerCo)
expect(trainerOk, "trainer command should yield")
expectEqual(trainerRequest.kind, "battle", "trainer uses Gold VM battle request")
expectEqual(trainerRequest.trainer.roster[2].species, "TEST_PACK_BETA",
    "trainer roster keeps custom species id")
expect(coroutine.resume(trainerCo, "win"), "trainer command resumes")
expect(framework.exports.helperComplete(provider, "trainer", "alpha_tester"),
    "trainer completion uses provider save")

local tradeCo = coroutine.create(function()
    helper({ vm = {} }, "trade", "alpha_for_beta")
end)
local tradeOk, tradeRequest = coroutine.resume(tradeCo)
expect(tradeOk, "trade command should yield")
expectEqual(tradeRequest.kind, "trade", "trade uses Gold VM trade request")
expectEqual(tradeRequest.trade, 6, "custom trade follows six vanilla rows")
game.save.tradeFlags[6] = true
expect(coroutine.resume(tradeCo), "trade command resumes")
expect(framework.exports.helperComplete(provider, "trade", "alpha_for_beta"),
    "trade completion is stored under provider save")
expectEqual(game.save.tradeFlags[6], nil, "runtime trade flag does not leak")

readyCallback({ game = game })
expectEqual(#data.gen2Pokedex.newOrder, 260, "hot reload must not duplicate Pokedex rows")
expectEqual(#data.gen2Pokedex.alphabeticalOrder, 260,
    "hot reload must not duplicate alphabetical rows")
expectEqual(#game.world.eventTables.trades, 7,
    "hot reload must not duplicate custom trade rows")

print(string.format(
    "PASS: allocated %d custom Gold species at IDs 252-260; trainer inserts cover first, middle and final positions",
    #allocatedIds
))
