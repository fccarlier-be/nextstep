-- Horaires des bateaux : détection à bord, apprentissage, prévision.

local wow = require("wow")

local function boot()
    local game = wow.boot({ faction = "Alliance" })
    game.ns.Transports = game.ns.Modules:Get("Transports")
    return game, game.ns.Transports, game.ns
end

-- Position monde d'un quai, décalée de dn yards vers le nord.
local function at(ns, dock, dn)
    local instance, north, west = ns.Travel.Where(dock)
    return instance, north + (dn or 0), west
end

-- Rejoue des relevés : { t, instance, north, west } ; renvoie les événements.
local function feed(tracker, samples)
    local events = {}
    for _, s in ipairs(samples) do
        local event = tracker:Feed(s[1], s[2], s[3], s[4], 0, false)
        if event then
            events[#events + 1] = event
        end
    end
    return events
end

-- Traversée : immobile au quai a, en mouvement (avec changement de continent si besoin),
-- immobile au quai b. Renvoie les relevés et l'heure suivante.
local function ride(ns, a, b, t0, wait, length)
    local samples = {}
    local t = t0
    local ai, an, aw = at(ns, a)
    for _ = 1, wait * 2 do
        samples[#samples + 1] = { t, ai, an, aw }
        t = t + 0.5
    end
    local bi, bn, bw = at(ns, b)
    for k = 1, length * 2 do
        if bi ~= ai and k > length then
            samples[#samples + 1] = { t, bi, bn + (length * 2 - k + 1) * 5, bw }
        else
            samples[#samples + 1] = { t, ai, an + k * 5, aw }
        end
        t = t + 0.5
    end
    for _ = 1, 4 do
        samples[#samples + 1] = { t, bi, bn, bw }
        t = t + 0.5
    end
    return samples, t
end

describe("Transports", function()
    it("reconnaît une traversée, d'un continent à l'autre", function()
        local _, Transports, ns = boot()
        local D = ns.Travel.DOCKS
        local tracker = Transports.Tracker.New()
        local samples = ride(ns, D.theramore, D.menethil, 1000, 5, 60)
        local events = feed(tracker, samples)
        expect_eq(#events, 1)
        local e = events[1]
        expect_eq(e.link, "menethil-theramore")
        expect_eq(e.from, "theramore")
        expect_eq(e.to, "menethil")
        expect_eq(e.departed, 1004.5, "dernier relevé à quai")
    end)

    it("retient le départ sans attendre l'arrivée, mais pas une simple poussée", function()
        local _, Transports, ns = boot()
        local D = ns.Travel.DOCKS
        -- Tram : on descend en marchant dès l'arrêt, sans jamais rester immobile.
        local tracker = Transports.Tracker.New()
        local t, events = 0, {}
        local function sample(west, speed, north)
            local e = tracker:Feed(t, 369, north or 4.5, west, speed, false)
            if e then
                events[#events + 1] = e
            end
            t = t + 0.5
        end
        sample(D.tramIronforge.west, 0)
        for k = 1, 30 do
            sample(D.tramIronforge.west + k * 40, 0)
        end
        for k = 1, 10 do
            sample(D.tramIronforge.west + 1200 + k * 3, 7)
        end
        expect_eq(#events, 1, "départ retenu")
        expect_eq(events[1].link, "tram-north")
        expect_eq(events[1].from, "tramIronforge")

        -- Poussée d'une seconde près d'un quai, puis marche : rien.
        tracker, events = Transports.Tracker.New(), {}
        local i, n, w = at(ns, D.menethil)
        for k = 0, 2 do
            local e = tracker:Feed(t, i, n + k * 6, w, 0, false)
            events[#events + 1] = e
            t = t + 0.5
        end
        for k = 1, 40 do
            local e = tracker:Feed(t, i, n + 12 + k * 3, w, 7, false)
            events[#events + 1] = e
            t = t + 0.5
        end
        expect_eq(#events, 0, "pas de départ")
    end)

    it("suit le bateau de Menethil d'escale en escale (Austrivage sur Forever)", function()
        local _, Transports, ns = boot()
        local D = ns.Travel.DOCKS
        local tracker = Transports.Tracker.New()
        local first, t = ride(ns, D.menethil, D.southshore, 1000, 5, 60)
        local second = ride(ns, D.southshore, D.auberdine, t, 30, 60)
        local events = feed(tracker, first)
        for _, e in ipairs(feed(tracker, second)) do
            events[#events + 1] = e
        end
        expect_eq(#events, 2)
        expect_eq(events[1].link, "menethil-auberdine")
        expect_eq(events[1].to, "southshore")
        expect_eq(events[2].link, "menethil-auberdine")
        expect_eq(events[2].from, "southshore")
        expect_eq(events[2].to, "auberdine")
    end)

    it("situe le tour d'un départ vu, et prévoit chaque escale", function()
        local _, Transports = boot()
        local route = Transports.RouteById("menethil-auberdine")
        local realm = {}
        -- Départ d'Auberdine vu à 10000 : le tour a commencé 404,997 s plus tôt.
        Transports.Learn(realm, { link = route.id, from = "auberdine", departed = 10000 })
        local data = realm[route.id]
        expect(math.abs(data.start - 9595.003) < 0.001, "début du tour")
        -- Menethil : départ 60 s après le début du tour, puis tous les 486,226 s.
        local wait, docked = Transports.NextDeparture(data, route, "menethil", 10000)
        expect(math.abs(wait - 141.229) < 0.01, "prochain départ de Menethil : " .. wait)
        expect_eq(docked, false)
        wait = Transports.NextDeparture(data, route, "southshore", 10000)
        expect(math.abs(wait - 343.505) < 0.01, "prochain départ d'Austrivage : " .. wait)
        -- 30 s avant le départ vu, le bateau est à quai à Auberdine.
        wait, docked = Transports.NextDeparture(data, route, "auberdine", 9970)
        expect(math.abs(wait - 30) < 0.01, "à quai")
        expect_eq(docked, true)
        -- Trop vieux : plus de prévision.
        expect_eq(Transports.NextDeparture(data, route, "menethil", 10000 + 25 * 3600), nil)
        -- Une observation plus ancienne ne remplace pas la récente.
        Transports.Learn(realm, { link = route.id, from = "menethil", departed = 9000 })
        expect_eq(realm[route.id].seen, 10000)
    end)

    it("convertit les observations de la version précédente", function()
        local _, Transports = boot()
        local realm = {
            ["menethil-auberdine"] = { last = { dock = "auberdine", t = 10000 }, ride = { auberdine = 82 },
                dwell = {} },
            ["menethil-theramore"] = { ride = {}, dwell = {} },
            ["inconnue"] = { last = { dock = "x", t = 1 } },
        }
        Transports.Migrate(realm)
        expect(math.abs(realm["menethil-auberdine"].start - 9595.003) < 0.001, "départ converti")
        expect_eq(realm["menethil-auberdine"].seen, 10000)
        expect_eq(realm["menethil-theramore"], nil, "rien à convertir")
        expect_eq(realm["inconnue"], nil)
    end)

    it("affiche l'attente près d'un quai, ou invite à prendre le bateau", function()
        local _, Transports, ns = boot()
        local D = ns.Travel.DOCKS
        local instance, north, west = at(ns, D.menethil, 20)
        local lines = Transports:Lines(instance, north, west, "Alliance", 10000)
        expect_eq(#lines, 2, "Auberdine (par Austrivage) et Theramore depuis Menethil")
        expect_eq(lines[1].text, "Boat to Southshore then Auberdine: time unknown, ride it once to learn it")
        Transports.Learn(Transports:Realm(), { link = "menethil-auberdine", from = "auberdine", departed = 10000 })
        lines = Transports:Lines(instance, north, west, "Alliance", 10000)
        expect_eq(lines[1].text, "Boat to Southshore then Auberdine: leaves in 2:21")
        lines = Transports:Lines(instance, north, west, "Alliance", 10000 + 141.229 - 20)
        expect_eq(lines[1].text, "Boat to Southshore then Auberdine: at the dock, leaves in 0:20")
        local far = { at(ns, D.menethil, 1000) }
        expect_eq(#Transports:Lines(far[1], far[2], far[3], "Alliance", 10000), 0, "loin du quai : rien")
    end)

    it("reconnaît la rame du tram à sa voie", function()
        local _, Transports, ns = boot()
        local D = ns.Travel.DOCKS
        for _, case in ipairs({ { 4.5, "tram-north" }, { -45.4, "tram-south" } }) do
            local tracker = Transports.Tracker.New()
            local samples = {}
            local t = 0
            for k = 0, 40 do
                local west = k == 0 and D.tramStormwind.west or (D.tramStormwind.west - k * 61)
                samples[#samples + 1] = { t, 369, case[1], math.max(west, D.tramIronforge.west) }
                t = t + 0.5
            end
            for _ = 1, 4 do
                samples[#samples + 1] = { t, 369, case[1], D.tramIronforge.west }
                t = t + 0.5
            end
            local events = feed(tracker, samples)
            expect_eq(#events, 1)
            expect_eq(events[1].link, case[2])
            expect_eq(events[1].from, "tramStormwind")
        end
        -- Au quai : une seule ligne pour les deux rames, la prochaine qui part.
        local realm = Transports:Realm()
        Transports.Learn(realm, { link = "tram-north", from = "tramStormwind", departed = 1000 })
        Transports.Learn(realm, { link = "tram-south", from = "tramStormwind", departed = 1060 })
        local lines = Transports:Lines(369, D.tramStormwind.north, D.tramStormwind.west, "Alliance", 1100)
        expect_eq(#lines, 1)
        expect_eq(lines[1].text, "Tram to Ironforge: leaves in 0:43")
    end)

    it("partage les horaires et apprend ceux des autres", function()
        local _, Transports = boot()
        local realm = {}
        Transports.Learn(realm, { link = "menethil-theramore", from = "theramore", departed = 5000 })
        local text = Transports.Encode("menethil-theramore", realm["menethil-theramore"])
        expect_eq(text, "T|menethil-theramore|4776.0|5000")
        local event = Transports.Decode(text, 5100)
        expect_eq(event.link, "menethil-theramore")
        expect_eq(event.start, 4776)
        expect_eq(event.seen, 5000)
        expect_eq(Transports.Decode(text, 5000 + 25 * 3600), nil, "trop vieux")
        expect_eq(Transports.Decode("T|inconnue|4776.0|5000", 5100), nil, "transport inconnu")
        expect_eq(Transports.Decode("S|menethil-theramore|menethil|5000|0|0", 5100), nil, "ancien format")

        _G.GetServerTime = function() return 5100 end
        Transports:OnAddonMessage(Transports.PREFIX, text, "GUILD", "Quelqu'un-Royaume")
        local data = Transports:Realm()["menethil-theramore"]
        expect(data and data.seen == 5000 and data.start == 4776, "horaire reçu de la guilde")
        _G.GetServerTime = nil
    end)
end)
