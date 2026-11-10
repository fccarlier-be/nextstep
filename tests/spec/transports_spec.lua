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
        local samples = ride(ns, D.menethil, D.theramore, 1000, 5, 60)
        local events = feed(tracker, samples)
        expect_eq(#events, 1)
        local e = events[1]
        expect_eq(e.link, "menethil-theramore")
        expect_eq(e.from, "menethil")
        expect_eq(e.to, "theramore")
        expect(math.abs(e.ride - 60) < 2, "durée de la traversée")
        expect_eq(e.dwell, nil, "pas d'escale vue au premier départ")
    end)

    it("mesure l'escale quand on reste à bord, puis prévoit les départs", function()
        local _, Transports, ns = boot()
        local D = ns.Travel.DOCKS
        local tracker = Transports.Tracker.New()
        local first, t = ride(ns, D.stormwind, D.auberdineWest, 1000, 5, 60)
        local back = ride(ns, D.auberdineWest, D.stormwind, t, 50, 60)
        local events = feed(tracker, first)
        for _, e in ipairs(feed(tracker, back)) do
            events[#events + 1] = e
        end
        expect_eq(#events, 2)
        expect_eq(events[2].from, "auberdineWest")
        expect(events[2].dwell and math.abs(events[2].dwell - 52) < 3, "escale mesurée à Auberdine")

        local realm = {}
        for _, e in ipairs(events) do
            Transports.Learn(realm, e)
        end
        local link = ns.Transports.LinkById("stormwind-auberdineWest")
        local data = realm[link.id]
        local period, exact = Transports.Period(data, link)
        -- Deux traversées mesurées, une escale : l'autre escale est présumée égale.
        expect(period > 200 and period < 240, "tour d'environ 2 x (60 + 52)")
        expect_eq(exact, false)
        -- Prochain départ d'Auberdine : un tour après le départ observé.
        local departed = events[2].departed
        local wait = Transports.NextDeparture(data, link, "auberdineWest", departed + 10)
        expect(math.abs(wait - (period - 10)) < 1, "un tour plus tard")
        -- Trop vieux : plus de prévision.
        expect_eq(Transports.NextDeparture(data, link, "auberdineWest", departed + 25 * 3600), nil)
    end)

    it("affine le tour avec deux départs du même quai", function()
        local _, Transports, ns = boot()
        local link = ns.Transports.LinkById("stormwind-auberdineWest")
        local realm = {}
        Transports.Learn(realm, { link = link.id, from = "stormwind", departed = 0, ride = 60 })
        Transports.Learn(realm, { link = link.id, from = "stormwind", departed = 3 * 250, ride = 60 })
        expect_eq(realm[link.id].period, 250, "trois tours de 250 s entre les deux départs")
        local _, exact = Transports.Period(realm[link.id], link)
        expect_eq(exact, true)
    end)

    it("affiche l'attente près d'un quai, ou invite à prendre le bateau", function()
        local _, Transports, ns = boot()
        local D = ns.Travel.DOCKS
        local instance, north, west = at(ns, D.menethil, 20)
        local lines = Transports:Lines(instance, north, west, "Alliance", 5000)
        expect_eq(#lines, 2, "Auberdine et Theramore depuis Menethil")
        expect(lines[1].text:find("ride it once", 1, true), "horaire encore inconnu")
        Transports.Learn(Transports:Realm(), { link = "menethil-theramore", from = "menethil", to = "theramore",
            departed = 4900, ride = 60, dwell = 40 })
        lines = Transports:Lines(instance, north, west, "Alliance", 5000)
        local found
        for _, line in ipairs(lines) do
            if line.text:find("Theramore", 1, true) then
                found = line
            end
        end
        expect(found and found.text:find("leaves in 3:49", 1, true), "durée du tour connue : heure exacte")
        local far = { at(ns, D.menethil, 1000) }
        expect_eq(#Transports:Lines(far[1], far[2], far[3], "Alliance", 5000), 0, "loin du quai : rien")
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
        Transports.Learn(realm, { link = "tram-north", from = "tramStormwind", departed = 1000, ride = 58 })
        Transports.Learn(realm, { link = "tram-south", from = "tramStormwind", departed = 1060, ride = 58 })
        local lines = Transports:Lines(369, D.tramStormwind.north, D.tramStormwind.west, "Alliance", 1100)
        expect_eq(#lines, 1)
        expect(lines[1].text:find("Tram to Ironforge: leaves in 0:43", 1, true), lines[1].text)
    end)

    it("partage les horaires et apprend ceux des autres", function()
        local _, Transports = boot()
        local realm = {}
        Transports.Learn(realm, { link = "menethil-theramore", from = "menethil", departed = 5000, ride = 120,
            dwell = 30 })
        local text = Transports.Encode("menethil-theramore", realm["menethil-theramore"])
        expect_eq(text, "S|menethil-theramore|menethil|5000|120|30")
        local event = Transports.Decode(text, 5100)
        expect_eq(event.link, "menethil-theramore")
        expect_eq(event.departed, 5000)
        expect_eq(Transports.Decode(text, 5000 + 25 * 3600), nil, "trop vieux")
        expect_eq(Transports.Decode("S|inconnue|menethil|5000|0|0", 5100), nil, "liaison inconnue")
        expect_eq(Transports.Decode("S|menethil-theramore|ratchet|5000|0|0", 5100), nil, "quai étranger")

        _G.GetServerTime = function() return 5100 end
        Transports:OnAddonMessage(Transports.PREFIX, text, "GUILD", "Quelqu'un-Royaume")
        local data = Transports:Realm()["menethil-theramore"]
        expect(data and data.last and data.last.t == 5000, "horaire reçu de la guilde")
        _G.GetServerTime = nil
    end)
end)
