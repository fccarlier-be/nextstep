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
        local tracker = { shown = true }
        function tracker.Show(self) self.shown = true end
        function tracker.Hide(self) self.shown = false end
        function tracker.IsProtected() return false end
        _G.ObjectiveTrackerFrame = tracker
        game:fire("QUEST_LOG_UPDATE")

        Guide:Start(GUIDE_ID)
        expect_eq(tracker.shown, false)
        tracker:Show()
        expect_eq(tracker.shown, false, "Blizzard le réaffiche : il reste caché")
        Guide:Stop()
        expect_eq(tracker.shown, true)
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
