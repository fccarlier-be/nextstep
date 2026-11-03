local wow = require("wow")

describe("Événements", function()
    it("transmet un événement du jeu à l'abonné", function()
        local game = wow.boot()
        local received
        game.ns.Events:Register("PLAYER_LEVEL_UP", "test", function(owner, event, level)
            received = { owner, event, level }
        end)
        expect(game:isEventRegistered("PLAYER_LEVEL_UP"), "l'événement devrait être écouté")
        game:fire("PLAYER_LEVEL_UP", 5)
        expect_eq(received, { "test", "PLAYER_LEVEL_UP", 5 })
    end)

    it("arrête d'écouter l'événement quand le dernier abonné part", function()
        local game = wow.boot()
        game.ns.Events:Register("PLAYER_LEVEL_UP", "a", function() end)
        game.ns.Events:Register("PLAYER_LEVEL_UP", "b", function() end)
        game.ns.Events:Unregister("PLAYER_LEVEL_UP", "a")
        expect(game:isEventRegistered("PLAYER_LEVEL_UP"), "b écoute encore")
        game.ns.Events:Unregister("PLAYER_LEVEL_UP", "b")
        expect(not game:isEventRegistered("PLAYER_LEVEL_UP"), "plus personne n'écoute")
    end)

    it("isole l'erreur d'un abonné des autres", function()
        local game = wow.boot()
        local called = false
        game.ns.Events:Register("PLAYER_LEVEL_UP", "broken", function()
            error("boom")
        end)
        game.ns.Events:Register("PLAYER_LEVEL_UP", "healthy", function()
            called = true
        end)
        game:fire("PLAYER_LEVEL_UP", 2)
        expect(called, "l'abonné sain doit être appelé")
        expect_eq(#game.errors, 1, "l'erreur est confiée au gestionnaire du jeu")
    end)

    it("transmet les messages internes", function()
        local game = wow.boot()
        local value
        game.ns.Events:RegisterMessage("NEXTSTEP_TEST", "test", function(_, _, v)
            value = v
        end)
        game.ns.Events:SendMessage("NEXTSTEP_TEST", 42)
        expect_eq(value, 42)
        game.ns.Events:UnregisterAll("test")
        game.ns.Events:SendMessage("NEXTSTEP_TEST", 7)
        expect_eq(value, 42, "plus de message après UnregisterAll")
    end)
end)
