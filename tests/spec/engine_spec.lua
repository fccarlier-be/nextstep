local wow = require("wow")
local Player = require("player")

-- Raccourcis pour écrire des guides de test lisibles.
local function accept(q, extra)
    local goal = { t = "accept", quest = q, npc = 1, map = 1429, x = 50, y = 50 }
    for k, v in pairs(extra or {}) do
        goal[k] = v
    end
    return goal
end
local function turnin(q)
    return { t = "turnin", quest = q, npc = 2, map = 1429, x = 50, y = 50 }
end
local function kill(q, oi)
    return { t = "kill", quest = q, oi = oi or 1, npc = 3, map = 1429, x = 40, y = 40 }
end
local function step(goals, extra)
    local s = { goals = goals }
    for k, v in pairs(extra or {}) do
        s[k] = v
    end
    return s
end
local function guide(steps, extra)
    local g = { id = "test/guide", category = "Leveling", minLevel = 1, maxLevel = 10, steps = steps }
    for k, v in pairs(extra or {}) do
        g[k] = v
    end
    return g
end

-- Évalue puis mémorise, comme le module Guide.
local function run(Engine, g, player, progress, extra)
    extra = extra or {}
    local result = Engine.Evaluate(g, {
        state = player,
        progress = progress,
        seen = extra.seen or {},
        answers = extra.answers or {},
        dungeons = extra.dungeons or {},
        trainedLevel = extra.trainedLevel,
    })
    Engine.Commit(progress, result)
    return result
end

local function setup()
    local Engine = wow.boot().ns.GuideEngine
    return Engine, Engine.NewProgress()
end

describe("Moteur du guide", function()
    it("commence à la première étape", function()
        local Engine, progress = setup()
        local g = guide({ step({ accept(1) }), step({ turnin(1) }) })
        local r = run(Engine, g, Player.new(), progress)
        expect_eq(r.current, 1)
        expect_eq(r.steps[1].status, "current")
        expect_eq(r.steps[1].goals[1].status, "todo")
        expect_eq(r.steps[2].status, "ahead")
    end)

    it("avance quand l'étape est faite et mémorise l'étape dépassée", function()
        local Engine, progress = setup()
        local g = guide({ step({ accept(1) }), step({ kill(1) }), step({ turnin(1) }) })
        local player = Player.new():accept(1)
        local r = run(Engine, g, player, progress)
        expect_eq(r.current, 2)
        expect_eq(progress.outcomes[Engine.Keys(g).steps[1]], "done")
    end)

    it("valide une étape faite en avance quand on y arrive (détour)", function()
        local Engine, progress = setup()
        local g = guide({ step({ accept(1) }), step({ accept(2) }), step({ turnin(1) }) })
        local player = Player.new():accept(2)
        expect_eq(run(Engine, g, player, progress).current, 1)
        expect_eq(run(Engine, g, player, progress).steps[2].goals[1].status, "done", "faite en avance")
        player:accept(1)
        expect_eq(run(Engine, g, player, progress).current, 3, "l'étape 2 est passée d'elle-même")
    end)

    it("ignore les étapes d'une autre classe, et la remise de leur quête", function()
        local Engine, progress = setup()
        local g = guide({
            step({ accept(1) }, { only = { classes = { "WARRIOR" } } }),
            step({ accept(2) }),
            step({ turnin(1), turnin(2) }),
        })
        local player = Player.new({ class = "MAGE" }):accept(2)
        local r = run(Engine, g, player, progress)
        expect_eq(r.steps[1].status, "na")
        expect_eq(r.current, 3)
        expect_eq(r.steps[3].goals[1].status, "na", "remise de la quête du guerrier hors sujet")
        expect_eq(r.steps[3].goals[2].status, "todo")
    end)

    it("bloque sur une quête de niveau trop élevé, en donnant la raison", function()
        local Engine, progress = setup()
        local g = guide({ step({ accept(1, { minLevel = 5 }) }) })
        local r = run(Engine, g, Player.new({ level = 3 }), progress)
        expect_eq(r.current, 1)
        expect_eq(r.steps[1].goals[1].status, "blocked")
        expect_eq(r.steps[1].blocked, { kind = "level", level = 5 })
    end)

    it("écarte une quête fermée ou sans prérequis, avec ses objectifs", function()
        local Engine, progress = setup()
        local g = guide({
            step({ accept(1, { closedBy = { 9 } }), accept(2, { pre = { 8 } }), accept(3) }),
            step({ kill(1), turnin(2), turnin(3) }),
        })
        local player = Player.new():accept(9):accept(3)
        local r = run(Engine, g, player, progress)
        expect_eq(r.steps[1].status, "done")
        expect_eq(progress.outcomes[Engine.Keys(g).steps[1]], "done")
        local goals = r.steps[2].goals
        expect_eq({ goals[1].status, goals[2].status, goals[3].status }, { "na", "na", "todo" })
    end)

    it("garde le résultat d'une étape conditionnelle une fois dépassée", function()
        local Engine, progress = setup()
        local water = { t = "buy", item = 159, count = 5, npc = 4, map = 1429, x = 1, y = 1 }
        local g = guide({
            step({ water }, { when = { { k = "has", item = 159, n = 5, neg = true } } }),
            step({ accept(1) }),
        })
        local player = Player.new({ items = { [159] = 10 } })
        expect_eq(run(Engine, g, player, progress).current, 2, "sacs pleins : étape passée")
        player.items[159] = 0
        local r = run(Engine, g, player, progress)
        expect_eq(r.steps[1].status, "na", "l'eau épuisée ne la fait pas revenir")
        expect_eq(r.current, 2)
    end)

    it("réactive une étape passée par sa condition, sans plus regarder la condition", function()
        local Engine, progress = setup()
        local g = guide({
            step({ accept(1) }, { when = { { k = "level", op = "<", n = 5 } } }),
            step({ accept(2) }),
        })
        local player = Player.new({ level = 8 })
        run(Engine, g, player, progress)
        Engine.Unskip(progress, g, 1)
        expect_eq(run(Engine, g, player, progress).current, 1)
    end)

    it("saute un bloc d'étapes quand le saut s'applique, une seule fois", function()
        local Engine, progress = setup()
        local g = guide({
            step({ accept(1) }, { skipto = { { to = "camp", when = { k = "turnedin", q = 5 } } } }),
            step({ kill(1) }),
            step({ turnin(1), accept(4) }, { label = "camp" }),
        })
        local player = Player.new()
        player.done[5] = true
        local r = run(Engine, g, player, progress)
        expect_eq({ r.steps[1].status, r.steps[2].status, r.current }, { "jumped", "jumped", 3 })
        expect_eq(r.steps[3].goals[1].status, "na", "quête jamais acceptée : sa remise est écartée")
        player.done[5] = nil
        expect_eq(run(Engine, g, player, progress).current, 3, "le saut reste acquis")

        Engine.Unskip(progress, g, 1)
        player.done[5] = true
        expect_eq(run(Engine, g, player, progress).current, 1,
            "l'étape réactivée revient, et son saut ne se reproduit pas")
        player:accept(1)
        Engine.Unskip(progress, g, 2)
        expect_eq(run(Engine, g, player, progress).current, 2, "puis l'étape suivante réactivée")
    end)

    it("ne saute pas une étape déjà faite", function()
        local Engine, progress = setup()
        local g = guide({
            step({ accept(1) }, { skipto = { { to = "camp", when = { k = "turnedin", q = 5 } } } }),
            step({ kill(1) }),
            step({ turnin(1) }, { label = "camp" }),
        })
        local player = Player.new():accept(1)
        player.done[5] = true
        local r = run(Engine, g, player, progress)
        expect_eq({ r.steps[1].status, r.current }, { "done", 2 })
    end)

    it("liste les objectifs en chemin jusqu'à l'étape indiquée", function()
        local Engine, progress = setup()
        local g = guide({
            step({ accept(1), accept(2) }),
            step({ kill(1) }, { along = "camp" }),
            step({ { t = "goto", map = 1429, x = 42, y = 65 }, accept(3) }),
            step({ turnin(1) }, { label = "camp" }),
        })
        local player = Player.new():accept(1):accept(2)
        local r = run(Engine, g, player, progress)
        expect_eq(r.current, 3, "l'étape en chemin ne retient pas la route")
        expect_eq(#r.along, 1)
        expect_eq({ r.along[1].step, r.along[1].goal }, { 2, 1 })
        player:accept(3)
        r = run(Engine, g, player, progress)
        expect_eq({ r.current, #r.along }, { 4, 0 }, "fin de la liste à l'étape « camp »")
    end)

    it("attend la réponse du joueur pour une quête de groupe", function()
        local Engine, progress = setup()
        local g = guide({
            step({ accept(6) }, { when = { { k = "group", q = 6 } } }),
            step({ accept(7) }, { when = { { k = "group", q = 6, neg = true } } }),
            step({ accept(8) }),
        })
        local player = Player.new()
        local r = run(Engine, g, player, progress)
        expect_eq({ r.current, r.steps[1].status, r.ask.quest }, { 1, "ask", 6 })
        local skip = run(Engine, g, player, Engine.NewProgress(), { answers = { [6] = false } })
        expect_eq({ skip.steps[1].status, skip.current }, { "na", 2 }, "la passer : voie solo")
        local doIt = run(Engine, g, player, Engine.NewProgress(), { answers = { [6] = true } })
        expect_eq(doIt.current, 1, "la faire")
    end)

    it("considère un trajet fait quand la suite de l'étape l'est", function()
        local Engine, progress = setup()
        local g = guide({ step({ { t = "goto", map = 1429, x = 10, y = 10 }, turnin(1) }), step({ accept(2) }) })
        local player = Player.new():accept(1):turnin(1)
        local r = run(Engine, g, player, progress)
        expect_eq(r.current, 2)
        expect_eq(r.steps[1].goals[1].implied, true)
    end)

    it("valide un point atteint, par la distance ou par un événement", function()
        local Engine, progress = setup()
        local g = guide({ step({ { t = "goto", map = 1429, x = 10, y = 10, r = 15 } }), step({ accept(2) }) })
        local near = Player.new({ distances = { ["1429:10:10"] = 12 } })
        expect_eq(run(Engine, g, near, Engine.NewProgress()).current, 2, "à 12 yards d'un rayon de 15")
        local far = Player.new({ distances = { ["1429:10:10"] = 40 } })
        expect_eq(run(Engine, g, far, progress).current, 1)
        local key = Engine.Keys(g).goals[1][1]
        expect_eq(run(Engine, g, far, progress, { seen = { [key] = true } }).current, 2)
    end)

    it("demande une validation pour ce que l'addon ne voit pas", function()
        local Engine, progress = setup()
        local g = guide({ step({ { t = "talk", npc = 5, map = 1429, x = 1, y = 1 } }), step({ accept(2) }) })
        local player = Player.new()
        local r = run(Engine, g, player, progress)
        expect_eq({ r.current, r.steps[1].goals[1].status }, { 1, "manual" })
        Engine.Tick(progress, g, 1, 1)
        expect_eq(run(Engine, g, player, progress).current, 2)
    end)

    it("n'est jamais retenu par une note ni par un objectif facultatif", function()
        local Engine, progress = setup()
        local g = guide({
            step({ { t = "note", text = "Info" }, accept(1, { optional = true }) }),
            step({ accept(2) }),
        })
        expect_eq(run(Engine, g, Player.new(), progress).current, 2)
    end)

    it("applique « when done » selon l'étape nommée", function()
        local Engine, progress = setup()
        local g = guide({
            step({ accept(1) }, { label = "willem" }),
            step({ turnin(1) }, { when = { { k = "done", label = "willem" } } }),
            step({ accept(2) }),
        })
        local player = Player.new({ class = "WARRIOR" })
        Engine.Skip(progress, g, 1)
        local r = run(Engine, g, player, progress)
        expect_eq({ r.steps[2].status, r.current }, { "na", 3 }, "étape nommée ignorée : condition fausse")
    end)

    it("signale une quête abandonnée sans revenir en arrière tout seul", function()
        local Engine, progress = setup()
        local g = guide({ step({ accept(1) }), step({ accept(2) }), step({ turnin(1) }) })
        local player = Player.new():accept(1)
        run(Engine, g, player, progress)
        player:abandon(1)
        local r = run(Engine, g, player, progress)
        expect_eq(r.current, 2)
        expect_eq(r.abandoned, { { quest = 1, step = 1 } })
        Engine.Reopen(progress, g, 1)
        expect_eq(run(Engine, g, player, progress).current, 1, "retour à l'étape sur demande")
    end)

    it("ne signale pas comme abandonnée une quête que le personnage ne peut pas reprendre", function()
        local Engine, progress = setup()
        local g = guide({
            step({ accept(1), accept(2, { only = { races = { "HUMAN" } } }), accept(3, { optional = true }) }),
            step({ accept(4) }),
            step({ turnin(1), turnin(2), turnin(3) }),
        })
        local player = Player.new({ race = "NIGHTELF" }):accept(1):accept(3)
        run(Engine, g, player, progress)
        player:abandon(3)
        local r = run(Engine, g, player, progress)
        expect_eq(r.current, 2)
        expect_eq(r.abandoned, {}, "quête réservée aux humains, ou facultative : rien à reprendre")
    end)

    it("ne renvoie pas chez le maître de classe s'il n'y a rien de nouveau", function()
        local Engine, progress = setup()
        local g = guide({ step({ { t = "train", class = true } }), step({ accept(1) }) })
        local function current(level, trainedLevel)
            local p = Engine.NewProgress()
            local r = run(Engine, g, Player.new({ level = level }), p, { trainedLevel = trainedLevel })
            return r.current
        end
        expect_eq(current(10, nil), 1, "jamais vu : il faut y aller")
        expect_eq(current(10, 10), 2, "déjà vu à ce niveau")
        expect_eq(current(11, 10), 2, "niveau impair : rien de nouveau depuis le 10")
        expect_eq(current(12, 10), 1, "niveau pair suivant : nouveaux sorts")
        expect(progress ~= nil)
    end)

    it("liste en détour les quêtes que le guide ne cite pas", function()
        local Engine, progress = setup()
        local g = guide({ step({ accept(1) }) })
        local player = Player.new():accept(42):accept(1)
        expect_eq(run(Engine, g, player, progress).detours, { 42 })
    end)

    it("regroupe en mode libre les objectifs du même endroit", function()
        local Engine, progress = setup()
        local fly = { t = "fly", area = 108, node = 4 }
        local g = guide({
            step({ accept(1), accept(2) }),
            step({ kill(1) }),
            step({ { t = "kill", quest = 2, oi = 1, map = 1436, x = 1, y = 1 } }),
            step({ fly }),
        })
        local player = Player.new():accept(1)
        local r = run(Engine, g, player, progress)
        expect_eq(r.current, 1)
        local listed = {}
        for _, entry in ipairs(r.free) do
            listed[#listed + 1] = entry.step .. "." .. entry.goal
        end
        expect_eq(listed, { "1.2", "2.1" }, "arrêt à la carte suivante")
    end)

    it("propose les guides suivants une fois terminé", function()
        local Engine, progress = setup()
        local g = guide({ step({ accept(1) }) }, { next = { "test/next" } })
        local r = run(Engine, g, Player.new():accept(1), progress)
        expect(r.finished)
        expect_eq(r.next, { "test/next" })
    end)

    it("signale un personnage en avance et les quêtes grises", function()
        local Engine, progress = setup()
        local g = guide({ step({ accept(1, { qlvl = 2 }) }), step({ accept(2, { qlvl = 9 }) }) }, { maxLevel = 6 })
        local r = run(Engine, g, Player.new({ level = 12 }), progress)
        expect(r.advice.overleveled)
        expect_eq(r.advice.greyAhead, 1)
    end)

    it("garde la progression quand une étape est ajoutée au guide", function()
        local Engine, progress = setup()
        local v1 = guide({ step({ accept(1) }), step({ accept(2) }), step({ turnin(1) }) })
        local player = Player.new({ class = "MAGE" }):accept(1)
        Engine.Skip(progress, v1, 2)
        run(Engine, v1, player, progress)
        local v2 = guide({ step({ accept(1) }), step({ accept(9) }), step({ accept(2) }), step({ turnin(1) }) })
        local r = run(Engine, v2, player, progress)
        expect_eq({ r.steps[1].status, r.steps[3].status, r.current }, { "done", "skipped", 2 },
            "les clés suivent les quêtes, pas les positions")
    end)

    it("ne demande pas de rendre une quête abandonnée, et la redemande si on la reprend", function()
        local Engine, progress = setup()
        local g = guide({
            step({ accept(1), accept(2) }),
            step({ turnin(1) }),
            step({ turnin(2) }),
        })
        local player = Player.new()
        player:accept(1)
        player:accept(2)
        local r = run(Engine, g, player, progress)
        expect_eq(r.current, 2, "rendre la 1")
        -- La quête 1 est abandonnée : son rendu est mis de côté, elle est proposée à la reprise.
        player.log[1] = nil
        r = run(Engine, g, player, progress)
        expect_eq(r.current, 3, "on passe au rendu de la 2")
        expect_eq(r.steps[2].goals[1].reason.kind, "abandoned")
        expect_eq(r.abandoned[1].quest, 1, "proposée à la reprise")
        -- Reprise de la quête 1 : l'étape de son rendu revient.
        player:accept(1)
        run(Engine, g, player, progress)
        r = run(Engine, g, player, progress)
        expect_eq(r.current, 2, "rendre la 1 de nouveau")
    end)
end)
