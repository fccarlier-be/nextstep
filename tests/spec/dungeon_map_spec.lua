local wow = require("wow")

-- Carte des donjons (Modules/UI/DungeonMap.lua) : étage du donjon sur la carte du monde,
-- repères des boss, panneau des étages sans carte du client.

local function boot(options)
    options = options or {}
    local world = { mapID = options.mapID or 1436, set = {}, instance = options.instance }
    local game = wow.boot({
        faction = "Alliance",
        loaded = options.loaded,
        player = { level = 20, map = options.playerMap },
        beforeInit = function()
            _G.MapCanvasDataProviderMixin = {}
            _G.CreateFromMixins = function(mixin)
                local copy = {}
                for key, value in pairs(mixin) do
                    copy[key] = value
                end
                return copy
            end
            _G.IsInInstance = function()
                return world.instance ~= nil, world.instance and "party" or "none"
            end
            _G.GetInstanceInfo = function()
                local instance = world.instance or {}
                return instance.name, "party", 1, "", 5, 0, false, instance.id
            end
            _G.C_Map.GetMapInfo = function(map)
                return { mapID = map, parentMapID = map == 291 and 1436 or 0 }
            end
            local canvas = CreateFrame("Frame")
            canvas.GetWidth = function() return 1000 end
            canvas.GetHeight = function() return 700 end
            canvas.GetFrameLevel = function() return 1 end
            local map = CreateFrame("Frame")
            map.ScrollContainer = CreateFrame("Frame")
            map.providers = {}
            map.dataProviders = {}
            map.AddDataProvider = function(_, provider) map.providers[#map.providers + 1] = provider end
            map.GetCanvas = function() return canvas end
            map.GetCanvasScale = function() return 1 end
            map.EnumeratePinsByTemplate = function() return function() end end
            map.GetMapID = function() return world.mapID end
            map.IsShown = function() return world.shown == true end
            map.SetMapID = function(_, id)
                world.mapID = id
                world.set[#world.set + 1] = id
                for _, provider in ipairs(map.providers) do
                    provider.RefreshAllData()
                end
            end
            world.canvas = canvas
            _G.WorldMapFrame = map
        end,
    })
    world.open = function()
        world.shown = true
        game:runScript(WorldMapFrame, "OnShow")
    end
    return game, game.ns.Modules:Get("DungeonMap"), world
end

-- Boss d'un donjon importé, par son nom anglais.
local function bossNamed(game, key, name)
    for _, boss in ipairs(game.ns.DB.dungeonMaps[key][1].bosses) do
        if boss.name == name then
            return boss
        end
    end
end

local function shownPins(pool)
    local list = {}
    for _, button in ipairs(pool or {}) do
        if button.point then
            list[#list + 1] = button.point
        end
    end
    return list
end

describe("Carte des donjons", function()
    it("retrouve l'étage d'une carte du client et le donjon en cours", function()
        local _, dungeonMap, world = boot()
        expect_eq({ dungeonMap.FloorOfMap(292) }, { "deadmines", 1, 2 })
        expect_eq(dungeonMap:Current(), nil, "hors instance")
        world.instance = { id = 36, name = "Les Mortemines" }
        expect_eq({ dungeonMap:Current() }, { "deadmines", 1 }, "par l'instance, étage inconnu")
    end)

    it("ouvre la carte du monde sur l'étage du donjon, avec ses boss", function()
        local game, dungeonMap, world = boot({ instance = { id = 36 } })
        world.open()
        expect_eq(world.set, { 291 }, "premier étage des Mortemines")
        local kinds, rare = {}, nil
        for _, button in ipairs(dungeonMap.canvasPins) do
            if button.point then
                kinds[button.point.kind] = (kinds[button.point.kind] or 0) + 1
                if button.point.boss and button.point.boss.name == "Miner Johnson" then
                    rare = button.point
                end
            end
        end
        expect(kinds.boss and kinds.boss >= 3, "boss du premier étage")
        expect_eq(kinds.entrance, 1, "entrée")
        expect_eq(kinds.transition, 1, "passage vers l'étage 2")
        expect(rare and rare.kind == "rare", "Miner Johnson est un boss rare")
        expect_eq(dungeonMap.toggle.text, "World map", "bouton de bascule")
        expect_eq(#game.errors, 0, tostring(game.errors[1]))
    end)

    it("laisse la carte si le client montre déjà l'étage du personnage", function()
        local _, _, world = boot({ instance = { id = 36 }, playerMap = 292, mapID = 292 })
        world.open()
        expect_eq(world.set, {}, "aucun changement de carte")
    end)

    it("ne touche pas à la carte hors des donjons", function()
        local _, dungeonMap, world = boot()
        world.open()
        expect_eq(world.set, {})
        expect_eq(dungeonMap:Current(), nil)
    end)

    it("grise un boss tué et l'oublie dans une autre instance", function()
        local game, dungeonMap, world = boot({ instance = { id = 36 } })
        local boss = bossNamed(game, "deadmines", "Rhahk'Zor")
        expect_eq(dungeonMap:IsKilled(boss), false)
        game:fire("ENCOUNTER_END", 1, "Rhahk'Zor", 1, 5, 1)
        expect_eq(dungeonMap:IsKilled(boss), true)
        local lines = dungeonMap:Tooltip({ kind = "boss", boss = boss })
        expect_eq(lines[2][1], "Killed in this instance")
        world.instance = { id = 43 }
        expect_eq(dungeonMap:IsKilled(boss), false, "autre instance")
    end)

    it("reconnaît un boss tué par son numéro de rencontre, quelle que soit la langue", function()
        local game, dungeonMap = boot({ instance = { id = 36 } })
        local boss = bossNamed(game, "deadmines", "Rhahk'Zor")
        expect(boss.encounters and #boss.encounters > 0, "numéro importé")
        game:fire("ENCOUNTER_END", boss.encounters[1], "Rhahk'Zor (nom traduit)", 1, 5, 1)
        expect_eq(dungeonMap:IsKilled(boss), true)
        local other = bossNamed(game, "deadmines", "Sneed")
        expect_eq(dungeonMap:IsKilled(other), false, "les autres boss restent")
        game:fire("ENCOUNTER_END", other.encounters[1], "Sneed", 1, 5, 0)
        expect_eq(dungeonMap:IsKilled(other), false, "combat perdu")
    end)

    it("cache les boss rares et les PNJ de quêtes sur option", function()
        local game, dungeonMap = boot()
        local wing = game.ns.DB.dungeonMaps.deadmines[1]
        local function count(kind)
            local n = 0
            for _, point in ipairs(dungeonMap:Points(wing, 1)) do
                n = n + (point.kind == kind and 1 or 0)
            end
            return n
        end
        expect(count("rare") > 0, "rares affichés par défaut")
        dungeonMap.db.rares = false
        expect_eq(count("rare"), 0, "rares cachés")
        local lordaeron = game.ns.DB.dungeonMaps.lordaeron[1]
        expect(#dungeonMap:Points(lordaeron, 1) > 0)
        local turnins = 0
        for _, point in ipairs(dungeonMap:Points(lordaeron, 1)) do
            turnins = turnins + (point.kind == "turnin" and 1 or 0)
        end
        expect_eq(turnins, 1, "Captain Truman")
        dungeonMap.db.quests = false
        for _, point in ipairs(dungeonMap:Points(lordaeron, 1)) do
            expect(point.kind ~= "turnin", "PNJ de quêtes cachés")
        end
    end)

    it("montre un donjon de Forever sans carte du client sur son panneau", function()
        local game, dungeonMap, world = boot({ instance = { name = "Hall of Thanes" },
            loaded = { "ForeverDungeonJournal" } })
        world.open()
        expect_eq(world.set, {}, "la carte native ne change pas")
        expect(dungeonMap.panel, "panneau créé")
        expect_eq(dungeonMap.panel.title.text, "Hall of Thanes")
        expect_eq(#game.errors, 0, tostring(game.errors[1]))
        expect(#shownPins(dungeonMap.panel.pins) >= 4, "boss sur le panneau")
        expect_eq(dungeonMap.credit.text, "Map details: DungeonJournal (Exehn)")
        expect_eq(#game.errors, 0, tostring(game.errors[1]))
    end)

    it("crédite Santiago Reyes sur ses cartes", function()
        local _, dungeonMap = boot()
        dungeonMap:UpdateCredit({ image = "x", reyes = true })
        expect(dungeonMap.credit.text:find("Santiago Reyes", 1, true), tostring(dungeonMap.credit.text))
    end)

    it("rebascule vers la carte de la zone", function()
        local _, dungeonMap, world = boot({ instance = { id = 36 } })
        world.open()
        dungeonMap:ShowWorld()
        expect_eq(world.mapID, 1436, "carte parente de l'étage")
    end)

    it("prévient une fois si DungeonJournal recouvre la carte du monde", function()
        local game, _, world = boot({ instance = { id = 36 }, loaded = { "ForeverDungeonJournal" } })
        _G.ForeverDungeonJournalDB = {}
        world.open()
        world.open()
        local _, count = game:chatText():gsub("DungeonJournal shows its own dungeon map", "")
        expect_eq(count, 1)
        _G.ForeverDungeonJournalDB = nil
    end)
end)
