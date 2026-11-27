-- Prévision de niveau : à quelle étape du guide le personnage montera de niveau, et
-- s'il sera au niveau que demande la prochaine étape « atteindre le niveau X ».
--
-- Compte seulement l'expérience des quêtes que le guide fait rendre d'ici là
-- (DB.questXP, forever-db), réduite comme dans le jeu quand le personnage dépasse le
-- niveau de la quête. Les monstres tués en chemin n'y sont pas : la prévision est
-- prudente, le personnage arrive en général un peu plus haut.

local _, ns = ...

local Pace = {}
ns.GuidePace = Pace

-- Expérience pour passer chaque niveau, au Classic. Le niveau en cours prend la valeur
-- du jeu (UnitXPMax) ; les suivants sont mis à la même échelle, au cas où Forever
-- aurait changé la courbe.
local XP_TO_LEVEL = {
    400, 900, 1400, 2100, 2800, 3600, 4500, 5400, 6500, 7600,
    8800, 10100, 11400, 12900, 14400, 16000, 17700, 19400, 21300, 23200,
    25200, 27300, 29400, 31700, 34000, 36400, 38900, 41400, 44300, 47400,
    50800, 54500, 58600, 62800, 67100, 71600, 76100, 80800, 85700, 90700,
    95800, 101000, 106300, 111800, 117500, 123200, 129100, 135100, 141200, 147500,
    153900, 160400, 167100, 173900, 180800, 187900, 195000, 202300, 209800,
}
Pace.XP_TO_LEVEL = XP_TO_LEVEL

-- Part de l'expérience d'une quête selon l'écart entre le personnage et la quête.
local REDUCED = { [6] = 0.8, [7] = 0.6, [8] = 0.4, [9] = 0.2 }

-- Barres de la jauge d'expérience : 20 par niveau.
local BARS = 20

-- Niveau et expérience au rendu d'une quête ; nil si la quête est inconnue.
function Pace.QuestInfo(quest)
    local packed = ns.DB.questXP and ns.DB.questXP[quest]
    if not packed then
        return nil
    end
    local level = packed % 100
    local xp = (packed - level) / 100
    if xp == 0 then
        xp = ns.DB.questXPByLevel and ns.DB.questXPByLevel[level] or 0
    end
    return level, xp
end

-- Expérience que rapporte une quête à un personnage de ce niveau.
function Pace.QuestXP(quest, playerLevel)
    local level, xp = Pace.QuestInfo(quest)
    if not level then
        return 0
    end
    local diff = playerLevel - level
    if diff <= 5 then
        return xp
    end
    return math.floor(xp * (REDUCED[diff] or 0.1) / 5 + 0.5) * 5
end

-- Calcule la prévision pour le résultat du moteur. level, fraction : niveau et part de
-- la jauge remplie ; maxXP : expérience du niveau en cours (UnitXPMax).
-- Renvoie nil sans prévision possible (niveau maximum, pas d'étape en cours), sinon
-- { level, step = étape du passage au niveau suivant (nil : pas avant la fin du guide),
--   goal = { level, step, missing = expérience manquante, bars } ou nil }.
function Pace.Forecast(result, level, fraction, maxXP)
    local current = result and result.current
    if not current or not maxXP or maxXP <= 0 or not XP_TO_LEVEL[level] then
        return nil
    end
    local scale = maxXP / XP_TO_LEVEL[level]
    local function need(l)
        return XP_TO_LEVEL[l] and XP_TO_LEVEL[l] * scale or math.huge
    end

    local simLevel, simXP = level, (fraction or 0) * maxXP
    local function gain(xp)
        simXP = simXP + xp
        while simXP >= need(simLevel) do
            simXP = simXP - need(simLevel)
            simLevel = simLevel + 1
        end
    end
    -- Expérience qui manque, au point atteint, pour le niveau l (et la part frac).
    local function missingFor(l, frac)
        local missing, at = -simXP, simLevel
        while at < l do
            missing = missing + need(at)
            at = at + 1
        end
        return missing + (frac or 0) * need(l)
    end

    local forecast = { level = level + 1 }
    local counted = {}
    local function turnIn(goal, status)
        if goal.t == "turnin" and goal.quest and status ~= "done" and status ~= "na" and not counted[goal.quest] then
            counted[goal.quest] = true
            gain(Pace.QuestXP(goal.quest, simLevel))
        end
    end
    -- Objectifs en chemin : rendus en même temps que l'étape en cours.
    local steps = result.guide.steps
    for _, entry in ipairs(result.along or {}) do
        turnIn(steps[entry.step].goals[entry.goal], entry.status)
    end

    local numbers = result.stepNumbers or {}
    local pendingStep = false
    for i = current, #steps do
        local entry = result.steps[i]
        if entry and (entry.status == "current" or entry.status == "ahead") then
            if pendingStep and numbers[i] then
                forecast.step, pendingStep = i, false
            end
            for j, goal in ipairs(steps[i].goals) do
                local status = entry.goals and entry.goals[j] and entry.goals[j].status
                if goal.t == "level" and not forecast.goal and status ~= "done" and status ~= "na"
                    and goal.level and goal.level > level then
                    local missing = missingFor(goal.level, goal.frac)
                    forecast.goal = {
                        level = goal.level,
                        step = i,
                        missing = math.max(0, missing),
                        bars = math.max(0, math.ceil(missing / need(math.max(simLevel, goal.level - 1)) * BARS)),
                    }
                end
                turnIn(goal, status)
            end
            if simLevel > level and not forecast.step and not pendingStep then
                if numbers[i] then
                    forecast.step = i
                else
                    pendingStep = true
                end
            end
        end
        if forecast.step and forecast.goal then
            break
        end
    end
    return forecast
end

---------------------------------------------------------------------------
-- Expérience par heure, sur la session
---------------------------------------------------------------------------

local MIN_SECONDS = 300 -- pas d'estimation avant 5 minutes de jeu

function Pace.NewSession(now, level, xp, maxXP)
    return { start = now, gained = 0, level = level, xp = xp, maxXP = maxXP }
end

-- Expérience reçue depuis le dernier relevé (passage de niveau compris).
function Pace.Update(session, level, xp, maxXP)
    if level == session.level then
        session.gained = session.gained + math.max(0, xp - session.xp)
    elseif level > session.level then
        session.gained = session.gained + math.max(0, session.maxXP - session.xp) + xp
    end
    session.level, session.xp, session.maxXP = level, xp, maxXP
end

-- Secondes avant le niveau suivant à ce rythme, ou nil.
function Pace.SecondsToLevel(session, now, xp, maxXP)
    local elapsed = now - session.start
    if elapsed < MIN_SECONDS or session.gained <= 0 or not maxXP or maxXP <= 0 then
        return nil
    end
    return (maxXP - xp) / (session.gained / elapsed)
end
