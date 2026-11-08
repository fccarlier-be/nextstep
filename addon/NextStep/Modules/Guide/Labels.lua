-- Libellés des étapes et des objectifs, dans la langue du client. Les objectifs
-- importés n'ont presque jamais de texte : le libellé est construit à partir du
-- type (accepter, rendre, tuer…) et des noms des entités. Pour un objectif de
-- quête, le texte du client (avec la progression, « Vermine kobold tuée : 6/10 »)
-- est préféré.

local _, ns = ...
local L = ns.L

local Labels = {}
ns.GuideLabels = Labels

local function name(kind, id, guide)
    if not id then
        return nil
    end
    return ns.DB:GetName(kind, id, guide) or "?"
end

local function areaOf(goal)
    return goal.area or tonumber((goal.text or ""):match("^{area:(%d+)}"))
end

local function placeName(goal, guide)
    local area = areaOf(goal)
    if area then
        return name("area", area, guide)
    end
    if goal.location then
        return goal.location
    end
    if goal.map then
        return name("zone", goal.map, guide)
    end
    return "?"
end

-- Texte du client pour un objectif de quête (progression comprise), si la quête
-- est dans le journal.
local function clientObjective(goal, state)
    if not (goal.quest and goal.oi and state and state.Objectives) then
        return nil
    end
    local objective = (state:Objectives(goal.quest) or {})[goal.oi]
    local text = objective and objective.text
    if type(text) == "string" and text ~= "" and not (issecretvalue and issecretvalue(text)) then
        return text
    end
end

local function withCount(text, goal, state)
    if goal.item and goal.count and goal.count > 1 and state then
        return ("%s %d/%d"):format(text, math.min(state:ItemCount(goal.item), goal.count), goal.count)
    end
    if goal.count and goal.count > 1 then
        return ("%s (%d)"):format(text, goal.count)
    end
    return text
end

-- Qui donne ou reprend la quête : PNJ, objet du monde (un alambic, une affiche...)
-- ou objet du sac. Le PNJ n'est pas répété si la note de l'objectif le nomme déjà.
local function questGiver(goal, guide)
    if goal.npc then
        if goal.note and goal.note:find("{npc:" .. goal.npc .. "}", 1, true) then
            return nil
        end
        return "npc", name("npc", goal.npc, guide)
    elseif goal.object then
        return "object", name("object", goal.object, guide)
    elseif goal.item then
        return "item", name("item", goal.item, guide)
    end
end

local GIVER_FORMATS = {
    accept = { npc = "Accept %s from %s", object = "Accept %s (object: %s)", item = "Accept %s (item: %s)" },
    turnin = { npc = "Turn in %s to %s", object = "Turn in %s (object: %s)", item = "Turn in %s (item: %s)" },
}

local function questAction(goal, guide, plain)
    local quest = name("quest", goal.quest, guide)
    local kind, giver = questGiver(goal, guide)
    if kind and giver and giver ~= "?" then
        return L[GIVER_FORMATS[goal.t][kind]]:format(quest, giver)
    end
    return L[plain]:format(quest)
end

local BUILDERS = {
    accept = function(goal, guide)
        return questAction(goal, guide, "Accept %s")
    end,
    turnin = function(goal, guide)
        return questAction(goal, guide, "Turn in %s")
    end,
    complete = function(goal, guide)
        return L["Complete %s"]:format(name("quest", goal.quest, guide))
    end,
    kill = function(goal, guide, state)
        return clientObjective(goal, state)
            or withCount(L["Kill %s"]:format(name("npc", goal.npc, guide) or goal.target or "?"), goal)
    end,
    collect = function(goal, guide, state)
        return clientObjective(goal, state)
            or withCount(L["Collect %s"]:format(name("item", goal.item, guide)), goal, state)
    end,
    buy = function(goal, guide, state)
        return withCount(L["Buy %s"]:format(name("item", goal.item, guide)), goal, state)
    end,
    use = function(goal, guide, state)
        return clientObjective(goal, state)
            or L["Use %s"]:format(name("item", goal.item, guide) or name("object", goal.object, guide) or "?")
    end,
    interact = function(goal, guide, state)
        return clientObjective(goal, state)
            or L["Use %s"]:format(name("object", goal.object, guide) or name("npc", goal.npc, guide) or "?")
    end,
    talk = function(goal, guide)
        return L["Talk to %s"]:format(name("npc", goal.npc, guide) or "?")
    end,
    vendor = function(goal, guide)
        if goal.npc then
            return L["Visit %s (vendor)"]:format(name("npc", goal.npc, guide))
        end
        return L["Visit a vendor"]
    end,
    ["goto"] = function(goal, guide)
        return L["Go to %s"]:format(placeName(goal, guide))
    end,
    explore = function(goal, guide)
        return L["Explore %s"]:format(placeName(goal, guide))
    end,
    enter = function(goal, guide)
        return L["Enter %s"]:format(placeName(goal, guide))
    end,
    fly = function(goal, guide)
        return L["Fly to %s"]:format(placeName(goal, guide))
    end,
    hearth = function(goal, guide)
        return L["Hearth to %s"]:format(placeName(goal, guide))
    end,
    sethome = function(goal, guide)
        return L["Make %s your home"]:format(placeName(goal, guide))
    end,
    getfp = function(goal, guide)
        return L["Get the flight path of %s"]:format(placeName(goal, guide))
    end,
    level = function(goal)
        return L["Reach level %d"]:format(goal.level)
    end,
    train = function(goal, guide)
        if goal.class then
            return L["Visit your class trainer"]
        end
        local what = goal.profName or name("spell", goal.spell, guide)
        if what then
            return L["Train %s"]:format(what)
        end
        return L["Visit the trainer"]
    end,
    learn = function(goal, guide)
        return L["Learn %s"]:format(name("spell", goal.spell, guide) or "?")
    end,
    cast = function(goal, guide)
        return L["Cast %s"]:format(name("spell", goal.spell, guide) or "?")
    end,
    craft = function(goal, guide)
        return withCount(L["Craft %s"]:format(name("item", goal.item, guide) or name("spell", goal.spell, guide)
            or "?"), goal)
    end,
    skill = function(goal, guide)
        return L["Reach %d in %s"]:format(goal.level, name("skill", goal.skillLine, guide) or goal.skill or "?")
    end,
    rep = function(goal, guide)
        local standing = _G["FACTION_STANDING_LABEL" .. tostring(goal.standing)] or tostring(goal.standing)
        return L["Reach %s with %s"]:format(standing, name("faction", goal.faction, guide) or "?")
    end,
    money = function(goal)
        return L["Have %d gold"]:format(math.ceil(goal.money / 10000))
    end,
    die = function()
        return L["Die (shortcut, not used)"]
    end,
}

-- Libellé d'un objectif. state (facultatif) : pour la progression.
function Labels.Goal(goal, guide, state)
    if goal.text then
        return ns.DB:Render(goal.text, guide)
    end
    local build = BUILDERS[goal.t]
    if build then
        return build(goal, guide, state)
    end
    if goal.note then
        return ns.DB:Render(goal.note, guide)
    end
    return goal.t
end

-- Précision d'un objectif (où, qui) : sa note, si elle n'a pas déjà servi de libellé.
function Labels.GoalNote(goal, guide)
    if goal.note and (goal.text or BUILDERS[goal.t]) then
        return ns.DB:Render(goal.note, guide)
    end
end

-- Contenu de groupe (champ group des données : élite, groupe de N, donjon, raid).
-- Une quête est marquée sur tous ses objectifs (accepter, rendre…) dès que l'un
-- d'eux porte l'information. Priorité : raid, donjon, groupe, élite.
local GROUP_PRIORITY = { raid = 4, dungeon = 3, group = 2, elite = 1 }
local questGroups = setmetatable({}, { __mode = "k" })   -- [guide] = { [quête] = group }

local function groupsOf(guide)
    local groups = questGroups[guide]
    if not groups then
        groups = {}
        for _, step in ipairs(guide.steps or {}) do
            for _, goal in ipairs(step.goals or {}) do
                local group = goal.group
                if goal.quest and group and GROUP_PRIORITY[group.kind] then
                    local known = groups[goal.quest]
                    if not known or GROUP_PRIORITY[group.kind] > GROUP_PRIORITY[known.kind] then
                        groups[goal.quest] = group
                    end
                end
            end
        end
        questGroups[guide] = groups
    end
    return groups
end

-- Mention du contenu de groupe d'un objectif (« élite », « groupe de 2 »…), ou nil.
-- Quêtes élites ou de groupe d'après forever-db (DB.questGroups), quand le guide ne le
-- dit pas : évite de traverser la carte pour une quête qu'on ne fera pas seul.
local QUEST_GROUPS = { e = { kind = "elite" }, g = { kind = "group" }, d = { kind = "dungeon" }, r = { kind = "raid" } }

function Labels.GroupTag(goal, guide)
    local group = goal.group
    if goal.quest and guide then
        group = groupsOf(guide)[goal.quest] or group
    end
    if not group and goal.quest and ns.DB.questGroups then
        group = QUEST_GROUPS[ns.DB.questGroups[goal.quest]]
    end
    local kind = group and group.kind
    if kind == "elite" then
        return L["elite"]
    elseif kind == "group" then
        return group.size and L["group of %d"]:format(group.size) or L["group"]
    elseif kind == "dungeon" then
        return group.name and L["dungeon: %s"]:format(group.name) or L["dungeon"]
    elseif kind == "raid" then
        return L["raid"]
    end
end

-- Niveau des quêtes (qlvl, porté par l'objectif « accepter ») : une quête garde
-- son niveau sur tous ses objectifs.
local questLevels = setmetatable({}, { __mode = "k" })   -- [guide] = { [quête] = niveau }

local function levelsOf(guide)
    local levels = questLevels[guide]
    if not levels then
        levels = {}
        for _, step in ipairs(guide.steps or {}) do
            for _, goal in ipairs(step.goals or {}) do
                if goal.quest and goal.qlvl and not levels[goal.quest] then
                    levels[goal.quest] = goal.qlvl
                end
            end
        end
        questLevels[guide] = levels
    end
    return levels
end

function Labels.QuestLevel(goal, guide)
    if goal.qlvl then
        return goal.qlvl
    end
    return goal.quest and guide and levelsOf(guide)[goal.quest] or nil
end

-- Difficulté d'une quête selon l'écart de niveau, comme les couleurs du jeu :
-- "trivial" (grise, plus d'expérience), "easy" (verte), "normal" (jaune : de 2
-- niveaux en dessous à 2 au-dessus), "hard" (orange : 3 ou 4 au-dessus),
-- "impossible" (rouge : 5 ou plus au-dessus).
function Labels.Difficulty(questLevel, level)
    local diff = questLevel - level
    if diff >= 5 then
        return "impossible"
    elseif diff >= 3 then
        return "hard"
    elseif diff >= -2 then
        return "normal"
    end
    -- Niveau gris du jeu classique (quêtes et monstres).
    local gray
    if level <= 5 then
        gray = 0
    elseif level <= 39 then
        gray = level - 5 - math.floor(level / 10)
    elseif level <= 59 then
        gray = level - 1 - math.floor(level / 5)
    else
        gray = level - 9
    end
    return questLevel <= gray and "trivial" or "easy"
end

Labels.DIFFICULTY_COLORS = {
    trivial = "808080",
    easy = "40c040",
    normal = "ffd100",
    hard = "ff8040",
    impossible = "ff1a1a",
}

-- Niveau de la quête d'un objectif, coloré selon sa difficulté (« [10] »), ou nil.
function Labels.LevelTag(goal, guide, level)
    local questLevel = Labels.QuestLevel(goal, guide)
    if not (questLevel and level) then
        return nil
    end
    local color = Labels.DIFFICULTY_COLORS[Labels.Difficulty(questLevel, level)]
    return ("|cff%s[%d]|r"):format(color, questLevel)
end

-- D'où vient un objet à ramasser : « Broche-tripes, Jeune broche-tripes » (au plus
-- trois monstres), ou l'objet du monde qui le contient. nil si inconnu.
local MAX_SOURCES = 3

function Labels.CollectSource(goal, guide)
    if goal.t ~= "collect" then
        return nil
    end
    if goal.fromKind == "object" and goal.fromId then
        local object = ns.DB:GetName("object", goal.fromId, guide)
        return object and object ~= "?" and L["in: %s"]:format(object) or nil
    end
    local names, seen = {}, {}
    for _, source in ipairs(goal.fromNpcs or {}) do
        local npcName = ns.DB:GetName("npc", source.npc, guide)
        if not npcName or npcName == "?" then
            npcName = source.npcName
        end
        if npcName and not seen[npcName] then
            seen[npcName] = true
            names[#names + 1] = npcName
        end
    end
    if #names == 0 then
        return nil
    end
    local more = #names > MAX_SOURCES
    while #names > MAX_SOURCES do
        table.remove(names)
    end
    return L["on: %s"]:format(table.concat(names, ", ") .. (more and "…" or ""))
end

function Labels.Step(step, guide)
    return ns.DB:Render(step.title, guide) or ""
end

function Labels.StepNote(step, guide)
    return ns.DB:Render(step.note, guide)
end

function Labels.Guide(guide)
    if not guide then
        return ""
    end
    local title = ns.DB:Render(guide.title, guide) or guide.id
    if guide.minLevel and guide.maxLevel then
        return ("%s %d-%d"):format(title, guide.minLevel, guide.maxLevel)
    end
    return title
end
