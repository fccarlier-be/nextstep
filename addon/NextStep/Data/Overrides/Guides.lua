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
-- Prérequis inconnus de Polestar, constatés en jeu.
-- 98191, suite de « Proche de la famille » (98190) chez Bolvar Fordragon, suppose 98190
-- rendue (Stoutfist ne propose 98190 qu'après « Rapporter la statuette », 2026-11-09 ;
-- Polestar 0.3.5 connaît ce premier lien, pas le second).
---------------------------------------------------------------------------

local EXTRA_PRE = {
    [98191] = 98190,
}

DB:AddGuideFix(function(guide)
    eachGoal(guide, function(goal)
        -- goal.pre se lit « l'une de ces quêtes rendue » : on ne complète pas une liste
        -- existante, ce qui affaiblirait la condition.
        local pre = goal.t == "accept" and EXTRA_PRE[goal.quest]
        if pre and not goal.pre then
            goal.pre = { pre }
        end
    end)
end)
