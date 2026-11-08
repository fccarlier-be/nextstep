local wow = require("wow")
local Player = require("player")

-- Célébration de niveau (Modules/Guide/Celebration.lua).

local function boot(player)
    local game = wow.boot({ faction = "Alliance" })
    local Guide = game.ns.Modules:Get("Guide")
    Guide:SetState(player)
    return game, Guide
end

describe("Célébration de niveau", function()
    it("annonce les sorts du maître et la quête de classe du niveau", function()
        local game, Guide = boot(Player.new({ race = "NIGHTELF", class = "HUNTER", level = 10 }))
        local played = 0
        _G.PlaySound = function() played = played + 1 end
        Guide:Celebrate(10)
        local texts = {}
        for _, line in ipairs(Guide.celebrationLines) do
            texts[#texts + 1] = line.text
        end
        local all = table.concat(texts, " | ")
        expect(all:find("New spells at your trainer", 1, true), all)
        expect(all:find("Class quest available", 1, true), "familier du chasseur : " .. all)
        expect_eq(played, 1, "un son du jeu")
        expect_eq(#game.errors, 0)
    end)

    it("conseille la suite quand le guide suivi est dépassé", function()
        local _, Guide = boot(Player.new({ race = "HUMAN", class = "WARRIOR", level = 13 }))
        Guide:Start("forever/alliance/human/01-elwynn-forest")
        local lines = Guide:CelebrationLines(13)
        local found = false
        for _, line in ipairs(lines) do
            found = found or line.text:find("Suggested next", 1, true) ~= nil
        end
        expect(found, "guide d'Elwynn dépassé au niveau 13")
    end)

    it("attend la fin du combat", function()
        local game, Guide = boot(Player.new({ race = "HUMAN", class = "WARRIOR", level = 6 }))
        game.inCombat = true
        Guide:Celebrate(6)
        expect_eq(Guide.celebrationLines, nil, "rien en combat")
        game.inCombat = false
        game:fire("PLAYER_REGEN_ENABLED")
        expect(Guide.celebrationLines, "bandeau après le combat")
        expect(not game:isEventRegistered("PLAYER_REGEN_ENABLED"))
    end)

    it("se coupe dans les options", function()
        local _, Guide = boot(Player.new({ race = "HUMAN", class = "WARRIOR", level = 5 }))
        Guide.db.celebration = false
        Guide:Celebrate(5)
        expect_eq(Guide.celebration, nil, "pas de bandeau")
    end)
end)
