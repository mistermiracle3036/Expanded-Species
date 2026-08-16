local VERSION = "0.4.0"
local API_VERSION = 1
local FIRST_CUSTOM_DEX = 252
local BASE_ENCOUNTER_WEIGHT = 100
local GRASS_TIMES = { "MORN", "DAY", "NITE" }
local SHINY_DVS = { attack = 14, defense = 10, speed = 10, special = 10 }
local TRAINER_TYPES = {
    TRAINERTYPE_NORMAL = true,
    TRAINERTYPE_MOVES = true,
    TRAINERTYPE_ITEM = true,
    TRAINERTYPE_ITEM_MOVES = true,
}
local TRADE_GENDERS = {
    either = "TRADE_GENDER_EITHER",
    male = "TRADE_GENDER_MALE",
    female = "TRADE_GENDER_FEMALE",
    TRADE_GENDER_EITHER = "TRADE_GENDER_EITHER",
    TRADE_GENDER_MALE = "TRADE_GENDER_MALE",
    TRADE_GENDER_FEMALE = "TRADE_GENDER_FEMALE",
}
local CAPABILITIES = {
    batchRegistration = true,
    capabilityQueries = true,
    customDex = true,
    customPalettes = true,
    diagnostics = true,
    extendedGrass = true,
    extendedWater = true,
    gifts = true,
    metadataQueries = true,
    preflight = true,
    runtimeWildBattles = true,
    scriptedStationary = true,
    scriptedTrades = true,
    scriptedTrainers = true,
    safeDefaults = true,
    vanillaTrainerPatches = true,
}

local function isInteger(value)
    return type(value) == "number" and value >= 1 and value % 1 == 0
end

local function copy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local out = {}
    seen[value] = out
    for key, item in pairs(value) do
        out[copy(key, seen)] = copy(item, seen)
    end
    return out
end

local function arrayContains(items, wanted)
    for _, item in ipairs(items or {}) do
        if item == wanted then
            return true
        end
    end
    return false
end

local function appendUnique(items, value)
    if not arrayContains(items, value) then
        items[#items + 1] = value
    end
end

local function encounterRandom(random, total)
    local value
    if type(random) == "function" then
        -- Gold supplies love.math.random through the encounter hook context;
        -- it returns 1..total while the encounter tables use a zero-based roll.
        value = (tonumber(random(total)) or 1) - 1
    elseif love and love.math and love.math.random then
        value = love.math.random(total) - 1
    else
        value = math.random(total) - 1
    end
    return math.max(0, math.floor(value)) % total
end

local function customEncounter(pool, random, pokemon)
    local active = {}
    local addedWeight = 0
    for _, placement in ipairs(pool or {}) do
        -- A provider's encounter journal is removed when that pack unloads.
        -- Keep the framework-side weight dormant as soon as its species is no
        -- longer present in the live merged registry.
        if type(pokemon) ~= "table" or pokemon[placement.species] ~= nil then
            active[#active + 1] = placement
            addedWeight = addedWeight + placement.weight
        end
    end
    if addedWeight <= 0 then
        return nil
    end

    local value = encounterRandom(random, BASE_ENCOUNTER_WEIGHT + addedWeight)
    if value < BASE_ENCOUNTER_WEIGHT then
        return nil
    end

    local cumulative = BASE_ENCOUNTER_WEIGHT
    for index, placement in ipairs(active) do
        cumulative = cumulative + placement.weight
        if value < cumulative then
            return {
                species = placement.species,
                level = placement.level,
                slot = placement.baseSlots + index,
            }
        end
    end
    return nil
end

local function markerFor(definition)
    if type(definition) ~= "table" then
        return nil
    end
    if type(definition.expandedSpecies) == "table" then
        return definition.expandedSpecies
    end
    return nil
end

local function isCustomSpecies(definition)
    if markerFor(definition) then
        return true
    end

    return (isInteger(definition.dex) and definition.dex >= FIRST_CUSTOM_DEX)
        or (isInteger(definition.index) and definition.index >= FIRST_CUSTOM_DEX)
end

local function requestedDex(speciesId, definition)
    local marker = markerFor(definition)
    local requested = marker and marker.requestedDex or definition.dex
    if not isInteger(requested) or requested < FIRST_CUSTOM_DEX then
        requested = nil
    end
    return requested, speciesId
end

local function sortedCustomSpecies(pokemon)
    local result = {}
    for speciesId, definition in pairs(pokemon or {}) do
        if type(speciesId) == "string"
            and type(definition) == "table"
            and isCustomSpecies(definition) then
            result[#result + 1] = speciesId
        end
    end

    table.sort(result, function(left, right)
        local leftDex = requestedDex(left, pokemon[left]) or math.huge
        local rightDex = requestedDex(right, pokemon[right]) or math.huge
        if leftDex ~= rightDex then
            return leftDex < rightDex
        end
        return left < right
    end)
    return result
end

local function customDexEntry(speciesId, definition)
    local marker = markerFor(definition) or {}
    local supplied = marker.dexEntry
    if type(supplied) ~= "table" and type(definition.dexEntry) == "table" then
        supplied = definition.dexEntry
    end
    supplied = supplied or {}

    local height = supplied.height
    if not isInteger(height) then
        local feet = tonumber(supplied.heightFt) or 0
        local inches = tonumber(supplied.heightIn) or 0
        height = math.max(0, math.floor(feet)) * 100 + math.max(0, math.floor(inches))
    end

    local weight = supplied.weight
    if type(weight) ~= "number" then
        local pounds = tonumber(supplied.weightLbs)
        weight = pounds and math.floor(pounds * 10 + 0.5) or 0
    end

    return {
        id = speciesId,
        dex = definition.dex,
        kind = supplied.kind or "CUSTOM",
        height = height,
        weight = weight,
        text = supplied.text or "A custom species.<NEXT>Added by a mod.",
        text2 = supplied.text2 or "Its data uses a<NEXT>virtual species ID.",
    }
end

local function rebuildPokedex(data, pokemon, customIds)
    local dex = data.gen2Pokedex
    if type(dex) ~= "table" then
        return
    end

    dex.entries = dex.entries or {}
    dex.newOrder = dex.newOrder or {}

    local customSet = {}
    for _, speciesId in ipairs(customIds) do
        customSet[speciesId] = true
        dex.entries[speciesId] = customDexEntry(speciesId, pokemon[speciesId])
    end

    local newOrder = {}
    for _, speciesId in ipairs(dex.newOrder) do
        if not customSet[speciesId] and pokemon[speciesId] then
            appendUnique(newOrder, speciesId)
        end
    end
    for _, speciesId in ipairs(customIds) do
        appendUnique(newOrder, speciesId)
    end
    dex.newOrder = newOrder

    local alphabetical = {}
    for speciesId, entry in pairs(dex.entries) do
        if pokemon[speciesId] and type(entry) == "table" then
            alphabetical[#alphabetical + 1] = speciesId
        end
    end
    table.sort(alphabetical, function(left, right)
        local leftName = tostring(pokemon[left].name or left):upper()
        local rightName = tostring(pokemon[right].name or right):upper()
        if leftName ~= rightName then
            return leftName < rightName
        end
        return left < right
    end)
    dex.alphabeticalOrder = alphabetical
end

local function safeIconId(speciesId)
    return "ICON_EXPANDED_SPECIES_" .. speciesId
end

local function installVisuals(data, pokemon, customIds)
    local iconData = data.gen2Icons
    local paletteData = data.gen2Palettes

    for _, speciesId in ipairs(customIds) do
        local definition = pokemon[speciesId]
        local marker = markerFor(definition) or {}

        if type(iconData) == "table" then
            iconData.icons = iconData.icons or {}
            iconData.species = iconData.species or {}

            local suppliedIcon = marker.icon or definition.icon
            if type(suppliedIcon) == "string" then
                suppliedIcon = { image = suppliedIcon }
            end

            if type(suppliedIcon) == "table" and type(suppliedIcon.image) == "string" then
                local iconId = safeIconId(speciesId)
                iconData.icons[iconId] = {
                    id = iconId,
                    image = suppliedIcon.image,
                    width = suppliedIcon.width or 16,
                    height = suppliedIcon.height or 32,
                    frames = suppliedIcon.frames or 2,
                }
                iconData.species[speciesId] = iconId
            else
                local fallback = marker.iconFallback or definition.iconFallback or "DITTO"
                iconData.species[speciesId] = iconData.species[fallback]
                    or iconData.species.DITTO
            end
        end

        if type(paletteData) == "table" then
            paletteData.pokemon = paletteData.pokemon or {}
            local suppliedPalette = marker.palette or definition.palette
            if type(suppliedPalette) == "table" then
                paletteData.pokemon[speciesId] = copy(suppliedPalette)
            else
                local fallback = marker.paletteFallback or definition.paletteFallback or "DITTO"
                local fallbackPalette = paletteData.pokemon[fallback]
                    or paletteData.pokemon.DITTO
                if fallbackPalette then
                    paletteData.pokemon[speciesId] = copy(fallbackPalette)
                end
            end
        end
    end
end

local function addIssue(items, path, message)
    items[#items + 1] = { path = path, message = message }
end

local function issueText(items)
    local lines = {}
    for _, issue in ipairs(items or {}) do
        lines[#lines + 1] = tostring(issue.path) .. ": " .. tostring(issue.message)
    end
    return table.concat(lines, "; ")
end

local function applySpeciesDefaults(definition)
    local record = copy(definition)
    if record.types == nil then record.types = { "NORMAL" } end
    if record.catchRate == nil then record.catchRate = 45 end
    if record.baseExp == nil then record.baseExp = 100 end
    if record.growthRate == nil then record.growthRate = "GROWTH_MEDIUM_FAST" end
    if record.levelMoves == nil then record.levelMoves = {} end
    if record.evolutions == nil then record.evolutions = {} end
    if record.picSize == nil then record.picSize = 7 end
    return record
end

local function speciesPreflight(providerMod, definition)
    local errors, warnings = {}, {}
    if type(providerMod) ~= "table" or type(providerMod.id) ~= "string"
        or providerMod.id == "" then
        addIssue(errors, "provider", "a provider mod with a non-empty id is required")
    end
    if type(definition) ~= "table" then
        addIssue(errors, "definition", "must be a table")
        return { ok = false, errors = errors, warnings = warnings }
    end

    local record = applySpeciesDefaults(definition)
    if type(record.id) ~= "string" or record.id == "" then
        addIssue(errors, "id", "must be a non-empty globally namespaced string")
    end
    if type(record.name) ~= "string" or record.name == "" then
        addIssue(errors, "name", "must be a non-empty string")
    end
    if type(record.types) ~= "table" or #record.types < 1 or #record.types > 2 then
        addIssue(errors, "types", "must contain one or two type ids")
    else
        for index, typeId in ipairs(record.types) do
            if type(typeId) ~= "string" or typeId == "" then
                addIssue(errors, "types[" .. index .. "]", "must be a type id string")
            end
        end
    end

    local statNames = {
        "hp", "attack", "defense", "speed", "specialAttack", "specialDefense",
    }
    if type(record.baseStats) ~= "table" then
        addIssue(errors, "baseStats", "must contain all six Gold stats")
    else
        for _, name in ipairs(statNames) do
            local value = record.baseStats[name]
            if not isInteger(value) or value > 255 then
                addIssue(errors, "baseStats." .. name,
                    "must be an integer from 1 through 255")
            end
        end
    end

    local function boundedInteger(path, value, minimum, maximum)
        if type(value) ~= "number" or value % 1 ~= 0
            or value < minimum or value > maximum then
            addIssue(errors, path, ("must be an integer from %d through %d")
                :format(minimum, maximum))
        end
    end
    boundedInteger("catchRate", record.catchRate, 0, 255)
    boundedInteger("baseExp", record.baseExp, 0, 255)
    boundedInteger("picSize", record.picSize, 1, 7)

    if type(record.growthRate) ~= "string" or record.growthRate == "" then
        addIssue(errors, "growthRate", "must be a Gold growth-rate id")
    end
    if type(record.levelMoves) ~= "table" then
        addIssue(errors, "levelMoves", "must be a list")
    end
    if type(record.evolutions) ~= "table" then
        addIssue(errors, "evolutions", "must be a list")
    end
    if type(record.spriteFront) ~= "string" or record.spriteFront == "" then
        addIssue(errors, "spriteFront", "must be an owned asset path")
    end
    if type(record.spriteBack) ~= "string" or record.spriteBack == "" then
        addIssue(errors, "spriteBack", "must be an owned asset path")
    end

    if record.index ~= nil then
        addIssue(warnings, "index", "is ignored; Expanded Species allocates it")
    end
    if record.cry == nil then
        addIssue(warnings, "cry", "no cry is assigned")
    end
    if record.dexEntry == nil then
        addIssue(warnings, "dexEntry", "the framework's generic custom entry will be used")
    end
    if record.trueColor and record.palette ~= nil then
        addIssue(warnings, "palette", "is bypassed while trueColor is enabled")
    end

    return {
        ok = #errors == 0,
        errors = errors,
        warnings = warnings,
        definition = record,
        provider = providerMod and providerMod.id or nil,
    }
end

local function normalizeForRegistration(providerMod, definition)
    assert(type(providerMod) == "table", "Expanded Species: provider mod is required")
    assert(type(providerMod.id) == "string" and providerMod.id ~= "",
        "Expanded Species: provider mod must have an id")
    assert(type(definition) == "table", "Expanded Species: species definition must be a table")
    assert(type(definition.id) == "string" and definition.id ~= "",
        "Expanded Species: species definition must have a string id")

    local record = applySpeciesDefaults(definition)
    local marker = type(record.expandedSpecies) == "table" and record.expandedSpecies or {}
    local desiredDex = record.dex
    if not isInteger(desiredDex) or desiredDex < FIRST_CUSTOM_DEX then
        desiredDex = record.index
    end
    if not isInteger(desiredDex) or desiredDex < FIRST_CUSTOM_DEX then
        desiredDex = marker.requestedDex
    end
    if not isInteger(desiredDex) or desiredDex < FIRST_CUSTOM_DEX then
        desiredDex = nil
    end

    marker.api = API_VERSION
    marker.provider = providerMod.id
    marker.requestedDex = desiredDex
    marker.dexEntry = copy(record.dexEntry or marker.dexEntry)
    marker.icon = copy(record.icon or marker.icon)
    marker.iconFallback = record.iconFallback or marker.iconFallback
    marker.palette = copy(record.palette or marker.palette)
    marker.paletteFallback = record.paletteFallback or marker.paletteFallback
    record.expandedSpecies = marker

    -- The Gold schema validates the optional cartridge index as one byte. Leave it
    -- unset during content validation; game.ready assigns the runtime-only index.
    record.index = nil
    record.dex = desiredDex or FIRST_CUSTOM_DEX
    return record
end

return function(mod)
    local state = {
        species = {},
        order = {},
        nextIndex = FIRST_CUSTOM_DEX,
        encounters = { grass = {}, water = {} },
        encounterKeys = {},
        providerSequences = {},
        scriptCommands = {},
        scriptHelpers = {
            gift = {},
            stationary = {},
            trainer = {},
            trade = {},
        },
        trades = {},
        tradeRuntimeIds = {},
        trainerPatches = {},
        trainerPatchWarnings = {},
    }

    local function providerKey(providerMod, kind, id)
        return table.concat({ providerMod.id, kind, id }, "|")
    end

    local function saveKey(kind, id)
        return "expanded_species." .. kind .. "." .. id
    end

    local function saveGet(providerMod, key, default)
        local save = providerMod and providerMod.save
        if save and type(save.get) == "function" then
            return save:get(key, default)
        end
        return default
    end

    local function saveSet(providerMod, key, value)
        local save = providerMod and providerMod.save
        if save and type(save.set) == "function" then
            save:set(key, value)
        end
    end

    local function requireGold(path)
        local ok, result = pcall(require, path)
        assert(ok, "Expanded Species: Gold runtime module unavailable: "
            .. path .. " (" .. tostring(result) .. ")")
        return result
    end

    local function liveGame()
        return mod.game
    end

    local function liveWorld()
        local game = liveGame()
        return game and game.world
    end

    local function shinyDvs(wanted)
        return wanted and copy(SHINY_DVS) or nil
    end

    local function buildMon(speciesId, level, opts)
        opts = opts or {}
        local game = liveGame()
        local data = game and game.data
        local Mon = requireGold("src.battle.gen2.Mon")
        local mon = Mon.new(data, speciesId, level, {
            dvs = opts.dvs or shinyDvs(opts.shiny),
            nickname = opts.nickname,
            item = opts.item,
            moves = opts.moves,
            happiness = opts.happiness,
        })
        return mon
    end

    local function warnTrainerPatchOnce(key, formatString, ...)
        if state.trainerPatchWarnings[key] then return end
        state.trainerPatchWarnings[key] = true
        mod.log:warn(formatString, ...)
    end

    local function trainerTargetIds(classValue, memberValue)
        local game = liveGame()
        local classes = game and game.data and game.data.gen2Trainers
            and game.data.gen2Trainers.classes
        local classId = classValue
        local class
        if type(classes) == "table" then
            if type(classValue) == "string" then
                class = classes[classValue]
            elseif type(classValue) == "number" then
                for id, row in pairs(classes) do
                    if type(row) == "table" and row.index == classValue then
                        classId = id
                        class = row
                        break
                    end
                end
            end
        end

        local memberId = memberValue
        if class and type(memberValue) == "number" then
            local row = class.trainers and class.trainers[memberValue]
            if row and row.id then memberId = row.id end
        end
        return classId, memberId, class
    end

    local function sortedTrainerPatches(classId, memberId)
        local out = {}
        for _, patch in pairs(state.trainerPatches) do
            if patch.class == classId and patch.member == memberId then
                out[#out + 1] = patch
            end
        end
        table.sort(out, function(left, right)
            if left.provider == right.provider then return left.id < right.id end
            return left.provider < right.provider
        end)
        return out
    end

    local function trainerPatchProviderActive(patch)
        if type(mod.find) ~= "function" then return true end
        return mod.find(patch.provider) ~= nil
    end

    local function buildTrainerPartyMember(change)
        local game = liveGame()
        local data = game and game.data
        local Trainers = requireGold("src.world.gen2.Trainers")
        local party = Trainers.party(data, {
            roster = {
                {
                    species = change.species,
                    level = change.level,
                    item = change.item,
                    moves = copy(change.moves),
                },
            },
        })
        return party and party[1] or nil
    end

    local function applyTrainerPatches(next_, trainerClass, trainerMember, party)
        local result = next_(trainerClass, trainerMember, party)
        if type(result) ~= "table" then result = party end
        if type(result) ~= "table" then return result end

        local classId, memberId = trainerTargetIds(trainerClass, trainerMember)
        local patches = sortedTrainerPatches(classId, memberId)
        if #patches == 0 then return result end

        -- Copy only the party array. Each existing member is already a
        -- battle-local mon and should retain identity for downstream hooks.
        local out = {}
        for index, mon in ipairs(result) do out[index] = mon end
        local replaced = {}

        for _, patch in ipairs(patches) do
            if trainerPatchProviderActive(patch) then
                for changeIndex, change in ipairs(patch.changes) do
                    local operationKey = table.concat({ patch.provider, patch.id,
                        tostring(changeIndex) }, "|")
                    local position = change.position
                    local validPosition = true
                    local replacementClaim
                    if change.action == "insert" then
                        validPosition = position <= #out + 1
                    elseif change.action == "replace" then
                        validPosition = position <= #out
                        replacementClaim = tostring(position)
                    end

                    if not validPosition then
                        warnTrainerPatchOnce(operationKey .. "|position",
                            "Expanded Species skipped %s/%s: %s position %s is "
                                .. "invalid for trainer %s/%s party size %d",
                            patch.provider, patch.id, change.action,
                            tostring(position), tostring(classId),
                            tostring(memberId), #out)
                    elseif replacementClaim and replaced[replacementClaim] then
                        warnTrainerPatchOnce(operationKey .. "|collision",
                            "Expanded Species skipped %s/%s: trainer %s/%s "
                                .. "position %d is already replaced by %s",
                            patch.provider, patch.id, tostring(classId),
                            tostring(memberId), position,
                            replaced[replacementClaim])
                    elseif change.action ~= "replace" and #out >= 6 then
                        warnTrainerPatchOnce(operationKey .. "|full",
                            "Expanded Species skipped %s/%s: trainer %s/%s "
                                .. "already has six Pokemon",
                            patch.provider, patch.id, tostring(classId),
                            tostring(memberId))
                    else
                        local mon = buildTrainerPartyMember(change)
                        if not mon then
                            warnTrainerPatchOnce(operationKey .. "|species",
                                "Expanded Species skipped %s/%s: species %s "
                                    .. "is unavailable",
                                patch.provider, patch.id, tostring(change.species))
                        elseif change.action == "insert" then
                            table.insert(out, position, mon)
                        elseif change.action == "append" then
                            out[#out + 1] = mon
                        else
                            out[position] = mon
                            replaced[replacementClaim] = patch.provider
                                .. "/" .. patch.id
                        end
                    end
                end
            end
        end
        return out
    end

    local function markDex(save, speciesId, caught)
        if not save then return end
        save.pokedex = save.pokedex or { seen = {}, caught = {} }
        save.pokedex.seen = save.pokedex.seen or {}
        save.pokedex.caught = save.pokedex.caught or {}
        save.pokedex.seen[speciesId] = true
        if caught then save.pokedex.caught[speciesId] = true end
    end

    local function depositGift(save, mon, allowBox)
        save.party = save.party or {}
        local Party = requireGold("src.pokemon.Party")
        if Party.add(save.party, mon) then
            return { ok = true, destination = "party", mon = mon }
        end
        if allowBox == false then
            return { ok = false, error = "party is full", mon = mon }
        end
        local Boxes = requireGold("src.pokemon.Boxes")
        local box = Boxes.deposit(save, mon)
        if not box then
            return { ok = false, error = "party and all boxes are full", mon = mon }
        end
        return { ok = true, destination = "box", box = box, mon = mon }
    end

    local function givePokemon(speciesId, level, opts)
        opts = opts or {}
        assert(type(speciesId) == "string" and speciesId ~= "",
            "Expanded Species: gift species id is required")
        assert(isInteger(level) and level <= 100,
            "Expanded Species: gift level must be an integer from 1 to 100")
        local game = liveGame()
        local save = game and game.save
        if not save then return { ok = false, error = "no active Gold save" } end
        local mon = buildMon(speciesId, level, opts)
        if not mon then
            return { ok = false, error = "unknown species: " .. speciesId }
        end
        local Mon = requireGold("src.battle.gen2.Mon")
        Mon.stampOT(save, mon)
        local result = depositGift(save, mon, opts.allowBox)
        if not result.ok then return result end
        markDex(save, speciesId, true)
        local Unown = requireGold("src.core.gen2.Unown")
        if Unown and type(Unown.registerCatch) == "function" then
            Unown.registerCatch(save, mon)
        end
        return result
    end

    local function startWildBattle(speciesId, level, opts, onDone)
        opts = opts or {}
        assert(type(speciesId) == "string" and speciesId ~= "",
            "Expanded Species: wild species id is required")
        assert(isInteger(level) and level <= 100,
            "Expanded Species: wild level must be an integer from 1 to 100")
        local game = liveGame()
        local world = liveWorld()
        if not (game and world) then return nil, "no active Gold overworld" end
        local party = game.save and game.save.party
        local Party = requireGold("src.pokemon.Party")
        if not Party.firstHealthy(party or {}) then return nil, "no healthy party" end
        local mon = buildMon(speciesId, level, opts)
        if not mon then return nil, "unknown species: " .. speciesId end
        markDex(game.save, speciesId, false)
        return world:startBattle({ wild = mon, battleType = opts.battleType }, onDone)
    end

    local function encounterPool(kind, mapId, time)
        if kind == "grass" then
            local maps = state.encounters.grass[mapId]
            return maps and maps[time]
        end
        return state.encounters.water[mapId]
    end

    local function addEncounterPlacement(providerMod, placement, kind)
        assert(type(providerMod) == "table" and type(providerMod.id) == "string"
            and providerMod.id ~= "",
            "Expanded Species: encounter provider mod is required")
        assert(type(placement) == "table",
            "Expanded Species: encounter placement must be a table")

        local registry = providerMod.content and providerMod.content.encounters
        assert(type(registry) == "table" and type(registry.get) == "function"
            and type(registry.patch) == "function",
            "Expanded Species: provider mod has no encounter content registry")

        local mapId = placement.map
        local speciesId = placement.species
        local level = placement.level
        local weight = placement.weight
        assert(type(mapId) == "string" and mapId ~= "",
            "Expanded Species: encounter placement requires a map id")
        assert(type(speciesId) == "string" and speciesId ~= "",
            "Expanded Species: encounter placement requires a species id")
        assert(isInteger(level) and level <= 100,
            "Expanded Species: encounter level must be an integer from 1 to 100")
        assert(isInteger(weight),
            "Expanded Species: encounter weight must be a positive integer")

        local current = registry:get(kind)
        local mapRow = current and current[mapId]
        assert(type(mapRow) == "table",
            ("Expanded Species: %s has no %s encounter table")
                :format(mapId, kind))

        local providerSequence = (state.providerSequences[providerMod.id] or 0) + 1
        local pending = {}
        local pendingKeys = {}

        local function prepare(time, baseSlots)
            local key = table.concat({ providerMod.id, kind, mapId,
                time or "-", speciesId, tostring(level) }, "|")
            assert(not state.encounterKeys[key],
                "Expanded Species: duplicate encounter placement " .. key)
            assert(not pendingKeys[key],
                "Expanded Species: duplicate encounter placement " .. key)
            pendingKeys[key] = true

            pending[#pending + 1] = {
                key = key,
                time = time,
                provider = providerMod.id,
                sequence = providerSequence,
                species = speciesId,
                level = level,
                weight = weight,
                baseSlots = baseSlots,
            }
        end

        local function commit(placementRow)
            state.encounterKeys[placementRow.key] = true
            local pool
            if kind == "grass" then
                state.encounters.grass[mapId] = state.encounters.grass[mapId] or {}
                local maps = state.encounters.grass[mapId]
                maps[placementRow.time] = maps[placementRow.time] or {}
                pool = maps[placementRow.time]
            else
                state.encounters.water[mapId] = state.encounters.water[mapId] or {}
                pool = state.encounters.water[mapId]
            end
            pool[#pool + 1] = placementRow
            table.sort(pool, function(left, right)
                if left.provider ~= right.provider then
                    return left.provider < right.provider
                end
                return left.sequence < right.sequence
            end)
        end

        if kind == "grass" then
            local requestedTimes = placement.times
            if placement.time ~= nil then
                assert(requestedTimes == nil,
                    "Expanded Species: use encounter time or times, not both")
                requestedTimes = { placement.time }
            end
            requestedTimes = requestedTimes or GRASS_TIMES
            assert(type(requestedTimes) == "table" and #requestedTimes > 0,
                "Expanded Species: grass encounter times must be a non-empty list")

            local slotsPatch = {}
            local seenTimes = {}
            for _, rawTime in ipairs(requestedTimes) do
                local time = rawTime == "DARK" and "NITE" or rawTime
                assert(time == "MORN" or time == "DAY" or time == "NITE",
                    "Expanded Species: grass time must be MORN, DAY or NITE")
                assert(not seenTimes[time],
                    "Expanded Species: duplicate grass encounter time " .. time)
                seenTimes[time] = true

                local base = mapRow.slots and (mapRow.slots[time]
                    or mapRow.slots.DAY)
                assert(type(base) == "table",
                    ("Expanded Species: %s has no %s grass slots")
                        :format(mapId, time))
                slotsPatch[time] = {
                    __append = { { level = level, species = speciesId } },
                }
                prepare(time, 7)
            end
            registry:patch("grass", { [mapId] = { slots = slotsPatch } })
        else
            assert(type(mapRow.slots) == "table",
                "Expanded Species: " .. mapId .. " has no water slots")
            prepare(nil, 3)
            registry:patch("water", {
                [mapId] = {
                    slots = {
                        __append = { { level = level, species = speciesId } },
                    },
                },
            })
        end

        state.providerSequences[providerMod.id] = providerSequence
        for _, placementRow in ipairs(pending) do
            commit(placementRow)
        end

        return {
            map = mapId,
            species = speciesId,
            level = level,
            weight = weight,
        }
    end

    local function helperBucket(kind, providerMod)
        local bucket = assert(state.scriptHelpers[kind],
            "Expanded Species: unknown scripted helper kind " .. tostring(kind))
        bucket[providerMod.id] = bucket[providerMod.id] or {}
        return bucket[providerMod.id]
    end

    local function showHelperText(ctx, body)
        if type(body) == "string" and body ~= ""
            and ctx and ctx.vm and type(ctx.vm.showRaw) == "function" then
            ctx.vm:showRaw(body)
        end
    end

    local function helperDone(providerMod, kind, spec)
        return spec.once ~= false
            and saveGet(providerMod, saveKey(kind, spec.id), false) == true
    end

    local function markHelperDone(providerMod, kind, spec)
        if spec.once ~= false then
            saveSet(providerMod, saveKey(kind, spec.id), true)
        end
    end

    local function trainerRecord(spec)
        local game = liveGame()
        local classes = game and game.data and game.data.gen2Trainers
            and game.data.gen2Trainers.classes
        local class = classes and classes[spec.classId]
        if not class then return nil end
        local member
        for _, row in ipairs(class.trainers or {}) do
            if row.id == spec.memberId then member = row break end
        end
        member = member or class.trainers and class.trainers[1]
        if not member then return nil end
        local items = {}
        for _, item in ipairs(class.items or {}) do items[#items + 1] = item end
        return {
            class = class.index,
            classId = spec.classId,
            className = class.name,
            member = member.index,
            id = member.id,
            name = member.name,
            trainerType = member.trainerType,
            roster = member.party or {},
            attributes = class.attributes,
            items = items,
            baseMoney = class.baseMoney,
        }
    end

    local function runGift(providerMod, spec, ctx)
        if helperDone(providerMod, "gift", spec) then
            showHelperText(ctx, spec.alreadyText or "You already received this POKéMON.")
            return
        end
        showHelperText(ctx, spec.introText)
        local result = givePokemon(spec.species, spec.level, spec)
        if not result.ok then
            showHelperText(ctx, spec.fullText or ("Could not receive it: "
                .. tostring(result.error) .. "."))
            return
        end
        markHelperDone(providerMod, "gift", spec)
        local destination = result.destination == "box"
            and ("It was sent to BOX " .. tostring(result.box) .. ".")
            or "It joined your party."
        showHelperText(ctx, spec.receivedText or destination)
    end

    local function runStationary(providerMod, spec, ctx)
        if helperDone(providerMod, "stationary", spec) then
            showHelperText(ctx, spec.alreadyText)
            return
        end
        showHelperText(ctx, spec.introText)
        local vm = ctx and ctx.vm
        assert(vm and type(vm.resume) == "function",
            "Expanded Species: stationary helper needs Gold's script VM")
        local ok, err = startWildBattle(spec.species, spec.level, spec,
            function(outcome) vm:resume(outcome) end)
        assert(ok, err or "stationary battle failed")
        local outcome = coroutine.yield({ kind = "expanded_species_battle" })
        if outcome ~= "lose" then
            markHelperDone(providerMod, "stationary", spec)
            local world = liveWorld()
            if spec.hideObject and world and ctx.object then
                world:disappearObject(ctx.object)
            end
            showHelperText(ctx, spec.afterText)
        end
    end

    local function runTrainer(providerMod, spec, ctx)
        if helperDone(providerMod, "trainer", spec) then
            showHelperText(ctx, spec.alreadyText or spec.afterText)
            return
        end
        showHelperText(ctx, spec.introText)
        local record = trainerRecord(spec)
        assert(record, "Expanded Species: trainer content is unavailable: "
            .. tostring(spec.classId))
        local outcome = coroutine.yield({ kind = "battle", trainer = record })
        if outcome ~= "lose" then
            markHelperDone(providerMod, "trainer", spec)
            showHelperText(ctx, spec.afterText)
        end
    end

    local installTrades

    local function runTrade(providerMod, spec)
        local game = liveGame()
        local save = game and game.save
        assert(save, "Expanded Species: trade helper needs an active Gold save")
        local key = providerKey(providerMod, "trade", spec.id)
        if state.tradeRuntimeIds[key] == nil and installTrades then
            installTrades(game)
        end
        local runtimeId = state.tradeRuntimeIds[key]
        assert(runtimeId ~= nil,
            "Expanded Species: trade rows are not ready; wait for game.ready")
        local stableKey = saveKey("trade", spec.id)
        save.tradeFlags = save.tradeFlags or {}
        local previousFlag = save.tradeFlags[runtimeId]
        save.tradeFlags[runtimeId] = saveGet(providerMod, stableKey, false) == true
        coroutine.yield({ kind = "trade", trade = runtimeId })
        if save.tradeFlags[runtimeId] then saveSet(providerMod, stableKey, true) end
        save.tradeFlags[runtimeId] = previousFlag
    end

    local function ensureScriptCommand(providerMod)
        if state.scriptCommands[providerMod.id] then
            return state.scriptCommands[providerMod.id]
        end
        local registry = providerMod.content and providerMod.content.commands
        assert(type(registry) == "table" and type(registry.register) == "function",
            "Expanded Species: provider mod has no commands content registry")
        local verb = providerMod.id .. ":expanded_species"
        registry:register(verb, function(ctx, kind, id)
            local bucket = state.scriptHelpers[kind]
            local spec = bucket and bucket[providerMod.id]
                and bucket[providerMod.id][id]
            assert(spec, ("Expanded Species: unknown %s helper %s")
                :format(tostring(kind), tostring(id)))
            if kind == "gift" then return runGift(providerMod, spec, ctx) end
            if kind == "stationary" then
                return runStationary(providerMod, spec, ctx)
            end
            if kind == "trainer" then return runTrainer(providerMod, spec, ctx) end
            if kind == "trade" then return runTrade(providerMod, spec, ctx) end
            error("Expanded Species: unsupported helper kind " .. tostring(kind))
        end)
        state.scriptCommands[providerMod.id] = verb
        return verb
    end

    local function registerScriptHelper(providerMod, kind, spec)
        assert(type(providerMod) == "table" and type(providerMod.id) == "string"
            and providerMod.id ~= "",
            "Expanded Species: scripted helper provider mod is required")
        assert(type(spec) == "table", "Expanded Species: helper definition is required")
        assert(type(spec.id) == "string" and spec.id ~= "",
            "Expanded Species: helper id must be a non-empty string")
        local bucket = helperBucket(kind, providerMod)
        assert(bucket[spec.id] == nil,
            ("Expanded Species: duplicate %s helper %s")
                :format(kind, spec.id))
        local record = copy(spec)
        record.once = record.once ~= false
        bucket[record.id] = record
        local verb = ensureScriptCommand(providerMod)
        return { verb, kind, record.id }, record
    end

    local function installTrainerVisuals(data)
        local classes = data and data.gen2Trainers and data.gen2Trainers.classes
        if not classes then return end
        local hud = data.gen2MenuGfx and data.gen2MenuGfx.battleHud
        local trainerPics = hud and hud.trainerPics
        local palettes = data.gen2Palettes and data.gen2Palettes.trainers
        for _, providers in pairs(state.scriptHelpers.trainer) do
            for _, spec in pairs(providers) do
                local class = classes[spec.classId]
                local fallback = spec.picFallback or "YOUNGSTER"
                if class and not class.pic and trainerPics then
                    class.pic = trainerPics[fallback] or trainerPics.YOUNGSTER
                end
                if class and palettes and not palettes[spec.classId]
                    and palettes[fallback] then
                    palettes[spec.classId] = copy(palettes[fallback])
                end
            end
        end
    end

    installTrades = function(game)
        local world = game and game.world
        local eventTables = world and world.eventTables
        local rows = eventTables and eventTables.trades
        if type(rows) ~= "table" then return 0 end

        for index = #rows, 1, -1 do
            if type(rows[index]) == "table" and rows[index].expandedSpeciesTrade then
                table.remove(rows, index)
            end
        end
        state.tradeRuntimeIds = {}
        local ordered = {}
        for key, entry in pairs(state.trades) do
            ordered[#ordered + 1] = { key = key, entry = entry }
        end
        table.sort(ordered, function(left, right) return left.key < right.key end)
        for _, wrapped in ipairs(ordered) do
            local runtimeId = #rows
            local row = copy(wrapped.entry.row)
            row.expandedSpeciesTrade = wrapped.key
            rows[#rows + 1] = row
            state.tradeRuntimeIds[wrapped.key] = runtimeId
        end
        return #ordered
    end

    local function reconcile(game)
        local data = game and game.data
        local pokemon = data and data.pokemon
        if type(pokemon) ~= "table" then
            mod.log:warn("Expanded Species could not find Gold's Pokemon registry")
            return 0
        end

        local customIds = sortedCustomSpecies(pokemon)
        local assigned = {}
        local nextIndex = FIRST_CUSTOM_DEX
        for _, speciesId in ipairs(customIds) do
            local definition = pokemon[speciesId]
            definition.dex = nextIndex
            definition.index = nextIndex
            local marker = markerFor(definition)
            if marker then
                marker.virtualIndex = nextIndex
            end
            assigned[speciesId] = nextIndex
            nextIndex = nextIndex + 1
        end

        rebuildPokedex(data, pokemon, customIds)
        installVisuals(data, pokemon, customIds)
        installTrainerVisuals(data)
        installTrades(game)

        state.species = assigned
        state.order = copy(customIds)
        state.nextIndex = nextIndex

        if #customIds == 0 then
            mod.log:info("Expanded Species %s ready; next virtual species ID is %d",
                VERSION, nextIndex)
        else
            mod.log:info("Expanded Species %s allocated %d custom species (%d-%d)",
                VERSION, #customIds, FIRST_CUSTOM_DEX, nextIndex - 1)
        end
        return #customIds
    end

    mod.exports.api_version = API_VERSION
    -- Legacy packs commonly compare api_version to 1 exactly. Keep that
    -- scalar stable for the entire 1.x contract and negotiate new features by
    -- capability. A future breaking facade can be added under getApi(2)
    -- without taking getApi(1) away from existing authors.
    mod.exports.latest_api_version = API_VERSION
    mod.exports.version = VERSION
    mod.exports.owns = {
        virtualSpeciesIndices = true,
        expandedSpeciesMetadata = true,
        customGen2PokedexRows = true,
        extendedEncounterWeights = true,
        scriptedSpeciesHelpers = true,
    }
    mod.exports.decorates = {
        vanillaTrainerParties = true,
    }

    function mod.exports.capabilities()
        return copy(CAPABILITIES)
    end

    function mod.exports.supports(name)
        return CAPABILITIES[name] == true
    end

    function mod.exports.supportsApi(version)
        return tonumber(version) == API_VERSION
    end

    function mod.exports.getApi(version)
        if mod.exports.supportsApi(version) then return mod.exports end
        return nil, "Expanded Species does not provide API " .. tostring(version)
    end

    function mod.exports.requireCapabilities(names)
        assert(type(names) == "table",
            "Expanded Species: capability requirements must be a list")
        local missing = {}
        for _, name in ipairs(names) do
            if not mod.exports.supports(name) then missing[#missing + 1] = name end
        end
        if #missing > 0 then
            return nil, "Expanded Species is missing capabilities: "
                .. table.concat(missing, ", ")
        end
        return mod.exports
    end

    function mod.exports.preflight(providerMod, definition)
        return speciesPreflight(providerMod, definition)
    end

    function mod.exports.register(providerMod, definition)
        local registry = providerMod
            and providerMod.content
            and providerMod.content.pokemon
        assert(type(registry) == "table" and type(registry.register) == "function",
            "Expanded Species: provider mod has no Pokemon content registry")

        local report = speciesPreflight(providerMod, definition)
        assert(report.ok, "Expanded Species: invalid species: "
            .. issueText(report.errors))
        local record = normalizeForRegistration(providerMod, report.definition)
        registry:register(record.id, record)
        return record
    end

    function mod.exports.registerAll(providerMod, definitions)
        assert(type(definitions) == "table",
            "Expanded Species: registerAll expects a list of definitions")
        local reports, seen = {}, {}
        for index, definition in ipairs(definitions) do
            local report = speciesPreflight(providerMod, definition)
            if type(definition) == "table" and type(definition.id) == "string" then
                if seen[definition.id] then
                    addIssue(report.errors, "id", "duplicates item "
                        .. tostring(seen[definition.id]) .. " in this batch")
                    report.ok = false
                else
                    seen[definition.id] = index
                end
            end
            reports[index] = report
        end
        local failures = {}
        for index, report in ipairs(reports) do
            if not report.ok then
                failures[#failures + 1] = ("item %d: %s")
                    :format(index, issueText(report.errors))
            end
        end
        assert(#failures == 0, "Expanded Species: batch preflight failed: "
            .. table.concat(failures, " | "))
        local registered = {}
        for index, report in ipairs(reports) do
            registered[index] = mod.exports.register(providerMod, report.definition)
        end
        return registered
    end

    function mod.exports.addGrassEncounter(providerMod, placement)
        return addEncounterPlacement(providerMod, placement, "grass")
    end

    function mod.exports.addWaterEncounter(providerMod, placement)
        return addEncounterPlacement(providerMod, placement, "water")
    end

    function mod.exports.givePokemon(speciesId, level, opts)
        return givePokemon(speciesId, level, opts)
    end

    function mod.exports.startWildBattle(speciesId, level, opts, onDone)
        return startWildBattle(speciesId, level, opts, onDone)
    end

    function mod.exports.registerGift(providerMod, spec)
        assert(type(spec) == "table", "Expanded Species: gift definition is required")
        assert(type(spec.species) == "string" and spec.species ~= "",
            "Expanded Species: gift species id is required")
        assert(isInteger(spec.level) and spec.level <= 100,
            "Expanded Species: gift level must be an integer from 1 to 100")
        return registerScriptHelper(providerMod, "gift", spec)
    end

    function mod.exports.registerStationaryEncounter(providerMod, spec)
        assert(type(spec) == "table",
            "Expanded Species: stationary definition is required")
        assert(type(spec.species) == "string" and spec.species ~= "",
            "Expanded Species: stationary species id is required")
        assert(isInteger(spec.level) and spec.level <= 100,
            "Expanded Species: stationary level must be an integer from 1 to 100")
        return registerScriptHelper(providerMod, "stationary", spec)
    end

    function mod.exports.registerTrainerEncounter(providerMod, spec)
        assert(type(spec) == "table",
            "Expanded Species: trainer definition is required")
        assert(type(spec.id) == "string" and spec.id ~= "",
            "Expanded Species: trainer helper id is required")
        assert(type(spec.party) == "table" and #spec.party > 0,
            "Expanded Species: trainer party must be a non-empty list")
        for index, member in ipairs(spec.party) do
            assert(type(member) == "table",
                "Expanded Species: trainer party row " .. index .. " must be a table")
            assert(type(member.species) == "string" and member.species ~= "",
                "Expanded Species: trainer party row " .. index .. " needs species")
            assert(isInteger(member.level) and member.level <= 100,
                "Expanded Species: trainer party row " .. index
                    .. " level must be 1 to 100")
        end
        local trainerType = spec.trainerType or "TRAINERTYPE_NORMAL"
        assert(TRAINER_TYPES[trainerType],
            "Expanded Species: unknown Gold trainerType " .. tostring(trainerType))
        local trainers = providerMod and providerMod.content
            and providerMod.content.trainers
        local commands = providerMod and providerMod.content
            and providerMod.content.commands
        assert(type(trainers) == "table" and type(trainers.register) == "function",
            "Expanded Species: provider mod has no trainers content registry")
        assert(type(commands) == "table" and type(commands.register) == "function",
            "Expanded Species: provider mod has no commands content registry")

        local classId = spec.classId
            or (providerMod.id .. "_" .. spec.id .. "_CLASS"):upper()
        local memberId = spec.memberId
            or (providerMod.id .. "_" .. spec.id):upper()
        local classRecord = {
            id = classId,
            name = spec.className or "TRAINER",
            pic = spec.pic,
            trueColor = spec.trueColor,
            baseMoney = spec.baseMoney or 30,
            encounterMusic = spec.encounterMusic,
            items = copy(spec.items or {}),
            attributes = copy(spec.attributes or {}),
            trainers = {
                {
                    id = memberId,
                    name = spec.trainerName or "CUSTOM",
                    trainerType = trainerType,
                    party = copy(spec.party),
                },
            },
        }
        trainers:register(classId, classRecord)
        local helper = copy(spec)
        helper.classId = classId
        helper.memberId = memberId
        local row = registerScriptHelper(providerMod, "trainer", helper)
        return row, classRecord
    end

    function mod.exports.patchVanillaTrainer(providerMod, spec)
        assert(type(providerMod) == "table" and type(providerMod.id) == "string"
            and providerMod.id ~= "",
            "Expanded Species: trainer patch provider mod is required")
        assert(type(spec) == "table",
            "Expanded Species: vanilla trainer patch is required")
        assert(type(spec.id) == "string" and spec.id ~= "",
            "Expanded Species: vanilla trainer patch id is required")
        local classId = spec.class or spec.classId
        local memberId = spec.member or spec.memberId
        assert(type(classId) == "string" and classId ~= "",
            "Expanded Species: vanilla trainer class id is required")
        assert(type(memberId) == "string" and memberId ~= "",
            "Expanded Species: vanilla trainer member id is required")
        assert(type(spec.changes) == "table" and #spec.changes > 0,
            "Expanded Species: vanilla trainer changes must be a non-empty list")

        local changes = {}
        for index, source in ipairs(spec.changes) do
            assert(type(source) == "table",
                "Expanded Species: trainer change " .. index .. " must be a table")
            local action = source.action or "insert"
            assert(action == "insert" or action == "append" or action == "replace",
                "Expanded Species: trainer change " .. index
                    .. " action must be insert, append or replace")
            if action ~= "append" then
                assert(isInteger(source.position),
                    "Expanded Species: trainer change " .. index
                        .. " position must be a positive integer")
            end
            assert(type(source.species) == "string" and source.species ~= "",
                "Expanded Species: trainer change " .. index .. " needs species")
            assert(isInteger(source.level) and source.level <= 100,
                "Expanded Species: trainer change " .. index
                    .. " level must be 1 to 100")
            if source.item ~= nil then
                assert(type(source.item) == "string" and source.item ~= "",
                    "Expanded Species: trainer change " .. index
                        .. " item must be a string id")
            end
            if source.moves ~= nil then
                assert(type(source.moves) == "table",
                    "Expanded Species: trainer change " .. index
                        .. " moves must be a list")
                for moveIndex, moveId in ipairs(source.moves) do
                    assert(type(moveId) == "string" and moveId ~= "",
                        "Expanded Species: trainer change " .. index .. " move "
                            .. moveIndex .. " must be a string id")
                end
            end
            changes[#changes + 1] = {
                action = action,
                position = action == "append" and nil or source.position,
                species = source.species,
                level = source.level,
                item = source.item,
                moves = copy(source.moves),
            }
        end

        local key = providerKey(providerMod, "vanilla_trainer", spec.id)
        assert(state.trainerPatches[key] == nil,
            "Expanded Species: duplicate vanilla trainer patch " .. spec.id)
        local record = {
            id = spec.id,
            provider = providerMod.id,
            class = classId,
            member = memberId,
            changes = changes,
        }
        state.trainerPatches[key] = record
        return copy(record)
    end

    function mod.exports.trainerPatches(classValue, memberValue)
        local classId, memberId = trainerTargetIds(classValue, memberValue)
        return copy(sortedTrainerPatches(classId, memberId))
    end

    function mod.exports.diagnoseTrainerPatches(classValue, memberValue)
        local errors, warnings = {}, {}
        local classId, memberId, class = trainerTargetIds(classValue, memberValue)
        local member
        if class then
            for _, row in ipairs(class.trainers or {}) do
                if row.id == memberId then member = row break end
            end
        end
        local game = liveGame()
        local data = game and game.data
        if data and not class then
            addIssue(errors, "class", "unknown trainer class " .. tostring(classId))
        elseif class and not member then
            addIssue(errors, "member", "unknown trainer member " .. tostring(memberId))
        elseif not data then
            addIssue(warnings, "runtime", "trainer data is not ready yet")
        end

        local patches = sortedTrainerPatches(classId, memberId)
        local size = member and #(member.party or {}) or nil
        local replacements = {}
        for _, patch in ipairs(patches) do
            for changeIndex, change in ipairs(patch.changes) do
                local path = patch.provider .. "/" .. patch.id
                    .. ".changes[" .. changeIndex .. "]"
                if data and data.pokemon and not data.pokemon[change.species] then
                    addIssue(errors, path .. ".species",
                        "unknown species " .. tostring(change.species))
                end
                if data and data.moves then
                    for moveIndex, moveId in ipairs(change.moves or {}) do
                        if not data.moves[moveId] then
                            addIssue(errors, path .. ".moves[" .. moveIndex .. "]",
                                "unknown move " .. tostring(moveId))
                        end
                    end
                end
                if change.item and data and data.items
                    and not data.items[change.item] then
                    addIssue(errors, path .. ".item",
                        "unknown item " .. tostring(change.item))
                end
                if size then
                    if change.action == "insert" then
                        if change.position > size + 1 then
                            addIssue(errors, path .. ".position",
                                "cannot insert at " .. change.position
                                    .. " when the composed party size is " .. size)
                        elseif size >= 6 then
                            addIssue(errors, path, "cannot exceed six Pokemon")
                        else
                            size = size + 1
                        end
                    elseif change.action == "append" then
                        if size >= 6 then
                            addIssue(errors, path, "cannot exceed six Pokemon")
                        else
                            size = size + 1
                        end
                    elseif change.position > size then
                        addIssue(errors, path .. ".position",
                            "cannot replace position " .. change.position
                                .. " when the composed party size is " .. size)
                    else
                        local claim = tostring(change.position)
                        if replacements[claim] then
                            addIssue(errors, path .. ".position",
                                "also replaced by " .. replacements[claim])
                        else
                            replacements[claim] = patch.provider .. "/" .. patch.id
                        end
                    end
                end
            end
        end
        return {
            ok = #errors == 0,
            class = classId,
            member = memberId,
            baseSize = member and #(member.party or {}) or nil,
            composedSize = size,
            patches = copy(patches),
            errors = errors,
            warnings = warnings,
        }
    end

    function mod.exports.registerTrade(providerMod, spec)
        assert(type(spec) == "table", "Expanded Species: trade definition is required")
        assert(type(spec.id) == "string" and spec.id ~= "",
            "Expanded Species: trade helper id is required")
        assert(type(spec.give) == "string" and spec.give ~= "",
            "Expanded Species: trade give species id is required")
        assert(type(spec.get) == "string" and spec.get ~= "",
            "Expanded Species: trade get species id is required")
        local gender = TRADE_GENDERS[spec.gender or "either"]
        assert(gender, "Expanded Species: trade gender must be either, male or female")
        local dvs
        if spec.shiny then
            dvs = { 0xea, 0xaa }
        elseif type(spec.dvs) == "table" and #spec.dvs >= 2 then
            dvs = { spec.dvs[1], spec.dvs[2] }
        elseif type(spec.dvs) == "table" then
            local attack = tonumber(spec.dvs.attack) or 9
            local defense = tonumber(spec.dvs.defense) or 8
            local speed = tonumber(spec.dvs.speed) or 8
            local special = tonumber(spec.dvs.special) or 8
            for name, value in pairs({ attack = attack, defense = defense,
                speed = speed, special = special }) do
                assert(value % 1 == 0 and value >= 0 and value <= 15,
                    "Expanded Species: trade DV " .. name .. " must be 0 to 15")
            end
            dvs = { attack * 16 + defense, speed * 16 + special }
        else
            dvs = { 0x98, 0x88 }
        end
        assert(type(dvs[1]) == "number" and dvs[1] % 1 == 0
            and dvs[1] >= 0 and dvs[1] <= 255
            and type(dvs[2]) == "number" and dvs[2] % 1 == 0
            and dvs[2] >= 0 and dvs[2] <= 255,
            "Expanded Species: trade dvs must be two bytes")

        local row, helper = registerScriptHelper(providerMod, "trade", spec)
        local key = providerKey(providerMod, "trade", helper.id)
        state.trades[key] = {
            provider = providerMod,
            spec = helper,
            row = {
                give = helper.give,
                get = helper.get,
                nickname = helper.nickname,
                dvs = dvs,
                item = helper.item,
                otName = helper.otName or "CUSTOM",
                otId = helper.otId or 0,
                gender = gender,
                dialog = helper.dialog or "EXPANDED_SPECIES",
            },
        }
        return row, copy(state.trades[key].row)
    end

    function mod.exports.virtualIndex(speciesId)
        return state.species[speciesId]
    end

    function mod.exports.all()
        return copy(state.order)
    end

    function mod.exports.nextIndex()
        return state.nextIndex
    end

    function mod.exports.owner(speciesId)
        local game = liveGame()
        local definition = game and game.data and game.data.pokemon
            and game.data.pokemon[speciesId]
        local marker = markerFor(definition)
        return marker and marker.provider or nil
    end

    function mod.exports.info(speciesId)
        local game = liveGame()
        local definition = game and game.data and game.data.pokemon
            and game.data.pokemon[speciesId]
        if not definition then return nil end
        local marker = markerFor(definition)
        return {
            id = speciesId,
            name = definition.name,
            dex = definition.dex,
            virtualIndex = state.species[speciesId],
            provider = marker and marker.provider or nil,
            custom = isCustomSpecies(definition),
            definition = copy(definition),
        }
    end

    function mod.exports.byProvider(provider)
        local wanted = type(provider) == "table" and provider.id or provider
        local out = {}
        for _, speciesId in ipairs(state.order) do
            if mod.exports.owner(speciesId) == wanted then out[#out + 1] = speciesId end
        end
        return out
    end

    function mod.exports.diagnose(speciesId)
        local errors, warnings = {}, {}
        local game = liveGame()
        local data = game and game.data
        local definition = data and data.pokemon and data.pokemon[speciesId]
        if not definition then
            addIssue(errors, "species", "is not present in the merged Gold registry")
            return { ok = false, id = speciesId, errors = errors, warnings = warnings }
        end
        if isCustomSpecies(definition) and not state.species[speciesId] then
            addIssue(errors, "virtualIndex", "was not allocated at game.ready")
        end
        if type(definition.spriteFront) ~= "string" then
            addIssue(errors, "spriteFront", "is missing")
        end
        if type(definition.spriteBack) ~= "string" then
            addIssue(errors, "spriteBack", "is missing")
        end
        local dex = data.gen2Pokedex and data.gen2Pokedex.entries
        if isCustomSpecies(definition) and not (dex and dex[speciesId]) then
            addIssue(errors, "pokedex", "custom entry is missing")
        end
        local icons = data.gen2Icons and data.gen2Icons.species
        if not (icons and icons[speciesId]) then
            addIssue(warnings, "icon", "no party/box icon is installed")
        end
        local palettes = data.gen2Palettes and data.gen2Palettes.pokemon
        if not definition.trueColor and not (palettes and palettes[speciesId]) then
            addIssue(warnings, "palette", "no normal/shiny palette is installed")
        end
        local cries = data.audio and data.audio.cries
        if not (cries and cries[speciesId]) then
            addIssue(warnings, "cry", "no cry is registered under the species id")
        end
        for index, evolution in ipairs(definition.evolutions or {}) do
            if not (data.pokemon and data.pokemon[evolution.into]) then
                addIssue(errors, "evolutions[" .. index .. "].into",
                    "unknown species " .. tostring(evolution.into))
            end
        end
        return {
            ok = #errors == 0,
            id = speciesId,
            errors = errors,
            warnings = warnings,
            info = mod.exports.info(speciesId),
        }
    end

    function mod.exports.helperComplete(providerMod, kind, id)
        return saveGet(providerMod, saveKey(kind, id), false) == true
    end

    function mod.exports.resetHelper(providerMod, kind, id)
        saveSet(providerMod, saveKey(kind, id), false)
        return true
    end


    mod.hooks:wrap("trainer.party", applyTrainerPatches)

    mod.hooks:wrap("encounter.roll", function(next_, tables, context)
        local rolled = next_(tables, context)
        if not rolled or type(tables) ~= "table" or type(context) ~= "table" then
            return rolled
        end

        local kind = context.terrain
        if kind ~= "grass" and kind ~= "water" then
            return rolled
        end
        local mapId = context.mapId
        if type(mapId) ~= "string" then
            return rolled
        end

        local time
        if kind == "grass" then
            time = context.daytime == "DARK" and "NITE"
                or (context.daytime or "DAY")
        end
        local pool = encounterPool(kind, mapId, time)
        if not pool or #pool == 0 then
            return rolled
        end

        local pokemon = context.data and context.data.pokemon
        return customEncounter(pool, context.rng, pokemon) or rolled
    end)

    mod.events:on("game.ready", function(context)
        reconcile(context and context.game or mod.game)
    end)

    mod.log:info("Expanded Species %s loaded", VERSION)
end
