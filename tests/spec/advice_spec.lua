local wow = require("wow")
local Player = require("player")

-- Mode conseil (Modules/Guide/Advice.lua) et onglet Zones (Modules/Guide/Zones.lua).

local function boot(player)
    local game = wow.boot({
        faction = "Alliance",
        player = { level = player.level or 1 },
        beforeInit = function()
            -- Noms anglais des cartes, comme le client.
            _G.C_Map.GetMapInfo = function(map)
                return { mapID = map, name = ({ [1436] = "Westfall", [1429] = "Elwynn Forest" })[map] }
            end
        end,
    })
    local Guide = game.ns.Modules:Get("Guide")
    local state = Player.new(player)
    for quest in pairs(player.done or {}) do
        state.done[quest] = true
    end
    Guide:SetState(state)
    return game, Guide
end

local function has(list, id)
    for _, quest in ipairs(list) do
        if quest.id == id then
            return true
        end
    end
    return false
end

describe("Mode conseil", function()
    it("propose les quêtes que le personnage peut prendre", function()
        local _, Guide = boot({ race = "HUMAN", class = "WARRIOR", level = 2 })
        local list = Guide:AvailableQuests()
        expect(#list > 0)
        expect(has(list, 783), "Une menace dans la vallée (Northshire)")
        expect(not has(list, 7), "Nettoyage du camp kobold : il faut d'abord rendre la 783")
        expect(not has(list, 8), "quête de la Horde")
        for _, quest in ipairs(list) do
            expect(quest.min <= 2 and quest.level <= 5, "niveau adapté : " .. quest.id)
        end
    end)

    it("suit les prérequis, la classe et les quêtes faites", function()
        local _, Guide = boot({ race = "HUMAN", class = "WARRIOR", level = 3, done = { [783] = true } })
        local list = Guide:AvailableQuests()
        expect(has(list, 7), "suite débloquée")
        expect(not has(list, 783), "déjà rendue")
    end)

    it("range les zones, à son niveau d'abord, avec leurs quêtes", function()
        local game, Guide = boot({ race = "HUMAN", class = "WARRIOR", level = 12 })
        local zones = Guide:ZoneList()
        expect(#zones > 0)
        expect(zones[1].fits, "une zone à son niveau en tête")
        local westfall
        for _, zone in ipairs(zones) do
            if zone.map == 1436 then
                westfall = zone
            end
        end
        expect(westfall and #westfall.quests > 0, "des quêtes en Marche de l'Ouest au niveau 12")
        local rows = Guide:ZoneDetailRows(1436)
        local texts = {}
        for _, row in ipairs(rows) do
            texts[#texts + 1] = row.text
        end
        local all = table.concat(texts, " | ")
        expect(all:find("Guide:", 1, true), "guide de leveling de la zone : " .. all)
        expect(all:find("Deadmines", 1, true) or all:find("#1581", 1, true), "donjon des Mortemines : " .. all)
        local clicked
        for _, row in ipairs(rows) do
            if row.onClick and row.text:find("%[") and not clicked then
                clicked = true
                row.onClick()
            end
        end
        expect(Guide.pointTarget, "la flèche pointe un donneur")
        Guide:ToggleJournal("zones")
        expect_eq(#game.errors, 0)
    end)
end)
