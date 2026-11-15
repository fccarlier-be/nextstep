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
