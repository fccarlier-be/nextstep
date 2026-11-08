-- Mode conseil (docs/DESIGN.md, « Enchaînement », mode conseil) : sans guide suivi, ou
-- dans l'onglet Zones du journal, les quêtes que le personnage peut prendre maintenant,
-- d'après forever-db (DB.adviceQuests) : sa faction, sa race, sa classe, son niveau
-- (ni grises ni trop dures), quêtes déjà faites et prérequis.
--
--   Guide:AvailableQuests(state) -> { { id, level, map, x, y, title, giver } }
--   Guide:NearbyQuests(state, count) -> les plus proches, avec leur distance
--
-- Un clic sur une quête tourne la flèche vers son donneur (Guide:PointTo).

local _, ns = ...
local L = ns.L

local Guide = ns.Modules:Get("Guide")
local Navigation = ns.Navigation
local Labels = ns.GuideLabels

-- Jetons de race et de classe -> identifiants du client (masques de forever-db).
local RACE_IDS = { HUMAN = 1, ORC = 2, DWARF = 3, NIGHTELF = 4, SCOURGE = 5, TAUREN = 6, GNOME = 7, TROLL = 8 }
local CLASS_IDS = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9,
    DRUID = 11 }
local SIDES = { Alliance = 1, Horde = 2 }
local HARD = 3   -- niveaux au-dessus du personnage encore proposés

local function hasBit(mask, id)
    if not (mask and mask > 0 and id) then
        return true
    end
    return math.floor(mask / 2 ^ (id - 1)) % 2 == 1
end

local function splitIDs(text)
    local list = {}
    for id in (text or ""):gmatch("%d+") do
        list[#list + 1] = tonumber(id)
    end
    return list
end

-- Quêtes décodées une fois : { id, level, min, side, races, classes, map, x, y, all, any, title, kind, giver }.
local parsed
function Guide.AdviceQuestList()
    if parsed then
        return parsed
    end
    parsed = {}
    for id, text in pairs(ns.DB.adviceQuests or {}) do
        local head, all, any, title, giver = text:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
        local level, min, side, races, classes, _, map, x, y =
            (head or ""):match("^(%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+) ([%d%.]+) ([%d%.]+)$")
        local kind, giverID = (giver or ""):match("^(%a) (%d+)$")
        if level then
            parsed[#parsed + 1] = {
                id = id, level = tonumber(level), min = tonumber(min), side = tonumber(side),
                races = tonumber(races), classes = tonumber(classes), map = tonumber(map), x = tonumber(x),
                y = tonumber(y), all = splitIDs(all), any = splitIDs(any), title = title, kind = kind,
                giver = tonumber(giverID),
            }
        end
    end
    table.sort(parsed, function(a, b)
        if a.level ~= b.level then
            return a.level < b.level
        end
        return a.id < b.id
    end)
    return parsed
end

-- La quête peut-elle être prise maintenant par ce personnage ?
function Guide.QuestAvailable(quest, state)
    local level = state:Level()
    if quest.side ~= 0 and quest.side ~= SIDES[state:Faction() or ""] then
        return false
    end
    if not hasBit(quest.races, RACE_IDS[state:Race() or ""])
        or not hasBit(quest.classes, CLASS_IDS[state:Class() or ""]) then
        return false
    end
    if (quest.min or 0) > level or quest.level > level + HARD then
        return false
    end
    if Labels.Difficulty(quest.level, level) == "trivial" then
        return false
    end
    if state:TurnedIn(quest.id) or state:InLog(quest.id) then
        return false
    end
    for _, pre in ipairs(quest.all) do
        if not state:TurnedIn(pre) then
            return false
        end
    end
    if #quest.any > 0 then
        local done = false
        for _, pre in ipairs(quest.any) do
            done = done or state:TurnedIn(pre)
        end
        if not done then
            return false
        end
    end
    return true
end

function Guide:AvailableQuests(state)
    state = state or self.state
    local list = {}
    if not state then
        return list
    end
    local ignored = self.char and self.char.ignoredQuests or {}
    for _, quest in ipairs(Guide.AdviceQuestList()) do
        if not ignored[quest.id] and Guide.QuestAvailable(quest, state) then
            list[#list + 1] = quest
        end
    end
    return list
end

-- Les count quêtes disponibles les plus proches : { quest, distance }.
function Guide:NearbyQuests(state, count)
    local list = {}
    for _, quest in ipairs(self:AvailableQuests(state)) do
        local distance = Navigation.DistanceTo(quest.map, quest.x, quest.y)
        if distance then
            list[#list + 1] = { quest = quest, distance = distance }
        end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    for index = #list, (count or 5) + 1, -1 do
        list[index] = nil
    end
    return list
end

function Guide.AdviceTitle(quest)
    return ns.DB:GetName("quest", quest.id) or quest.title or ("#" .. quest.id)
end

function Guide.AdviceGiver(quest)
    if quest.kind == "o" then
        return (ns.DB.adviceGivers or {})[-(quest.giver or 0)] or "?"
    end
    return ns.DB:GetName("npc", quest.giver) or (ns.DB.adviceGivers or {})[quest.giver] or "?"
end

-- Ligne d'une quête : « [12] Titre — Donneur (Zone) ».
function Guide:AdviceText(quest, withZone)
    local tag = Labels.LevelTag({ qlvl = quest.level }, nil, self.state and self.state:Level() or 1)
    local text = ("%s %s - %s"):format(tag or "", Guide.AdviceTitle(quest), Guide.AdviceGiver(quest))
    if withZone then
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(quest.map)
        if info and info.name then
            text = ("%s (%s)"):format(text, info.name)
        end
    end
    return text
end

function Guide:PointToQuest(quest)
    self:PointTo({ map = quest.map, x = quest.x, y = quest.y }, Guide.AdviceTitle(quest))
    ns:Print(L["The arrow points to %s. Right-click it to go back to the guide."]:format(Guide.AdviceGiver(quest)))
end
