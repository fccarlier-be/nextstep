local wow = require("wow")

-- Valeurs de vie et de ressources (Modules/UI/UnitText.lua).

local function boot(options)
    options = options or {}
    local world = { cvars = { statusText = "0", statusTextDisplay = "NONE" }, health = {}, plates = {} }
    local game = wow.boot({
        saved = options.saved,
        beforeInit = function()
            _G.C_CVar = {
                GetCVar = function(name) return world.cvars[name] end,
                SetCVar = function(name, value) world.cvars[name] = value end,
            }
            _G.UnitHealth = function(unit) return world.health[unit] and world.health[unit][1] end
            _G.UnitHealthMax = function(unit) return world.health[unit] and world.health[unit][2] end
            _G.UnitHealthPercent = function(unit)
                local h = world.health[unit]
                return h and h[1] / h[2] * 100
            end
            _G.AbbreviateNumbers = function(value) return ("%.1fk"):format(value / 1000) end
            _G.BreakUpLargeNumbers = function(value) return tostring(value) end
            _G.C_NamePlate = { GetNamePlateForUnit = function(unit) return world.plates[unit] end }
        end,
    })
    return game, game.ns.Modules:Get("UnitText"), world
end

local function plate()
    return CreateFrame("Frame")
end

describe("Valeurs de vie et de ressources", function()
    it("active le texte de statut natif et rend les réglages d'origine", function()
        local game, module, world = boot()
        expect_eq(world.cvars.statusText, "1")
        expect_eq(world.cvars.statusTextDisplay, "BOTH")
        game.ns.Modules:SetEnabled("UnitText", false)
        expect_eq(world.cvars.statusText, "0", "réglage d'origine rendu")
        expect_eq(world.cvars.statusTextDisplay, "NONE")
        expect_eq(module.db.saved, nil)
    end)

    it("affiche la vie sous la barre de nom, et la suit", function()
        local game, module, world = boot()
        world.plates.nameplate1 = plate()
        world.health.nameplate1 = { 4500, 6000 }
        game:fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
        local text = module.texts[world.plates.nameplate1]
        expect_eq(text.text, "4.5k (75%)")
        world.health.nameplate1 = { 3000, 6000 }
        game:fire("UNIT_HEALTH", "nameplate1")
        expect_eq(text.text, "3.0k (50%)")
        module.db.plateFormat = "full"
        module:RefreshPlates()
        expect_eq(text.text, "3000 / 6000")
        game:fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
        expect_eq(module.units.nameplate1, nil)
        expect_eq(#game.errors, 0)
    end)

    it("passe à une forme plus simple quand une valeur secrète refuse le calcul", function()
        local game, module, world = boot()
        _G.AbbreviateNumbers = function() error("attempt to perform arithmetic on a secret value") end
        _G.UnitHealthPercent = function() error("secret") end
        world.plates.nameplate2 = plate()
        world.health.nameplate2 = { 1234, 5000 }
        game:fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
        expect_eq(module.texts[world.plates.nameplate2].text, "1234 / 5000", "repli sur une forme qui passe")
        expect_eq(#game.errors, 0, "aucune erreur remontée")
    end)

    it("ignore les barres de nom verrouillées", function()
        local game, module, world = boot()
        local locked = plate()
        locked.IsForbidden = function() return true end
        world.plates.nameplate3 = locked
        world.health.nameplate3 = { 10, 10 }
        game:fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
        expect_eq(module.texts[locked], nil)
        expect_eq(#game.errors, 0)
    end)
end)
