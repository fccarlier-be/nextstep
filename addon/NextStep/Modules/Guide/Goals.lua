-- État d'un objectif de guide, selon son type (goal.t). Fonctions pures.
--
-- Statuts :
--   done     accompli
--   todo     à faire
--   blocked  à faire mais impossible pour l'instant (raison dans reason)
--   manual   à faire, invisible pour l'addon : validé par le joueur ou par un
--            événement du jeu (ctx.seen)
--   na       ne concerne pas ce personnage, ou plus disponible (raison dans reason)
--   info     simple texte, ne bloque jamais

local _, ns = ...

local Goals = {}
ns.GuideGoals = Goals

-- Objectifs de déplacement : accomplis dès qu'un objectif suivant de l'étape l'est
-- (arrivé au bout du trajet, peu importe comment).
-- ["goto"] : mot réservé de LuaJIT (outil de test), pas du Lua 5.1 du jeu.
Goals.TRAVEL = { ["goto"] = true, fly = true, hearth = true, enter = true, explore = true }

local function result(status, reason)
    return { status = status, reason = reason }
end

local DONE, TODO, MANUAL, NA, INFO = result("done"), result("todo"), result("manual"), result("na"), result("info")

-- Une quête dont l'acceptation a été sautée (étape ignorée, hors sujet...) emporte
-- ses autres objectifs, sauf si le joueur l'a quand même dans son journal.
local function dropped(goal, state, ctx)
    return ctx.droppedQuests[goal.quest] and not state:InLog(goal.quest)
end

-- Premier prérequis manquant : tous les preAll, et au moins un des pre.
local function missingPre(goal, state)
    for _, q in ipairs(goal.preAll or {}) do
        if not state:TurnedIn(q) then
            return q
        end
    end
    if goal.pre and #goal.pre > 0 then
        for _, q in ipairs(goal.pre) do
            if state:TurnedIn(q) then
                return nil
            end
        end
        return goal.pre[1]
    end
end

local function closedBy(goal, state)
    for _, by in ipairs(goal.closedBy or {}) do
        if state:InLog(by) or state:TurnedIn(by) then
            return by
        end
    end
end

local function accept(goal, state, ctx)
    local q = goal.quest
    if state:InLog(q) or state:TurnedIn(q) then
        return DONE
    end
    if ctx.droppedQuests[q] then
        return result("na", { kind = "skipped" })
    end
    local by = closedBy(goal, state)
    if by then
        return result("na", { kind = "closed", by = by })
    end
    local pre = missingPre(goal, state)
    if pre then
        return result("na", { kind = "prerequisite", quest = pre })
    end
    local need = goal.minLevel
    if need and state:Level() < need then
        return result("blocked", { kind = "level", level = need })
    end
    return TODO
end

local function turnin(goal, state, ctx)
    if state:TurnedIn(goal.quest) then
        return DONE
    end
    if dropped(goal, state, ctx) then
        return result("na", { kind = "skipped" })
    end
    return TODO
end

local function complete(goal, state, ctx)
    if state:TurnedIn(goal.quest) or state:Complete(goal.quest) then
        return DONE
    end
    if dropped(goal, state, ctx) then
        return result("na", { kind = "skipped" })
    end
    return TODO
end

local function seenOrManual(goal, _, ctx)
    if ctx.seen(goal) then
        return DONE
    end
    return MANUAL
end

-- Objectif lié à un objectif de quête (quest + oi), sinon vérifié autrement.
local function questObjective(otherwise)
    return function(goal, state, ctx)
        if not goal.quest then
            return otherwise(goal, state, ctx)
        end
        local q = goal.quest
        if state:TurnedIn(q) or state:Complete(q) then
            return DONE
        end
        if dropped(goal, state, ctx) then
            return result("na", { kind = "skipped" })
        end
        if state:InLog(q) and goal.oi and state:Objective(q, goal.oi) then
            return DONE
        end
        return TODO
    end
end

local function itemCount(goal, state)
    if state:ItemCount(goal.item) >= (goal.count or 1) then
        return DONE
    end
    return TODO
end

local function reached(goal, state, ctx)
    if ctx.seen(goal) then
        return DONE
    end
    local distance = goal.map and state:Distance(goal.map, goal.x, goal.y, goal.f)
    if distance and distance <= (goal.r or 8) then
        return DONE
    end
    return TODO
end

local function inArea(goal, state, ctx)
    if ctx.seen(goal) or state:InArea(goal.area, goal.location) then
        return DONE
    end
    return TODO
end

local function areaOf(goal)
    return goal.area or tonumber((goal.text or ""):match("^{area:(%d+)}"))
end

local EVALUATORS = {
    accept = accept,
    turnin = turnin,
    complete = complete,
    kill = questObjective(seenOrManual),
    collect = questObjective(itemCount),
    interact = questObjective(seenOrManual),
    use = questObjective(seenOrManual),
    talk = seenOrManual,
    vendor = seenOrManual,
    cast = seenOrManual,
    task = seenOrManual,
    buy = itemCount,
    ["goto"] = reached,
    explore = function(goal, state, ctx)
        local area = areaOf(goal)
        if area and (state:Explored(area) or state:InArea(area)) then
            return DONE
        end
        return reached(goal, state, ctx)
    end,
    enter = inArea,
    fly = inArea,
    hearth = inArea,
    sethome = function(goal, state)
        if state:BoundAt(goal.area, goal.location) then
            return DONE
        end
        return TODO
    end,
    getfp = function(goal, state, ctx)
        -- Sans identifiant de point de vol, l'addon ne peut pas le vérifier.
        if not goal.node then
            return seenOrManual(goal, state, ctx)
        end
        if state:KnowsTaxi(goal.node) then
            return DONE
        end
        return TODO
    end,
    level = function(goal, state)
        local level, fraction = state:Level()
        if level > goal.level or (level == goal.level and (fraction or 0) >= (goal.frac or 0)) then
            return DONE
        end
        return TODO
    end,
    money = function(goal, state)
        if state:Money() >= goal.money then
            return DONE
        end
        return TODO
    end,
    skill = function(goal, state)
        if (state:Skill(goal.skillLine, goal.skill) or 0) >= goal.level then
            return DONE
        end
        return TODO
    end,
    learn = function(goal, state)
        if state:Knows(goal.spell) then
            return DONE
        end
        return TODO
    end,
    craft = function(goal, state, ctx)
        if goal.untilSkill then
            if (state:Skill(goal.skillLine) or 0) >= goal.untilSkill then
                return DONE
            end
            return TODO
        end
        return seenOrManual(goal, state, ctx)
    end,
    train = function(goal, state, ctx)
        -- Rang de métier : vérifiable. Maître de classe ou PNJ : à valider.
        if goal.profLine and goal.rankMax then
            local _, maxRank = state:Skill(goal.profLine)
            if (maxRank or 0) >= goal.rankMax then
                return DONE
            end
            return TODO
        end
        return seenOrManual(goal, state, ctx)
    end,
    rep = function(goal, state)
        if (state:Standing(goal.faction) or 0) >= goal.standing then
            return DONE
        end
        return TODO
    end,
    -- Raccourci par la mort : désactivé par défaut, comme dans Polestar.
    die = function()
        return result("na", { kind = "deathskip" })
    end,
    note = function()
        return INFO
    end,
}

-- ctx : droppedQuests (table), seen(goal) -> bool, character (state).
function Goals.Evaluate(goal, state, ctx)
    if goal.only and not ns.GuideConditions.Matches(goal.only, state) then
        return NA
    end
    local evaluate = EVALUATORS[goal.t]
    if not evaluate then
        -- Type inconnu (nouveau format) : le joueur le valide.
        return seenOrManual(goal, state, ctx)
    end
    return evaluate(goal, state, ctx)
end

-- Un objectif retient l'étape tant qu'il est à faire et n'est pas facultatif.
function Goals.Holds(goal, status)
    if goal.optional then
        return false
    end
    return status == "todo" or status == "blocked" or status == "manual"
end
