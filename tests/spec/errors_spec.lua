-- Relevé des erreurs Lua de NextStep (Core/Errors.lua).

local wow = require("wow")

-- Démarre l'addon avec un gestionnaire d'erreurs remplaçable, comme dans le jeu.
local function boot()
    local game = wow.boot()
    local ns = game.ns
    local shown = {}
    local current = function(message)
        shown[#shown + 1] = message
    end
    _G.geterrorhandler = function()
        return current
    end
    _G.seterrorhandler = function(fn)
        current = fn
    end
    _G.debugstack = function()
        return "Interface/AddOns/NextStep/Modules/Test.lua:12: in function <...>\n[C]: ?"
    end
    expect(ns.Errors.Install(), "gestionnaire installé")
    return game, ns, shown
end

describe("Relevé des erreurs", function()
    it("note les erreurs de NextStep, regroupe les doublons et laisse le jeu les afficher", function()
        local _, ns, shown = boot()
        ns.Errors.Clear()
        local function fail()
            error("Interface/AddOns/NextStep/Modules/Test.lua:12: attempt to index a nil value", 0)
        end
        ns.SafeCall(fail)
        ns.SafeCall(fail)
        local entries = ns.Errors.List()
        expect_eq(#entries, 1, "une seule erreur différente")
        expect_eq(entries[1].count, 2)
        expect(entries[1].stack:find("Test.lua:12", 1, true), "pile gardée")
        expect_eq(#shown, 2, "le gestionnaire du jeu les reçoit toujours")
        expect(ns.db.errors == entries, "gardées dans NextStepDB")

        -- Une erreur d'un autre addon n'est pas notée.
        _G.debugstack = function()
            return "Interface/AddOns/OtherAddon/Core.lua:3: in main chunk"
        end
        geterrorhandler()("Interface/AddOns/OtherAddon/Core.lua:3: boom")
        expect_eq(#ns.Errors.List(), 1, "pas d'erreur d'un autre addon")
        expect_eq(#shown, 3)

        -- Installer deux fois ne double pas l'enveloppe.
        ns.Errors.Install()
        ns.SafeCall(fail)
        expect_eq(ns.Errors.List()[1].count, 3)
    end)

    it("note les actions bloquées et les liste avec /ns errors", function()
        local game, ns = boot()
        ns.Errors.Clear()
        ns.Errors.Blocked("ADDON_ACTION_BLOCKED", "NextStep", "UseAction()")
        ns.Errors.Blocked("ADDON_ACTION_BLOCKED", "OtherAddon", "UseAction()")
        expect_eq(#ns.Errors.List(), 1)
        expect_eq(ns.Errors.List()[1].kind, "blocked")

        SlashCmdList.NEXTSTEP("errors")
        local chat = table.concat(game.chat, "\n")
        expect(chat:find("1 Lua error(s) recorded", 1, true), chat)
        expect(chat:find("UseAction()", 1, true), "erreur listée")
        SlashCmdList.NEXTSTEP("errors clear")
        expect_eq(#ns.Errors.List(), 0, "effacées")
    end)

    it("garde les erreurs du chargement jusqu'à la lecture des sauvegardes", function()
        boot()
        local db = {}
        -- Fichier rechargé à neuf : les sauvegardes ne sont pas encore lues.
        local ns = {}
        assert(loadfile("addon/NextStep/Core/Errors.lua"))("NextStep", ns)
        ns.Errors.Record("Interface/AddOns/NextStep/Core/X.lua:1: early", nil, "error")
        ns.Errors.Attach(db)
        expect_eq(#db.errors, 1, "erreur du chargement reprise")
        expect_eq(db.errors[1].message, "Interface/AddOns/NextStep/Core/X.lua:1: early")
    end)
end)
