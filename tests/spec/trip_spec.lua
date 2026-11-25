local wow = require("wow")

-- Voyages (Modules/Guide/Trip.lua) : trajet le plus rapide avec les vraies tables de
-- voyage (NextStep_Nav/Travel.lua), suivi étape par étape, durée d'un vol.

-- Lieux des tables (coordonnées monde : nord, ouest, continent).
local SENTINEL_HILL = { -10628.9, 1036.7, 0 }    -- point de vol 4
local LAKESHIRE = { -9429.1, -2231.4, 0 }        -- point de vol 5
local STORMWIND_FP = { -8840.6, 489.7, 0 }       -- point de vol 2
local STORMWIND_HARBOR = { -8654.5, 1344.4, 0 }  -- bateau pour Auberdine
local AUBERDINE_FP = { 6341.4, 557.7, 1 }        -- point de vol 26, carte 1439 à 36,4 45,62

local function loadData()
    _G.NextStepTravelData, _G.NextStepFlightTracks = nil, nil
    dofile("addon/NextStep_Nav/Travel.lua")
    dofile("addon/NextStep_Nav/FlightTracks.lua")
    return _G.NextStepTravelData
end

local function at(place, dNorth)
    return { instance = place[3], north = place[1] + (dNorth or 0), west = place[2] }
end

local function kinds(plan)
    local list = {}
    for _, leg in ipairs(plan.legs) do
        list[#list + 1] = leg.kind
    end
    return table.concat(list, ",")
end

local function boot(known)
    local world = { clock = 100, onTaxi = false }
    local game = wow.boot({
        faction = "Alliance",
        beforeInit = function()
            _G.GetTime = function() return world.clock end
            _G.UnitOnTaxi = function() return world.onTaxi end
            _G.C_Map.GetMapInfo = function(map) return { mapID = map, name = "Map" .. map } end
            loadData()
        end,
    })
    local Guide = game.ns.Modules:Get("Guide")
    for node in pairs(known or {}) do
        Guide.char.taxi[node] = true
    end
    return game, Guide, world
end

describe("Voyages", function()
    it("vole quand c'est plus court, puis prend le bateau pour l'autre continent", function()
        local data = loadData()
        local Trip = wow.boot({ faction = "Alliance" }).ns.Trip
        local places = Trip.Places(data, "Alliance", "HUNTER")
        expect(places.taxi[2] and places.taxi[4], "points de vol de l'Alliance")
        expect(places.taxi[23] == nil, "pas ceux de la Horde (Orgrimmar)")
        local plan = Trip.Plan(places, { [2] = true, [4] = true, [26] = true },
            at(SENTINEL_HILL, 20), at(AUBERDINE_FP, 30))
        expect(plan, "un trajet")
        expect_eq(kinds(plan), "walk,fly,walk,ride,walk")
        expect_eq(plan.legs[2].from.node, 4)
        expect_eq(plan.legs[2].to.node, 2, "vol vers Hurlevent")
        expect_eq(plan.legs[4].transport, "boat")
        expect(math.abs(plan.legs[4].from.north - STORMWIND_HARBOR[1]) < 1, "bateau du port de Hurlevent")
    end)

    it("n'arrive jamais en vol à un point inconnu, mais peut partir d'un point à découvrir", function()
        local data = loadData()
        local Trip = wow.boot({ faction = "Alliance" }).ns.Trip
        local places = Trip.Places(data, "Alliance", "HUNTER")
        -- Hurlevent inconnu : pas de vol vers lui, tout à pied jusqu'au port.
        local plan = Trip.Plan(places, { [4] = true }, at(SENTINEL_HILL, 20), at(STORMWIND_HARBOR, 10))
        expect(not kinds(plan):find("fly"), kinds(plan))
        -- Au pied du maître de vol de Lothar (inconnu) : le découvrir, puis voler.
        plan = Trip.Plan(places, { [2] = true }, at(LAKESHIRE, 10), at(STORMWIND_FP, 30))
        local fly
        for _, leg in ipairs(plan.legs) do
            fly = fly or (leg.kind == "fly" and leg)
        end
        expect(fly and fly.learn, "vol depuis un point à découvrir : " .. kinds(plan))
        -- Points inconnus près d'une marche signalés.
        plan = Trip.Plan(places, {}, at(LAKESHIRE, 400), at(LAKESHIRE, -400))
        local unknown = Trip.UnknownNear(plan, places, {})
        expect_eq(#unknown, 1)
        expect_eq(unknown[1].node, 5)
    end)

    it("guide étape par étape, met le guide de côté et le rend à l'arrivée", function()
        local game, Guide, world = boot({ [2] = true, [4] = true, [26] = true })
        game.player.position = { SENTINEL_HILL[1] + 60, SENTINEL_HILL[2], 0 }
        expect(Guide:StartTrip({ map = 1439, x = 36.4, y = 45.62, f = "e" }, "Auberdine"), "voyage lancé")
        local trip = Guide.trip
        expect_eq(#trip.legs, 5)
        expect(Guide.pointTarget and Guide.pointTarget.trip, "la flèche suit le voyage")
        expect(Guide.pointTarget.label:find("flight master", 1, true), Guide.pointTarget.label)
        expect(Guide.windowTexts[1]:find("Auberdine", 1, true), Guide.windowTexts[1])
        expect(#Guide.pinPoints >= 4, "repères des étapes")
        expect(game:chatText():find("Trip to Auberdine", 1, true), "annoncé")

        -- Au maître de vol : étape suivante, le vol (sans chemin à pied).
        game.player.position = { SENTINEL_HILL[1] + 5, SENTINEL_HILL[2], 0 }
        Guide:UpdateTrip()
        expect_eq(trip.index, 2)
        expect(Guide.pointTarget.noRoute, "pas de chemin à pied pendant le vol")
        expect(Guide:RouteGoal() == nil)

        -- En vol : rien ne bouge ; atterrissage à Hurlevent : vers le port.
        world.onTaxi = true
        game.player.position = { -9500, 700, 0 }
        Guide:UpdateTrip()
        expect_eq(trip.index, 2, "en vol")
        world.onTaxi = false
        game.player.position = { STORMWIND_FP[1] + 10, STORMWIND_FP[2], 0 }
        Guide:UpdateTrip()
        expect_eq(trip.index, 3, "atterri")
        -- Le bateau : arrivée sur l'autre continent, puis à destination.
        game.player.position = { STORMWIND_HARBOR[1], STORMWIND_HARBOR[2], 0 }
        Guide:UpdateTrip()
        expect_eq(trip.index, 4)
        game.player.position = { 6548.3, 942.2, 1 }
        Guide:UpdateTrip()
        expect_eq(trip.index, 5, "débarqué à Auberdine")
        game.player.position = { AUBERDINE_FP[1] + 5, AUBERDINE_FP[2], 1 }
        Guide:UpdateTrip()
        expect(Guide.trip == nil, "arrivé")
        expect(Guide.pointTarget == nil, "la flèche revient au guide")
        expect(Guide.char.trip == nil)
        expect(game:chatText():find("arrived", 1, true), "arrivée annoncée")
        expect_eq(#game.errors, 0)
    end)

    it("s'annule quand la flèche revient au guide, et reprend après /reload", function()
        local game, Guide = boot({ [2] = true, [4] = true })
        game.player.position = { SENTINEL_HILL[1] + 60, SENTINEL_HILL[2], 0 }
        Guide:StartTrip({ map = 1453, x = 66.3, y = 62.67, f = "e" }, "Stormwind")
        expect(Guide.char.trip, "voyage enregistré pour le personnage")
        local saved = Guide.char.trip
        Guide:BackToGuide()
        Guide:UpdateTrip()
        expect(Guide.trip == nil, "annulé")
        expect(game:chatText():find("cancelled", 1, true))
        -- Après /reload : repris depuis la position du joueur.
        Guide.char.trip = saved
        Guide.tripRestored = nil
        Guide:UpdateTrip()
        expect(Guide.trip, "voyage repris")
        expect_eq(#game.errors, 0)
    end)

    it("affiche le temps restant d'un vol et retient sa vraie durée", function()
        local game, Guide, world = boot({ [2] = true, [4] = true })
        game.player.position = { SENTINEL_HILL[1] + 5, SENTINEL_HILL[2], 0 }
        _G.C_TaxiMap = {
            GetAllTaxiNodes = function()
                return {
                    { nodeID = 4, slotIndex = 1, name = "Colline des Sentinelles" },
                    { nodeID = 2, slotIndex = 2, name = "Hurlevent" },
                }
            end,
        }
        Guide:RecordTaxiMap(1436)
        expect_eq(Guide.db.taxiNames[2], "Hurlevent")
        Guide:OnTakeTaxi(2)
        expect(Guide.flight and Guide.flight.duration, "durée estimée")
        local estimate = Guide.flight.duration
        world.onTaxi = true
        Guide:UpdateFlightTimer()
        local text = Guide.flightTimer.text.text
        expect(text:find("Hurlevent", 1, true), text)
        world.clock = world.clock + 70
        world.onTaxi = false
        Guide:UpdateFlightTimer()
        expect_eq(Guide.db.flightTimes["4-2"], 70, "durée réelle retenue")
        expect_eq(Guide:FlightDuration(4, 2), 70)
        expect(estimate > 60 and estimate < 120, "estimation " .. estimate)
        expect_eq(#game.errors, 0)
    end)
end)
