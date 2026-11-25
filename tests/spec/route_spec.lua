local wow = require("wow")

-- Chemin à pied (Modules/Guide/Route.lua) : géométrie, demandes au calculateur
-- (simulé : NextStep_NavEngine), flèche et tracé sur la minimap.
local MAP = 1429
local GUIDE_ID = "test/route"

local function close(a, b, tolerance)
    return math.abs(a - b) < (tolerance or 1e-6)
end

local function addGuide(ns)
    ns.DB.AddGuide(function() return {
        id = GUIDE_ID, title = "Route", category = "Test", minLevel = 1, maxLevel = 10,
        steps = {
            { title = "Saw", goals = {
                { t = "collect", quest = 91733, item = 247813, map = MAP, x = 60, y = 50, f = "e" },
            } },
        },
    } end)
end

-- Calculateur simulé : garde chaque demande, répond quand le test le décide.
local function fakeEngine()
    local engine = { calls = {}, cancelled = {} }
    function engine.Find(map, from, to, callback, opts)
        local job = { map = map, from = from, to = to, callback = callback, opts = opts }
        engine.calls[#engine.calls + 1] = job
        return job
    end
    function engine.Cancel(job)
        engine.cancelled[#engine.cancelled + 1] = job
    end
    function engine.Available()
        return true
    end
    return engine
end

local function boot()
    local world = { clock = 100, lines = {} }
    local engine = fakeEngine()
    local game = wow.boot({
        faction = "Alliance",
        beforeInit = function(ns)
            local minimap = setmetatable({}, { __index = function() return function() end end })
            function minimap.GetWidth() return 140 end
            function minimap.GetViewRadius() return 200 end
            function minimap.GetFrameLevel() return 1 end
            _G.Minimap = minimap
            _G.C_CVar = { GetCVar = function() return "0" end }
            _G.GetTime = function() return world.clock end
            _G.NextStep_NavEngine = engine
            addGuide(ns)
        end,
    })
    local Guide = game.ns.Modules:Get("Guide")
    if Guide.minimapPins then
        rawset(Guide.minimapPins, "CreateLine", function()
            local line = setmetatable({}, { __index = function() return function() end end })
            function line.Show(self) self.shown = true end
            function line.Hide(self) self.shown = false end
            world.lines[#world.lines + 1] = line
            return line
        end)
    end
    return game, Guide, engine, world
end

local function worldOf(ns, x, y)
    local box = ns.DB.mapFrames.era[MAP]
    return { box.top + (box.bottom - box.top) * y / 100, box.left + (box.right - box.left) * x / 100, box.c }
end

local function shownLines(world)
    local count = 0
    for _, line in ipairs(world.lines) do
        if line.shown then
            count = count + 1
        end
    end
    return count
end

local function start(game, Guide)
    game:acceptQuest(91733, { { text = "Waterlogged Saw: 0/1", finished = false } })
    game:fire("QUEST_LOG_UPDATE")
    Guide:Start(GUIDE_ID)
end

-- Réponse du calculateur : le joueur, un détour par l'est de 40 yards, la cible.
local function answer(job)
    local from, to = job.from, job.to
    local middle = { x = (from.x + to.x) / 2, y = (from.y + to.y) / 2 - 40 }
    job.callback({ { x = from.x, y = from.y }, middle, { x = to.x, y = to.y } }, 100, job)
end

describe("Chemin à pied", function()
    it("coupe un segment au bord de la minimap ronde ou carrée, et de la carte", function()
        local _, Guide = boot()
        local ax, ay, bx, by = Guide.ClipSegment(0, 0, 100, 0, 50)
        expect(close(ax, 0) and close(ay, 0) and close(bx, 50) and close(by, 0), "coupé au cercle")
        expect(Guide.ClipSegment(100, 100, 200, 100, 50) == nil, "dehors")
        local cx, _, dx = Guide.ClipSegment(-100, 0, 100, 0, 50)
        expect(close(cx, -50) and close(dx, 50), "traverse le cercle")
        local _, _, ex, ey = Guide.ClipSegment(0, 0, 100, 100, 50, true)
        expect(close(ex, 50) and close(ey, 50), "coupé au coin du carré")
        expect(Guide.ClipSegment(60, -100, 60, 100, 50, true) == nil, "à côté du carré")
        ax, ay, bx, by = Guide.ClipBox(-10, 50, 110, 50, 100, 200)
        expect(close(ax, 0) and close(ay, 50) and close(bx, 100) and close(by, 50), "coupé à la carte")
    end)

    it("situe le joueur sur le chemin et vise un point devant lui", function()
        local _, Guide = boot()
        local points = { { x = 0, y = 0 }, { x = 0, y = 100 }, { x = 100, y = 100 } }
        local distance, index, fraction = Guide.RouteProgress(points, 5, 50)
        expect(close(distance, 5) and index == 1 and close(fraction, 0.5), "milieu du premier segment")
        local x, y, remaining = Guide.RouteAhead(points, index, fraction, 15)
        expect(close(x, 0) and close(y, 65), "15 yards plus loin")
        expect(close(remaining, 150), "reste " .. remaining)
        x, y = Guide.RouteAhead(points, index, fraction, 60)
        expect(close(x, 10) and close(y, 100), "après le virage")
        x, y = Guide.RouteAhead(points, index, fraction, 500)
        expect(close(x, 100) and close(y, 100), "au plus loin : la fin")
    end)

    it("demande le chemin de la flèche, le suit, et redemande quand on s'en écarte", function()
        local game, Guide, engine, world = boot()
        game.player.position = worldOf(game.ns, 55, 50)
        start(game, Guide)
        Guide:UpdateRoute()
        expect_eq(#engine.calls, 1, "une demande")
        local job = engine.calls[1]
        local target = worldOf(game.ns, 60, 50)
        expect_eq(job.map, target[3])
        expect(close(job.to.x, target[1]) and close(job.to.y, target[2]), "vers la cible")
        expect(close(job.from.x, game.player.position[1]), "depuis le joueur")
        expect_eq(job.opts.profile, "Alliance")
        Guide:UpdateRoute()
        expect_eq(#engine.calls, 1, "rien de plus pendant le calcul")

        answer(job)
        expect(Guide:CurrentRoute(), "chemin suivi")
        -- La flèche vise le chemin (vers le détour à l'est), pas la cible tout droit.
        local aimNorth, aimWest, remaining = Guide:RouteAim()
        expect(aimWest < game.player.position[2], "le point visé est à l'est du joueur")
        Guide:UpdateArrowDirection()
        local text = Guide.arrowFrame.distance.text
        expect_eq(text, ("%d yd"):format(math.floor(remaining + 0.5)), "distance du chemin")
        expect(aimNorth, "point visé")

        -- Tracé sur la minimap.
        Guide:UpdateMinimapPins()
        expect(shownLines(world) > 0, "des lignes sur la minimap")

        -- Sur le chemin : rien de plus. Écarté de 60 yards : nouvelle demande.
        world.clock = world.clock + 5
        Guide:UpdateRoute()
        expect_eq(#engine.calls, 1, "toujours sur le chemin")
        game.player.position = { game.player.position[1] + 60, game.player.position[2], target[3] }
        Guide:UpdateRoute()
        expect_eq(#engine.calls, 2, "écarté : nouvelle demande")
        expect_eq(#game.errors, 0)
    end)

    it("pointe tout droit sans chemin, et redemande plus tard après un échec", function()
        local game, Guide, engine, world = boot()
        game.player.position = worldOf(game.ns, 55, 50)
        start(game, Guide)
        Guide:UpdateRoute()
        engine.calls[1].callback(nil, "offmesh", engine.calls[1])
        expect(Guide:CurrentRoute() == nil, "pas de chemin")
        expect(Guide:RouteAim() == nil, "la flèche pointe tout droit")
        world.clock = world.clock + 5
        Guide:UpdateRoute()
        expect_eq(#engine.calls, 1, "pas tout de suite")
        world.clock = world.clock + 6
        Guide:UpdateRoute()
        expect_eq(#engine.calls, 2, "10 secondes après l'échec")
        -- Réglage coupé : la demande en cours est annulée, rien n'est tracé.
        Guide:SetRouteLinesShown(false)
        expect_eq(#engine.cancelled, 1, "demande annulée")
        expect(Guide.route == nil, "plus de chemin")
        Guide:UpdateRoute()
        expect_eq(#engine.calls, 2, "plus de demande")
        expect_eq(#game.errors, 0)
    end)

    it("ne demande rien en combat ni sur un autre continent", function()
        local game, Guide, engine = boot()
        game.player.position = worldOf(game.ns, 55, 50)
        start(game, Guide)
        game.inCombat = true
        Guide:UpdateRoute()
        expect_eq(#engine.calls, 0, "en combat")
        game.inCombat = false
        local here = game.player.position
        game.player.position = { here[1], here[2], 9999 }
        Guide:UpdateRoute()
        expect_eq(#engine.calls, 0, "autre continent")
        game.player.position = here
        Guide:UpdateRoute()
        expect_eq(#engine.calls, 1)
        expect_eq(#game.errors, 0)
    end)
end)
