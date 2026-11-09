local wow = require("wow")

-- Guide de test sur la vraie carte de la forêt d'Elwynn (repère « era »).
local GUIDE_ID = "test/live"
local MAP = 1429
-- Objectif de quête du client : une table neuve par test (completeQuest la modifie).
local function kill()
    return { text = "Kobold Vermin slain: 0/10", finished = false }
end

local function addGuide(ns)
    ns.DB.AddGuide(function() return {
        id = GUIDE_ID,
        title = "Test guide",
        category = "Test",
        minLevel = 1,
        maxLevel = 10,
        pool = {
            { npc = 911, map = MAP, x = 50.24, y = 42.29, f = "e", faction = "A", classes = { "WARRIOR" } },
            { npc = 198, map = MAP, x = 49.66, y = 39.4, f = "e", faction = "A", classes = { "MAGE" } },
        },
        steps = {
            { title = "Accept", goals = {
                { t = "accept", quest = 783, npc = 823, map = MAP, x = 48.17, y = 42.94, f = "e" },
            } },
            { title = "Kill", goals = {
                { t = "kill", quest = 783, oi = 1, npc = 6, count = 10, map = MAP, x = 48.1, y = 36.96, f = "e",
                    spotsPacked = "48.6,36,81.4,59,22;51.2,36.9,82.4,32,7" },
            } },
            { title = "Talk", goals = { { t = "talk", npc = 100 } } },
            { title = "Train", goals = { { t = "train", class = true, candidates = { 1, 2 } } } },
            { title = "Go", goals = { { t = "goto", map = MAP, x = 50, y = 40, f = "e", r = 10 } } },
            { title = "Turn in", goals = { { t = "turnin", quest = 783, npc = 197 } } },
        },
    } end)
end

local function boot(player)
    local game = wow.boot({ faction = "Alliance", player = player })
    addGuide(game.ns)
    return game, game.ns.Modules:Get("Guide")
end

-- Position monde (nord, ouest, continent) d'un point de la carte, d'après son cadre.
local function worldOf(ns, x, y)
    local box = ns.DB.mapFrames.era[MAP]
    return { box.top + (box.bottom - box.top) * y / 100, box.left + (box.right - box.left) * x / 100, box.c }
end

local function hasText(Guide, pattern)
    for _, text in ipairs(Guide.windowTexts or {}) do
        if text:find(pattern, 1, true) then
            return true
        end
    end
    return false
end

local function npcGUID(id)
    return ("Creature-0-1-0-1-%d-0000000001"):format(id)
end

describe("Guide en jeu", function()
    it("lit l'état du personnage dans l'API du jeu", function()
        local game, Guide = boot({ level = 4, xp = 100, maxXP = 400, race = "NightElf", money = 250 })
        local state = Guide.state
        expect_eq(state, Guide.live, "l'état réel est mis en place à la connexion")
        expect_eq({ state:Level() }, { 4, 0.25 })
        expect_eq(state:Race(), "NIGHTELF")
        expect_eq(state:Money(), 250)
        expect_eq(state:Ready(), false, "journal pas encore lu")
        game:acceptQuest(7, { { text = "x", finished = true }, { text = "y", finished = false } })
        game:fire("QUEST_LOG_UPDATE")
        expect_eq(state:Ready(), true)
        expect(state:InLog(7) and not state:Complete(7))
        expect(state:Objective(7, 1) and not state:Objective(7, 2))
        expect_eq(state:LogQuests(), { 7 })
        game:turnInQuest(7)
        game:fire("QUEST_TURNED_IN", 7)
        expect(state:TurnedIn(7) and not state:InLog(7))
    end)

    it("suit le guide au fil des événements et valide dialogue et maître", function()
        local game, Guide = boot()
        local r = Guide:Start(GUIDE_ID)
        expect_eq(r.ready, false)
        expect(hasText(Guide, "Reading the quest log"), "attend le journal")

        game:fire("QUEST_LOG_UPDATE")
        expect_eq(Guide.result.current, 1)
        expect(hasText(Guide, "Accept "), "libellé construit pour accept")

        game:acceptQuest(783, { kill() })
        game:fire("QUEST_ACCEPTED", 783)
        expect_eq(Guide.result.current, 2)
        expect(hasText(Guide, "Kobold Vermin slain: 0/10"), "texte du client pour l'objectif de quête")

        game:completeQuest(783)
        game:fire("QUEST_LOG_UPDATE")
        expect_eq(Guide.result.current, 3, "étape de dialogue")

        game:setUnit("npc", { guid = npcGUID(55) })
        game:fire("GOSSIP_SHOW")
        expect_eq(Guide.result.current, 3, "un autre PNJ ne valide rien")
        game:setUnit("npc", { guid = npcGUID(100) })
        game:fire("GOSSIP_SHOW")
        expect_eq(Guide.result.current, 4, "dialogue avec le bon PNJ")

        game:setUnit("npc", { guid = npcGUID(555) })
        game:fire("TRAINER_SHOW")
        expect_eq(Guide.result.current, 4, "maître absent de la liste du guide")
        expect_eq(Guide.char.trainedLevel, nil, "pas un maître de classe connu")
        game:setUnit("npc", { guid = npcGUID(911) })
        game:fire("TRAINER_SHOW")
        expect_eq(Guide.result.current, 5, "maître de classe proposé")
        expect_eq(Guide.char.trainedLevel, 1, "visite retenue d'une session à l'autre")
    end)

    it("constate l'arrivée au point de passage", function()
        local game, Guide = boot()
        game:acceptQuest(783, { kill() }):completeQuest(783)
        game:fire("QUEST_LOG_UPDATE")
        Guide:Start(GUIDE_ID)
        Guide:Tick(3, 1)
        Guide:Tick(4, 1)
        expect_eq(Guide.result.current, 5)
        expect(Guide.result.needsPosition, "un point de passage à surveiller")

        game.player.position = worldOf(game.ns, 50, 30)
        Guide:OnTick()
        expect_eq(Guide.result.current, 5, "encore loin")
        game.player.position = worldOf(game.ns, 50.05, 40)
        Guide:OnTick()
        expect_eq(Guide.result.current, 6, "arrivé")
    end)

    it("vise la zone de mobs la plus proche et le maître de sa classe", function()
        local game, Guide = boot()
        game.player.position = worldOf(game.ns, 51, 37)
        game:acceptQuest(783, { kill() })
        game:fire("QUEST_LOG_UPDATE")
        local r = Guide:Start(GUIDE_ID)
        expect_eq({ r.current, r.target.x, r.target.y }, { 2, 51.2, 36.9 })

        game:completeQuest(783)
        game:fire("QUEST_LOG_UPDATE")
        Guide:Tick(3, 1)
        expect_eq({ Guide.result.current, Guide.result.target.x }, { 4, 50.24 }, "le maître des guerriers")
    end)

    it("vise, en mode strict, l'objectif le plus proche de l'étape", function()
        local game, Guide = boot()
        game.ns.DB.AddGuide(function() return {
            id = "test/river", title = "River", category = "Test", minLevel = 1, maxLevel = 10,
            steps = {
                { title = "River", goals = {
                    { t = "goto", map = MAP, x = 30, y = 30, f = "e", r = 5 },
                    { t = "goto", map = MAP, x = 70, y = 70, f = "e", r = 5, optional = true },
                    { t = "goto", map = MAP, x = 60, y = 60, f = "e", r = 5 },
                } },
            },
        } end)
        game.player.position = worldOf(game.ns, 62, 62)
        game:fire("QUEST_LOG_UPDATE")
        local r = Guide:Start("test/river")
        expect_eq({ r.target.goal, r.target.x }, { 3, 60 }, "le dernier objectif, le plus proche")
        expect_eq(r.target.choices, 2, "deux objectifs obligatoires : la cible peut changer")
    end)

    it("retient les sorts lus chez le maître, et signale le maître tout près", function()
        local game, Guide = boot({ level = 4, class = "WARRIOR" })
        local services = {
            { "Battle Shout", "Rank 1", "available", 10, 1 },
            { "Rend", "Rank 1", "available", 10, 4 },
            { "Thunder Clap", "Rank 1", "unavailable", 100, 6 },
        }
        _G.IsTradeskillTrainer = function() return false end
        _G.GetNumTrainerServices = function() return #services end
        _G.GetTrainerServiceInfo = function(i) return services[i][1], services[i][2], services[i][3] end
        _G.GetTrainerServiceCost = function(i) return services[i][4] end
        _G.GetTrainerServiceLevelReq = function(i) return services[i][5] end
        game:fire("TRAINER_SHOW")
        local list, total = Guide:SpellsToLearn()
        expect_eq(#list, 2, "les sorts disponibles chez le maître")
        expect_eq(total, 20)
        expect_eq(list[2].name, "Rend (Rank 1)")
        services = {}
        game:fire("TRAINER_UPDATE")
        expect_eq(#Guide:SpellsToLearn(), 0, "tout appris")
        expect(Guide:SpellsToLearn(nil, 10), "au-delà du niveau : les tables")

        -- En ville : le maître des guerriers du guide est à quelques mètres.
        Guide.char.trainerList = nil
        game.player.position = worldOf(game.ns, 50.3, 42.3)
        Guide:Start(GUIDE_ID)
        local trainer, distance = Guide:NearbyClassTrainer()
        expect(trainer and trainer.npc == 911, "maître des guerriers")
        expect(distance < 400)
        game.player.position = worldOf(game.ns, 20, 80)
        expect_eq(Guide:NearbyClassTrainer(), nil, "loin de la ville")
        expect_eq(#game.errors, 0)
    end)

    it("ignore une seule quête ou un seul objectif, et les reprend", function()
        local game, Guide = boot()
        game.ns.DB.AddGuide(function() return {
            id = "test/many", title = "Many", category = "Test", minLevel = 1, maxLevel = 10,
            steps = {
                { title = "Accept", goals = {
                    { t = "accept", quest = 900, npc = 1 },
                    { t = "accept", quest = 901, npc = 1 },
                } },
                { title = "Later", goals = { { t = "turnin", quest = 901, npc = 2 } } },
            },
        } end)
        game:fire("QUEST_LOG_UPDATE")
        local r = Guide:Start("test/many")
        expect_eq(r.current, 1)
        local entries = Guide:GoalMenuEntries(1, 1)
        expect(entries[1].label:find("Ignore this objective", 1, true))
        expect(entries[2].label:find("Ignore the quest", 1, true))
        -- Ignorer la quête 900 : l'étape ne retient plus que la 901.
        entries[2].action()
        expect(Guide.char.ignoredQuests[900])
        expect_eq(Guide.result.steps[1].goals[1].status, "na")
        expect_eq(Guide.result.current, 1, "la 901 reste à prendre")
        -- Ignorer l'objectif de la 901 : l'étape est passée, la quête emportée.
        Guide:IgnoreGoal(1, 2)
        expect(Guide.result.current ~= 1, "étape passée")
        local texts = table.concat(Guide.windowTexts or {}, " | ")
        expect(texts:find("1 ignored quests", 1, true), texts)
        -- Reprendre la quête 900.
        Guide:IgnoreQuest(900, false)
        Guide:IgnoreGoal(1, 2, false)
        expect_eq(Guide.char.ignoredQuests[900], nil)
        expect_eq(Guide.result.current, 1, "de nouveau à faire")
        expect_eq(#game.errors, 0)
    end)

    it("ne vise pas le rendu d'une quête pas encore acceptée", function()
        local game, Guide = boot()
        game.ns.DB.AddGuide(function() return {
            id = "test/chain", title = "Chain", category = "Test", minLevel = 1, maxLevel = 10,
            steps = {
                { title = "Herbalist", goals = {
                    { t = "turnin", quest = 130, npc = 342, map = MAP, x = 30, y = 30, f = "e" },
                    { t = "accept", quest = 131, npc = 342, map = MAP, x = 30, y = 30, f = "e", pre = { 130 } },
                    { t = "turnin", quest = 131, npc = 379, map = MAP, x = 60, y = 60, f = "e" },
                } },
            },
        } end)
        game:acceptQuest(130, {})
        game:completeQuest(130)
        game.player.position = worldOf(game.ns, 61, 61)
        game:fire("QUEST_LOG_UPDATE")
        local r = Guide:Start("test/chain")
        expect_eq(r.target.goal, 1, "d'abord rendre la quête de l'herboriste, même si Darcy est plus près")
        game:turnInQuest(130)
        game:fire("QUEST_TURNED_IN", 130)
        game:fire("QUEST_LOG_UPDATE")
        expect_eq(Guide.result.target.goal, 2, "puis accepter la suite")
        game:acceptQuest(131, {})
        game:fire("QUEST_LOG_UPDATE")
        expect_eq(Guide.result.target.goal, 3, "enfin la rendre à Darcy")
    end)

    it("met de côté une quête que le PNJ ne propose pas", function()
        local game, Guide = boot({ level = 26 })
        game.ns.DB.AddGuide(function() return {
            id = "test/offers", title = "Offers", category = "Test", minLevel = 1, maxLevel = 60,
            steps = {
                { title = "Menethil", goals = {
                    { t = "accept", quest = 900, npc = 50, qlvl = 25 },
                    { t = "accept", quest = 901, npc = 50, qlvl = 25 },
                    { t = "accept", quest = 902, npc = 50, qlvl = 12 },
                } },
                { title = "Rendre 900", goals = { { t = "turnin", quest = 900, npc = 60 } } },
                { title = "Rendre 901", goals = { { t = "turnin", quest = 901, npc = 60 } } },
            },
        } end)
        local offered = { 901 }
        _G.C_GossipInfo = { GetAvailableQuests = function()
            local list = {}
            for i, id in ipairs(offered) do list[i] = { questID = id } end
            return list
        end }
        game:fire("QUEST_LOG_UPDATE")
        Guide:Start("test/offers")
        local function status(i, j) return Guide.result.steps[i].goals[j] end

        game:setUnit("npc", { guid = npcGUID(51) })
        game:fire("GOSSIP_SHOW")
        expect_eq(status(1, 1).status, "todo", "un autre PNJ ne dit rien de la quête")

        game:setUnit("npc", { guid = npcGUID(50) })
        game:fire("GOSSIP_SHOW")
        expect_eq(status(1, 1).status, "na", "absente de la liste du PNJ")
        expect_eq(status(1, 1).reason.kind, "notOffered")
        expect_eq(status(1, 2).status, "todo", "proposée")
        expect_eq(status(1, 3).status, "todo", "grise : le client peut la cacher, rien n'est prouvé")

        offered = { 900, 901 }
        game:fire("GOSSIP_SHOW")
        expect_eq(status(1, 1).status, "todo", "proposée à nouveau : elle revient")

        offered = { 901 }
        game:fire("GOSSIP_SHOW")
        expect_eq(status(1, 1).status, "na")
        game:fire("QUEST_TURNED_IN", 5)
        game:fire("QUEST_LOG_UPDATE")
        expect_eq(status(1, 1).status, "todo", "une quête rendue peut la débloquer")

        game:fire("GOSSIP_SHOW")
        Guide.char.notOffered[900] = 25
        Guide:Refresh()
        expect_eq(status(1, 1).status, "todo", "refus d'un autre niveau oublié")

        game:fire("GOSSIP_SHOW")
        game:acceptQuest(901, {})
        game:acceptQuest(902, {})
        game:fire("QUEST_LOG_UPDATE")
        expect_eq(Guide.result.current, 3, "le rendu de la quête refusée est passé aussi")
        expect_eq(#game.errors, 0)
        _G.C_GossipInfo = nil
    end)

    it("déduit l'absence de quête à proposer d'une fenêtre de quête ouverte d'emblée", function()
        local game, Guide = boot({ level = 27 })
        game.ns.DB.AddGuide(function() return {
            id = "test/direct", title = "Direct", category = "Test", minLevel = 1, maxLevel = 60,
            steps = { { title = "Whelgar", goals = {
                { t = "accept", quest = 920, npc = 80 },
                { t = "accept", quest = 921, npc = 80 },
                { t = "talk", npc = 999 },   -- garde l'étape ouverte
            } } },
        } end)
        local clock = 100
        _G.GetTime = function() return clock end
        _G.C_GossipInfo = { GetAvailableQuests = function() return { { questID = 920 }, { questID = 921 } } end }
        game:fire("QUEST_LOG_UPDATE")
        Guide:Start("test/direct")
        local function status(j) return Guide.result.steps[1].goals[j].status end
        game:setUnit("npc", { guid = npcGUID(80) })

        -- Liste, puis une quête choisie : la fenêtre de quête continue le dialogue.
        game:fire("GOSSIP_SHOW")
        game:fire("GOSSIP_CLOSED")
        clock = clock + 0.1
        game:fire("QUEST_PROGRESS")
        clock = clock + 10
        game:fire("QUEST_COMPLETE")
        expect_eq(status(1), "todo", "venue de la liste : rien n'est déduit")
        game:fire("QUEST_FINISHED")

        -- Plus tard, la fenêtre de la quête en cours s'ouvre d'emblée : rien à proposer.
        clock = clock + 30
        game:fire("QUEST_PROGRESS")
        expect_eq(status(1), "na")
        expect_eq(status(2), "na")
        game:fire("QUEST_FINISHED")

        -- Une seule quête proposée, ouverte d'emblée : les autres ne le sont pas.
        _G.GetQuestID = function() return 921 end
        clock = clock + 30
        game:fire("QUEST_DETAIL")
        expect_eq(status(1), "na")
        expect_eq(status(2), "todo")
        expect_eq(#game.errors, 0)
        _G.GetTime, _G.GetQuestID, _G.C_GossipInfo = nil, nil, nil
    end)

    it("lit aussi les quêtes proposées sans dialogue (QUEST_GREETING)", function()
        local game, Guide = boot({ level = 20 })
        game.ns.DB.AddGuide(function() return {
            id = "test/greeting", title = "Greeting", category = "Test", minLevel = 1, maxLevel = 60,
            steps = { { title = "PNJ", goals = {
                { t = "accept", quest = 910, npc = 70 },
                { t = "accept", quest = 911, npc = 70 },
            } } },
        } end)
        _G.GetNumAvailableQuests = function() return 1 end
        _G.GetAvailableQuestInfo = function() return false, 0, false, false, 911 end
        game:fire("QUEST_LOG_UPDATE")
        Guide:Start("test/greeting")
        game:setUnit("npc", { guid = npcGUID(70) })
        game:fire("QUEST_GREETING")
        expect_eq(Guide.result.steps[1].goals[1].status, "na")
        expect_eq(Guide.result.steps[1].goals[2].status, "todo")
        _G.GetNumAvailableQuests, _G.GetAvailableQuestInfo = nil, nil
    end)

    it("signale les quêtes de groupe et d'élite sur tous leurs objectifs", function()
        local game, Guide = boot()
        game.ns.DB.AddGuide(function() return {
            id = "test/group", title = "Group", category = "Test", minLevel = 1, maxLevel = 10,
            steps = {
                { title = "Accept", goals = {
                    { t = "accept", quest = 900, npc = 1 },
                    { t = "accept", quest = 901, npc = 1 },
                } },
                { title = "Do", goals = {
                    { t = "collect", quest = 900, item = 2, group = { kind = "elite", rank = 1 } },
                    { t = "kill", quest = 901, npc = 3, group = { kind = "group", size = 3 } },
                } },
            },
        } end)
        game:fire("QUEST_LOG_UPDATE")
        Guide:Start("test/group")
        expect(hasText(Guide, "(elite)"), "quête d'élite signalée dès l'acceptation")
        expect(hasText(Guide, "(group of 3)"), "taille du groupe")
        local Labels = game.ns.GuideLabels
        local guide = game.ns.DB:GetGuide("test/group")
        expect_eq(Labels.GroupTag({ t = "accept", quest = 902 }, guide), nil, "quête solo")
        -- Sans indication du guide : la base de quêtes (« Recherché : Lardeur », de groupe).
        expect_eq(Labels.GroupTag({ t = "accept", quest = 176 }, guide), "group")
        local elite
        for quest, kind in pairs(game.ns.DB.questGroups) do
            if kind == "e" then
                elite = elite or quest
            end
        end
        expect_eq(Labels.GroupTag({ t = "accept", quest = elite }, guide), "elite", "quête élite " .. elite)
        expect_eq(Labels.GroupTag({ group = { kind = "dungeon", name = "Stockade" } }, guide), "dungeon: Stockade")
    end)

    it("colore le niveau des quêtes selon leur difficulté", function()
        local game, Guide = boot()
        local Labels = game.ns.GuideLabels
        expect_eq(Labels.Difficulty(10, 10), "normal")
        expect_eq(Labels.Difficulty(12, 10), "normal", "2 au-dessus : encore jaune")
        expect_eq(Labels.Difficulty(13, 10), "hard")
        expect_eq(Labels.Difficulty(15, 10), "impossible")
        expect_eq(Labels.Difficulty(7, 10), "easy")
        expect_eq(Labels.Difficulty(4, 10), "trivial", "gris à 10 : niveau 4 et moins")
        expect_eq(Labels.Difficulty(1, 3), "normal", "rien n'est gris avant le niveau 6")
        expect_eq(Labels.Difficulty(36, 45), "easy")
        expect_eq(Labels.Difficulty(35, 45), "trivial", "gris à 45 : niveau 35 et moins")

        game.ns.DB.AddGuide(function() return {
            id = "test/levels", title = "Levels", category = "Test", minLevel = 1, maxLevel = 10,
            steps = {
                { title = "Quests", goals = {
                    { t = "accept", quest = 910, npc = 1, qlvl = 6 },
                    { t = "turnin", quest = 911, npc = 1 },
                } },
            },
        } end)
        local guide = game.ns.DB:GetGuide("test/levels")
        expect_eq(Labels.QuestLevel({ t = "kill", quest = 910 }, guide), 6, "niveau repris de l'acceptation")
        expect_eq(Labels.LevelTag({ t = "turnin", quest = 911 }, guide, 1), nil, "niveau inconnu")
        game:fire("QUEST_LOG_UPDATE")
        Guide:Start("test/levels")
        expect(hasText(Guide, "|cffff1a1a[6]|r"), "niveau 6 en rouge pour un personnage de niveau 1")
    end)

    it("dit qui donne et qui reprend la quête", function()
        local game = boot()
        local Labels = game.ns.GuideLabels
        local guide = game.ns.DB:GetGuide("forever/alliance/human/01-elwynn-forest")
        expect_eq(Labels.Goal({ t = "accept", quest = 91736, object = 562131 }, guide),
            "Accept Applejack Still (object: Applejack Still)", "quête donnée par un objet du monde")
        expect_eq(Labels.Goal({ t = "turnin", quest = 783, npc = 197 }, guide),
            "Turn in A Threat Within to Marshal McBride")
        expect_eq(Labels.Goal({ t = "accept", quest = 91741, item = 247834 }, guide),
            "Accept " .. game.ns.DB:GetName("quest", 91741, guide) .. " (item: Nibbled-On Book)")
        expect_eq(Labels.Goal({ t = "turnin", quest = 783, npc = 197, note = "{npc:197}, inside" }, guide),
            "Turn in A Threat Within", "PNJ déjà nommé par la note")
    end)

    it("dit pourquoi la flèche envoie vers un lieu", function()
        local game, Guide = boot()
        game.ns.DB.AddGuide(function() return {
            id = "test/purpose", title = "Purpose", category = "Test", minLevel = 1, maxLevel = 10,
            steps = {
                { title = "Goldshire", goals = {
                    { t = "goto", map = MAP, x = 42, y = 65, f = "e", r = 10, text = "{area:87}" },
                    { t = "turnin", quest = 999, npc = 1, only = { races = { "DWARF" } } },
                    { t = "train", class = true },
                } },
            },
        } end)
        game.player.position = worldOf(game.ns, 48, 42)
        game:fire("QUEST_LOG_UPDATE")
        local r = Guide:Start("test/purpose")
        expect_eq(r.target.goal, 1, "la flèche vise le déplacement")
        local label = Guide.arrowFrame.label.text
        expect(label:find(", for: ", 1, true), "le but est annoncé : " .. tostring(label))
        expect(label:find("class trainer", 1, true), "le maître de classe, pas la quête d'une autre race")
    end)

    it("montre le texte d'une quête au survol et l'ouvre dans le journal de quêtes", function()
        local game, Guide = boot()
        game:acceptQuest(783, { kill() })
        game:fire("QUEST_LOG_UPDATE")
        Guide:Start(GUIDE_ID)
        Guide:Refresh()
        -- Ligne de l'objectif « tuer » de la quête 783 (étape 2) : infobulle et clic.
        local line
        for _, candidate in ipairs(Guide.window.lines) do
            if type(rawget(candidate, "tooltip")) == "function" and rawget(candidate, "onClick") then
                line = candidate
            end
        end
        expect(line, "ligne de quête avec infobulle et clic")
        local texts = {}
        local tooltip = {
            SetText = function(_, text) texts[#texts + 1] = text end,
            AddLine = function(_, text) texts[#texts + 1] = text end,
        }
        line.tooltip(tooltip)
        local all = table.concat(texts, " ")
        expect(all:find("Kobold Vermin slain", 1, true), "objectif du client dans l'infobulle")
        expect(all:find("quest log", 1, true), "invitation à cliquer")
        local opened
        _G.QuestMapFrame_OpenToQuestDetails = function(quest) opened = quest end
        line.onClick()
        expect_eq(opened, 783, "journal de quêtes ouvert sur la quête")
        _G.QuestMapFrame_OpenToQuestDetails = nil

        -- Quête absente du journal : infobulle, mais pas de clic.
        texts = {}
        Guide:FillQuestTooltip(tooltip, 999999, Guide.result.guide)
        expect(table.concat(texts, " "):find("Not in your quest log", 1, true))
        expect_eq(#game.errors, 0)
    end)

    it("rappelle le mode Libre en groupe, et y passe d'un clic", function()
        local game, Guide = boot()
        game:fire("QUEST_LOG_UPDATE")
        Guide:Start(GUIDE_ID)
        expect(not hasText(Guide, "In a group?"), "seul : pas de rappel")
        _G.IsInGroup = function() return true end
        Guide:Refresh()
        expect(hasText(Guide, "In a group?"), "en groupe : rappel")
        for _, line in ipairs(Guide.window.lines) do
            local text = rawget(line.text, "text")
            if text and text:find("In a group?", 1, true) then
                rawget(line, "onClick")()
            end
        end
        expect_eq(Guide.char.mode, "free")
        expect(not hasText(Guide, "In a group?"), "déjà en mode libre : plus de rappel")
        _G.IsInGroup = nil
        SlashCmdList.NEXTSTEP("debug")
        expect_eq(#game.errors, 0)
    end)

    it("signale ce qu'on peut faire tout de suite auprès d'un PNJ proche", function()
        local game, Guide = boot()
        game.ns.DB.AddGuide(function() return {
            id = "test/nearby", title = "Nearby", category = "Test", minLevel = 1, maxLevel = 10,
            steps = {
                { title = "Far away", goals = { { t = "goto", map = MAP, x = 20, y = 80, f = "e", r = 5 } } },
                { title = "Later", goals = {
                    { t = "turnin", quest = 901, npc = 197, map = MAP, x = 50, y = 40, f = "e" },
                    { t = "accept", quest = 902, npc = 197, map = MAP, x = 50, y = 40, f = "e", pre = { 901 } },
                    { t = "accept", quest = 903, npc = 197, map = MAP, x = 50, y = 40, f = "e" },
                } },
            },
        } end)
        game:acceptQuest(901, { kill() })
        game:completeQuest(901)
        game:fire("QUEST_LOG_UPDATE")
        game.player.position = worldOf(game.ns, 50, 40)
        Guide:Start("test/nearby")
        local kinds = {}
        for _, entry in ipairs(Guide:NearbyActions()) do
            kinds[#kinds + 1] = entry.kind .. " " .. Guide.result.guide.steps[entry.step].goals[entry.goal].quest
        end
        expect_eq(kinds, { "turnin 901", "accept 903" }, "rendre la 901 ; la 902 attend que la 901 soit rendue")
        expect(hasText(Guide, "Here too"), "section « Ici aussi » dans la fenêtre")

        game.player.position = worldOf(game.ns, 20, 80)
        expect_eq(#Guide:NearbyActions(), 0, "loin du PNJ : rien")

        local container = _G.C_Container
        _G.C_Container = { GetContainerNumFreeSlots = function() return 0 end }
        Guide:Refresh()
        expect(hasText(Guide, "Bags almost full"), "sacs pleins signalés")
        _G.C_Container = container
        expect_eq(#game.errors, 0)
    end)

    it("calcule distance et direction en coordonnées monde", function()
        local game = boot()
        local Navigation = game.ns.Navigation
        game.player.position = worldOf(game.ns, 50, 50)
        expect(Navigation.DistanceTo(MAP, 50, 50, "e") < 0.001)
        local box = game.ns.DB.mapFrames.era[MAP]
        local width = math.abs(box.right - box.left)
        expect(math.abs(Navigation.DistanceTo(MAP, 60, 50, "e") - width / 10) < 0.01)

        local _, north = Navigation.Direction(MAP, 50, 40, "e")
        expect(math.abs(north) < 1e-6, "cible au nord, regard au nord : devant")
        local _, west = Navigation.Direction(MAP, 40, 50, "e")
        expect(math.abs(west - math.pi / 2) < 1e-6, "cible à l'ouest : à gauche")
        game.player.facing = math.pi / 2
        local _, ahead = Navigation.Direction(MAP, 40, 50, "e")
        expect(ahead < 1e-6 or ahead > 2 * math.pi - 1e-6, "regard à l'ouest : devant")

        game.player.position = { 0, 0, 1 }
        expect_eq(Navigation.DistanceTo(MAP, 50, 50, "e"), nil, "autre continent")
    end)

    it("propose les guides du personnage, puis le guide suivant", function()
        local game, Guide = boot()
        game:fire("QUEST_LOG_UPDATE")
        Guide:Refresh()
        expect(hasText(Guide, "No guide followed."))
        expect(hasText(Guide, "Start: "), "au moins une suggestion")
        -- Clic sur la première suggestion.
        -- rawget : un cadre simulé répond à tout champ inconnu par une fonction.
        for _, line in ipairs(Guide.window.lines) do
            local onClick = rawget(line, "onClick")
            if onClick then
                onClick()
                break
            end
        end
        expect_eq(Guide.char.active, Guide:Suggest()[1].id)
    end)

    it("propose le guide de la zone du joueur, sous-zone comprise", function()
        -- Elfe de la nuit dans une sous-carte (9999) de la forêt d'Elwynn.
        local _, Guide = boot({ race = "NightElf", map = 9999, mapParents = { [9999] = MAP, [MAP] = 1415 } })
        local maps = Guide.live:Maps()
        expect(maps[9999] and maps[MAP] and maps[1415], "carte et parentes")
        expect_eq(Guide:Suggest()[1].id, "forever/alliance/human/01-elwynn-forest")
    end)

    it("propose de nouveau les guides après /ns guide stop", function()
        local game, Guide = boot({ race = "NightElf", map = MAP, level = 3 })
        game:fire("QUEST_LOG_UPDATE")
        SlashCmdList.NEXTSTEP("guide start 1")
        expect_eq(Guide.char.active, "forever/alliance/human/01-elwynn-forest")
        SlashCmdList.NEXTSTEP("guide stop")
        expect(hasText(Guide, "No guide followed."))
        expect(hasText(Guide, "Start: Elwynn Forest"), "guide de la zone proposé")
        expect_eq(#game.errors, 0)
    end)

    it("affiche l'état du guide avec /ns debug", function()
        local game = boot({ unknownEvents = nil })
        game:fire("QUEST_LOG_UPDATE")
        local before = #game.chat
        SlashCmdList.NEXTSTEP("debug")
        expect(#game.chat > before + 5, "plusieurs lignes dans le chat")
        local all = table.concat(game.chat, " ", before + 1)
        expect(all:find("LEARNED_SPELL_IN_TAB", 1, true), "événement refusé signalé")
        expect(all:find("prêt true", 1, true), "journal lu")
        expect_eq(#game.errors, 0)
    end)

    it("masque le suivi de quêtes Blizzard pendant un guide", function()
        local game, Guide = boot()
        -- Show et Hide sont interdits : ils souilleraient le suivi de Blizzard.
        local tracker = { alpha = 1, mouse = true }
        function tracker.Show() error("Show souillerait le suivi") end
        function tracker.Hide() error("Hide souillerait le suivi") end
        function tracker.IsProtected() return false end
        function tracker.GetAlpha(self) return self.alpha end
        function tracker.SetAlpha(self, alpha) self.alpha = alpha end
        function tracker.IsMouseEnabled(self) return self.mouse end
        function tracker.EnableMouse(self, enabled) self.mouse = enabled end
        _G.ObjectiveTrackerFrame = tracker
        game:fire("QUEST_LOG_UPDATE")

        Guide:Start(GUIDE_ID)
        expect_eq(tracker.alpha, 0, "transparent")
        expect_eq(tracker.mouse, false, "ne prend plus la souris")
        Guide:Stop()
        expect_eq(tracker.alpha, 1)
        expect_eq(tracker.mouse, true)
        expect_eq(#game.errors, 0)
    end)

    it("répond aux commandes /ns guide et /ns arrow", function()
        local game, Guide = boot()
        game:fire("QUEST_LOG_UPDATE")
        SlashCmdList.NEXTSTEP("guide start 1")
        expect_eq(Guide.char.active, Guide:Suggest()[1].id)
        SlashCmdList.NEXTSTEP("guide mode")
        expect_eq(Guide.char.mode, "free")
        SlashCmdList.NEXTSTEP("guide stop")
        expect_eq(Guide.char.active, nil)
        SlashCmdList.NEXTSTEP("arrow")
        expect_eq(Guide.db.arrow, false)
        SlashCmdList.NEXTSTEP("guide")
        expect_eq(Guide.db.window.shown, false, "fenêtre masquée")
    end)

    it("affiche le vrai guide d'Elwynn en français, sans erreur", function()
        local game = wow.boot({ faction = "Alliance", locale = "frFR", player = { position = { -8900, -150, 0 } } })
        local Guide = game.ns.Modules:Get("Guide")
        game:fire("QUEST_LOG_UPDATE")
        local r = Guide:Start("forever/alliance/human/01-elwynn-forest")
        expect_eq(r.current, 1)
        expect(hasText(Guide, "Accepter "), "libellés traduits")
        expect(r.target and r.target.map == MAP, "une cible sur la carte d'Elwynn")
        Guide:UpdateArrowDirection()
        Guide:OnTick()
        expect_eq(game.errors, {}, "aucune erreur Lua")
    end)

    it("colore la flèche selon la direction", function()
        local _, Guide = boot()
        local function near(angle, expected)
            local color = { Guide.ArrowColor(angle) }
            for index = 1, 3 do
                local message = ("angle %s, composante %d"):format(angle, index)
                expect(math.abs(color[index] - expected[index]) < 1e-9, message)
            end
        end
        near(0, { 0.2, 1, 0.2 })                 -- devant : vert
        near(math.pi / 2, { 1, 0.82, 0 })        -- de côté : doré
        near(math.pi, { 1, 0.3, 0.1 })           -- derrière : rouge-orangé
        near(3 * math.pi / 2, { 1, 0.82, 0 })
    end)
end)
