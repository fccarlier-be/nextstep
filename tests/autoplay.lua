-- Joueur automatique : fait ce que demande l'étape courante, jusqu'à la fin du
-- guide. Sert à vérifier que le moteur ne reste coincé dans aucun guide importé.
--
--   local ok, report = autoplay(Engine, guide, player)

local Player = require("player")

local function ensureInLog(player, q)
    if not player:InLog(q) and not player:TurnedIn(q) then
        player:accept(q)
    end
end

-- Accomplit un objectif ; renvoie true si c'est une validation manuelle.
local function act(player, goal, seen, key)
    local t, q = goal.t, goal.quest
    if t == "accept" then
        if goal.minLevel and player.level < goal.minLevel then
            player.level = goal.minLevel
        end
        player:accept(q)
    elseif t == "turnin" then
        ensureInLog(player, q)
        if player:InLog(q) then
            player:turnin(q)
        end
    elseif t == "complete" then
        ensureInLog(player, q)
        if player:InLog(q) then
            player:complete(q)
        end
    elseif q and (t == "kill" or t == "collect" or t == "interact" or t == "use") then
        ensureInLog(player, q)
        if player:InLog(q) then
            if goal.oi then
                player:objective(q, goal.oi)
            else
                player:complete(q)
            end
        end
    elseif (t == "collect" or t == "buy") and goal.item then
        player.items[goal.item] = goal.count or 1
    elseif t == "level" then
        player.level = goal.frac and goal.level + 1 or goal.level
    elseif t == "money" then
        player.money = goal.money
    elseif t == "skill" then
        player.skills[goal.skillLine] = { goal.level, math.max(goal.level, 300) }
    elseif t == "craft" and goal.untilSkill then
        player.skills[goal.skillLine] = { goal.untilSkill, 300 }
    elseif t == "train" and goal.profLine then
        player.skills[goal.profLine] = { 1, goal.rankMax }
    elseif t == "learn" then
        player.spells[goal.spell] = true
    elseif t == "rep" then
        player.standings[goal.faction] = goal.standing
    elseif t == "sethome" then
        player.bound = goal.area
    elseif t == "getfp" and goal.node then
        player.taxi[goal.node] = true
    elseif (t == "fly" or t == "hearth" or t == "enter") and goal.area then
        player.area = goal.area
    else
        seen[key] = true
    end
end

return function(Engine, guide, player, options)
    options = options or {}
    player = player or Player.new()
    local progress, seen, answers = Engine.NewProgress(), {}, {}
    local keys = Engine.Keys(guide)
    local maxRounds = options.maxRounds or (#guide.steps * 4 + 20)
    local lastSignature, stuck = nil, 0

    for _ = 1, maxRounds do
        local result = Engine.Evaluate(guide, {
            state = player, progress = progress, seen = seen, answers = answers,
        })
        Engine.Commit(progress, result)
        if result.finished then
            return true, { progress = progress }
        end
        local i = result.current
        if result.ask then
            answers[result.ask.quest] = false
        else
            local entry = result.steps[i]
            for j, goal in ipairs(guide.steps[i].goals) do
                local status = entry.goals and entry.goals[j].status
                if status == "todo" or status == "manual" or status == "blocked" then
                    act(player, goal, seen, keys.goals[i][j])
                end
            end
        end
        local signature = i .. ":" .. tostring(result.ask and result.ask.quest)
        if signature == lastSignature then
            stuck = stuck + 1
            if stuck >= 3 then
                return false, { step = i, result = result }
            end
        else
            lastSignature, stuck = signature, 0
        end
    end
    return false, { rounds = true }
end
