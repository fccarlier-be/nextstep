local wow = require("wow")

-- Résultat du moteur réduit à ce que lit la prévision : étapes, statuts, numéros.
local function result(steps, statuses)
    local r = { guide = { steps = steps }, steps = {}, along = {}, stepNumbers = {}, current = nil }
    local number = 0
    for i, status in ipairs(statuses) do
        r.steps[i] = { status = status, goals = {} }
        for j in ipairs(steps[i].goals) do
            r.steps[i].goals[j] = { status = "todo" }
        end
        if status ~= "na" then
            number = number + 1
            r.stepNumbers[i] = number
            r.current = r.current or (status == "current" and i or nil)
        end
    end
    return r
end

local function turnin(q)
    return { t = "turnin", quest = q }
end

local function setup()
    local ns = wow.boot().ns
    ns.DB.questXP = {
        [1] = 300 * 100 + 10,  -- 300 XP, niveau 10
        [2] = 500 * 100 + 10,
        [3] = 0 * 100 + 10,    -- XP inconnue : médiane du niveau 10
        [4] = 1000 * 100 + 2,  -- quête de niveau 2
    }
    ns.DB.questXPByLevel = { [10] = 400 }
    return ns.GuidePace
end

describe("Prévision de niveau", function()
    it("réduit l'expérience d'une quête trop basse, comme le jeu", function()
        local Pace = setup()
        expect_eq(Pace.QuestXP(1, 10), 300)
        expect_eq(Pace.QuestXP(1, 15), 300, "jusqu'à 5 niveaux d'écart : entière")
        expect_eq(Pace.QuestXP(1, 16), 240, "6 niveaux : 80 %")
        expect_eq(Pace.QuestXP(4, 20), 100, "10 niveaux et plus : 10 %")
        expect_eq(Pace.QuestXP(3, 10), 400, "XP inconnue : médiane du niveau")
        expect_eq(Pace.QuestXP(99, 10), 0, "quête inconnue")
    end)

    it("trouve l'étape du niveau suivant et l'avance sur un palier de niveau", function()
        local Pace = setup()
        local steps = {
            { goals = { turnin(1) } },                     -- 300
            { goals = { { t = "goto" } } },
            { goals = { turnin(2) } },                     -- 500 : 800 au total
            { goals = { { t = "level", level = 11 } } },
            { goals = { turnin(3) } },
        }
        -- Niveau 10 à moitié (3800 / 7600) : il manque 3800... trop pour 800 XP.
        local r = result(steps, { "current", "ahead", "ahead", "ahead", "ahead" })
        local f = Pace.Forecast(r, 10, 0.5, 7600)
        expect_eq(f.level, 11)
        expect_eq(f.step, nil, "pas avant la fin du guide")
        expect_eq(f.goal.level, 11)
        expect_eq(f.goal.step, 4)
        expect_eq(f.goal.missing, 3000)
        expect_eq(f.goal.bars, 8, "3000 sur 7600 : 8 barres sur 20")

        -- Presque au niveau 11 (7000 / 7600) : la quête de l'étape 3 le fait passer.
        f = Pace.Forecast(r, 10, 7000 / 7600, 7600)
        expect_eq(f.step, 3)
        expect_eq(f.goal.missing, 0, "en bonne voie")
    end)

    it("ne compte ni les quêtes déjà rendues ni les étapes hors sujet", function()
        local Pace = setup()
        local steps = { { goals = { turnin(1) } }, { goals = { turnin(2) } }, { goals = { turnin(4) } } }
        local r = result(steps, { "current", "na", "ahead" })
        r.steps[1].goals[1].status = "done"
        -- Niveau 10, il manque 300 : la quête 1, rendue, les aurait donnés dès l'étape 1 ;
        -- seule compte la quête 4, de niveau 2 (1000 XP réduits à 400).
        local f = Pace.Forecast(r, 10, 7300 / 7600, 7600)
        expect_eq(f.step, 3)
    end)

    it("se tait au niveau maximum", function()
        local Pace = setup()
        local r = result({ { goals = { turnin(1) } } }, { "current" })
        expect_eq(Pace.Forecast(r, 60, 0, 0), nil)
    end)

    it("mesure l'expérience par heure, passage de niveau compris", function()
        local Pace = setup()
        local session = Pace.NewSession(0, 10, 7000, 7600)
        Pace.Update(session, 11, 400, 8800)
        expect_eq(session.gained, 1000)
        expect_eq(Pace.SecondsToLevel(session, 60, 400, 8800), nil, "pas avant 5 minutes")
        -- 1000 XP en 10 minutes : 8400 XP restants en 84 minutes.
        expect_eq(Pace.SecondsToLevel(session, 600, 400, 8800), 5040)
    end)
end)
