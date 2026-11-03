-- Conditions des guides : à qui s'adresse une étape (only) et dans quel état (when).
-- Sémantique de Polestar, voir docs/DATA_FORMAT.md. Fonctions pures : l'état du
-- joueur est fourni par l'objet state (voir Modules/Guide/Engine.lua).

local _, ns = ...

local Conditions = {}
ns.GuideConditions = Conditions

-- Une liste de jetons est un OU ; « !X » vaut pour toute valeur sauf X.
local function anyMatches(list, value)
    if not list or #list == 0 then
        return true
    end
    for _, token in ipairs(list) do
        if token:sub(1, 1) == "!" then
            if token:sub(2) ~= value then
                return true
            end
        elseif token == value then
            return true
        end
    end
    return false
end

-- only = { races, classes, factions } : OU dans chaque liste, ET entre les listes.
function Conditions.Matches(only, state)
    if not only then
        return true
    end
    return anyMatches(only.races, state:Race())
        and anyMatches(only.classes, state:Class())
        and anyMatches(only.factions, state:Faction())
end

local function compare(a, op, b)
    if op == "<" then
        return a < b
    elseif op == "<=" then
        return a <= b
    elseif op == ">" then
        return a > b
    elseif op == ">=" then
        return a >= b
    end
    return a == b
end

local function questList(q)
    return type(q) == "table" and q or { q }
end

-- Niveau avec sa fraction d'expérience : 12,5 = milieu du niveau 12.
local function levelValue(state)
    local level, fraction = state:Level()
    return level + (fraction or 0)
end

local function available(pred, state)
    local q = pred.q
    if state:InLog(q) or state:TurnedIn(q) then
        return false
    end
    if pred.minLevel and state:Level() < pred.minLevel then
        return false
    end
    for _, by in ipairs(pred.closedBy or {}) do
        if state:InLog(by) or state:TurnedIn(by) then
            return false
        end
    end
    return true
end

-- Prédicats : renvoient true ou false, ou "ask" (le joueur doit répondre).
-- ctx.labelDone(label), ctx.answer(quest), ctx.dungeons[name] viennent du moteur.
local PREDICATES = {
    level = function(p, state)
        return compare(levelValue(state), p.op, p.n + (p.frac or 0))
    end,
    money = function(p, state)
        return compare(state:Money(), p.op, p.n)
    end,
    onquest = function(p, state)
        for _, q in ipairs(questList(p.q)) do
            if state:InLog(q) then
                return true
            end
        end
        return false
    end,
    complete = function(p, state)
        return state:Complete(p.q) == true
    end,
    turnedin = function(p, state)
        return state:TurnedIn(p.q) == true
    end,
    available = available,
    has = function(p, state)
        return state:ItemCount(p.item) >= (p.n or 1)
    end,
    zone = function(p, state)
        return state:InArea(p.area, p.name) == true
    end,
    subzone = function(p, state)
        return state:InArea(p.area, p.name) == true
    end,
    bound = function(p, state)
        return state:BoundAt(p.area, p.name) == true
    end,
    knows = function(p, state)
        return state:Knows(p.spell) == true
    end,
    skill = function(p, state)
        return (state:Skill(p.skillLine, p.name) or 0) >= (p.n or 1)
    end,
    cooldown = function(p, state)
        return state:OnCooldown(p.item and "item" or "spell", p.item or p.spell) == true
    end,
    -- Sans avis sur l'objet, il compte comme une amélioration : le joueur décide.
    upgrade = function(p, state)
        return state:IsUpgrade(p.item) ~= false
    end,
    done = function(p, _, ctx)
        return ctx.labelDone(p.label) == true
    end,
    dungeon = function(p, _, ctx)
        return ctx.dungeons[p.name] == true
    end,
    -- Gère neg lui-même. Quête déjà rendue : la condition est ignorée. Sans réponse,
    -- l'étape attend la réponse du joueur, sauf une étape « en chemin », qui s'applique.
    group = function(p, state, ctx)
        if state:TurnedIn(p.q) then
            return true
        end
        local answer = ctx.answer(p.q)
        if answer == nil then
            return ctx.along and true or "ask"
        end
        if p.neg then
            return not answer
        end
        return answer
    end,
}

function Conditions.Holds(pred, state, ctx)
    local check = PREDICATES[pred.k]
    if not check then
        -- Prédicat inconnu (nouveau format) : l'étape s'affiche, le joueur décide.
        return true
    end
    local result = check(pred, state, ctx)
    if result == "ask" or pred.k == "group" then
        return result
    end
    if pred.neg then
        return not result
    end
    return result
end

-- Toutes les conditions d'une étape : false dès qu'une échoue, "ask" si une
-- question attend une réponse, sinon true.
function Conditions.AllHold(list, state, ctx)
    local ask = false
    for _, pred in ipairs(list or {}) do
        local result = Conditions.Holds(pred, state, ctx)
        if result == false then
            return false
        elseif result == "ask" then
            ask = true
        end
    end
    return ask and "ask" or true
end
