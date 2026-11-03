local wow = require("wow")

describe("Sauvegardes", function()
    it("crée des sauvegardes neuves au schéma courant", function()
        local game = wow.boot()
        expect_eq(NextStepDB.schema, game.ns.Storage.SCHEMA)
        expect_eq(NextStepCharDB.schema, game.ns.Storage.SCHEMA)
        expect_eq(NextStepDB.modules, {})
        expect(game.ns.db == NextStepDB and game.ns.char == NextStepCharDB)
    end)

    it("conserve les valeurs d'une session précédente", function()
        wow.boot()
        NextStepDB.modules.Test = { enabled = false }
        local saved = wow.saved()
        wow.boot({ saved = saved })
        expect_eq(NextStepDB.modules.Test.enabled, false)
    end)

    it("applique les migrations dans l'ordre", function()
        local steps = {}
        wow.boot({
            saved = { NextStepDB = { schema = 1, modules = {}, old = "x" } },
            beforeInit = function(ns)
                ns.Storage.SCHEMA = 3
                ns.Storage.migrations.account[2] = function(db)
                    steps[#steps + 1] = 2
                    db.new = db.old
                    db.old = nil
                end
                ns.Storage.migrations.account[3] = function()
                    steps[#steps + 1] = 3
                end
            end,
        })
        expect_eq(steps, { 2, 3 })
        expect_eq(NextStepDB.schema, 3)
        expect_eq(NextStepDB.new, "x")
    end)

    it("ne touche pas aux données d'une version plus récente", function()
        local game = wow.boot({ saved = { NextStepDB = { schema = 99, modules = {} } } })
        expect_eq(NextStepDB.schema, 99)
        expect(game:chatText():find("newer version"), "un avertissement est affiché")
    end)
end)
