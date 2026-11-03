-- État réel du joueur, lu dans l'API du jeu : il répond aux questions du moteur
-- (voir l'en-tête de Engine.lua), comme le joueur simulé des tests.
--
-- Les lectures coûteuses (journal de quêtes, sacs, compétences) sont gardées en
-- cache, vidé par catégorie quand un événement du jeu les change : voir
-- State.EVENTS. Toute valeur potentiellement secrète est ignorée (réponse nil).
--
-- [À vérifier] sur Forever : C_QuestLog (GetInfo, GetQuestObjectives,
-- IsQuestFlaggedCompleted), GetSkillLineInfo, C_Reputation, GetBindLocation,
-- C_TaxiMap.GetAllTaxiNodes.

local _, ns = ...

local State = {}
State.__index = State
ns.GuideState = State

-- Événement du jeu -> catégories du cache à vider.
State.EVENTS = {
    QUEST_LOG_UPDATE = { "quests" },
    QUEST_ACCEPTED = { "quests" },
    QUEST_REMOVED = { "quests" },
    QUEST_TURNED_IN = { "quests", "turnedIn" },
    UNIT_QUEST_LOG_CHANGED = { "quests" },
    BAG_UPDATE_DELAYED = { "items" },
    SKILL_LINES_CHANGED = { "skills" },
    LEARNED_SPELL_IN_TAB = { "spells" },
    SPELLS_CHANGED = { "spells" },
    UPDATE_FACTION = { "standings" },
    PLAYER_LEVEL_UP = {},
    PLAYER_XP_UPDATE = {},
    PLAYER_MONEY = {},
    ZONE_CHANGED = {},
    ZONE_CHANGED_INDOORS = {},
    ZONE_CHANGED_NEW_AREA = {},
    PLAYER_ENTERING_WORLD = { "quests", "items", "skills", "spells", "standings" },
}

local function usable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

-- taxi : table sauvegardée [identifiant du point de vol] = true (points connus,
-- relevés à chaque ouverture de la carte des vols).
function State.New(taxi)
    return setmetatable({
        cache = {},
        taxi = taxi or {},
        questsSeen = false,
        turnedIn = {},   -- quêtes rendues pendant la session (le client peut tarder à le dire)
    }, State)
end

function State:Invalidate(category)
    if category then
        self.cache[category] = nil
    else
        self.cache = {}
    end
end

-- Vide le cache des catégories touchées par un événement du jeu.
function State:OnEvent(event, ...)
    if event == "QUEST_LOG_UPDATE" then
        self.questsSeen = true
    elseif event == "QUEST_TURNED_IN" then
        local quest = ...
        if usable(quest) then
            self.turnedIn[quest] = true
        end
    end
    for _, category in ipairs(State.EVENTS[event] or {}) do
        self.cache[category] = nil
    end
end

local function cached(self, category, build)
    local value = self.cache[category]
    if value == nil then
        value = build(self)
        self.cache[category] = value
    end
    return value
end

---------------------------------------------------------------------------
-- Personnage
---------------------------------------------------------------------------

-- Le journal de quêtes n'est fiable qu'après le premier QUEST_LOG_UPDATE.
function State:Ready()
    return self.questsSeen
end

function State:Level()
    local level = UnitLevel("player")
    if not usable(level) then
        return 1, 0
    end
    local xp, maxXP = UnitXP("player"), UnitXPMax("player")
    local fraction = 0
    if usable(xp) and usable(maxXP) and maxXP > 0 then
        fraction = xp / maxXP
    end
    return level, fraction
end

function State:Race()
    local _, race = UnitRace("player")
    return race and race:upper()
end

function State:Class()
    local _, class = UnitClass("player")
    return class
end

function State:Faction()
    return (UnitFactionGroup("player"))
end

function State:Money()
    local money = GetMoney()
    return usable(money) and money or 0
end

---------------------------------------------------------------------------
-- Quêtes
---------------------------------------------------------------------------

-- [quête] = { complete = bool, objectives = liste du client ou nil (lue à la demande) }
local function readLog()
    local log = {}
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID and info.questID > 0 then
            log[info.questID] = { complete = C_QuestLog.IsComplete(info.questID) == true }
        end
    end
    return log
end

local function questLog(self)
    return cached(self, "quests", readLog)
end

function State:InLog(q)
    return questLog(self)[q] ~= nil
end

function State:Complete(q)
    local entry = questLog(self)[q]
    return entry ~= nil and entry.complete
end

function State:TurnedIn(q)
    if self.turnedIn[q] then
        return true
    end
    local done = cached(self, "turnedIn", function()
        return {}
    end)
    if done[q] == nil then
        done[q] = C_QuestLog.IsQuestFlaggedCompleted(q) == true
    end
    return done[q]
end

-- Objectifs d'une quête du journal : liste { text, finished, numFulfilled, numRequired }.
function State:Objectives(q)
    local entry = questLog(self)[q]
    if not entry then
        return nil
    end
    if entry.objectives == nil then
        entry.objectives = C_QuestLog.GetQuestObjectives(q) or {}
    end
    return entry.objectives
end

function State:Objective(q, oi)
    local objective = (self:Objectives(q) or {})[oi]
    return objective ~= nil and objective.finished == true
end

function State:LogQuests()
    local list = {}
    for q in pairs(questLog(self)) do
        list[#list + 1] = q
    end
    table.sort(list)
    return list
end

---------------------------------------------------------------------------
-- Objets, compétences, sorts, réputations
---------------------------------------------------------------------------

function State:ItemCount(item)
    local counts = cached(self, "items", function()
        return {}
    end)
    if counts[item] == nil then
        local count = C_Item.GetItemCount(item)
        counts[item] = usable(count) and count or 0
    end
    return counts[item]
end

-- [nom localisé en minuscules] = { rang, rang max }. Les lignes de compétence n'ont
-- pas d'identifiant dans GetSkillLineInfo : on compare les noms.
local function readSkills()
    local skills = {}
    if not GetNumSkillLines then
        return skills
    end
    for i = 1, GetNumSkillLines() do
        local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
        if name and not isHeader then
            skills[name:lower()] = { rank or 0, maxRank or 0 }
        end
    end
    return skills
end

-- Nom de la ligne dans la langue du client, quand le client sait le donner.
local function skillLineName(line)
    if line and C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName then
        local name = C_TradeSkillUI.GetTradeSkillDisplayName(line)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
end

function State:Skill(line, name)
    local skills = cached(self, "skills", readSkills)
    local candidates = {}
    local function add(value)
        if type(value) == "string" and value ~= "" then
            candidates[#candidates + 1] = value
        end
    end
    add(skillLineName(line))
    add(line and ns.DB:GetName("skill", line))
    add(name)
    for _, candidate in ipairs(candidates) do
        local skill = skills[candidate:lower()]
        if skill then
            return skill[1], skill[2]
        end
    end
end

function State:Knows(spell)
    if not spell then
        return false
    end
    if IsPlayerSpell and IsPlayerSpell(spell) then
        return true
    end
    return IsSpellKnown ~= nil and IsSpellKnown(spell) == true
end

-- Rang de réputation : 1 (Haï) à 8 (Exalté).
function State:Standing(faction)
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local data = C_Reputation.GetFactionDataByID(faction)
        return data and data.reaction
    end
    if GetFactionInfoByID then
        local _, _, standing = GetFactionInfoByID(faction)
        return standing
    end
end

---------------------------------------------------------------------------
-- Lieux
---------------------------------------------------------------------------

-- Noms possibles d'une région : celui du client (sa langue), puis le nom anglais
-- du guide (utile sur un client anglais).
local function areaNames(area, name)
    local names = {}
    if area then
        local own = C_Map.GetAreaInfo(area)
        if type(own) == "string" and own ~= "" then
            names[#names + 1] = own
        end
        local imported = ns.DB:GetName("area", area)
        if imported then
            names[#names + 1] = imported
        end
    end
    if name then
        names[#names + 1] = name
    end
    return names
end

local function matchesAny(text, names)
    if type(text) ~= "string" or text == "" then
        return false
    end
    for _, name in ipairs(names) do
        if text == name then
            return true
        end
    end
    return false
end

function State:InArea(area, name)
    local names = areaNames(area, name)
    return matchesAny(GetSubZoneText(), names) or matchesAny(GetZoneText(), names)
        or matchesAny(GetMinimapZoneText(), names)
end

function State:BoundAt(area, name)
    return matchesAny(GetBindLocation(), areaNames(area, name))
end

function State:KnowsTaxi(node)
    return self.taxi[node] == true
end

-- À l'ouverture de la carte des vols : retient les points connus.
function State:RecordTaxi(uiMapID)
    if not (C_TaxiMap and C_TaxiMap.GetAllTaxiNodes) then
        return
    end
    local reachable = Enum and Enum.FlightPathState and Enum.FlightPathState.Unreachable
    for _, node in ipairs(C_TaxiMap.GetAllTaxiNodes(uiMapID) or {}) do
        if node.nodeID and node.state ~= reachable then
            self.taxi[node.nodeID] = true
        end
    end
end

-- Exploration des régions : le moteur se rabat sur la position du joueur.
function State:Explored()
    return nil
end

function State:Distance(map, x, y, frame)
    return ns.Navigation.DistanceTo(map, x, y, frame)
end

---------------------------------------------------------------------------
-- Temps de recharge, équipement
---------------------------------------------------------------------------

local function onCooldown(start, duration)
    if not (usable(start) and usable(duration)) then
        return nil
    end
    return start > 0 and duration > 1.5
end

function State:OnCooldown(kind, id)
    if kind == "item" and C_Container and C_Container.GetItemCooldown then
        return onCooldown(C_Container.GetItemCooldown(id))
    end
    if kind == "spell" and C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(id)
        if info then
            return onCooldown(info.startTime, info.duration)
        end
    end
end

-- Calcul du score des objets : phase 6.
function State:IsUpgrade()
    return nil
end
