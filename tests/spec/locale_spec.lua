local wow = require("wow")

describe("Traductions", function()
    it("affiche le texte anglais par défaut", function()
        local game = wow.boot({ locale = "enUS" })
        expect_eq(game.ns.L["Show this help"], "Show this help")
    end)

    it("traduit en français sur un client frFR", function()
        local game = wow.boot({ locale = "frFR" })
        expect_eq(game.ns.L["Show this help"], "Affiche cette aide")
        expect_eq(game.ns.L["%s: %s"], "%s : %s")
    end)

    it("affiche la clé quand une traduction manque", function()
        local game = wow.boot({ locale = "frFR" })
        expect_eq(game.ns.L["Texte jamais traduit"], "Texte jamais traduit")
    end)

    it("traduit en français chaque texte de l'addon", function()
        local game = wow.boot({ locale = "frFR" })
        local missing = {}
        for _, file in ipairs(game.tocs.NextStep.files) do
            if file:match("%.lua$") and not file:match("^Data/") then
                local handle = assert(io.open("addon/NextStep/" .. file, "r"))
                -- Clés écrites d'un seul tenant, L["..."], hors commentaires.
                for line in handle:lines() do
                    for key in line:gsub("%-%-.*$", ""):gmatch('L%["([^"]+)"%]') do
                        if rawget(game.ns.L, key) == nil then
                            missing[#missing + 1] = file .. " : " .. key
                        end
                    end
                end
                handle:close()
            end
        end
        expect_eq(#missing, 0, "sans traduction :\n      " .. table.concat(missing, "\n      "))
    end)

    it("traduit les messages de la commande /ns", function()
        local game = wow.boot({ locale = "frFR" })
        SlashCmdList.NEXTSTEP("inconnue")
        expect(game:chatText():find("Commande inconnue : inconnue", 1, true))
    end)
end)
