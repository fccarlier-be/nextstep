-- Simulation minimale de l'API du jeu pour tester l'addon hors de WoW.
-- Charge les addons à partir de leur fichier TOC, comme le client :
-- chaque fichier reçoit (nom de l'addon, espace de noms partagé).
--
--   local game = wow.boot({ faction = "Horde", locale = "frFR" })
--   game:fire("SOME_EVENT", ...)
--   game.chat, game.errors, game.loaded

local wow = {}

local ADDON_ROOT = "addon/"
local KNOWN_ADDONS = { "NextStep", "NextStep_Alliance", "NextStep_Horde" }

-- État global de référence, restauré entre deux tests.
local pristine = {}
for key, value in pairs(_G) do
    pristine[key] = value
end

function wow.reset()
    for key in pairs(_G) do
        if pristine[key] == nil then
            _G[key] = nil
        end
    end
    for key, value in pairs(pristine) do
        _G[key] = value
    end
end

local function parseToc(name)
    local path = ADDON_ROOT .. name .. "/" .. name .. ".toc"
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local toc = { metadata = {}, files = {} }
    for line in file:lines() do
        line = line:gsub("\r$", "")
        local key, value = line:match("^##%s*([^:]+):%s*(.-)%s*$")
        if key then
            toc.metadata[key] = value
        elseif line:match("%S") and not line:match("^#") then
            toc.files[#toc.files + 1] = (line:gsub("\\", "/"))
        end
    end
    file:close()
    return toc
end

-- Objet générique : toute méthode inconnue ne fait rien.
local function stub()
    return setmetatable({}, {
        __index = function()
            return function() end
        end,
    })
end

local Game = {}
Game.__index = Game

local function newFrame(game)
    local frame = { events = {}, scripts = {}, hooks = {} }
    function frame.RegisterEvent(self, event)
        self.events[event] = true
    end
    function frame.UnregisterEvent(self, event)
        self.events[event] = nil
    end
    function frame.IsEventRegistered(self, event)
        return self.events[event] == true
    end
    -- Comme dans le jeu, SetScript efface les fonctions ajoutées par HookScript.
    function frame.SetScript(self, name, fn)
        self.scripts[name] = fn
        self.hooks[name] = nil
    end
    function frame.GetScript(self, name)
        return self.scripts[name]
    end
    function frame.HookScript(self, name, fn)
        self.hooks[name] = self.hooks[name] or {}
        table.insert(self.hooks[name], fn)
    end
    function frame.SetChecked(self, checked)
        self.checked = checked and true or false
    end
    function frame.GetChecked(self)
        return self.checked
    end
    function frame.SetText(self, text)
        self.text = text
    end
    function frame.CreateTexture()
        return stub()
    end
    function frame.CreateFontString()
        local fontString = stub()
        rawset(fontString, "SetText", function(self, text)
            rawset(self, "text", text)
        end)
        return fontString
    end
    setmetatable(frame, getmetatable(stub()))
    game.frames[#game.frames + 1] = frame
    return frame
end

function Game:fire(event, ...)
    -- Copie : un gestionnaire peut créer des cadres pendant l'envoi.
    local frames = {}
    for i, frame in ipairs(self.frames) do
        frames[i] = frame
    end
    for _, frame in ipairs(frames) do
        if frame.events[event] and frame.scripts.OnEvent then
            frame.scripts.OnEvent(frame, event, ...)
        end
    end
end

-- Déclenche un script de cadre (OnShow, OnClick...) puis ses HookScript.
function Game:runScript(frame, name, ...)
    if frame.scripts[name] then
        frame.scripts[name](frame, ...)
    end
    for _, hook in ipairs(frame.hooks[name] or {}) do
        hook(frame, ...)
    end
end

-- Place une unité du jeu : game:setUnit("target", { guid = ..., name = ... }), ou nil.
function Game:setUnit(unit, info)
    self.units[unit] = info
end

function Game:isEventRegistered(event)
    for _, frame in ipairs(self.frames) do
        if frame.events[event] then
            return true
        end
    end
    return false
end

-- Charge un addon (fichiers du TOC) puis déclenche ADDON_LOADED.
function Game:loadAddOn(name)
    if self.loaded[name] then
        return true
    end
    local toc = self.tocs[name]
    if not toc then
        return false, "MISSING"
    end
    if self.disabled[name] then
        return false, "DISABLED"
    end
    local namespace = {}
    for _, file in ipairs(toc.files) do
        local chunk = assert(loadfile(ADDON_ROOT .. name .. "/" .. file))
        chunk(name, namespace)
    end
    self.loaded[name] = true
    self:fire("ADDON_LOADED", name)
    return true
end

-- Personnage simulé, lu par l'API (UnitLevel, C_QuestLog, UnitPosition...).
-- Quêtes : game:acceptQuest(q, { objectifs }), game:completeQuest(q), game:turnInQuest(q).
local function newPlayer(options)
    local player = {
        level = 1, xp = 0, maxXP = 400, race = "Human", class = "WARRIOR", money = 0,
        log = {},        -- liste { questID, complete, objectives = { { text, finished } } }
        done = {},       -- [quête] = true
        items = {},      -- [objet] = nombre
        spells = {},     -- [sort] = true
        position = nil,  -- { nord, ouest, instance }
        facing = 0,
        zone = "", subzone = "", bind = "",
    }
    for key, value in pairs(options or {}) do
        player[key] = value
    end
    return player
end

function Game:findQuest(q)
    for index, entry in ipairs(self.player.log) do
        if entry.questID == q then
            return entry, index
        end
    end
end

function Game:acceptQuest(q, objectives)
    self.player.log[#self.player.log + 1] = { questID = q, complete = false, objectives = objectives or {} }
    return self
end

function Game:completeQuest(q)
    local entry = self:findQuest(q)
    entry.complete = true
    for _, objective in ipairs(entry.objectives) do
        objective.finished = true
    end
    return self
end

function Game:turnInQuest(q)
    local _, index = self:findQuest(q)
    if index then
        table.remove(self.player.log, index)
    end
    self.player.done[q] = true
    return self
end

function Game:chatText()
    return table.concat(self.chat, "\n")
end

local function install(game, options)
    _G.CreateFrame = function()
        return newFrame(game)
    end
    _G.DEFAULT_CHAT_FRAME = {
        AddMessage = function(_, message)
            game.chat[#game.chat + 1] = message
        end,
    }
    _G.geterrorhandler = function()
        return function(err)
            game.errors[#game.errors + 1] = err
        end
    end
    _G.GetLocale = function()
        return game.locale
    end
    _G.UnitFactionGroup = function(unit)
        if unit == "player" then
            return game.faction, game.faction
        end
    end
    _G.InCombatLockdown = function()
        return game.inCombat
    end
    _G.UnitGUID = function(unit)
        return game.units[unit] and game.units[unit].guid
    end
    _G.UnitName = function(unit)
        return game.units[unit] and game.units[unit].name
    end
    _G.UNKNOWNOBJECT = "Unknown"

    -- Personnage
    local player = game.player
    _G.UnitLevel = function()
        return player.level
    end
    _G.UnitXP = function()
        return player.xp
    end
    _G.UnitXPMax = function()
        return player.maxXP
    end
    _G.UnitRace = function()
        return player.race, player.race
    end
    _G.UnitClass = function()
        return player.class, player.class
    end
    _G.GetMoney = function()
        return player.money
    end
    _G.C_QuestLog = {
        GetNumQuestLogEntries = function()
            return #player.log
        end,
        GetInfo = function(index)
            local entry = player.log[index]
            return entry and { questID = entry.questID, isHeader = false }
        end,
        IsComplete = function(q)
            local entry = game:findQuest(q)
            return entry ~= nil and entry.complete
        end,
        IsQuestFlaggedCompleted = function(q)
            return player.done[q] == true
        end,
        GetQuestObjectives = function(q)
            local entry = game:findQuest(q)
            return entry and entry.objectives
        end,
    }
    _G.C_Item = {
        GetItemCount = function(item)
            return player.items[item] or 0
        end,
    }
    _G.IsPlayerSpell = function(spell)
        return player.spells[spell] == true
    end
    _G.C_Map = {
        GetAreaInfo = function()
            return nil
        end,
        GetBestMapForUnit = function()
            return nil
        end,
    }
    _G.GetZoneText = function()
        return player.zone
    end
    _G.GetSubZoneText = function()
        return player.subzone
    end
    _G.GetMinimapZoneText = function()
        return player.subzone
    end
    _G.GetBindLocation = function()
        return player.bind
    end
    _G.UnitPosition = function()
        local position = player.position
        if position then
            return position[1], position[2], 0, position[3]
        end
    end
    _G.GetPlayerFacing = function()
        return player.facing
    end
    _G.hooksecurefunc = function(target, name, hook)
        local original = target[name]
        target[name] = function(...)
            original(...)
            hook(...)
        end
    end
    _G.SlashCmdList = {}
    _G.Settings = options.settings
    _G.C_AddOns = {
        GetAddOnMetadata = function(name, key)
            local toc = game.tocs[name]
            return toc and toc.metadata[key]
        end,
        IsAddOnLoaded = function(name)
            return game.loaded[name] == true
        end,
        LoadAddOn = function(name)
            return game:loadAddOn(name)
        end,
    }
end

-- options :
--   faction    ("Alliance", "Horde", "Neutral"), locale ("enUS", "frFR")
--   saved      { NextStepDB = ..., NextStepCharDB = ... } : sauvegardes d'une session précédente
--   loaded     { "Bagnon", ... } : autres addons déjà chargés
--   disabled   { NextStep_Horde = true, ... } : addons désactivés dans la liste des addons
--   beforeInit function(ns) : appelée après le chargement des fichiers, avant ADDON_LOADED
--   login      false pour ne pas déclencher PLAYER_LOGIN
--   player     { level = 5, class = "MAGE", position = { nord, ouest, instance }, ... } : personnage
--   metadata   { NextStep = { Version = "v0.1.0" }, ... } : remplace des métadonnées des TOC
function wow.boot(options)
    options = options or {}
    wow.reset()

    local game = setmetatable({
        frames = {},
        chat = {},
        errors = {},
        loaded = {},
        tocs = {},
        disabled = options.disabled or {},
        locale = options.locale or "enUS",
        faction = options.faction or "Alliance",
        units = {},
        inCombat = false,
        player = newPlayer(options.player),
    }, Game)
    for _, name in ipairs(KNOWN_ADDONS) do
        game.tocs[name] = parseToc(name)
        for key, value in pairs((options.metadata or {})[name] or {}) do
            game.tocs[name].metadata[key] = value
        end
    end
    for _, name in ipairs(options.loaded or {}) do
        game.loaded[name] = true
    end
    install(game, options)

    for key, value in pairs(options.saved or {}) do
        _G[key] = value
    end

    -- Chargement du cœur sans ADDON_LOADED, pour laisser beforeInit agir.
    local namespace = {}
    for _, file in ipairs(game.tocs.NextStep.files) do
        local chunk = assert(loadfile(ADDON_ROOT .. "NextStep/" .. file))
        chunk("NextStep", namespace)
    end
    game.ns = namespace
    if options.beforeInit then
        options.beforeInit(namespace)
    end
    game.loaded.NextStep = true
    game:fire("ADDON_LOADED", "NextStep")
    if options.login ~= false then
        game:fire("PLAYER_LOGIN")
    end
    return game
end

-- Sauvegardes telles que le jeu les écrirait en fin de session.
function wow.saved()
    return { NextStepDB = _G.NextStepDB, NextStepCharDB = _G.NextStepCharDB }
end

return wow
