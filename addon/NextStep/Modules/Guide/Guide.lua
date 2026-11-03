-- Module Guide : guide actif, progression sauvegardée du personnage et
-- recalcul par le moteur. L'interface (phase 4) affiche self.result et écoute
-- le message NEXTSTEP_GUIDE_UPDATED (result).
--
-- L'état du joueur est fourni par SetState : une simulation dans les tests,
-- l'API du jeu en jeu (phase 4).

local _, ns = ...
local L = ns.L

local Engine = ns.GuideEngine

local Guide = ns.Modules:New("Guide", {
    title = L["Leveling guide"],
    description = L["Step-by-step guide for your race, class and level, which accepts detours."],
    charDefaults = {
        active = nil,      -- identifiant du guide suivi
        mode = "strict",   -- "strict" : une étape à la fois ; "free" : les objectifs du même endroit
        progress = {},     -- [identifiant du guide] = progression (Engine.NewProgress)
        answers = {},      -- [quête de groupe] = true (la faire) / false (la passer)
        dungeons = {},     -- [nom du donjon] = true : donjons choisis
    },
})

function Guide:OnInitialize()
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

function Guide:Refresh()
    local guide = self:ActiveGuide()
    if not guide or not self.state then
        self.result = nil
        return nil
    end
    local progress = self:Progress(guide.id)
    local result = Engine.Evaluate(guide, {
        state = self.state,
        progress = progress,
        seen = self.seen[guide.id] or {},
        answers = self.char.answers,
        dungeons = self.char.dungeons,
    })
    -- Tant que le journal de quêtes n'est pas lu, rien n'est mémorisé.
    if self.state:Ready() ~= false then
        Engine.Commit(progress, result)
    end
    result.mode = self.char.mode
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
        Engine.Skip(progress, guide, step)
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

-- Guides de leveling adaptés au personnage : faction, race, classe et niveau.
-- Les guides propres à la race passent en premier, puis par niveau croissant.
function Guide:Suggest(state)
    state = state or self.state
    local level, race = state:Level(), state:Race()
    local list = {}
    for _, guide in ns.DB:IterateGuides() do
        if guide.category == "Leveling"
            and (not guide.faction or guide.faction == state:Faction())
            and (not guide.races or contains(guide.races, race))
            and (not guide.classes or contains(guide.classes, state:Class()))
            and (guide.minLevel or 1) <= level and level <= (guide.maxLevel or 60) then
            list[#list + 1] = guide
        end
    end
    table.sort(list, function(a, b)
        if (a.races ~= nil) ~= (b.races ~= nil) then
            return a.races ~= nil
        end
        if (a.minLevel or 1) ~= (b.minLevel or 1) then
            return (a.minLevel or 1) < (b.minLevel or 1)
        end
        return a.id < b.id
    end)
    return list
end
