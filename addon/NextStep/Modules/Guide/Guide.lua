-- Module Guide : guide actif, progression sauvegardée du personnage et
-- recalcul par le moteur. L'interface (Window.lua, Arrow.lua) affiche self.result
-- et écoute le message NEXTSTEP_GUIDE_UPDATED (result, nil sans guide suivi).
--
-- L'état du joueur est fourni par SetState : l'API du jeu en jeu (State.lua, mis
-- en place par Live.lua), une simulation dans les tests.

local _, ns = ...
local L = ns.L

local Engine = ns.GuideEngine

local Guide = ns.Modules:New("Guide", {
    title = L["Leveling guide"],
    description = L["Step-by-step guide for your race, class and level, which accepts detours."],
    defaults = {
        window = {
            shown = true,
            collapsed = false,  -- réduite à la ligne de titre
            locked = false,
            scale = 1,
            point = nil,        -- { point, point relatif, x, y } : position mémorisée
        },
        arrow = true,
        minimapPins = true,     -- points de l'étape sur la minimap
        mapPins = true,         -- points de l'étape sur la carte du monde
        hideTracker = true,     -- masque le suivi de quêtes Blizzard quand un guide est suivi
        celebration = true,     -- bandeau à chaque niveau gagné (Celebration.lua)
        celebrationSound = true,
    },
    charDefaults = {
        taxi = {},         -- [point de vol] = true : points connus (relevés à la carte des vols)
        active = nil,      -- identifiant du guide suivi
        mode = "strict",   -- "strict" : une étape à la fois ; "free" : les objectifs du même endroit
        progress = {},     -- [identifiant du guide] = progression (Engine.NewProgress)
        answers = {},      -- [quête de groupe] = true (la faire) / false (la passer)
        dungeons = {},     -- [nom du donjon] = true : donjons choisis
        completed = {},    -- [identifiant du guide] = true : guides terminés
        returnTo = nil,    -- guide de leveling à reprendre après un guide annexe (classe, collection...)
        ignoredQuests = {}, -- [quête] = true : ignorée par le joueur, dans tous les guides
        notOffered = {},    -- [quête] = niveau : le PNJ ne la proposait pas (Live.lua, ReadOffers)
        trainedLevel = nil, -- niveau du personnage à sa dernière visite au maître de classe
        trainerList = nil,  -- { level, spells, total } : sorts disponibles lus chez le maître (Spells.lua)
    },
})

function Guide:OnInitialize()
    self:AddCommands()
    self.seen = {}   -- [identifiant du guide] = { [clé d'objectif] = true } : session
    -- Guide remplacé dans Polestar : on n'y reste pas. (Un guide absent n'est pas
    -- forcément disparu : les guides de faction ne sont chargés qu'à la connexion.)
    local active = self.char.active
    if active and ns.DB.retired[active] then
        self.char.active = nil
    end
end

function Guide:SetState(state)
    self.state = state
end

function Guide:ActiveGuide()
    return self.char.active and ns.DB:GetGuide(self.char.active)
end

function Guide:Progress(id)
    local progress = self.char.progress[id]
    if not progress then
        progress = Engine.NewProgress()
        self.char.progress[id] = progress
    end
    return progress
end

-- Quêtes refusées par leur PNJ à ce niveau : [quête] = true. Un niveau de plus peut les
-- débloquer, les refus d'un autre niveau sont oubliés.
function Guide:NotOffered()
    local list, level = {}, self.state and self.state:Level()
    for q, at in pairs(self.char.notOffered or {}) do
        if at == level then
            list[q] = true
        else
            self.char.notOffered[q] = nil
        end
    end
    return list
end

function Guide:Refresh()
    local guide = self:ActiveGuide()
    if not guide or not self.state then
        self.result = nil
        if self.UpdateTracker then
            self:UpdateTracker()
        end
        self:SendMessage("NEXTSTEP_GUIDE_UPDATED", nil)
        return nil
    end
    local progress = self:Progress(guide.id)
    local result = Engine.Evaluate(guide, {
        notOffered = self:NotOffered(),
        state = self.state,
        progress = progress,
        seen = self.seen[guide.id] or {},
        answers = self.char.answers,
        dungeons = self.char.dungeons,
        trainedLevel = self.char.trainedLevel,
        ignoredQuests = self.char.ignoredQuests,
        spellsToLearn = function()
            local list = self.SpellsToLearn and self:SpellsToLearn()
            return list and #list
        end,
    })
    -- Tant que le journal de quêtes n'est pas lu, rien n'est mémorisé.
    if self.state:Ready() ~= false then
        Engine.Commit(progress, result)
    end
    result.mode = self.char.mode
    if self.Decorate then
        self:Decorate(result)
    end
    if result.finished and result.ready ~= false and self.state:Ready() ~= false then
        self.char.completed[guide.id] = true
    end
    self.result = result
    self:SendMessage("NEXTSTEP_GUIDE_UPDATED", result)
    return result
end

function Guide:Start(id)
    assert(ns.DB:GetGuide(id), "NextStep: unknown guide " .. tostring(id))
    self.char.active = id
    return self:Refresh()
end

function Guide:Stop()
    self.char.active = nil
    return self:Refresh()
end

-- Guide terminé : continuer sur l'un des guides suivants.
function Guide:ChooseNext(id)
    local guide = self:ActiveGuide()
    for _, nextID in ipairs(guide and guide.next or {}) do
        if nextID == id then
            return self:Start(id)
        end
    end
    error("NextStep: " .. tostring(id) .. " is not a next guide of the active guide")
end

local function withActive(self, change)
    local guide = self:ActiveGuide()
    if guide then
        change(self:Progress(guide.id), guide)
    end
    return self:Refresh()
end

function Guide:Skip(step)
    return withActive(self, function(progress, guide)
        Engine.Remember(progress, guide, step, "skip")
        Engine.Skip(progress, guide, step)
    end)
end

-- Retour à l'étape précédente : annule le dernier « Passer l'étape » ou « Étape faite »
-- (clic de trop).
function Guide:CanGoBack()
    local guide = self:ActiveGuide()
    return guide ~= nil and Engine.CanGoBack(self:Progress(guide.id))
end

function Guide:Back()
    local guide = self:ActiveGuide()
    if not (guide and Engine.Back(self:Progress(guide.id))) then
        ns:Print(ns.L["Nothing to undo in this guide."])
        return self.result
    end
    return self:Refresh()
end

-- Ignore une quête partout (acceptation, objectifs, rendu), ou la reprend.
function Guide:IgnoreQuest(quest, ignored)
    self.char.ignoredQuests = self.char.ignoredQuests or {}
    self.char.ignoredQuests[quest] = ignored ~= false or nil
    if ignored == false then
        -- Reprise : les étapes de la quête passées à cause d'elle sont rouvertes.
        local guide = self:ActiveGuide()
        if guide then
            local progress = self:Progress(guide.id)
            for i, step in ipairs(guide.steps) do
                for _, goal in ipairs(step.goals) do
                    if goal.quest == quest then
                        Engine.Reopen(progress, guide, i)
                    end
                end
            end
        end
    end
    return self:Refresh()
end

function Guide:IgnoreGoal(step, goal, ignored)
    return withActive(self, function(progress, guide)
        Engine.IgnoreGoal(progress, guide, step, goal, ignored)
        if ignored == false then
            Engine.Reopen(progress, guide, step)
            -- Les étapes suivantes de la même quête aussi.
            local quest = guide.steps[step].goals[goal].quest
            for i, other in ipairs(guide.steps) do
                for _, g in ipairs(other.goals) do
                    if quest and g.quest == quest then
                        Engine.Reopen(progress, guide, i)
                    end
                end
            end
        end
    end)
end

function Guide:Unskip(step)
    return withActive(self, function(progress, guide)
        Engine.Unskip(progress, guide, step)
    end)
end

function Guide:Tick(step, goal)
    return withActive(self, function(progress, guide)
        Engine.Tick(progress, guide, step, goal)
    end)
end

function Guide:Reopen(step)
    return withActive(self, function(progress, guide)
        Engine.Reopen(progress, guide, step)
    end)
end

-- Un événement du jeu a accompli un objectif invisible autrement (PNJ parlé,
-- marchand visité, point atteint) : retenu pour la session.
function Guide:MarkSeen(step, goal)
    return withActive(self, function(_, guide)
        local seen = self.seen[guide.id] or {}
        self.seen[guide.id] = seen
        seen[Engine.Keys(guide).goals[step][goal]] = true
    end)
end

function Guide:Answer(quest, doIt)
    self.char.answers[quest] = doIt and true or false
    return self:Refresh()
end

function Guide:SetMode(mode)
    assert(mode == "strict" or mode == "free", "NextStep: unknown guide mode " .. tostring(mode))
    self.char.mode = mode
    return self:Refresh()
end

function Guide:Reset(id)
    id = id or self.char.active
    if id then
        self.char.progress[id] = nil
        self.seen[id] = nil
    end
    return self:Refresh()
end

local function contains(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

-- Guides de leveling adaptés au personnage : faction, classe et niveau. La race
-- n'exclut aucun guide (un elfe de la nuit peut commencer chez les humains).
-- Ordre : guide de la zone où se trouve le joueur, puis guides de sa race, guides
-- communs, guides des autres races ; à rang égal, par niveau croissant.
function Guide:Suggest(state)
    state = state or self.state
    local level, race = state:Level(), state:Race()
    local maps = state.Maps and state:Maps() or {}
    local rank = {}
    local list = {}
    for _, guide in ns.DB:IterateGuides() do
        if guide.category == "Leveling"
            and (not guide.faction or guide.faction == state:Faction())
            and (not guide.classes or contains(guide.classes, state:Class()))
            and (guide.minLevel or 1) <= level and level <= (guide.maxLevel or 60) then
            list[#list + 1] = guide
            if guide.zone and maps[guide.zone] then
                rank[guide] = 1
            elseif guide.races and contains(guide.races, race) then
                rank[guide] = 2
            elseif not guide.races then
                rank[guide] = 3
            else
                rank[guide] = 4
            end
        end
    end
    table.sort(list, function(a, b)
        if rank[a] ~= rank[b] then
            return rank[a] < rank[b]
        end
        if (a.minLevel or 1) ~= (b.minLevel or 1) then
            return (a.minLevel or 1) < (b.minLevel or 1)
        end
        return a.id < b.id
    end)
    return list
end

-- Quêtes de classe à faire (guides de la catégorie Class) : classe, faction et race
-- du personnage, à partir de leur niveau minimal et jusqu'à 5 niveaux au-delà du
-- maximal. Une quête est faite quand son guide est terminé, ou quand le personnage
-- connaît déjà les sorts qu'elle apprend (reward).
local CLASS_LEVEL_MARGIN = 5

local function rewardKnown(guide, state)
    local any = false
    for _, reward in ipairs(guide.reward or {}) do
        if reward.spell then
            any = true
            if not state:Knows(reward.spell) then
                return false
            end
        end
    end
    return any
end

function Guide:ClassGuides(state)
    state = state or self.state
    local list = {}
    if not state then
        return list
    end
    local level, race, class = state:Level(), state:Race(), state:Class()
    for _, guide in ns.DB:IterateGuides() do
        if guide.category == "Class"
            and guide.id ~= self.char.active
            and not self.char.completed[guide.id]
            and (not guide.faction or guide.faction == state:Faction())
            and (not guide.classes or contains(guide.classes, class))
            and (not guide.races or contains(guide.races, race))
            and (guide.minLevel or 1) <= level
            and level <= (guide.maxLevel or 60) + CLASS_LEVEL_MARGIN
            and not rewardKnown(guide, state) then
            list[#list + 1] = guide
        end
    end
    table.sort(list, function(a, b)
        if (a.minLevel or 1) ~= (b.minLevel or 1) then
            return (a.minLevel or 1) < (b.minLevel or 1)
        end
        return a.id < b.id
    end)
    return list
end

-- Commence un guide annexe (quête de classe, collection, réputation, métier...) : le
-- guide de leveling suivi sera repris à la fin, ou plus tôt d'un clic dans la fenêtre.
-- Un guide de leveling, lui, remplace simplement le précédent.
function Guide:StartSideGuide(id)
    local guide = ns.DB:GetGuide(id)
    local current = self:ActiveGuide()
    if guide and guide.category == "Leveling" then
        self.char.returnTo = nil
    elseif current and current.category == "Leveling" and current.id ~= id then
        self.char.returnTo = current.id
    end
    return self:Start(id)
end

function Guide:StartClassGuide(id)
    return self:StartSideGuide(id)
end

-- Reprend le guide de leveling interrompu par un guide annexe.
function Guide:Resume()
    local id = self.char.returnTo
    self.char.returnTo = nil
    if id and ns.DB:GetGuide(id) then
        return self:Start(id)
    end
    return self:Stop()
end
