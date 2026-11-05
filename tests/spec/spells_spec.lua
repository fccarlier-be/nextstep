local wow = require("wow")
local Player = require("player")

-- Sorts à apprendre chez le maître de classe (Modules/Guide/Spells.lua), d'après les
-- tables importées de What's Training.

local function boot()
    local game = wow.boot({ faction = "Alliance" })
    return game, game.ns.Modules:Get("Guide")
end

local function ids(list)
    local set = {}
    for _, spell in ipairs(list or {}) do
        set[spell.id] = spell
    end
    return set
end

-- Tous les sorts de la classe jusqu'au niveau donné : le personnage les connaît.
local function knownUpTo(ns, class, level)
    local spells = {}
    for spellLevel, list in pairs(ns.DB.trainerSpells[class]) do
        if spellLevel <= level then
            for _, spell in ipairs(list) do
                spells[spell.id] = true
            end
        end
    end
    return spells
end

describe("Sorts à apprendre", function()
    it("importe les sorts des neuf classes de Forever", function()
        local game = boot()
        for _, class in ipairs({ "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK",
            "WARRIOR" }) do
            expect(game.ns.DB.trainerSpells[class], class)
        end
        expect_eq(game.ns.DB.trainerSpells.HUNTER[1][1].id, 1494, "Pistage des bêtes au niveau 1")
    end)

    it("liste les sorts jusqu'au niveau du personnage, avec leurs prérequis", function()
        local _, Guide = boot()
        local hunter = Player.new({ race = "NIGHTELF", class = "HUNTER", level = 10 })
        local list, total = Guide:SpellsToLearn(hunter)
        local set = ids(list)
        expect(set[1494], "sort du niveau 1 jamais appris")
        expect(set[1978] and set[13549], "Morsure de serpent puis son rang 2 dans la même visite")
        expect(not set[14281], "sort du niveau 12 pas encore")
        local sum = 0
        for _, spell in ipairs(list) do
            sum = sum + spell.cost
        end
        expect_eq(total, sum, "coût total")
    end)

    it("ne propose que les sorts nouveaux", function()
        local game, Guide = boot()
        local hunter = Player.new({ class = "HUNTER", level = 11, spells = knownUpTo(game.ns, "HUNTER", 10) })
        local list = Guide:SpellsToLearn(hunter)
        expect_eq(#list, 0, "niveau 11, tout appris au 10")
        local level, count = Guide:NextTrainerLevel(hunter)
        expect_eq(level, 12)
        expect(count > 0, "nouveaux sorts au 12")
    end)

    it("tient un rang dépassé pour connu", function()
        local _, Guide = boot()
        -- Rang 2 de Morsure de serpent (13549) connu, rang 1 (1978) non signalé par le client.
        local hunter = Player.new({ class = "HUNTER", level = 10, spells = { [13549] = true } })
        local set = ids(Guide:SpellsToLearn(hunter))
        expect(not set[1978], "rang 1 dépassé")
        expect(not set[13549], "rang 2 connu")
    end)

    it("respecte la race, les talents et les compétences", function()
        local game, Guide = boot()
        local function hasRacial(race)
            for _, spell in ipairs(Guide:SpellsToLearn(Player.new({ class = "PRIEST", race = race, level = 60 }))) do
                local entry
                for _, list in pairs(game.ns.DB.trainerSpells.PRIEST) do
                    for _, candidate in ipairs(list) do
                        if candidate.id == spell.id then
                            entry = candidate
                        end
                    end
                end
                if entry.races then
                    for _, token in ipairs(entry.races) do
                        if token ~= race then
                            return false, "sort racial d'une autre race : " .. spell.id
                        end
                    end
                end
            end
            return true
        end
        expect(hasRacial("HUMAN"))
        expect(hasRacial("DWARF"))

        -- Talent : Sanguinaire (rang 2, 23892) seulement si le talent 23881 est connu.
        local warrior = Player.new({ class = "WARRIOR", level = 48, spells = knownUpTo(game.ns, "WARRIOR", 47) })
        expect(not ids(Guide:SpellsToLearn(warrior))[23892], "talent absent")
        warrior.spells[23881] = true
        expect(ids(Guide:SpellsToLearn(warrior))[23892], "talent appris")

        -- Compétence : les poisons du voleur demandent la compétence Poisons (40).
        local rogue = Player.new({ class = "ROGUE", level = 20 })
        expect(not ids(Guide:SpellsToLearn(rogue))[3420], "sans la compétence Poisons")
        rogue.skills[40] = { 1, 300 }
        expect(ids(Guide:SpellsToLearn(rogue))[3420], "avec la compétence Poisons")
    end)

    it("valide l'étape « maître de classe » quand il n'y a rien à apprendre", function()
        local game, Guide = boot()
        game.ns.DB.AddGuide(function() return {
            id = "test/trainer", title = "Trainer", category = "Test", minLevel = 1, maxLevel = 60,
            steps = {
                { title = "Trainer", goals = { { t = "train", class = true } } },
                { title = "Next", goals = { { t = "accept", quest = 1, npc = 1 } } },
            },
        } end)
        local hunter = Player.new({ class = "HUNTER", level = 10 })
        Guide:SetState(hunter)
        expect_eq(Guide:Start("test/trainer").current, 1, "des sorts à apprendre : on y va")
        hunter.spells = knownUpTo(game.ns, "HUNTER", 10)
        expect_eq(Guide:Refresh().current, 2, "tout est appris : étape faite")
    end)

    it("affiche le coût et liste les sorts avec /ns spells", function()
        local game, Guide = boot()
        expect_eq(Guide.FormatMoney(12345), "1 g 23 s 45 c")
        expect_eq(Guide.FormatMoney(0), "0 c")
        Guide:SetState(Player.new({ class = "HUNTER", level = 4 }))
        local before = #game.chat
        SlashCmdList.NEXTSTEP("spells")
        local text = table.concat(game.chat, " ", before + 1)
        expect(text:find("spells to learn", 1, true), "résumé dans le chat")
        expect(text:find("Level 6", 1, true), "prochain niveau")
        expect_eq(#game.errors, 0)
    end)
end)
