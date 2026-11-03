local wow = require("wow")

local function run(input)
    SlashCmdList.NEXTSTEP(input)
end

describe("Commandes", function()
    it("enregistre /ns et /nextstep", function()
        wow.boot()
        expect_eq(SLASH_NEXTSTEP1, "/ns")
        expect_eq(SLASH_NEXTSTEP2, "/nextstep")
    end)

    it("affiche la version lue dans le TOC", function()
        local game = wow.boot()
        run("version")
        expect(game:chatText():find("Version " .. game.tocs.NextStep.metadata.Version, 1, true))
    end)

    it("affiche l'aide sans argument et pour une commande inconnue", function()
        local game = wow.boot()
        run("")
        expect(game:chatText():find("/ns modules", 1, true))
        game.chat = {}
        run("nimportequoi")
        expect(game:chatText():find("Unknown command: nimportequoi", 1, true))
    end)

    it("liste, désactive et réactive un module", function()
        local game = wow.boot({
            beforeInit = function(ns)
                ns.Modules:New("Test")
            end,
        })
        run("modules")
        expect(game:chatText():find("Test: enabled", 1, true))
        run("  DISABLE   Test  ")
        expect(not game.ns.Modules:Get("Test").enabled, "commande insensible à la casse, espaces ignorés")
        expect_eq(NextStepDB.modules.Test.enabled, false)
        run("enable Test")
        expect(game.ns.Modules:Get("Test").enabled)
    end)

    it("signale un module inconnu", function()
        local game = wow.boot()
        run("enable Inconnu")
        expect(game:chatText():find("Unknown module: Inconnu", 1, true))
    end)
end)
