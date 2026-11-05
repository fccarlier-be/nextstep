-- Module Guide en jeu : état réel du joueur, recalcul sur les événements,
-- validations automatiques, cible de la flèche, suivi de quêtes Blizzard masqué.
--
-- Validations automatiques (objectifs « à valider » de l'étape courante, des
-- objectifs en chemin et du mode libre) :
--   talk      dialogue ouvert avec le PNJ (bavardage, quête) ;
--   vendor    marchand ouvert (le PNJ indiqué, ou n'importe lequel) ;
--   train     maître ouvert (un des maîtres proposés par le guide) ;
--   getfp     carte des vols ouverte (point de vol sans identifiant) ;
--   cast      sort lancé par le joueur.

local _, ns = ...

local Guide = ns.Modules:Get("Guide")
local Engine, Navigation = ns.GuideEngine, ns.Navigation

local REFRESH_DELAY = 0.1   -- secondes : regroupe les rafales d'événements
local POSITION_PERIOD = 1   -- secondes : arrivée aux points de passage, cible la plus proche

local OPEN = { todo = true, manual = true, blocked = true }
local NEEDS_POSITION = { ["goto"] = true, explore = true }

-- Événements où un PNJ (unité « npc ») ouvre une fenêtre : type d'objectif validé.
local NPC_EVENTS = {
    GOSSIP_SHOW = "talk",
    QUEST_GREETING = "talk",
    QUEST_DETAIL = "talk",
    QUEST_PROGRESS = "talk",
    QUEST_COMPLETE = "talk",
    MERCHANT_SHOW = "vendor",
    TRAINER_SHOW = "train",
}

function Guide:OnEnable()
    self.live = self.live or ns.GuideState.New(self.char.taxi)
    if not self.state then
        self:SetState(self.live)
    end

    for event in pairs(ns.GuideState.EVENTS) do
        self:RegisterEvent(event, function(_, _, ...)
            self.live:OnEvent(event, ...)
            self:RequestRefresh()
        end)
    end
    for event, kind in pairs(NPC_EVENTS) do
        self:RegisterEvent(event, function()
            self:OnNpcWindow(kind, ns.NpcID(UnitGUID("npc")))
        end)
    end
    self:RegisterEvent("TAXIMAP_OPENED", function()
        local map = GetTaxiMapID and GetTaxiMapID() or C_Map.GetBestMapForUnit("player")
        if map then
            self.live:RecordTaxi(map)
        end
        self:OnNpcWindow("getfp", ns.NpcID(UnitGUID("npc")))
    end)
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, _, unit, _, spell)
        if unit == "player" and ns.Usable(spell) then
            self:Validate(function(goal)
                return goal.t == "cast" and goal.spell == spell
            end)
        end
    end)

    if C_Timer and C_Timer.NewTicker then
        self.ticker = C_Timer.NewTicker(POSITION_PERIOD, function()
            self:OnTick()
        end)
    end
    self:CreateInterface()
    self:Refresh()
end

function Guide:OnDisable()
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    self.result = nil
    self.target = nil
    self:HideInterface()
    self:UpdateTracker()
end

-- Recalcul différé : plusieurs événements de suite ne coûtent qu'un calcul.
function Guide:RequestRefresh()
    if not self.enabled then
        return
    end
    if not (C_Timer and C_Timer.After) then
        self:Refresh()
        return
    end
    if self.refreshPending then
        return
    end
    self.refreshPending = true
    C_Timer.After(REFRESH_DELAY, function()
        self.refreshPending = false
        if self.enabled then
            self:Refresh()
        end
    end)
end

function Guide:OnTick()
    local result = self.result
    if not result then
        return
    end
    if result.needsPosition then
        self:Refresh()
    elseif result.target and result.target.choices > 1 then
        -- Plusieurs points possibles (zones de mobs, maîtres) : le plus proche change.
        result.target = self:FindTarget(result)
        self:SendMessage("NEXTSTEP_TARGET_UPDATED", result.target)
    end
end

---------------------------------------------------------------------------
-- Objectifs ouverts et validations
---------------------------------------------------------------------------

-- Objectifs encore à faire, dans l'ordre d'affichage : { step, goal, status }.
-- Mode strict : étape courante puis objectifs en chemin ; mode libre : liste libre.
function Guide:OpenGoals(result)
    result = result or self.result
    local list = {}
    if not (result and result.current) then
        return list
    end
    if result.mode == "free" then
        for _, entry in ipairs(result.free) do
            list[#list + 1] = entry
        end
    else
        local i = result.current
        for j, goal in ipairs(result.guide.steps[i].goals) do
            local status = result.steps[i].goals and result.steps[i].goals[j].status
            if OPEN[status] then
                list[#list + 1] = { step = i, goal = j, status = status, optional = goal.optional }
            end
        end
    end
    for _, entry in ipairs(result.along) do
        list[#list + 1] = entry
    end
    return list
end

-- Valide pour la session les objectifs « à valider » ouverts qui répondent à match(goal).
function Guide:Validate(match)
    local result = self.result
    if not (result and result.current) then
        return false
    end
    local guide = result.guide
    local keys = Engine.Keys(guide)
    local seen = self.seen[guide.id] or {}
    local changed = false
    for _, entry in ipairs(self:OpenGoals(result)) do
        local goal = guide.steps[entry.step].goals[entry.goal]
        if entry.status == "manual" and match(goal, guide) then
            seen[keys.goals[entry.step][entry.goal]] = true
            changed = true
        end
    end
    if changed then
        self.seen[guide.id] = seen
        self:Refresh()
    end
    return changed
end

local function isCandidate(goal, guide, npc)
    for _, index in ipairs(goal.candidates or {}) do
        local entry = guide.pool and guide.pool[index]
        if entry and entry.npc == npc then
            return true
        end
    end
    return false
end

-- Le PNJ est-il un maître de classe ? D'après le client (un maître de métier
-- répond vrai à IsTradeskillTrainer), sinon d'après les maîtres de classe du guide.
local function classTrainer(guide, npc)
    if IsTradeskillTrainer then
        return not IsTradeskillTrainer()
    end
    for _, entry in ipairs(guide and guide.pool or {}) do
        if entry.npc == npc and entry.classes then
            return true
        end
    end
    return false
end

-- Une fenêtre de PNJ s'ouvre (dialogue, marchand, maître, vols).
function Guide:OnNpcWindow(kind, npc)
    if kind == "train" and classTrainer(self:ActiveGuide(), npc) then
        -- Retenu d'une session à l'autre : l'étape « maître de classe » ne renvoie
        -- pas chez le maître tant qu'il n'y a rien de nouveau à apprendre.
        self.char.trainedLevel = (self.state and self.state:Level()) or self.char.trainedLevel
    end
    self:Validate(function(goal, guide)
        if goal.t ~= kind then
            return false
        end
        if kind == "talk" then
            return npc ~= nil and goal.npc == npc
        elseif kind == "vendor" then
            return goal.npc == nil or goal.npc == npc
        elseif kind == "train" then
            if goal.npc then
                return goal.npc == npc
            end
            return not goal.candidates or isCandidate(goal, guide, npc)
        elseif kind == "getfp" then
            return goal.node == nil and (goal.npc == nil or goal.npc == npc)
        end
        return false
    end)
end

---------------------------------------------------------------------------
-- Cible de la flèche
---------------------------------------------------------------------------

local FACTIONS = { A = { Alliance = true }, H = { Horde = true }, AH = { Alliance = true, Horde = true } }

local function contains(list, value)
    for _, item in ipairs(list or {}) do
        if item == value then
            return true
        end
    end
    return false
end

-- Points possibles d'un objectif : sa position, les maîtres proposés au personnage,
-- les zones d'apparition des mobs. kind : "place" (position, maître) ou "zone".
local function pointsOf(goal, guide, state)
    local points = {}
    if goal.map and goal.x and goal.y then
        points[#points + 1] = { map = goal.map, x = goal.x, y = goal.y, f = goal.f, kind = "place" }
    end
    for _, index in ipairs(goal.candidates or {}) do
        local entry = guide.pool and guide.pool[index]
        if entry and entry.map
            and (not entry.classes or contains(entry.classes, state:Class()))
            and (not entry.faction or (FACTIONS[entry.faction] or {})[state:Faction()]) then
            points[#points + 1] = { map = entry.map, x = entry.x, y = entry.y, f = entry.f, npc = entry.npc,
                kind = "place" }
        end
    end
    for _, spot in ipairs(Navigation.Spots(goal) or {}) do
        points[#points + 1] = { map = goal.map, x = spot.x, y = spot.y, f = goal.f, kind = "zone" }
    end
    return points
end

-- Points d'un objectif, pour les repères de la carte et de la minimap.
function Guide:GoalPoints(goal, guide)
    return pointsOf(goal, guide, self.state)
end

-- Point le plus proche (le premier si aucune distance n'est connue).
local function nearest(points)
    local best, bestDistance
    for _, point in ipairs(points) do
        local distance = Navigation.DistanceTo(point.map, point.x, point.y, point.f)
        if distance and (not bestDistance or distance < bestDistance) then
            best, bestDistance = point, distance
        end
    end
    return best or points[1], bestDistance
end

-- Libellé d'un objectif pour la flèche et la carte. Un déplacement dit pourquoi on
-- y va : le premier objectif suivant de l'étape encore à faire (« Aller à
-- Comté-de-l'Or, pour : Aller voir votre maître de classe »).
local SETTLED = { done = true, na = true, info = true }

function Guide:GoalLabel(result, i, j)
    local guide = result.guide
    local goals = guide.steps[i].goals
    local text = ns.GuideLabels.Goal(goals[j], guide, self.state)
    if not ns.GuideGoals.TRAVEL[goals[j].t] then
        return text
    end
    local statuses = result.steps[i] and result.steps[i].goals or {}
    for k = j + 1, #goals do
        local status = statuses[k] and statuses[k].status
        if not ns.GuideGoals.TRAVEL[goals[k].t] and not SETTLED[status] then
            return ns.L["%s, for: %s"]:format(text, ns.GuideLabels.Goal(goals[k], guide, self.state))
        end
    end
    return text
end

-- Point le plus proche parmi des objectifs ouverts : { step, goal, choices, ... }, où
-- choices compte tous les points possibles (plus d'un : la cible change en route).
local function nearestGoal(entries, guide, state)
    local best, total = nil, 0
    for _, entry in ipairs(entries) do
        local points = pointsOf(guide.steps[entry.step].goals[entry.goal], guide, state)
        if #points > 0 then
            total = total + #points
            local point, distance = nearest(points)
            if not best or (distance and (not best.distance or distance < best.distance)) then
                best = {
                    step = entry.step, goal = entry.goal,
                    map = point.map, x = point.x, y = point.y, f = point.f, distance = distance,
                }
            end
        end
    end
    if best then
        best.choices = total
    end
    return best
end

-- Cible : mode strict, l'objectif ouvert le plus proche de l'étape courante (les
-- objectifs facultatifs seulement s'il ne reste qu'eux), puis les objectifs en
-- chemin ; mode libre, le plus proche de tous.
function Guide:FindTarget(result)
    if not (result and result.current) then
        return nil
    end
    local guide, state = result.guide, self.state
    local open = self:OpenGoals(result)
    if result.mode == "free" then
        local best = nearestGoal(open, guide, state)
        if best then
            best.choices = math.max(best.choices, 2)   -- en mode libre, la plus proche change
        end
        return best
    end
    local required, optional, along = {}, {}, {}
    for _, entry in ipairs(open) do
        if entry.step ~= result.current then
            along[#along + 1] = entry
        elseif entry.optional then
            optional[#optional + 1] = entry
        else
            required[#required + 1] = entry
        end
    end
    return nearestGoal(required, guide, state) or nearestGoal(optional, guide, state)
        or nearestGoal(along, guide, state)
end

-- Appelé par Guide:Refresh avant l'envoi du résultat.
function Guide:Decorate(result)
    local needsPosition = false
    for _, entry in ipairs(self:OpenGoals(result)) do
        if NEEDS_POSITION[result.guide.steps[entry.step].goals[entry.goal].t] then
            needsPosition = true
        end
    end
    result.needsPosition = needsPosition
    result.ready = self.state:Ready() ~= false
    result.target = self:FindTarget(result)
    self:UpdateTracker()
end

---------------------------------------------------------------------------
-- Suivi de quêtes Blizzard : masqué quand un guide est suivi
---------------------------------------------------------------------------

-- [À vérifier] sur Forever : nom du cadre (ObjectiveTrackerFrame sur le client
-- moderne, QuestWatchFrame sur l'ancien) et masquage sans souillure.
local function trackerFrame()
    return ObjectiveTrackerFrame or QuestWatchFrame
end

function Guide:UpdateTracker()
    local frame = trackerFrame()
    if not frame then
        return
    end
    local hide = self.enabled and self.db.hideTracker and self.char.active ~= nil
    if InCombatLockdown() and frame:IsProtected() then
        if not self.trackerPending then
            self.trackerPending = true
            self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                self.trackerPending = nil
                self:UpdateTracker()
            end)
        end
        return
    end
    if not self.trackerHooked then
        hooksecurefunc(frame, "Show", function(shown)
            if self.trackerHidden then
                shown:Hide()
            end
        end)
        self.trackerHooked = true
    end
    if hide and not self.trackerHidden then
        self.trackerHidden = true
        frame:Hide()
    elseif not hide and self.trackerHidden then
        self.trackerHidden = false
        frame:Show()
    end
end

---------------------------------------------------------------------------
-- Commandes, options, raccourcis
---------------------------------------------------------------------------

-- Libellés du menu Raccourcis (Bindings.xml).
BINDING_NAME_NEXTSTEP_GUIDE = ns.L["Show or hide the guide window"]
BINDING_NAME_NEXTSTEP_ARROW = ns.L["Show or hide the arrow"]
BINDING_NAME_NEXTSTEP_DONE = ns.L["Mark the current step as done"]

local SUBCOMMANDS = {}

function SUBCOMMANDS.list(self)
    local list = self:Suggest()
    if #list == 0 then
        ns:Print(ns.L["No leveling guide for your level."])
        return
    end
    ns:Print(ns.L["Guides for your character:"])
    for index, guide in ipairs(list) do
        local line = ("  %d. %s |cffa0a0a0(%s)|r"):format(index, ns.GuideLabels.Guide(guide), guide.id)
        DEFAULT_CHAT_FRAME:AddMessage(line)
    end
end

function SUBCOMMANDS.start(self, argument)
    local guide = ns.DB:GetGuide(argument)
    if not guide then
        guide = self:Suggest()[tonumber(argument) or 1]
    end
    if not guide then
        ns:Print(ns.L["Unknown guide: %s"]:format(argument))
        return
    end
    self:Start(guide.id)
    self:SetWindowShown(true)
end

function SUBCOMMANDS.stop(self)
    self:Stop()
end

function SUBCOMMANDS.reset(self)
    self:Reset()
    ns:Print(ns.L["Progress of the guide reset."])
end

function SUBCOMMANDS.skip(self)
    local result = self.result
    if result and result.current then
        self:Skip(result.current)
    end
end

function SUBCOMMANDS.done(self)
    self:ValidateCurrent()
end

function SUBCOMMANDS.mode(self)
    self:SetMode(self.char.mode == "free" and "strict" or "free")
end

-- /ns debug : état du guide et de sa fenêtre, pour diagnostiquer en jeu sans /run.
-- Texte technique, non traduit.
function Guide:PrintDebug()
    local function out(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring((select(i, ...)))
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99NS debug|r " .. table.concat(parts, " "))
    end
    local function try(label, fn)
        local ok, a, b, c = pcall(fn)
        if ok then
            out(label, a, b, c)
        else
            out(label, "ERREUR", a)
        end
    end
    out("version", ns.version, "module", self.enabled, "actif", self.char and self.char.active)
    local refused = {}
    for event in pairs(ns.Events.refused) do
        refused[#refused + 1] = event
    end
    table.sort(refused)
    out("événements refusés", #refused > 0 and table.concat(refused, ", ") or "aucun")
    out("écoute QUEST_LOG_UPDATE", ns.Events:IsListening("QUEST_LOG_UPDATE"),
        "PLAYER_ENTERING_WORLD", ns.Events:IsListening("PLAYER_ENTERING_WORLD"))
    local live = self.live
    out("état réel", live ~= nil, "état utilisé = réel", self.state == live)
    if live then
        try("prêt", function() return live:Ready(), "questsSeen", live.questsSeen end)
        try("niveau/race/classe", function() return live:Level(), live:Race(), live:Class() end)
        try("faction", function() return live:Faction() end)
        try("cartes", function()
            local list = {}
            for map in pairs(live:Maps()) do
                list[#list + 1] = map
            end
            return table.concat(list, ",")
        end)
        try("quêtes du journal", function() return #live:LogQuests() end)
        try("quête 783 rendue", function() return live:TurnedIn(783) end)
    end
    try("suggestions", function()
        local list = self:Suggest()
        return #list, list[1] and list[1].id
    end)
    local result = self.result
    out("résultat", result ~= nil, "prêt", result and result.ready, "étape", result and result.current)
    out("repères", self.pinPoints and #self.pinPoints, "minimap", self.minimapPins ~= nil,
        "carte du monde", self.mapProvider ~= nil,
        "rayon minimap", Minimap and Minimap.GetViewRadius and Minimap:GetViewRadius())
    local frame = self.window
    if not frame then
        out("fenêtre absente")
        return
    end
    out("fenêtre", frame:IsShown(), frame:IsVisible(), "hauteur", frame:GetHeight(),
        "échelle", frame:GetEffectiveScale())
    out("corps", frame.body:IsShown(), frame.body:IsVisible(), frame.body:GetWidth(), frame.body:GetHeight())
    out("textes", self.windowTexts and #self.windowTexts, "lignes", #frame.lines)
    for i = 1, math.min(#frame.lines, 4) do
        local line = frame.lines[i]
        local _, _, _, a = line.text:GetTextColor()
        out("ligne", i, line:IsShown(), line:IsVisible(), line:GetHeight(), "alpha", line.text:GetAlpha(), a,
            "police", line.text:GetFont(), "texte", line.text:GetText())
    end
end

function Guide:AddCommands()
    ns.Slash:Add("guide", function(input)
        local name, argument = input:match("^(%S*)%s*(.-)$")
        local command = SUBCOMMANDS[(name or ""):lower()]
        if not self.enabled then
            ns:Print(ns.L["%s is disabled: enable it in the options."]:format(self.title))
        elseif command then
            command(self, argument or "")
        elseif name == "" then
            self:ToggleWindow()
        else
            ns:Print(ns.L["Usage: /ns guide [list | start <number or id> | stop | reset | skip | done | mode]"])
        end
    end, ns.L["Show or hide the guide; /ns guide list, start, stop, reset, skip, done, mode"])
    ns.Slash:Add("arrow", function()
        self:SetArrowShown(not self.db.arrow)
    end, ns.L["Show or hide the arrow"])
    ns.Slash:Add("spells", function()
        self:PrintSpells()
    end, ns.L["List the spells to learn at your class trainer"])
    ns.Slash:Add("debug", function()
        self:PrintDebug()
    end, ns.L["Show debugging information"])
end

function Guide:BuildOptions(panel, anchor)
    local Options = ns.Options
    local arrow = Options.AddCheck(panel, anchor, ns.L["Show the arrow"],
        function() return self.db.arrow end,
        function(value) self:SetArrowShown(value) end)
    local tracker = Options.AddCheck(panel, arrow, ns.L["Hide the Blizzard quest tracker while following a guide"],
        function() return self.db.hideTracker end,
        function(value)
            self.db.hideTracker = value
            self:UpdateTracker()
        end)
    local minimap = Options.AddCheck(panel, tracker, ns.L["Show the step's points on the minimap"],
        function() return self.db.minimapPins end,
        function(value) self:SetMinimapPinsShown(value) end)
    local map = Options.AddCheck(panel, minimap, ns.L["Show the step's points on the world map"],
        function() return self.db.mapPins end,
        function(value) self:SetMapPinsShown(value) end)
    local locked = Options.AddCheck(panel, map, ns.L["Lock the guide window"],
        function() return self.db.window.locked end,
        function(value) self:SetWindowLocked(value) end)
    return locked
end
