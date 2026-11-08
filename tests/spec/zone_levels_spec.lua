local wow = require("wow")

-- Niveau des zones (Modules/UI/ZoneLevels.lua).

local NAMES = { [1436] = "Westfall", [1411] = "Durotar", [1429] = "Elwynn Forest" }

local function boot(level)
    local world = { label = {}, mapID = 1436 }
    local game = wow.boot({
        faction = "Alliance",
        player = { level = level or 12 },
        beforeInit = function()
            _G.C_Map.GetMapInfo = function(map)
                return { mapID = map, name = NAMES[map] or ("Map " .. map) }
            end
            local label = setmetatable({ Name = {} }, { __index = function() return function() end end })
            function label.SetLabel() end
            function label.ClearLabel() end
            world.label = label
            local provider = { Label = label }
            _G.WorldMapFrame = setmetatable({
                ScrollContainer = CreateFrame("Frame"),
                dataProviders = { [provider] = true },
                GetMapID = function() return world.mapID end,
                OnMapChanged = function() end,
                EnumeratePinsByTemplate = function() return function() end end,
            }, { __index = function() return function() end end })
        end,
    })
    return game, game.ns.Modules:Get("ZoneLevels"), world
end

describe("Niveau des zones", function()
    it("prend la tranche des guides, sinon celle du Classic", function()
        local _, zones = boot()
        local low, high = zones:Range(1436)
        expect(low and high and low <= high, "Marche de l'Ouest d'après les guides")
        expect_eq({ zones:Range(1411) }, { 1, 10 }, "Durotar : tranche du Classic (pas de guide Alliance)")
        expect_eq(zones:Range(999999), nil)
    end)

    it("colore la tranche selon le niveau du personnage", function()
        local _, zones = boot()
        local Color = zones.Color
        expect_eq(Color(20, 30, 10)[1], 1, "bien au-dessus : rouge")
        expect_eq(Color(20, 30, 31)[1], 0.55, "en dessous : gris")
        expect_eq(Color(20, 30, 22)[2], 0.82, "dedans : jaune")
    end)

    it("ajoute la tranche au nom de la zone survolée et au titre de la carte", function()
        local game, zones, world = boot(5)
        expect(zones.attached, "accroché à la carte du monde")
        world.label:SetLabel(1, "Durotar")
        expect(zones.hoverText.text:find("1-10", 1, true), tostring(zones.hoverText.text))
        world.label:SetLabel(1, "Somewhere")
        expect_eq(zones.hoverText.text, "", "zone inconnue : rien")
        WorldMapFrame:OnMapChanged()
        expect(zones.titleText.text:find("Levels", 1, true), "titre de la carte de la zone")
        expect_eq(#game.errors, 0, tostring(game.errors[1]))
    end)
end)
