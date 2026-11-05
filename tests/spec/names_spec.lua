local wow = require("wow")

local GUARD = 999001   -- PNJ absent des données importées

local function creature(id)
    return ("Creature-0-4170-0-12-%d-0000ABCDEF"):format(id)
end

local function target(game, id, name)
    game:setUnit("target", { guid = creature(id), name = name })
    game:fire("PLAYER_TARGET_CHANGED")
end

-- Un PNJ cité par les guides qui n'a pas de nom français importé.
local function untranslatedNPC(DB)
    for id in pairs(DB.names.enUS.npc) do
        if not DB.names.frFR.npc[id] then
            return id
        end
    end
end

describe("Noms appris", function()
    it("est actif par défaut sur un client français", function()
        local game = wow.boot({ locale = "frFR" })
        expect(game.ns.Modules:Get("Names").enabled)
        expect(game:isEventRegistered("PLAYER_TARGET_CHANGED"), "écoute la cible")
    end)

    it("retient le nom d'un PNJ ciblé et le garde d'une session à l'autre", function()
        local game = wow.boot({ locale = "frFR" })
        target(game, GUARD, "Gardien d'essai")
        expect_eq(game.ns.DB:GetName("npc", GUARD), "Gardien d'essai")

        local again = wow.boot({ locale = "frFR", saved = wow.saved() })
        expect_eq(again.ns.DB:GetName("npc", GUARD), "Gardien d'essai")
    end)

    it("comble un PNJ sans traduction importée", function()
        local game = wow.boot({ locale = "frFR" })
        local id = untranslatedNPC(game.ns.DB)
        expect(id, "un PNJ sans nom français")
        expect_eq(game.ns.DB:GetName("npc", id), game.ns.DB.names.enUS.npc[id], "anglais avant")
        target(game, id, "Nom vu en jeu")
        expect_eq(game.ns.DB:GetName("npc", id), "Nom vu en jeu")
    end)

    it("passe avant la traduction importée", function()
        local game = wow.boot({ locale = "frFR" })
        target(game, 197, "Maréchal McBride (renommé)")
        expect_eq(game.ns.DB:GetName("npc", 197), "Maréchal McBride (renommé)")
    end)

    it("apprend aussi par survol, nameplate et dialogue", function()
        local game = wow.boot({ locale = "frFR" })
        game:setUnit("mouseover", { guid = creature(999002), name = "Survolé" })
        game:fire("UPDATE_MOUSEOVER_UNIT")
        game:setUnit("nameplate3", { guid = creature(999003), name = "Barre" })
        game:fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
        game:setUnit("npc", { guid = creature(999004), name = "Interlocuteur" })
        game:fire("GOSSIP_SHOW")
        local DB = game.ns.DB
        expect_eq({ DB:GetName("npc", 999002), DB:GetName("npc", 999003), DB:GetName("npc", 999004) },
            { "Survolé", "Barre", "Interlocuteur" })
    end)

    it("n'apprend rien en combat", function()
        local game = wow.boot({ locale = "frFR" })
        game.inCombat = true
        target(game, GUARD, "En combat")
        expect_eq(game.ns.DB:GetName("npc", GUARD), nil)
    end)

    it("ignore les valeurs secrètes", function()
        local game = wow.boot({
            locale = "frFR",
            beforeInit = function()
                _G.issecretvalue = function(value)
                    return value == "Secret"
                end
            end,
        })
        target(game, GUARD, "Secret")
        expect_eq(game.ns.DB:GetName("npc", GUARD), nil)
    end)

    it("ignore les joueurs, les noms inconnus et les GUID illisibles", function()
        local game = wow.boot({ locale = "frFR" })
        game:setUnit("target", { guid = "Player-4170-0ABCDEF1", name = "Untel" })
        game:fire("PLAYER_TARGET_CHANGED")
        target(game, GUARD, "Unknown")
        game:setUnit("target", { guid = "n'importe quoi", name = "X" })
        game:fire("PLAYER_TARGET_CHANGED")
        expect_eq(game.ns.Modules:Get("Names"):Count(), 0)
        expect_eq(#game.errors, 0, "aucune erreur")
    end)

    it("ne fait rien sur un client anglais", function()
        local game = wow.boot({ locale = "enUS" })
        expect(not game:isEventRegistered("PLAYER_TARGET_CHANGED"))
        expect_eq(game.ns.DB:GetName("npc", 197), "Marshal McBride")
    end)

    it("arrête la collecte une fois désactivé, mais garde les noms appris", function()
        local game = wow.boot({ locale = "frFR" })
        target(game, GUARD, "Avant")
        game.ns.Modules:SetEnabled("Names", false)
        target(game, 999005, "Après")
        expect_eq(game.ns.DB:GetName("npc", GUARD), "Avant")
        expect_eq(game.ns.DB:GetName("npc", 999005), nil)
    end)

    it("oublie les noms appris sur demande", function()
        local game = wow.boot({ locale = "frFR" })
        target(game, GUARD, "Temporaire")
        game.ns.Modules:Get("Names"):Clear()
        expect_eq(game.ns.DB:GetName("npc", GUARD), nil)
    end)

    it("demande au client le nom d'un PNJ jamais croisé, une seule fois", function()
        local calls = 0
        local game = wow.boot({
            locale = "frFR",
            beforeInit = function()
                _G.C_TooltipInfo = {
                    GetHyperlink = function(link)
                        calls = calls + 1
                        if link:find("%-" .. GUARD .. "%-") then
                            return { lines = { { leftText = "Depuis l'infobulle" } } }
                        end
                    end,
                }
            end,
        })
        local DB = game.ns.DB
        expect_eq(DB:GetName("npc", GUARD), "Depuis l'infobulle")
        expect_eq(DB:GetName("npc", 999006), nil)
        expect_eq(DB:GetName("npc", 999006), nil)
        expect_eq(calls, 2, "un appel par PNJ, puis mémorisé")
        expect_eq(game.ns.Modules:Get("Names"):Count(), 1)
    end)
end)

describe("Options", function()
    local function withSettings()
        return {
            RegisterCanvasLayoutCategory = function(panel, name)
                return { panel = panel, name = name, GetID = function()
                    return 1
                end }
            end,
            RegisterAddOnCategory = function() end,
            OpenToCategory = function() end,
        }
    end

    it("affiche une case par module et désactive le module décoché", function()
        local game = wow.boot({ locale = "frFR", settings = withSettings() })
        local Options = game.ns.Options
        local check = Options.checks.Names
        expect(check, "case du module Noms appris")
        expect(check:GetChecked(), "cochée par défaut")
        check:SetChecked(false)
        game:runScript(check, "OnClick")
        expect(not game.ns.Modules:Get("Names").enabled)
        expect_eq(NextStepDB.modules.Names.enabled, false)
    end)

    it("met à jour l'affichage à l'ouverture et efface les noms appris", function()
        local game = wow.boot({ locale = "frFR", settings = withSettings() })
        target(game, GUARD, "Affiché")
        local Options, Names = game.ns.Options, game.ns.Modules:Get("Names")
        game.ns.Modules:SetEnabled("Names", false)
        game:runScript(Options.panel, "OnShow")
        expect(not Options.checks.Names:GetChecked(), "case synchronisée avec /ns disable")
        expect_eq(Names.countText.text, "Noms appris : 1", "compteur mis à jour à l'ouverture")
        game:runScript(Names.clearButton, "OnClick")
        expect_eq(Names:Count(), 0)
        expect_eq(Names.countText.text, "Noms appris : 0")
    end)

    it("ouvre la fenêtre des options de NextStep, aussi depuis les options du jeu", function()
        local game = wow.boot({ locale = "frFR", settings = withSettings() })
        local Options = game.ns.Options
        expect(Options.window, "fenêtre des options")
        expect(Options.gamePage, "page NextStep des options du jeu")
        Options:Open()
        SlashCmdList.NEXTSTEP("options")
        expect(game.ns.Modules:Get("MapReveal").brightnessSlider, "curseur de la carte sans brouillard")
        expect_eq(#game.errors, 0)
    end)
end)
