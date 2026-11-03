local wow = require("wow")

local ADDON_FILE = "Tools/diagnostic/NextStep_Diagnostic/Diagnostic.lua"

-- Fonctions du client absentes de la simulation générale.
local function stubClient()
    _G.GetBuildInfo = function()
        return "1.60.1", "70425", "Nov 3 2026", 16001
    end
    _G.UnitRace = function()
        return "Humain", "Human"
    end
    _G.UnitClass = function()
        return "Guerrier", "WARRIOR"
    end
    _G.UnitLevel = function()
        return 1
    end
    _G.UnitHealth = function()
        return 50
    end
    _G.UIParent = CreateFrame("Frame")
    _G.time = os.time
end

local function loadDiagnostic(game)
    stubClient()
    assert(loadfile(ADDON_FILE))("NextStep_Diagnostic", {})
    game:fire("ADDON_LOADED", "NextStep_Diagnostic")
end

describe("Addon de diagnostic", function()
    it("produit un rapport sans erreur, même quand des API manquent", function()
        local game = wow.boot({ locale = "frFR" })
        loadDiagnostic(game)
        SlashCmdList.NEXTSTEPDIAG("")
        local report = NextStepDiagDB.reports.general
        expect(report, "rapport enregistré")
        expect(#report.sections >= 8, "toutes les sections : " .. #report.sections)
        expect_eq(report.client.interface, 16001)
        expect_eq(#game.errors, 0, "aucune erreur remontée au jeu")
        expect(game:chatText():find("/reload", 1, true), "explique comment enregistrer")
    end)

    it("refuse de tourner en combat et arme la capture", function()
        local game = wow.boot()
        loadDiagnostic(game)
        game.inCombat = true
        SlashCmdList.NEXTSTEPDIAG("")
        expect(not (NextStepDiagDB and NextStepDiagDB.reports), "rien en combat")
        SlashCmdList.NEXTSTEPDIAG("combat")
        expect(game:chatText():find("capture armée", 1, true))
    end)

    it("convertit les sauvegardes en rapport Markdown", function()
        local game = wow.boot({ locale = "frFR" })
        loadDiagnostic(game)
        SlashCmdList.NEXTSTEPDIAG("")
        -- Sauvegarde telle que le jeu l'écrirait, puis conversion.
        local saved = os.tmpname()
        local out = os.tmpname()
        local function serialize(value, indent)
            if type(value) == "table" then
                local parts = {}
                for k, v in pairs(value) do
                    parts[#parts + 1] = ("%s[%s] = %s,"):format(indent .. "\t",
                        type(k) == "string" and ("%q"):format(k) or tostring(k), serialize(v, indent .. "\t"))
                end
                return "{\n" .. table.concat(parts, "\n") .. "\n" .. indent .. "}"
            elseif type(value) == "string" then
                return ("%q"):format(value)
            end
            return tostring(value)
        end
        local file = assert(io.open(saved, "wb"))
        file:write("NextStepDiagDB = " .. serialize(NextStepDiagDB, "") .. "\n")
        file:close()

        local previous = _G.arg
        _G.arg = { saved, out }
        local ok, err = pcall(dofile, "Tools/diagnostic/report.lua")
        _G.arg = previous
        expect(ok, tostring(err))
        local markdown = assert(io.open(out, "rb")):read("*a")
        os.remove(saved)
        os.remove(out)
        expect(markdown:find("# Rapport de diagnostic", 1, true))
        expect(markdown:find("C_QuestLog.IsOnQuest", 1, true), "les API vérifiées sont listées")
    end)
end)
