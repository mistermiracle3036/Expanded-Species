local VERSION = "0.2.1"
local API_VERSION = 1
local FIRST_CUSTOM_DEX = 252
local BASE_ENCOUNTER_WEIGHT = 100
local GRASS_TIMES = { "MORN", "DAY", "NITE" }

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

local function normalizeForRegistration(providerMod, definition)
    assert(type(providerMod) == "table", "Expanded Species: provider mod is required")
    assert(type(providerMod.id) == "string" and providerMod.id ~= "",
        "Expanded Species: provider mod must have an id")
    assert(type(definition) == "table", "Expanded Species: species definition must be a table")
    assert(type(definition.id) == "string" and definition.id ~= "",
        "Expanded Species: species definition must have a string id")

    local record = copy(definition)
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
    }

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
    mod.exports.version = VERSION
    mod.exports.owns = {
        virtualSpeciesIndices = true,
        expandedSpeciesMetadata = true,
        customGen2PokedexRows = true,
        extendedEncounterWeights = true,
    }

    function mod.exports.register(providerMod, definition)
        local registry = providerMod
            and providerMod.content
            and providerMod.content.pokemon
        assert(type(registry) == "table" and type(registry.register) == "function",
            "Expanded Species: provider mod has no Pokemon content registry")

        local record = normalizeForRegistration(providerMod, definition)
        registry:register(record.id, record)
        return record
    end

    function mod.exports.addGrassEncounter(providerMod, placement)
        return addEncounterPlacement(providerMod, placement, "grass")
    end

    function mod.exports.addWaterEncounter(providerMod, placement)
        return addEncounterPlacement(providerMod, placement, "water")
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
