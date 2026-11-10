-- Moteur du guide : à partir d'un guide, de l'état du joueur et de la progression
-- sauvegardée, calcule l'étape courante et tout ce que l'interface affiche.
-- Fonctions pures, sans accès au jeu : voir docs/DESIGN.md, « Moteur du guide ».
--
-- Règles :
--   1. L'étape courante est calculée à chaque fois, jamais stockée.
--   2. Une étape dépassée garde son résultat (fait, hors sujet, sautée, en chemin) :
--      Engine.Commit le mémorise, par clé stable, jamais par position.
--   3. Les choix du joueur (étapes ignorées, validations, réponses) sont sauvegardés.
--
-- L'état du joueur (state) répond à : Ready, Level (niveau, fraction), Race, Class,
-- Faction, Money, InLog, Complete, TurnedIn, Objective(q, oi), LogQuests, ItemCount,
-- Skill(ligne, nom) -> rang, rang max, Knows, Standing, InArea(area, nom),
-- BoundAt(area, nom), KnowsTaxi, Explored, Distance(map, x, y, repère), OnCooldown,
-- IsUpgrade. Une réponse inconnue est nil.

local _, ns = ...

local Conditions, Goals = ns.GuideConditions, ns.GuideGoals

local Engine = {}
ns.GuideEngine = Engine

-- Nombre maximal d'étapes regroupées en mode libre.
Engine.FREE_STEPS = 6

---------------------------------------------------------------------------
-- Clés stables
---------------------------------------------------------------------------

local function goalSignature(goal)
    return table.concat({
        goal.t,
        goal.quest or "",
        goal.npc or "",
        goal.item or goal.object or goal.spell or goal.node or goal.area or goal.level or "",
        goal.oi or "",
    }, ":")
end

local keysCache = setmetatable({}, { __mode = "k" })

-- Clé d'une étape : son label, sinon la signature de ses premiers objectifs (le
-- texte peut changer d'une version à l'autre, pas les quêtes ni les PNJ).
function Engine.Keys(guide)
    local cached = keysCache[guide]
    if cached then
        return cached
    end
    local keys = { steps = {}, goals = {}, labels = {}, byGoal = setmetatable({}, { __mode = "k" }) }
    local used = {}
    for i, step in ipairs(guide.steps) do
        local base
        if step.label then
            base = "label:" .. step.label
            keys.labels[step.label] = i
        else
            local parts = {}
            for j = 1, math.min(3, #step.goals) do
                parts[j] = goalSignature(step.goals[j])
            end
            base = #parts > 0 and table.concat(parts, "|") or ("title:" .. tostring(step.title))
        end
        used[base] = (used[base] or 0) + 1
        local key = used[base] == 1 and base or (base .. "#" .. used[base])
        keys.steps[i] = key

        keys.goals[i] = {}
        local usedGoals = {}
        for j, goal in ipairs(step.goals) do
            local signature = goalSignature(goal)
            usedGoals[signature] = (usedGoals[signature] or 0) + 1
            local goalKey = key .. "/" .. signature
            if usedGoals[signature] > 1 then
                goalKey = goalKey .. "#" .. usedGoals[signature]
            end
            keys.goals[i][j] = goalKey
            keys.byGoal[goal] = goalKey
        end
    end
    keysCache[guide] = keys
    return keys
end

function Engine.NewProgress()
    return {
        outcomes = {},     -- [clé d'étape] = "done" | "na" | "jumped" | "along"
        skipped = {},      -- [clé d'étape] = true : ignorée par le joueur
        ticks = {},        -- [clé d'objectif] = true : validé à la main
        forced = {},       -- [clé d'étape] = true : réactivée, ses conditions when ignorées
        jumpOrigin = {},   -- [clé d'étape sautée] = clé de l'étape qui a déclenché le saut
        noJump = {},       -- [clé d'étape] = true : son saut a été annulé par le joueur
        ignoredGoals = {}, -- [clé d'objectif] = true : ignoré par le joueur
    }
end

---------------------------------------------------------------------------
-- Niveau « gris » d'une quête (formule du Classic)
---------------------------------------------------------------------------

function Engine.GreyLevel(level)
    if level <= 5 then
        return 0
    elseif level <= 39 then
        return level - 5 - math.floor(level / 10)
    elseif level <= 59 then
        return level - 1 - math.floor(level / 5)
    end
    return level - 12
end

---------------------------------------------------------------------------
-- Évaluation
---------------------------------------------------------------------------

local PASSED = { done = true, na = true, jumped = true, along = true, skipped = true }
local NOT_APPLYING = { na = true, jumped = true, skipped = true }

local function firstGroupQuest(when)
    for _, pred in ipairs(when or {}) do
        if pred.k == "group" then
            return pred.q
        end
    end
end

local function firstLocated(step)
    for _, goal in ipairs(step.goals) do
        if goal.map then
            return goal
        end
    end
end

local function hasTrip(step)
    for _, goal in ipairs(step.goals) do
        if goal.t == "fly" or goal.t == "hearth" then
            return true
        end
    end
    return false
end

-- ctx : state, progress, seen ([clé d'objectif] = true pour la session),
-- answers ([quête] = true/false : quêtes de groupe), dungeons ([nom] = true).
-- Quêtes qu'un guide fait prendre (objectifs « accept ») : [quête] = true, mis en cache.
local taken = setmetatable({}, { __mode = "k" })
local function takenBy(guide)
    local set = taken[guide]
    if not set then
        set = {}
        for _, step in ipairs(guide.steps) do
            for _, goal in ipairs(step.goals) do
                if goal.t == "accept" and goal.quest then
                    set[goal.quest] = true
                end
            end
        end
        taken[guide] = set
    end
    return set
end

function Engine.Evaluate(guide, ctx)
    local state, progress = ctx.state, ctx.progress
    local keys = Engine.Keys(guide)
    local result = {
        guide = guide,
        steps = {},          -- [i] = { key, status, goals = { [j] = { status, reason } }, blocked }
        passed = {},         -- [clé] = résultat à mémoriser
        jumpOrigin = {},
        along = {},          -- { step, goal, status } : objectifs à faire en chemin
        abandoned = {},      -- quêtes acceptées par le guide puis abandonnées
        detours = {},        -- quêtes du journal que le guide ne cite pas
        free = {},           -- { step, goal, status } : mode libre
    }

    local droppedQuests = {}
    local evaluated = {}     -- [i] = résultat calculé pendant cette évaluation

    local ignoredQuests = ctx.ignoredQuests or {}
    local ignoredGoals = progress.ignoredGoals or {}
    -- Quêtes acceptées dans une étape faite : [quête] = étape. Si l'une n'est plus dans
    -- le journal ni rendue, elle a été abandonnée : ses objectifs suivants sont mis de
    -- côté (sans être mémorisés), et la quête est proposée à la reprise.
    local acceptedAt = {}
    local abandonedHere = {}
    -- Étapes passées à cause d'un abandon, retenues pour être rouvertes si la quête
    -- revient dans le journal : [quête] = { [clé d'étape] = true }.
    result.abandonedSteps = {}
    result.reopen = {}
    for q, stepKeys in pairs(progress.abandonedSteps or {}) do
        if state:InLog(q) or state:TurnedIn(q) then
            result.reopen[q] = stepKeys
        end
    end
    -- Quêtes que ce guide fait prendre. Une quête rendue ici mais prise dans un autre
    -- guide (« Voyage vers Ashenvale », prise à Auberdine) n'est demandée que si elle est
    -- dans le journal : sinon ses objectifs sont mis de côté, et rouverts si elle y entre.
    local takenHere = takenBy(guide)
    local reopened = {}
    for _, stepKeys in pairs(result.reopen) do
        for stepKey in pairs(stepKeys) do
            reopened[stepKey] = true
        end
    end
    -- Une étape retenue « hors sujet » est réévaluée tant qu'une de ses quêtes est dans
    -- le journal : une quête qu'on a ne la rend pas hors sujet. Le jeu retire une quête
    -- rendue du journal un instant avant d'annoncer son rendu ; vue abandonnée, elle
    -- emportait les étapes suivantes, retenues hors sujet (sac de couchage : « Cent pas
    -- vers le nord » et le barrage, passés alors que « Travail humide » était en cours).
    for i, step in ipairs(guide.steps) do
        local key = keys.steps[i]
        if progress.outcomes[key] == "na" then
            for _, goal in ipairs(step.goals) do
                if goal.quest and state:InLog(goal.quest) then
                    reopened[key] = true
                    break
                end
            end
        end
    end

    local goalCtx = {
        droppedQuests = droppedQuests,
        notOffered = ctx.notOffered or {}, -- quêtes que leur PNJ ne propose pas (Live.lua)
        trainedLevel = ctx.trainedLevel,   -- niveau de la dernière visite au maître de classe
        spellsToLearn = ctx.spellsToLearn, -- nombre de sorts à apprendre (nil sans données)
        seen = function(goal)
            local key = keys.byGoal[goal]
            return key ~= nil and (ctx.seen[key] or progress.ticks[key]) == true
        end,
    }

    local function outcomeOf(i)
        return evaluated[i] or progress.outcomes[keys.steps[i]]
    end

    local function conditionCtx(along)
        return {
            along = along,
            dungeons = ctx.dungeons or {},
            answer = function(q)
                return ctx.answers[q]
            end,
            labelDone = function(label)
                local i = keys.labels[label]
                return i ~= nil and outcomeOf(i) == "done"
            end,
        }
    end

    local function applies(i)
        local step = guide.steps[i]
        if not Conditions.Matches(step.only, state) then
            return false
        end
        if step.when and not progress.forced[keys.steps[i]] then
            return Conditions.AllHold(step.when, state, conditionCtx(step.along ~= nil))
        end
        return true
    end

    -- Objectifs d'une étape : statuts, l'étape est-elle retenue, et pourquoi bloquée.
    local function evaluateGoals(i)
        local step = guide.steps[i]
        local list = {}
        for j, goal in ipairs(step.goals) do
            -- Objectif ou quête ignorés par le joueur : hors sujet, comme une étape ignorée.
            local q = goal.quest
            if ignoredGoals[keys.goals[i][j]] or (q and ignoredQuests[q]) then
                list[j] = { status = "na", reason = { kind = "ignored" } }
            elseif q and goal.t ~= "accept" and acceptedAt[q] and acceptedAt[q] < i
                and not state:InLog(q) and not state:TurnedIn(q) then
                list[j] = { status = "na", reason = { kind = "abandoned" } }
                abandonedHere[q] = true
                local stepKeys = result.abandonedSteps[q] or {}
                result.abandonedSteps[q] = stepKeys
                stepKeys[keys.steps[i]] = true
            elseif q and goal.t ~= "accept" and not takenHere[q]
                and not state:InLog(q) and not state:TurnedIn(q) then
                list[j] = { status = "na", reason = { kind = "notTaken" } }
                local stepKeys = result.abandonedSteps[q] or {}
                result.abandonedSteps[q] = stepKeys
                stepKeys[keys.steps[i]] = true
            else
                list[j] = Goals.Evaluate(goal, state, goalCtx)
            end
        end
        -- Escorte : « aller voir » le PNJ escorté (là où il attend) est fait dès que sa
        -- quête est dans le journal, puisqu'il quitte cet endroit pendant l'escorte
        -- (Kerlonian Evershade, quête 5321 : l'étape restait bloquée sans flèche).
        for j, goal in ipairs(step.goals) do
            local npc = goal.t == "goto" and tonumber((goal.text or ""):match("^{npc:(%d+)}$"))
            if npc and list[j].status ~= "done" then
                for _, other in ipairs(step.goals) do
                    if other.t == "accept" and other.escort and other.npc == npc and other.quest
                        and (state:InLog(other.quest) or state:TurnedIn(other.quest)) then
                        list[j] = { status = "done", implied = true }
                    end
                end
            end
        end
        -- Un déplacement est accompli dès qu'un objectif suivant l'est.
        local laterDone = false
        for j = #step.goals, 1, -1 do
            local goal = step.goals[j]
            if laterDone and Goals.TRAVEL[goal.t] and Goals.Holds(goal, list[j].status) then
                list[j] = { status = "done", implied = true }
            end
            if list[j].status == "done" then
                laterDone = true
            end
        end
        local holding, onlyBlocked, reason, relevant = false, true, nil, false
        for j, goal in ipairs(step.goals) do
            if goal.t == "accept" and list[j].status == "na" then
                droppedQuests[goal.quest] = true
            end
            if list[j].status ~= "na" and list[j].status ~= "info" then
                relevant = true
            end
            if Goals.Holds(goal, list[j].status) then
                holding = true
                if list[j].status == "blocked" then
                    reason = reason or list[j].reason
                else
                    onlyBlocked = false
                end
            end
        end
        -- relevant : au moins un objectif concerne le personnage (sinon l'étape est hors sujet).
        return list, holding, holding and onlyBlocked and reason or nil, relevant
    end

    local function dropAccepts(i)
        for _, goal in ipairs(guide.steps[i].goals) do
            if goal.t == "accept" and goal.quest then
                droppedQuests[goal.quest] = true
            end
        end
    end

    local function firstJump(i)
        for _, jump in ipairs(guide.steps[i].skipto or {}) do
            if Conditions.Holds(jump.when, state, conditionCtx(false)) == true then
                return jump.to
            end
        end
    end

    local current, jumpTo, jumpFrom
    local alongSteps = {}

    for i, step in ipairs(guide.steps) do
        local key = keys.steps[i]
        local entry = { key = key }
        result.steps[i] = entry
        if jumpTo and step.label == jumpTo then
            jumpTo = nil
        end

        if progress.skipped[key] then
            entry.status = "skipped"
        elseif current then
            -- Après l'étape courante : aperçu, rien n'est mémorisé.
            local applying = applies(i)
            if applying == false then
                entry.status = "na"
            else
                entry.status = "ahead"
                entry.goals = evaluateGoals(i)
            end
        elseif progress.outcomes[key] and not reopened[key] then
            entry.status = progress.outcomes[key]
        elseif jumpTo then
            entry.status = "jumped"
            result.jumpOrigin[key] = jumpFrom
            result.passed[key] = "jumped"
        else
            local applying = applies(i)
            if applying == false then
                entry.status = "na"
            elseif applying == "ask" then
                entry.status = "ask"
                result.ask = { quest = firstGroupQuest(step.when) }
                current = i
            elseif step.along then
                entry.status = "along"
            else
                local goals, holding, blockReason, relevant = evaluateGoals(i)
                entry.goals = goals
                if not holding then
                    entry.status = relevant and "done" or "na"
                else
                    local target = not progress.noJump[key] and firstJump(i)
                    if target then
                        entry.status = "jumped"
                        jumpTo, jumpFrom = target, key
                        result.jumpOrigin[key] = key
                    else
                        entry.status = "current"
                        entry.blocked = blockReason
                        current = i
                    end
                end
            end
            if entry.status ~= "current" and entry.status ~= "ask" then
                result.passed[key] = entry.status
            end
        end

        -- Quêtes acceptées par une étape faite (pour reconnaître un abandon plus loin).
        if not current and (entry.status == "done") then
            for _, goal in ipairs(step.goals) do
                if goal.t == "accept" and goal.quest and not acceptedAt[goal.quest] then
                    acceptedAt[goal.quest] = i
                end
            end
        end

        if not current or i < current then
            if PASSED[entry.status] then
                evaluated[i] = entry.status
            end
            if NOT_APPLYING[entry.status] then
                dropAccepts(i)
            elseif entry.status == "along" then
                alongSteps[#alongSteps + 1] = i
            end
        end
    end

    result.current = current
    result.finished = current == nil
    if result.finished then
        result.next = guide.next
    end

    -- Objectifs à faire en chemin : jusqu'au label indiqué (along = "label"), ou
    -- jusqu'à ce qu'ils soient accomplis.
    if current then
        for _, i in ipairs(alongSteps) do
            local untilIndex = type(guide.steps[i].along) == "string" and keys.labels[guide.steps[i].along]
            if not untilIndex or untilIndex > current then
                local goals = evaluateGoals(i)
                for j, goal in ipairs(guide.steps[i].goals) do
                    local status = goals[j].status
                    if status == "todo" or status == "manual" or status == "blocked" then
                        result.along[#result.along + 1] = {
                            step = i, goal = j, status = status, optional = goal.optional,
                        }
                    end
                end
            end
        end
    end

    -- Quêtes acceptées dans une étape dépassée, absentes du journal et pas rendues,
    -- alors que le guide les rend plus loin : abandonnées. Seulement celles que le
    -- personnage peut reprendre et qui retiendraient l'étape rouverte : pas une quête
    -- réservée à une autre race ou classe, fermée, sans son prérequis, ou facultative
    -- (sinon le clic « reprendre » ne changerait rien).
    if current then
        local handedInAhead = {}
        for i = current, #guide.steps do
            for _, goal in ipairs(guide.steps[i].goals) do
                if goal.t == "turnin" and goal.quest and Conditions.Matches(goal.only, state) then
                    handedInAhead[goal.quest] = true
                end
            end
        end
        for i = 1, current - 1 do
            if outcomeOf(i) == "done" then
                for _, goal in ipairs(guide.steps[i].goals) do
                    local q = goal.t == "accept" and goal.quest
                    if q and handedInAhead[q] and not state:InLog(q) and not state:TurnedIn(q)
                        and Goals.Holds(goal, Goals.Evaluate(goal, state, goalCtx).status) then
                        result.abandoned[#result.abandoned + 1] = { quest = q, step = i }
                    end
                end
            end
        end
    end

    -- Quêtes abandonnées dont le rendu a été mis de côté : proposées à la reprise.
    local listed = {}
    for _, entry in ipairs(result.abandoned) do
        listed[entry.quest] = true
    end
    for q in pairs(abandonedHere) do
        local i = acceptedAt[q]
        if not listed[q] and i then
            for _, goal in ipairs(guide.steps[i].goals) do
                if goal.t == "accept" and goal.quest == q
                    and Goals.Holds(goal, Goals.Evaluate(goal, state, goalCtx).status) then
                    result.abandoned[#result.abandoned + 1] = { quest = q, step = i }
                    listed[q] = true
                end
            end
        end
    end

    -- Détours : quêtes du journal que ce guide ne cite pas.
    local cited = {}
    for _, step in ipairs(guide.steps) do
        for _, goal in ipairs(step.goals) do
            if goal.quest then
                cited[goal.quest] = true
            end
        end
    end
    for _, q in ipairs(state:LogQuests() or {}) do
        if not cited[q] then
            result.detours[#result.detours + 1] = q
        end
    end

    -- Mode libre : objectifs ouverts de l'étape courante et des suivantes au même
    -- endroit (même carte), jusqu'à un trajet en vol ou par la pierre de foyer.
    if current then
        local anchor = firstLocated(guide.steps[current])
        local count = 0
        for i = current, #guide.steps do
            local entry = result.steps[i]
            if entry.status == "current" or entry.status == "ahead" then
                local located = firstLocated(guide.steps[i])
                if i > current and (hasTrip(guide.steps[i]) or (anchor and located and located.map ~= anchor.map)) then
                    break
                end
                count = count + 1
                if count > Engine.FREE_STEPS then
                    break
                end
                for j, goal in ipairs(guide.steps[i].goals) do
                    local status = entry.goals and entry.goals[j].status
                    if status == "todo" or status == "manual" or status == "blocked" then
                        result.free[#result.free + 1] = {
                            step = i, goal = j, status = status, optional = goal.optional,
                        }
                    end
                end
            end
        end
    end

    -- Conseils : personnage en avance sur le guide, quêtes grises à venir.
    local level = state:Level()
    local grey = Engine.GreyLevel(level)
    local greyAhead = 0
    for i = current or #guide.steps + 1, #guide.steps do
        for j, goal in ipairs(guide.steps[i].goals) do
            local goals = result.steps[i].goals
            if goal.t == "accept" and goal.qlvl and goal.qlvl <= grey and goals and goals[j].status == "todo" then
                greyAhead = greyAhead + 1
            end
        end
    end
    result.advice = {
        overleveled = guide.maxLevel ~= nil and level > guide.maxLevel,
        greyAhead = greyAhead,
    }

    return result
end

-- Mémorise le résultat des étapes dépassées. À n'appeler que si l'état du joueur
-- est fiable (journal de quêtes lu).
function Engine.Commit(progress, result)
    -- Quête abandonnée revenue dans le journal : ses étapes passées sont rouvertes.
    progress.abandonedSteps = progress.abandonedSteps or {}
    for q, stepKeys in pairs(result.reopen or {}) do
        for stepKey in pairs(stepKeys) do
            progress.outcomes[stepKey] = nil
        end
        progress.abandonedSteps[q] = nil
    end
    for key, outcome in pairs(result.passed) do
        progress.outcomes[key] = outcome
    end
    for q, stepKeys in pairs(result.abandonedSteps or {}) do
        local known = progress.abandonedSteps[q] or {}
        progress.abandonedSteps[q] = known
        for stepKey in pairs(stepKeys) do
            if result.passed[stepKey] then
                known[stepKey] = true
            end
        end
    end
    for key, origin in pairs(result.jumpOrigin) do
        progress.jumpOrigin[key] = origin
    end
end

---------------------------------------------------------------------------
-- Choix du joueur
---------------------------------------------------------------------------

function Engine.Skip(progress, guide, i)
    progress.skipped[Engine.Keys(guide).steps[i]] = true
end

-- Ignore un seul objectif d'une étape (ou le reprend).
function Engine.IgnoreGoal(progress, guide, i, j, ignored)
    progress.ignoredGoals = progress.ignoredGoals or {}
    progress.ignoredGoals[Engine.Keys(guide).goals[i][j]] = ignored ~= false or nil
end

-- Réactive une étape ignorée, sautée ou hors sujet : elle s'applique alors quelles
-- que soient ses conditions when, et un saut annulé ne se reproduit pas.
function Engine.Unskip(progress, guide, i)
    local key = Engine.Keys(guide).steps[i]
    progress.skipped[key] = nil
    if progress.outcomes[key] == "jumped" then
        local origin = progress.jumpOrigin[key]
        if origin then
            progress.noJump[origin] = true
        end
        progress.jumpOrigin[key] = nil
    end
    if progress.outcomes[key] == "na" then
        progress.forced[key] = true
    end
    progress.outcomes[key] = nil
end

-- Valide (ou dévalide) à la main un objectif que l'addon ne peut pas vérifier.
function Engine.Tick(progress, guide, i, j)
    local key = Engine.Keys(guide).goals[i][j]
    progress.ticks[key] = not progress.ticks[key] or nil
end

---------------------------------------------------------------------------
-- Retour en arrière : annule le dernier « Passer l'étape » ou « Étape faite »
---------------------------------------------------------------------------

local HISTORY = 5    -- actions annulables retenues par guide

-- Note, avant une action du joueur, de quoi l'annuler : l'étape, et les étapes déjà
-- passées (celles que l'action fera passer ensuite seront rouvertes).
function Engine.Remember(progress, guide, i, kind, ticks)
    local before = {}
    for key in pairs(progress.outcomes) do
        before[key] = true
    end
    progress.history = progress.history or {}
    table.insert(progress.history, {
        kind = kind, step = Engine.Keys(guide).steps[i], ticks = ticks, before = before,
    })
    while #progress.history > HISTORY do
        table.remove(progress.history, 1)
    end
end

function Engine.CanGoBack(progress)
    return progress.history ~= nil and #progress.history > 0
end

-- Annule la dernière action retenue. -> true si quelque chose a été annulé.
function Engine.Back(progress)
    local entry = progress.history and table.remove(progress.history)
    if not entry then
        return false
    end
    progress.skipped[entry.step] = nil
    for _, key in ipairs(entry.ticks or {}) do
        progress.ticks[key] = nil
    end
    -- Étapes passées depuis l'action (sa propre étape comprise) : rouvertes.
    for key in pairs(progress.outcomes) do
        if not entry.before[key] then
            progress.outcomes[key] = nil
        end
    end
    progress.outcomes[entry.step] = nil
    return true
end

-- Revient à une étape dépassée (quête abandonnée à reprendre).
function Engine.Reopen(progress, guide, i)
    progress.outcomes[Engine.Keys(guide).steps[i]] = nil
end
