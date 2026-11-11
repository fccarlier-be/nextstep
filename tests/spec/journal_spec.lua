local wow = require("wow")
local Player = require("player")

-- Journal du guide (Modules/Guide/Journal.lua) : onglet Routes.
local ELWYNN = "forever/alliance/human/01-elwynn-forest"
local WESTFALL = "forever/alliance/02-westfall"
local TAMING = "forever/class/hunter/taming-the-beast-alliance"

local function boot(player)
    local game = wow.boot({ faction = "Alliance" })
    local Guide = game.ns.Modules:Get("Guide")
    Guide:SetState(player or Player.new({ race = "NIGHTELF", class = "HUNTER", level = 10 }))
    return game, Guide
end

local function guideIDs(rows)
    local list = {}
    for _, row in ipairs(rows) do
        if row.guide then
            list[#list + 1] = row.guide.id
        end
    end
    return list
end

local function has(list, id)
    for _, value in ipairs(list) do
        if value == id then
            return true
        end
    end
    return false
end

describe("Journal du guide", function()
    it("range les guides du personnage par catégorie", function()
        local _, Guide = boot()
        local categories = Guide:JournalCategories()
        expect_eq(categories[1].key, "Leveling", "le leveling d'abord")
        local keys = {}
        for _, category in ipairs(categories) do
            keys[category.key] = category.count
        end
        expect(keys.Class and keys.Class > 0, "guides de classe du chasseur")
        local class = guideIDs(Guide:JournalRows("Class"))
        expect(has(class, TAMING), "quête du familier")
        for _, id in ipairs(class) do
            local guide = Guide:JournalShows(NextStep.DB:GetGuide(id))
            expect(guide, id)
        end
        local mage = guideIDs(Guide:JournalRows("Class", Player.new({ class = "MAGE", race = "HUMAN", level = 10 })))
        expect(not has(mage, TAMING), "pas pour un mage")
    end)

    it("propose « Choisis ton chemin » en tête du leveling", function()
        local _, Guide = boot(Player.new({ race = "NIGHTELF", class = "HUNTER", level = 10,
            maps = { [1429] = true } }))
        Guide:Start(ELWYNN)
        local rows = Guide:JournalRows("Leveling")
        expect_eq(rows[1].header, "Choose your path")
        expect_eq(rows[2].guide.id, WESTFALL, "le guide suivant du guide suivi d'abord")
        local all = guideIDs(rows)
        expect(has(all, "forever/alliance/nightelf/01-teldrassil"), "la race n'exclut aucun guide de leveling")
    end)

    it("montre l'avancement et le détail d'un guide, puis le suit", function()
        local game, Guide = boot()
        local elwynn = game.ns.DB:GetGuide(ELWYNN)
        expect_eq(Guide:GuideStatus(elwynn), 0)
        Guide:Start(ELWYNN)
        expect_eq(Guide:GuideStatus(elwynn), "active")
        Guide.char.completed[WESTFALL] = true
        expect_eq(Guide:GuideStatus(game.ns.DB:GetGuide(WESTFALL)), "done")

        local details = table.concat(Guide:GuideDetails(game.ns.DB:GetGuide(TAMING)), "\n")
        expect(details:find("Tame Beast", 1, true), "récompense : Apprivoiser une bête")
        expect(details:find("Zone: ", 1, true), "zone")

        Guide:FollowFromJournal(game.ns.DB:GetGuide(TAMING))
        expect_eq(Guide.char.active, TAMING)
        expect_eq(Guide.char.returnTo, ELWYNN, "quête de classe : la route sera reprise")

        expect(Guide:LevelRange(elwynn, 30):find("808080", 1, true), "guide gris pour un niveau 30")
        expect(Guide:LevelRange(game.ns.DB:GetGuide(WESTFALL), 10):find("ff8040", 1, true)
            or Guide:LevelRange(game.ns.DB:GetGuide(WESTFALL), 10):find("ff1a1a", 1, true)
            or Guide:LevelRange(game.ns.DB:GetGuide(WESTFALL), 10):find("ffd100", 1, true), "couleur selon le niveau")

        SlashCmdList.NEXTSTEP("journal")
        SlashCmdList.NEXTSTEP("spells")
        expect_eq(#game.errors, 0, "le journal s'ouvre sans erreur")

        -- Dessin des deux onglets (le cadre simulé se dit affiché).
        rawset(Guide.journal, "IsShown", function() return true end)
        rawset(Guide.journal.list, "GetHeight", function() return 440 end)
        rawset(Guide.journal.spells, "GetHeight", function() return 440 end)
        Guide.journalSelected = TAMING
        Guide:ShowJournalTab("routes")
        expect(#Guide.journalRows > 0, "liste dessinée")
        Guide.journalCategory = "Class"
        Guide:UpdateJournal()
        expect(has(guideIDs(Guide.journalRows), TAMING))
        expect(#Guide.journal.cards > 0, "cartes de guides dessinées")
        Guide:ShowJournalTab("spells")
        expect(#Guide.spellsWindowRows > 0, "sorts dessinés")
        expect(#Guide.journal.spells.lines > 0, "lignes de sorts dessinées")
        expect_eq(#game.errors, 0)
    end)

    it("recommence ou abandonne un guide depuis le journal, après confirmation", function()
        local game, Guide = boot()
        Guide:Start(ELWYNN)
        local key = game.ns.GuideEngine.Keys(game.ns.DB:GetGuide(ELWYNN)).steps[1]
        Guide.char.progress[ELWYNN].skipped[key] = true
        Guide.char.completed[WESTFALL] = true
        Guide.char.progress[WESTFALL] = { outcomes = {}, skipped = {} }

        -- Recommencer un guide non suivi : avancement et « terminé » oubliés.
        Guide:RestartGuide(WESTFALL)
        expect_eq(Guide.char.progress[WESTFALL], nil)
        expect_eq(Guide.char.completed[WESTFALL], nil)
        expect_eq(Guide.char.active, ELWYNN, "le guide suivi ne change pas")

        -- Le guide suivi reprend à sa première étape.
        Guide:RestartGuide(ELWYNN)
        expect(not (Guide.char.progress[ELWYNN] and Guide.char.progress[ELWYNN].skipped[key]), "étape passée oubliée")
        expect_eq(Guide.char.active, ELWYNN)

        -- Les quêtes rendues viennent du jeu, pas de l'avancement : recommencer ne les
        -- oublie pas, les étapes déjà faites se revalident d'elles-mêmes.
        local guide = game.ns.DB:GetGuide(ELWYNN)
        for _, step in ipairs(guide.steps) do
            for _, goal in ipairs(step.goals) do
                if goal.quest then
                    Guide.state:turnin(goal.quest)
                end
            end
        end
        Guide:RestartGuide(ELWYNN)
        local result = Guide:Refresh()
        expect(result.finished or (result.current and result.current > 1), "étapes des quêtes rendues validées")

        -- Abandonner un guide annexe rend la main au leveling ; l'avancement reste.
        Guide:FollowFromJournal(game.ns.DB:GetGuide(TAMING))
        Guide:AbandonGuide(TAMING)
        expect_eq(Guide.char.active, ELWYNN, "leveling repris")
        Guide:AbandonGuide(ELWYNN)
        expect_eq(Guide.char.active, nil, "plus de guide suivi")
        expect(Guide.char.progress[ELWYNN] ~= nil, "avancement gardé")

        -- Boutons du détail : un premier clic demande confirmation.
        Guide:Start(ELWYNN)
        SlashCmdList.NEXTSTEP("journal")
        rawset(Guide.journal, "IsShown", function() return true end)
        rawset(Guide.journal.list, "GetHeight", function() return 440 end)
        Guide.journalSelected = ELWYNN
        Guide:ShowJournalTab("routes")
        local abandon = Guide.journal.detail.abandon
        abandon:GetScript("OnClick")(abandon)
        expect_eq(Guide.char.active, ELWYNN, "pas encore confirmé")
        abandon:GetScript("OnClick")(abandon)
        expect_eq(Guide.char.active, nil, "abandonné au second clic")
        expect_eq(#game.errors, 0)
    end)

    it("garde le guide de leveling à reprendre après un guide annexe", function()
        local game, Guide = boot()
        Guide:Start(ELWYNN)
        local side
        for _, guide in game.ns.DB:IterateGuides() do
            if guide.category == "Collectibles" and not side then
                side = guide
            end
        end
        expect(side, "un guide de collection")
        Guide:FollowFromJournal(side)
        expect_eq(Guide.char.active, side.id)
        expect_eq(Guide.char.returnTo, ELWYNN, "le leveling sera repris")
        Guide:UpdateWindow(Guide.result)
        local texts = table.concat(Guide.windowTexts or {}, " | ")
        expect(texts:find("Back to:", 1, true), "ligne pour reprendre le leveling : " .. texts)
        Guide:Resume()
        expect_eq(Guide.char.active, ELWYNN, "leveling repris")
        expect_eq(Guide.char.returnTo, nil)

        -- Un autre guide de leveling remplace simplement le précédent.
        Guide:FollowFromJournal(game.ns.DB:GetGuide(WESTFALL))
        expect_eq(Guide.char.active, WESTFALL)
        expect_eq(Guide.char.returnTo, nil)
        expect_eq(#game.errors, 0)
    end)
end)
