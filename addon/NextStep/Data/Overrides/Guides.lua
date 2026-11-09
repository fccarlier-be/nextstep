-- Corrections des guides importés (docs/DATA_SOURCES.md, « Corrections propres à
-- NextStep ») : écrites à la main, appliquées à chaque guide quand il est chargé, après
-- les données de Polestar ; elles survivent aux réimports.
--
-- Une correction : DB:AddGuideFix(function(guide) ... end). Elle modifie le guide en
-- place ; elle doit rester sans effet sur les guides qu'elle ne concerne pas.

local _, ns = ...
local DB = ns.DB

local function eachGoal(guide, fn)
    for _, step in ipairs(guide.steps or {}) do
        for _, goal in ipairs(step.goals or {}) do
            fn(goal, step)
        end
    end
end

---------------------------------------------------------------------------
-- Tube en bronze (objet 4371) : Herble Baubbletump (PNJ 3133), à Sombre-Comté, n'en vend
-- pas sur Forever (vérifié en jeu le 2026-11-09). Neal Allen (PNJ 1448), à Port de
-- Menethil, en vend : l'achat va chez lui. Position : forever-db (carte 1437).
---------------------------------------------------------------------------

local BRONZE_TUBE, HERBLE, NEAL_ALLEN = 4371, 3133, 1448
local NEAL_ALLEN_SPOT = { map = 1437, x = 10.75, y = 56.75 }

local TUBE_NOTE = GetLocale() == "frFR"
    and "{item:4371} : {npc:3133} n'en vend pas sur Forever ; {npc:1448}, à {area:150}, en vend."
    or "{item:4371}: {npc:3133} does not sell it on Forever; {npc:1448} in {area:150} does."

DB:AddGuideFix(function(guide)
    eachGoal(guide, function(goal, step)
        if goal.t == "buy" and goal.item == BRONZE_TUBE and goal.npc == HERBLE then
            goal.npc = NEAL_ALLEN
            goal.map, goal.x, goal.y, goal.z, goal.f = NEAL_ALLEN_SPOT.map, NEAL_ALLEN_SPOT.x, NEAL_ALLEN_SPOT.y,
                nil, nil
            goal.note = TUBE_NOTE
            if type(step.note) == "string" and step.note:find("{npc:3133}", 1, true) then
                step.note = TUBE_NOTE
            end
        end
    end)
end)

---------------------------------------------------------------------------
-- Lingots de sancteforge (quête 526) : Glorin Steelbrow (PNJ 1217), à Port de Menethil,
-- ne la propose pas sur Forever (vérifié en jeu le 2026-11-09, chasseur niveau 26, sans
-- la chaîne de la Flotte maudite). Les mêmes 5 lingots sont demandés par « Les lingots
-- perdus » (324), de cette chaîne, que les guides suivent déjà. On retire l'acceptation ;
-- le ramassage et le rendu, dans un autre guide, sont passés tant que la quête n'est
-- pas dans le journal.
---------------------------------------------------------------------------

local LIGHTFORGE_INGOTS = 526

DB:AddGuideFix(function(guide)
    for _, step in ipairs(guide.steps or {}) do
        local goals = step.goals or {}
        for i = #goals, 1, -1 do
            local goal = goals[i]
            if goal.t == "accept" and goal.quest == LIGHTFORGE_INGOTS and #goals > 1 then
                table.remove(goals, i)
            end
        end
    end
end)
