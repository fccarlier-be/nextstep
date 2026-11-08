local wow = require("wow")
local Player = require("player")

-- Donjons et équipement à venir (Modules/Items/Dungeons.lua, Upgrades.lua) : données
-- importées, suites de quêtes, butin, onglets du journal.

local DEFIAS = 166            -- « La Confrérie défias », quête des Mortemines (Alliance)
local VANCLEEF = 639

-- Objets inconnus du client : le score vient des caractéristiques importées.
local function boot(options)
    options = options or {}
    local game = wow.boot({
        faction = options.faction or "Alliance",
        player = options.player or { level = 20, class = "WARRIOR" },
        beforeInit = function()
            _G.C_Item.GetItemStats = function() return nil end
            _G.C_Item.GetItemInfo = options.itemInfo or function() return nil end
            _G.GetInventoryItemLink = function() return nil end
            _G.C_Container = { GetContainerNumSlots = function() return 0 end,
                GetContainerItemLink = function() return nil end }
        end,
    })
    return game, game.ns.Modules:Get("Items")
end

local function contains(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

local function texts(rows)
    local list = {}
    for _, row in ipairs(rows) do
        list[#list + 1] = row.text or ""
    end
    return table.concat(list, "\n")
end

describe("Donjons : données importées", function()
    it("décrit chaque donjon, ses quêtes et leurs prérequis", function()
        local game = boot()
        local DB = game.ns.DB
        expect(#DB.dungeons >= 19, "donjons du Classic et de Forever")
        local deadmines
        for _, dungeon in ipairs(DB.dungeons) do
            expect(dungeon.min <= dungeon.max, dungeon.key)
            for _, id in ipairs(dungeon.quests) do
                expect(DB.dungeonQuests[id], dungeon.key .. " : quête " .. id .. " décrite")
            end
            if dungeon.key == "deadmines" then
                deadmines = dungeon
            end
        end
        expect(contains(deadmines.quests, DEFIAS), "La Confrérie défias")
        expect_eq(deadmines.bosses[1].npc, VANCLEEF)
        for id, quest in pairs(DB.dungeonQuests) do
            for _, list in ipairs({ quest.all or {}, quest.any or {} }) do
                for _, pre in ipairs(list) do
                    expect(DB.dungeonQuests[pre], ("prérequis %d de %d décrit"):format(pre, id))
                end
            end
        end
        expect(next(DB.itemStats) and next(DB.itemSources), "objets et provenance")
    end)
end)

describe("Donjons : quêtes et suites", function()
    it("liste les étapes encore à faire, dans l'ordre", function()
        local _, items = boot()
        local facts = items:QuestFacts()
        local steps = items.QuestChain(DEFIAS, facts)
        expect(#steps > 1, "suite de quêtes")
        expect_eq(steps[#steps], DEFIAS, "la quête du donjon en dernier")
        local position = {}
        for index, id in ipairs(steps) do
            position[id] = index
        end
        for _, id in ipairs(steps) do
            local quest = NextStep.DB.dungeonQuests[id]
            for _, pre in ipairs(quest.all or {}) do
                expect(position[pre] and position[pre] < position[id], "prérequis avant")
            end
        end
        expect_eq(items.QuestState(DEFIAS, facts), "locked", "étape avant")
    end)

    it("ne garde que ce qui reste à faire", function()
        local done = {}
        local _, probe = boot()
        for _, id in ipairs(probe.QuestChain(DEFIAS, probe:QuestFacts())) do
            if id ~= DEFIAS then
                done[id] = true
            end
        end
        local _, items = boot({ player = { level = 20, class = "WARRIOR", done = done } })
        local facts = items:QuestFacts()
        expect_eq(items.QuestChain(DEFIAS, facts), { DEFIAS })
        expect_eq(items.QuestState(DEFIAS, facts), "open")
        local low = boot({ player = { level = 5, class = "WARRIOR", done = done } })
        local lowItems = low.ns.Modules:Get("Items")
        expect_eq(lowItems.QuestState(DEFIAS, lowItems:QuestFacts()), "level")
    end)

    it("écarte les quêtes de l'autre faction", function()
        local _, items = boot({ faction = "Horde" })
        local facts = items:QuestFacts()
        expect_eq(items.QuestApplies(NextStep.DB.dungeonQuests[DEFIAS], facts), false)
        for _, dungeon in ipairs(items:Dungeons(facts)) do
            expect(dungeon.key ~= "stockade", "la Prison est pour l'Alliance")
        end
    end)

    it("détaille un donjon : quêtes, étapes, donneur et butin", function()
        local game, items = boot()
        local deadmines = items.DungeonByKey("deadmines")
        local rows = items:DungeonDetailRows(deadmines, items:QuestFacts())
        local text = texts(rows)
        expect(text:find("Quest chain:", 1, true), "étapes de la suite")
        expect(text:find("Edwin VanCleef", 1, true), "boss")
        local pointed
        for _, row in ipairs(rows) do
            if row.onClick and not pointed then
                pointed = true
                row.onClick()
            end
        end
        local guide = game.ns.Modules:Get("Guide")
        expect(guide.pointTarget and guide.pointTarget.map, "la flèche pointe le donneur")
        guide:PointTo(nil)
        expect_eq(guide.pointTarget, nil)
        expect_eq(#game.errors, 0)
    end)

    it("rend la flèche au guide : second clic, clic droit ou /ns arrow", function()
        local game, items = boot()
        local guide = game.ns.Modules:Get("Guide")
        local rows = items:DungeonDetailRows(items.DungeonByKey("deadmines"), items:QuestFacts())
        local click
        for _, row in ipairs(rows) do
            click = click or row.onClick
        end
        click()
        expect(guide.pointTarget, "flèche vers le donneur")
        expect(game:chatText():find("Right-click it to go back", 1, true), "le chat dit comment revenir")
        click()
        expect_eq(guide.pointTarget, nil, "second clic : retour au guide")
        expect(game:chatText():find("follows the guide again", 1, true))

        click()
        local arrow = guide.arrowFrame
        arrow.scripts.OnMouseUp(arrow, "RightButton")
        expect_eq(guide.pointTarget, nil, "clic droit sur la flèche")

        click()
        local shown = guide.db.arrow
        SlashCmdList.NEXTSTEP("arrow")
        expect_eq(guide.pointTarget, nil, "/ns arrow rend la flèche au guide")
        expect_eq(guide.db.arrow, shown, "sans la cacher")
        expect_eq(#game.errors, 0)
    end)
end)

describe("Donjons : butin et équipement", function()
    it("note le butin avec les caractéristiques importées", function()
        local game, items = boot()
        local Score = game.ns.Score
        local boss = items.DungeonByKey("deadmines").bosses[1]
        local link = Score.LinkOf(boss.loot[1][1])
        local info = Score.Info(link)
        expect(info and next(info.stats), "caractéristiques importées")
        local row = items:LootRow(boss.loot[1][1], boss.loot[1][2])
        expect(row.right:find("%", 1, true), "taux de butin")
    end)

    it("retient le butin vu en jeu dans un donjon", function()
        local _, items = boot({ itemInfo = function(link)
            if link == "item:2169" or link == 2169 then
                return "Buzzer Blade", "item:2169", 2, 15, 15, "", "", 1, "INVTYPE_WEAPON", "icon", 100, 2, 15
            end
        end })
        _G.IsInInstance = function() return true end
        _G.GetInstanceInfo = function() return "The Deadmines", "party", 1, "", 5, 0, false, 36 end
        _G.GetNumLootItems = function() return 1 end
        _G.GetLootSlotLink = function() return "item:2169" end
        _G.GetLootSourceInfo = function() return "Creature-0-1-36-1-642-0000" end
        items:LearnLoot()
        expect_eq(items.db.learnedLoot.deadmines[2169], 642)
        local text = texts(items:DungeonDetailRows(items.DungeonByKey("deadmines"), items:QuestFacts()))
        expect(text:find("Buzzer Blade", 1, true), "affiché sous son boss")
    end)

    it("propose l'équipement à ne pas rater et signale les récompenses", function()
        local game, items = boot()
        local facts = items:QuestFacts()
        local list = items:UpcomingUpgrades(facts)
        expect(#list > 0, "améliorations à venir")
        for _, entry in ipairs(list) do
            expect(entry.req <= 25, "portable d'ici cinq niveaux")
            expect(#entry.sources > 0, "provenance")
        end
        expect(items:QuestRewardTag(DEFIAS), "récompense de la Confrérie défias")
        local text = texts(items:GearRows(facts))
        expect(text:find("riding", 1, true), "jalon : monture")
        expect_eq(#game.errors, 0)
    end)

    it("ouvre les onglets Donjons et Équipement du journal", function()
        local game = wow.boot({ faction = "Alliance", player = { level = 20, class = "WARRIOR" } })
        local guide = game.ns.Modules:Get("Guide")
        local items = game.ns.Modules:Get("Items")
        guide:SetState(Player.new({ race = "HUMAN", class = "WARRIOR", level = 20 }))
        guide:ToggleJournal("dungeons")
        rawset(guide.journal, "IsShown", function() return true end)
        for _, extra in pairs(guide.journal.extra) do
            rawset(extra.body, "IsShown", function() return true end)
            for _, list in ipairs({ rawget(extra.body, "list"), rawget(extra.body, "detail") }) do
                rawset(list, "GetHeight", function() return 440 end)
            end
        end
        guide:ShowJournalTab("dungeons")
        expect(#items.dungeonsBody.list.rows > 0, "liste des donjons")
        expect_eq(items.dungeonSelected, "thanes", "premier donjon de son niveau choisi")
        expect(#items.dungeonsBody.detail.lines > 0, "détail dessiné")
        guide:ShowJournalTab("gear")
        expect(#items.gearBody.list.rows > 0, "onglet Équipement")
        SlashCmdList.NEXTSTEP("dungeons")
        expect_eq(#game.errors, 0)
    end)
end)
