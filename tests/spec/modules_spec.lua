local wow = require("wow")

-- Enregistre un module de test, comme le ferait un fichier de module.
local function withModule(options, log)
    return function(ns)
        local module = ns.Modules:New("Test", options)
        function module:OnInitialize()
            log[#log + 1] = "init"
        end
        function module:OnEnable()
            log[#log + 1] = "enable"
            self:RegisterEvent("PLAYER_LEVEL_UP")
        end
        function module:OnDisable()
            log[#log + 1] = "disable"
        end
        function module:PLAYER_LEVEL_UP(_, level)
            log[#log + 1] = "level " .. level
        end
    end
end

describe("Modules", function()
    it("initialise puis active un module à la connexion", function()
        local log = {}
        local game = wow.boot({ beforeInit = withModule({ defaults = { size = 2 } }, log) })
        local module = game.ns.Modules:Get("Test")
        expect_eq(log, { "init", "enable" })
        expect(module.enabled)
        expect_eq(module.db.size, 2, "les réglages par défaut sont appliqués")
        expect_eq(NextStepDB.modules.Test.enabled, true)
        game:fire("PLAYER_LEVEL_UP", 3)
        expect_eq(log[3], "level 3", "le module reçoit ses événements")
    end)

    it("respecte defaultEnabled = false", function()
        local log = {}
        local game = wow.boot({ beforeInit = withModule({ defaultEnabled = false }, log) })
        expect(not game.ns.Modules:Get("Test").enabled)
        expect_eq(log, { "init" })
    end)

    it("mémorise la désactivation et arrête les événements", function()
        local log = {}
        local game = wow.boot({ beforeInit = withModule({}, log) })
        game.ns.Modules:SetEnabled("Test", false)
        game:fire("PLAYER_LEVEL_UP", 4)
        expect_eq(log, { "init", "enable", "disable" })

        local again = {}
        wow.boot({ saved = wow.saved(), beforeInit = withModule({}, again) })
        expect_eq(again, { "init" }, "toujours désactivé à la session suivante")
    end)

    it("se met de côté si un addon concurrent est chargé", function()
        local log = {}
        local game = wow.boot({
            loaded = { "Bagnon" },
            beforeInit = withModule({ conflicts = { "Bagnon" } }, log),
        })
        local module = game.ns.Modules:Get("Test")
        expect(not module.enabled)
        expect_eq(module.blockedBy, "Bagnon")
        expect(game:chatText():find("Bagnon"), "le joueur est prévenu")
    end)

    it("isole l'erreur d'un module des autres", function()
        local game = wow.boot({
            beforeInit = function(ns)
                local broken = ns.Modules:New("Broken")
                function broken.OnEnable()
                    error("boom")
                end
                ns.Modules:New("Healthy")
            end,
        })
        expect(game.ns.Modules:Get("Healthy").enabled)
        expect_eq(#game.errors, 1)
    end)
end)
