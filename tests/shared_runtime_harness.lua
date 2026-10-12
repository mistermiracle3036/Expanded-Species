-- Shared species runtime harness (0.8.0, checker A-0079).
--
--   luajit tests/shared_runtime_harness.lua <engine root>
--
-- Loads main.lua several times in one process -- the framework and embedded
-- copies in other "host" mods -- over ONE event bus, ONE hook chain and the
-- engine's REAL content Registry (src/mods/Registry.lua), then checks:
--   * the election: framework always runs; otherwise highest version, ties
--     to the lowest host id; independent of load order
--   * exactly one copy acts on game.ready / save events; others pass through
--   * registerShared: absent -> register, identical -> shared, different ->
--     refused with a reason; a late rollback of one carrier keeps the species
--   * the save guardian writes save.modData.expanded_species, whoever runs
--   * an embedded copy's queries answer from the runner; its framework-only
--     helpers refuse
local engineRoot = assert(arg and arg[1], "engine root argument is required")
engineRoot = engineRoot:gsub("\\", "/"):gsub("/$", "")
package.path = engineRoot .. "/?.lua;" .. engineRoot .. "/?/init.lua;" .. package.path
love = love or {}

local Registry = require("src.mods.Registry")

local failures = 0
local function check(name, cond)
    if cond then
        print("PASS " .. name)
    else
        failures = failures + 1
        print("FAIL " .. name)
    end
end

local SOURCE = assert(io.open("main.lua", "rb")):read("*a")

local function world()
    local w = { listeners = {}, chains = {}, pokemon = Registry.new("pokemon", { semantics = "record" }),
                mods = {}, logs = {} }
    function w.emit(name, payload)
        for _, entry in ipairs(w.listeners[name] or {}) do entry.cb(payload) end
    end
    function w.callHook(name, vanilla, ...)
        local chain = w.chains[name] or {}
        local function step(i, ...)
            if i < 1 then return vanilla(...) end
            return chain[i](function(...) return step(i - 1, ...) end, ...)
        end
        return step(#chain, ...)
    end
    return w
end

-- One mod as the engine hands it to an entry chunk: events, hooks, log and a
-- content.pokemon handle stamped with its id (src/mods/Loader.lua:1240-1265).
local function makeMod(w, id)
    local m = { id = id, exports = {}, events = {}, hooks = {}, log = {} }
    function m.events:on(name, cb)
        w.listeners[name] = w.listeners[name] or {}
        table.insert(w.listeners[name], { owner = id, cb = cb })
    end
    function m.hooks:wrap(name, fn)
        w.chains[name] = w.chains[name] or {}
        table.insert(w.chains[name], fn)
    end
    for _, level in ipairs({ "info", "warn", "error" }) do
        m.log[level] = function(_, fmt, ...)
            table.insert(w.logs, { mod = id, text = string.format(fmt, ...) })
        end
    end
    m.content = { pokemon = {
        register = function(_, sid, v) return w.pokemon:register(sid, v, id) end,
        override = function(_, sid, v) return w.pokemon:override(sid, v, id) end,
        get = function(_, sid) return w.pokemon:get(sid) end,
    } }
    m.find = function(other)
        local o = w.mods[other]
        return o and { id = other, version = o.version, exports = o.exports } or nil
    end
    return m
end

-- load one copy; `embedded` false = the framework itself
local function loadCopy(w, id, embedded, version)
    local src = SOURCE
    if version then
        src = src:gsub('local VERSION = "[^"]+"', 'local VERSION = "' .. version .. '"', 1)
    end
    local init = assert(loadstring(src, "@main.lua"))()
    local m = makeMod(w, id)
    w.mods[id] = { version = version or "0.8.0", exports = m.exports }
    local api = init(m, embedded and { embedded = true } or nil)
    return m, (embedded and api or m.exports)
end

local function ralts(extra)
    local d = {
        id = "SHARED_RALTS", name = "RALTS", dex = 280,
        types = { "PSYCHIC", "PSYCHIC" },
        baseStats = { hp = 28, attack = 25, defense = 25, speed = 40,
                      specialAttack = 45, specialDefense = 35 },
        catchRate = 235, baseExp = 70, growthRate = "SLOW",
        levelMoves = { { level = 1, move = "GROWL" } },
        tmhm = {},
        spriteFront = "assets/species/ralts_front.png",
        spriteBack = "assets/species/ralts_back.png",
    }
    for k, v in pairs(extra or {}) do d[k] = v end
    return d
end

local function runnersOf(w, event)
    -- who acted on an event: a copy that runs logs from reconcile/guardian;
    -- we count the hosts whose game.ready produced a reconcile log line
    local hosts = {}
    for _, l in ipairs(w.logs) do
        if l.text:find("ready; next virtual") or l.text:find("allocated %d+ custom") then
            hosts[#hosts + 1] = l.mod
        end
    end
    return hosts
end

local function boot(w, game)
    w.logs = {}
    w.emit("mods.loaded", { data = game.data })
    w.emit("game.ready", { game = game })
end

local function fakeGame()
    return { data = { pokemon = {} }, save = { version = "crystal", modData = {} } }
end

-- ---------------------------------------------------------------------------
-- 1. Election
local cases = {
    { "framework installed always runs (loaded last)",
      { { "indigo_conference", true }, { "johto_quest_pack", true }, { "expanded_species", false } },
      "expanded_species" },
    { "framework installed always runs (loaded first)",
      { { "expanded_species", false }, { "johto_quest_pack", true }, { "indigo_conference", true } },
      "expanded_species" },
    { "no framework: lowest host id on a version tie",
      { { "johto_quest_pack", true }, { "indigo_conference", true } },
      "indigo_conference" },
    { "no framework: same answer in the other load order",
      { { "indigo_conference", true }, { "johto_quest_pack", true } },
      "indigo_conference" },
    { "no framework: the higher runtime version runs",
      { { "indigo_conference", true, "0.8.0" }, { "johto_quest_pack", true, "0.8.1" } },
      "johto_quest_pack" },
    { "framework runs even when an embedded copy is newer",
      { { "expanded_species", false, "0.8.0" }, { "johto_quest_pack", true, "0.9.0" } },
      "expanded_species" },
}
for _, c in ipairs(cases) do
    local w = world()
    for _, spec in ipairs(c[2]) do loadCopy(w, spec[1], spec[2], spec[3]) end
    local game = fakeGame()
    local ok, err = pcall(boot, w, game)
    local ran = runnersOf(w)
    check("election: " .. c[1] .. " -> " .. c[3],
        ok and #ran == 1 and ran[1] == c[3])
    if not ok then print("   boot error: " .. tostring(err)) end
    if ok and not (#ran == 1 and ran[1] == c[3]) then
        print("   ran: " .. table.concat(ran, ", "))
    end
end

-- ---------------------------------------------------------------------------
-- 2. registerShared + rollback
do
    local w = world()
    local ipc, ipcApi = loadCopy(w, "indigo_conference", true)
    local jqp, jqpApi = loadCopy(w, "johto_quest_pack", true)
    local rec1, how1 = ipcApi.registerShared(ipc, ralts())
    check("registerShared: first carrier registers", rec1 ~= nil and how1 == "registered")
    local rec2, how2 = jqpApi.registerShared(jqp, ralts({
        spriteFront = "assets/pokemon/ralts.png", spriteBack = "assets/pokemon/ralts_b.png" }))
    check("registerShared: identical data (own paths) is shared", rec2 ~= nil and how2 == "shared")
    check("one record for the species", w.pokemon:get("SHARED_RALTS") ~= nil)
    check("effective owner is the last carrier", w.pokemon.owners["SHARED_RALTS"] == "johto_quest_pack")
    w.pokemon:rollback("johto_quest_pack")
    check("late rollback of one carrier keeps the species (the other's op remains)",
        w.pokemon:get("SHARED_RALTS") ~= nil
        and w.pokemon.owners["SHARED_RALTS"] == "indigo_conference")
    local w2 = world()
    local a, aApi = loadCopy(w2, "indigo_conference", true)
    local b, bApi = loadCopy(w2, "johto_quest_pack", true)
    aApi.registerShared(a, ralts())
    local bad, why = bApi.registerShared(b, ralts({ catchRate = 120 }))
    check("different data is refused with a reason", bad == nil and type(why) == "string"
        and why:find("differs") ~= nil)
    check("...and the first copy is untouched", w2.pokemon:get("SHARED_RALTS").catchRate == 235
        and w2.pokemon.owners["SHARED_RALTS"] == "indigo_conference")
    local plainOk = pcall(bApi.register, b, ralts())
    check("plain register still refuses a duplicate (engine behaviour kept)", not plainOk)
end

-- ---------------------------------------------------------------------------
-- 3. Guardian namespace, pass-through hooks, delegation, embedded limits
do
    local w = world()
    local ipc, ipcApi = loadCopy(w, "indigo_conference", true)
    local jqp, jqpApi = loadCopy(w, "johto_quest_pack", true)
    local game = fakeGame()
    w.emit("mods.loaded", { data = game.data })
    -- the guardian needs the live game (liveGame(): game.ready sets it), so
    -- the save event under test is a write after game.ready
    w.emit("game.ready", { game = game })
    w.emit("save.writing", { save = game.save })
    check("guardian writes save.modData.expanded_species",
        type(game.save.modData.expanded_species) == "table")
    check("...and not the host's own namespace",
        game.save.modData.indigo_conference == nil and game.save.modData.johto_quest_pack == nil)
    local calls = 0
    local out = w.callHook("pokemon.sprite", function(path) calls = calls + 1; return path end,
        "assets/x.png", { species = "PIDGEY", data = game.data })
    check("hook chain reaches vanilla exactly once through two copies",
        calls == 1 and out == "assets/x.png")
    check("a non-runner's query answers from the runner",
        jqpApi.nextIndex() == ipcApi.nextIndex())
    local refused = not pcall(jqpApi.addGrassEncounter, jqp, {})
    check("embedded copy refuses framework-only helpers", refused)
    check("embedded copy reports those capabilities off",
        jqpApi.supports("gifts") == false and jqpApi.supports("sharedIdentity") == true)
    check("embedded copy does not take over the host's exports",
        next(jqp.exports) == nil and jqpApi.embedded == true)
end

print(failures == 0 and "ALL PASS" or (failures .. " FAILED"))
os.exit(failures == 0 and 0 or 1)
