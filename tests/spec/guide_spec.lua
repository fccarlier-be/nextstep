local wow = require("wow")
local Player = require("player")

local ELWYNN = "forever/alliance/human/01-elwynn-forest"
local WESTFALL = "forever/alliance/02-westfall"
local TELDRASSIL = "forever/alliance/nightelf/01-teldrassil"

local function start(options)
    options = options or {}
    local game = wow.boot({ faction = options.faction or "Alliance", saved = options.saved })
    local Guide = game.ns.Modules:Get("Guide")
    local player = options.player or Player.new()
    Guide:SetState(player)
    return game, Guide, player
end

describe("Module Guide", function()
    it("suggère le guide de départ de la race du personnage", function()
        local _, Guide = start()
        local human = Guide:Suggest(Player.new({ race = "HUMAN" }))
        expect_eq(human[1].id, ELWYNN)

        local _, HordeGuide = start({ faction = "Horde" })
        local orc = HordeGuide:Suggest(Player.new({ race = "ORC", faction = "Horde" }))
        expect(orc[1], "un guide pour un orc niveau 1")
        local races = {}
        for _, race in ipairs(orc[1].races or {}) do
            races[race] = true
        end
        expect(races.ORC, "propre à la race : " .. orc[1].id)
    end)

    it("suggère d'abord le guide de la zone où se trouve le personnage", function()
        local _, Guide = start()
        -- Elfe de la nuit à la forêt d'Elwynn (1429) : le guide humain d'abord.
        local list = Guide:Suggest(Player.new({ race = "NIGHTELF", maps = { [1429] = true, [1415] = true } }))
        expect_eq(list[1].id, ELWYNN)
        expect_eq(list[2].id, TELDRASSIL, "puis le guide de sa race")

        -- Ailleurs : sa race d'abord, mais les autres zones de départ restent proposées.
        list = Guide:Suggest(Player.new({ race = "NIGHTELF" }))
        expect_eq(list[1].id, TELDRASSIL)
        local ids = {}
        for _, guide in ipairs(list) do
            ids[guide.id] = true
        end
        expect(ids[ELWYNN], "la race n'exclut aucun guide")
    end)

    it("propose la quête du familier au chasseur de niveau 10, puis reprend la route", function()
        local TAMING = "forever/class/hunter/taming-the-beast-alliance"
        local player = Player.new({ race = "NIGHTELF", class = "HUNTER", level = 10 })
        local _, Guide = start({ player = player })
        local function ids(list)
            local set = {}
            for _, guide in ipairs(list) do
                set[guide.id] = true
            end
            return set
        end
        expect(ids(Guide:ClassGuides())[TAMING], "quête du familier proposée")
        expect(not ids(Guide:ClassGuides(Player.new({ class = "HUNTER", level = 9 })))[TAMING], "pas avant 10")
        expect(not ids(Guide:ClassGuides(Player.new({ class = "MAGE", level = 10 })))[TAMING], "pas pour un mage")
        expect(not ids(Guide:ClassGuides(Player.new({ class = "HUNTER", level = 10, spells = { [1515] = true,
            [5149] = true } })))[TAMING], "sorts déjà appris : faite")

        Guide:Start(ELWYNN)
        Guide:StartClassGuide(TAMING)
        expect_eq(Guide.char.active, TAMING)
        expect_eq(Guide.char.returnTo, ELWYNN, "la route sera reprise")
        Guide:Resume()
        expect_eq(Guide.char.active, ELWYNN)
        expect_eq(Guide.char.returnTo, nil)
    end)

    it("ne suggère que des guides du niveau du personnage", function()
        local _, Guide = start()
        for _, guide in ipairs(Guide:Suggest(Player.new({ level = 20 }))) do
            expect(guide.minLevel <= 20 and 20 <= guide.maxLevel, guide.id)
        end
    end)

    it("suit les premiers pas d'un humain guerrier à Comté-du-Nord", function()
        local _, Guide, player = start({ player = Player.new({ race = "HUMAN", class = "WARRIOR" }) })
        local r = Guide:Start(ELWYNN)
        expect_eq(r.current, 1)
        local first = r.guide.steps[1].goals[1]
        expect_eq({ first.t, first.quest, r.steps[1].goals[1].status }, { "accept", 783, "todo" })

        player:accept(783):turnin(783):accept(7):accept(5261):turnin(5261):accept(33)
        r = Guide:Refresh()
        expect_eq(r.current, 2, "l'étape de la quête de démoniste ne retient pas un guerrier")
        expect_eq(r.guide.steps[2].goals[1].quest, 33)

        player:objective(33, 1)
        r = Guide:Refresh()
        expect_eq(r.current, 3)
        expect_eq(r.steps[3].goals[2].status, "manual", "aller voir le maître de classe se valide")
    end)

    it("garde la progression d'une session à l'autre", function()
        local game, Guide, player = start()
        Guide:Start(ELWYNN)
        player:accept(783):turnin(783):accept(7):accept(5261):turnin(5261):accept(33)
        Guide:Refresh()
        local saved = wow.saved()
        expect_eq(saved.NextStepCharDB.modules.Guide.active, ELWYNN)

        local _, again = start({ saved = saved, player = Player.new() })
        local r = again:Refresh()
        expect_eq(r.steps[1].status, "done", "étape dépassée mémorisée, même sans le journal")
        expect(game, "première session")
    end)

    it("ne mémorise rien tant que le journal de quêtes n'est pas lu", function()
        local _, Guide, player = start({ player = Player.new({ ready = false }) })
        Guide:Start(ELWYNN)
        player:accept(783):turnin(783):accept(7):accept(5261):turnin(5261):accept(33)
        Guide:Refresh()
        expect_eq(next(Guide:Progress(ELWYNN).outcomes), nil)
    end)

    it("prévient l'interface à chaque recalcul", function()
        local game, Guide = start()
        local received
        game.ns.Events:RegisterMessage("NEXTSTEP_GUIDE_UPDATED", "test", function(_, _, result)
            received = result
        end)
        Guide:Start(ELWYNN)
        expect(received and received.guide.id == ELWYNN)
        expect_eq(received.mode, "strict")
        Guide:SetMode("free")
        expect_eq(received.mode, "free")
    end)

    it("ignore une étape puis la réactive", function()
        local _, Guide = start()
        Guide:Start(ELWYNN)
        local skipped = Guide:Skip(1)
        expect_eq(skipped.steps[1].status, "skipped")
        expect_eq(skipped.steps[2].status, "na", "la quête 33 acceptée à l'étape 1 est écartée")
        expect_eq(skipped.current, 3)
        expect_eq(Guide:Unskip(1).current, 1)
    end)

    it("enchaîne sur un guide suivant, et seulement sur l'un d'eux", function()
        local _, Guide = start()
        Guide:Start(ELWYNN)
        expect_eq(Guide:ChooseNext(WESTFALL).guide.id, WESTFALL)
        local ok = pcall(Guide.ChooseNext, Guide, ELWYNN)
        expect(not ok, "Elwynn ne suit pas la Marche de l'Ouest")
    end)

    it("abandonne un guide retiré de Polestar", function()
        local game = wow.boot()
        local retired = next(game.ns.DB.retired)
        local _, Guide = start({
            saved = { NextStepCharDB = { schema = 1, modules = { Guide = { active = retired } } } },
        })
        expect_eq(Guide.char.active, nil)
    end)

    it("évalue chaque guide importé sans erreur", function()
        local game = wow.boot({ faction = "Alliance" })
        local horde = wow.boot({ faction = "Horde" })
        local Engine = game.ns.GuideEngine
        local count = 0
        for _, ns in ipairs({ game.ns, horde.ns }) do
            for id, guide in ns.DB:IterateGuides() do
                local ok, err = pcall(Engine.Evaluate, guide, {
                    state = Player.new({ faction = guide.faction or "Alliance" }),
                    progress = Engine.NewProgress(),
                    seen = {},
                    answers = {},
                })
                expect(ok, id .. " : " .. tostring(err))
                count = count + 1
            end
        end
        expect(count > 250, "tous les guides : " .. count)
    end)
end)
