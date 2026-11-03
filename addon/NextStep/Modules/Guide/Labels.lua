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

local BUILDERS = {
    accept = function(goal, guide)
        return L["Accept %s"]:format(name("quest", goal.quest, guide))
    end,
    turnin = function(goal, guide)
        return L["Turn in %s"]:format(name("quest", goal.quest, guide))
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
