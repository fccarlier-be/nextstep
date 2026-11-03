local wow = require("wow")

local function trackFaction(received)
    return function(ns)
        ns.Events:RegisterMessage("NEXTSTEP_FACTION_LOADED", "test", function(_, _, faction)
            received[#received + 1] = faction
        end)
    end
end

describe("Données de faction", function()
    it("charge seulement les données Alliance pour un personnage Alliance", function()
        local received = {}
        local game = wow.boot({ faction = "Alliance", beforeInit = trackFaction(received) })
        expect(game.loaded.NextStep_Alliance)
        expect(not game.loaded.NextStep_Horde)
        expect(game.ns.Factions.loaded.Alliance, "les données sont enregistrées")
        expect_eq(game.ns.Factions.faction, "Alliance")
        expect_eq(received, { "Alliance" })
    end)

    it("charge seulement les données Horde pour un personnage Horde", function()
        local game = wow.boot({ faction = "Horde" })
        expect(game.loaded.NextStep_Horde)
        expect(not game.loaded.NextStep_Alliance)
    end)

    it("attend que la faction d'un personnage neutre soit connue", function()
        local game = wow.boot({ faction = "Neutral" })
        expect(not game.loaded.NextStep_Alliance and not game.loaded.NextStep_Horde)
        game.faction = "Horde"
        game:fire("UNIT_FACTION", "target")
        expect(not game.loaded.NextStep_Horde, "seul le joueur compte")
        game:fire("UNIT_FACTION", "player")
        expect(game.loaded.NextStep_Horde)
        expect(not game:isEventRegistered("UNIT_FACTION"), "plus besoin d'écouter")
    end)

    it("prévient si l'addon de faction est désactivé", function()
        local game = wow.boot({ faction = "Alliance", disabled = { NextStep_Alliance = true } })
        expect(not game.loaded.NextStep_Alliance)
        expect(game:chatText():find("NextStep_Alliance"), "le joueur est prévenu")
    end)
end)
