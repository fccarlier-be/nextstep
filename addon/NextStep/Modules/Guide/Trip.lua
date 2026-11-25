-- Voyages (docs/DESIGN.md, « Voyages ») : le joueur choisit une destination (Ctrl+clic
-- sur la carte du monde, /ns voyage), NextStep calcule le trajet le plus rapide
-- (marche, vols, bateaux, zeppelins, tram, portails) et y guide étape par étape : la
-- flèche, le chemin à pied et les repères suivent le voyage, le guide en cours est mis
-- de côté le temps du trajet, puis reprend à l'arrivée.
--
-- Données : tables de voyage de Polestar (NextStep_Nav, Travel.lua : points de vol,
-- vols directs, transports, portails ; FlightTracks.lua : tracé des vols), parties de
-- Shortest Path Forever de Cillian Berragan (GPL-3.0-or-later, voir CREDITS.md).
--
-- Points de vol connus et inconnus : un vol ne peut arriver qu'à un point connu du
-- personnage (relevés à chaque ouverture de la carte des vols, char.taxi). Un point
-- inconnu peut servir de départ : il suffit de parler à son maître de vol (le
-- trajet le dit). Les points inconnus près des trajets à pied sont signalés.
--
-- Pendant un vol, un encart donne le temps restant (durée apprise des vols déjà
-- faits, sinon estimée par la longueur du vol).

local _, ns = ...
local L = ns.L

local Guide = ns.Modules:Get("Guide")
local Navigation = ns.Navigation

local Trip = {}
ns.Trip = Trip

local RUN_SPEED, MAX_SPEED = 7, 14   -- yards par seconde : course, monture rapide
local WALK_DETOUR = 1.3              -- un trajet à pied n'est jamais tout droit
local FLIGHT_SPEED = 30              -- yards par seconde en vol
local FLIGHT_STOP = 2                -- secondes par escale (décollage, atterrissage)
local TAKE_OFF = 4                   -- secondes pour parler au maître de vol
local LEARN = 10                     -- secondes pour découvrir un point de vol
local NEAR_UNKNOWN = 300             -- yards : point de vol inconnu signalé près d'un trajet à pied
local REACH = { walk = 20, fly = 150, ride = 300, portal = 100 }
local ARRIVED = 15                   -- yards : destination atteinte
local REPLAN_PERIOD = 10             -- secondes entre deux recalculs en marchant
local REPLAN_GAIN = 30               -- secondes gagnées pour changer de trajet
local LEFT_BEHIND = 300              -- yards : départ d'un vol ou d'un bateau abandonné
local FACTION_BIT = { Alliance = 1, Horde = 2 }

Trip.ARRIVED = ARRIVED

local function distance(n1, w1, n2, w2)
    local dn, dw = n1 - n2, w1 - w2
    return math.sqrt(dn * dn + dw * dw)
end

local function placeDistance(a, b)
    return distance(a.north, a.west, b.north, b.west)
end

local function allowed(mask, faction)
    local bit = FACTION_BIT[faction]
    return bit ~= nil and (mask or 3) % (2 * bit) >= bit
end

---------------------------------------------------------------------------
-- Lieux et liaisons, tirés des tables de voyage
---------------------------------------------------------------------------

local function endPlace(kind, e)
    -- { nom, continent, nord, ouest, carte, x, y, repère, zone }
    return {
        kind = kind, name = e[1], instance = e[2], north = e[3], west = e[4],
        map = e[5], x = e[6], y = e[7], f = e[8] == "e" and "e" or nil, area = e[9],
    }
end

-- Lieux du voyage pour une faction et une classe : { list, taxi = { [id] = lieu },
-- flights = { [id] = { { vers, yards }, ... } }, links = { [lieu] = { liaisons } } }.
function Trip.Places(data, faction, class)
    local places = { list = {}, taxi = {}, flights = {}, links = {} }
    local function link(from, to, kind, cost, extra)
        local list = places.links[from] or {}
        places.links[from] = list
        local entry = { from = from, to = to, kind = kind, cost = cost }
        for key, value in pairs(extra or {}) do
            entry[key] = value
        end
        list[#list + 1] = entry
    end
    for _, t in ipairs(data.taxi or {}) do
        -- id, continent, nord, ouest, carte, x, y, faction, nom[, classe][, "l"]
        local cls = t[10]
        if allowed(t[8], faction) and (cls == nil or cls == class) then
            local place = {
                kind = "taxi", node = t[1], instance = t[2], north = t[3], west = t[4],
                map = t[5], x = t[6], y = t[7], f = t[11] ~= "l" and "e" or nil, name = t[9],
            }
            places.taxi[t[1]] = place
            places.list[#places.list + 1] = place
        end
    end
    local flights = data.flights or {}
    for i = 1, #flights - 2, 3 do
        local from, to, yards = flights[i], flights[i + 1], flights[i + 2]
        if places.taxi[from] and places.taxi[to] then
            local list = places.flights[from] or {}
            places.flights[from] = list
            list[#list + 1] = { to = to, yards = yards }
        end
    end
    for _, t in ipairs(data.transports or {}) do
        if allowed(t.faction, faction) then
            local a, b = endPlace("dock", t.a), endPlace("dock", t.b)
            places.list[#places.list + 1] = a
            places.list[#places.list + 1] = b
            link(a, b, "ride", (t.waitA or 0) + (t.ab or 0), { transport = t.kind })
            link(b, a, "ride", (t.waitB or 0) + (t.ba or 0), { transport = t.kind })
        end
    end
    for _, t in ipairs(data.portals or {}) do
        if not t.item then
            local a, b = endPlace("portal", t.a), endPlace("place", t.b)
            places.list[#places.list + 1] = a
            places.list[#places.list + 1] = b
            link(a, b, "portal", t.seconds or 5)
        end
    end
    return places
end

---------------------------------------------------------------------------
-- Calcul du trajet (Dijkstra sur une centaine de lieux)
---------------------------------------------------------------------------

-- Trajet le plus rapide de from à to ({ instance, north, west }) :
-- { legs = { { kind = "walk"|"fly"|"ride"|"portal", from, to, cost, hops, learn, transport } },
--   cost } ou nil. known : [point de vol] = true ; speed : yards par seconde à pied.
function Trip.Plan(places, known, from, to, speed)
    speed = speed or RUN_SPEED
    local start = { kind = "start", instance = from.instance, north = from.north, west = from.west }
    local target = { kind = "target", instance = to.instance, north = to.north, west = to.west }
    local nodes = { start, target }
    for _, place in ipairs(places.list) do
        nodes[#nodes + 1] = place
    end
    local dist, prev, done = { [start] = 0 }, {}, {}
    local function relax(u, v, cost, edge)
        local d = dist[u] + cost
        if not dist[v] or d < dist[v] - 1e-9 then
            dist[v], prev[v] = d, edge
        end
    end
    while true do
        local u, best = nil, math.huge
        for _, node in ipairs(nodes) do
            local d = dist[node]
            if d and not done[node] and d < best then
                u, best = node, d
            end
        end
        if not u or u == target then
            break
        end
        done[u] = true
        local arrivedBy = prev[u] and prev[u].kind
        -- À pied vers tout lieu du même continent (pas deux marches de suite).
        if arrivedBy ~= "walk" then
            for _, v in ipairs(nodes) do
                if v ~= u and v ~= start and not done[v] and v.instance == u.instance then
                    relax(u, v, placeDistance(u, v) * WALK_DETOUR / speed, { kind = "walk", from = u, to = v })
                end
            end
        end
        -- En vol : départ de n'importe quel point (à découvrir s'il est inconnu), arrivée
        -- seulement à un point connu ; les escales s'enchaînent sans reparler au maître.
        if u.kind == "taxi" then
            local chained = arrivedBy == "fly"
            local learn = not chained and not known[u.node]
            local extra = chained and 0 or (TAKE_OFF + (learn and LEARN or 0))
            for _, flight in ipairs(places.flights[u.node] or {}) do
                local v = places.taxi[flight.to]
                if v and known[flight.to] and not done[v] then
                    relax(u, v, flight.yards / FLIGHT_SPEED + FLIGHT_STOP + extra,
                        { kind = "fly", from = u, to = v, yards = flight.yards, learn = learn })
                end
            end
        end
        for _, edge in ipairs(places.links[u] or {}) do
            if not done[edge.to] then
                relax(u, edge.to, edge.cost, edge)
            end
        end
    end
    if not dist[target] then
        return nil
    end
    local edges, node = {}, target
    while prev[node] do
        table.insert(edges, 1, prev[node])
        node = prev[node].from
    end
    -- Vols enchaînés : un seul trajet chez le maître de vol.
    local legs = {}
    for _, edge in ipairs(edges) do
        local last = legs[#legs]
        local cost = edge.kind == "walk" and placeDistance(edge.from, edge.to) * WALK_DETOUR / speed
            or edge.cost
        if edge.kind == "fly" then
            cost = edge.yards / FLIGHT_SPEED + FLIGHT_STOP + (edge.learn and LEARN or 0)
        end
        if edge.kind == "fly" and last and last.kind == "fly" then
            last.to = edge.to
            last.hops[#last.hops + 1] = edge.to
            last.cost = last.cost + cost
            last.yards = last.yards + edge.yards
        else
            legs[#legs + 1] = {
                kind = edge.kind, from = edge.from, to = edge.to, cost = cost, learn = edge.learn,
                transport = edge.transport, yards = edge.yards,
                hops = edge.kind == "fly" and { edge.from, edge.to } or nil,
            }
        end
    end
    -- Marche de zéro yard (départ sur un point de vol) : inutile.
    if legs[1] and legs[1].kind == "walk" and placeDistance(legs[1].from, legs[1].to) < 1 and #legs > 1 then
        table.remove(legs, 1)
    end
    return { legs = legs, cost = dist[target] }
end

-- Distance d'un point à un segment (yards, coordonnées monde).
local function segmentDistance(p, a, b)
    local dn, dw = b.north - a.north, b.west - a.west
    local length = dn * dn + dw * dw
    local t = 0
    if length > 0 then
        t = math.max(0, math.min(1, ((p.north - a.north) * dn + (p.west - a.west) * dw) / length))
    end
    return distance(p.north, p.west, a.north + dn * t, a.west + dw * t)
end

-- Points de vol inconnus près des trajets à pied (hors étapes du voyage).
function Trip.UnknownNear(plan, places, known)
    local used, list = {}, {}
    for _, leg in ipairs(plan.legs) do
        used[leg.from], used[leg.to] = true, true
    end
    for _, place in ipairs(places.list) do
        if place.kind == "taxi" and not known[place.node] and not used[place] then
            for _, leg in ipairs(plan.legs) do
                if leg.kind == "walk" and leg.from.instance == place.instance
                    and segmentDistance(place, leg.from, leg.to) <= NEAR_UNKNOWN then
                    list[#list + 1] = place
                    break
                end
            end
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Libellés
---------------------------------------------------------------------------

-- Nom d'un lieu, dans la langue du client quand on la connaît.
function Guide:TripPlaceName(place)
    if not place then
        return "?"
    end
    if place.kind == "target" then
        return self.trip and self.trip.label or L["your destination"]
    end
    if place.kind == "taxi" then
        local names = self.db.taxiNames
        local name = names and names[place.node]
        if name then
            return name
        end
        local spot = place.name:match("^([^,]+)") or place.name
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(place.map)
        if info and info.name and info.name ~= "" and not place.name:find(info.name, 1, true) then
            return ("%s (%s)"):format(spot, info.name)
        end
        return place.name
    end
    if place.area and place.area > 0 and C_Map and C_Map.GetAreaInfo then
        local name = C_Map.GetAreaInfo(place.area)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
    return L[place.name]
end

local RIDES = {
    boat = "Boat to %s", zeppelin = "Zeppelin to %s", tram = "Tram to %s", airship = "Airship to %s",
}

-- Phrase d'une étape du voyage.
function Guide:TripLegText(leg)
    local to = self:TripPlaceName(leg.to)
    if leg.kind == "walk" then
        if leg.to.kind == "taxi" then
            return L["Go to the flight master: %s"]:format(to)
        elseif leg.to.kind == "dock" then
            return L["Go to the dock: %s"]:format(to)
        elseif leg.to.kind == "portal" then
            return L["Go to the portal: %s"]:format(to)
        elseif leg.to.kind == "target" then
            return L["Go to %s"]:format(to)
        end
        return L["Go to %s"]:format(to)
    elseif leg.kind == "fly" then
        local text
        if #leg.hops > 2 then
            local via = {}
            for i = 2, #leg.hops - 1 do
                via[#via + 1] = self:TripPlaceName(leg.hops[i])
            end
            text = L["Fly to %s (via %s)"]:format(to, table.concat(via, ", "))
        else
            text = L["Fly to %s"]:format(to)
        end
        if leg.learn then
            text = L["Discover this flight point, then: %s"]:format(text)
        end
        return text
    elseif leg.kind == "ride" then
        return L[RIDES[leg.transport] or "Boat to %s"]:format(to)
    elseif leg.kind == "portal" then
        return L["Take the portal to %s"]:format(to)
    end
    return to
end

local function minutes(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end
Trip.Minutes = minutes

---------------------------------------------------------------------------
-- Suivi du voyage
---------------------------------------------------------------------------

local function now()
    return GetTime and GetTime() or 0
end

-- Tables de voyage (NextStep_Nav, chargé à la demande hors combat).
function Guide:TravelData()
    local data = _G.NextStepTravelData
    if not data and not (InCombatLockdown and InCombatLockdown()) then
        local load = C_AddOns and C_AddOns.LoadAddOn or _G.LoadAddOn
        if load then
            pcall(load, "NextStep_Nav")
        end
        data = _G.NextStepTravelData
    end
    return type(data) == "table" and data or nil
end

function Guide:TripPlaces()
    local data = self:TravelData()
    if not data then
        return nil
    end
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    local class = UnitClass and select(2, UnitClass("player"))
    local key = tostring(faction) .. ":" .. tostring(class)
    if not (self.tripPlaces and self.tripPlacesKey == key) then
        self.tripPlaces, self.tripPlacesKey = Trip.Places(data, faction, class), key
    end
    return self.tripPlaces
end

local function runSpeed()
    local speed
    if GetUnitSpeed then
        local ok, _, run = pcall(GetUnitSpeed, "player")
        if ok and ns.Usable(run) and type(run) == "number" then
            speed = run
        end
    end
    return math.max(RUN_SPEED, math.min(MAX_SPEED, speed or RUN_SPEED))
end

local function ownSpeed()
    if GetUnitSpeed then
        local ok, speed = pcall(GetUnitSpeed, "player")
        if ok and ns.Usable(speed) and type(speed) == "number" then
            return speed
        end
    end
    return 0
end

local function onTaxi()
    return UnitOnTaxi and UnitOnTaxi("player") == true
end

-- Calcule le trajet depuis la position du joueur ; false si impossible.
function Guide:PlanTrip()
    local trip = self.trip
    local places = self:TripPlaces()
    local instance, north, west = Navigation.PlayerPosition()
    if not (trip and places and instance) then
        return false
    end
    local known = self.char.taxi or {}
    local plan = Trip.Plan(places, known, { instance = instance, north = north, west = west }, trip.to, runSpeed())
    trip.planned = now()
    if not plan or #plan.legs == 0 then
        return false
    end
    trip.legs, trip.cost, trip.index = plan.legs, plan.cost, 1
    trip.unknown = Trip.UnknownNear(plan, places, known)
    return true
end

-- Temps restant estimé (secondes) depuis la position du joueur.
function Guide:TripRemaining()
    local trip = self.trip
    if not (trip and trip.legs) then
        return nil
    end
    local leg = trip.legs[trip.index]
    local total = 0
    local instance, north, west = Navigation.PlayerPosition()
    if leg and leg.kind == "walk" and instance == leg.to.instance then
        total = distance(north, west, leg.to.north, leg.to.west) * WALK_DETOUR / runSpeed()
    elseif leg then
        total = leg.cost
    end
    for k = trip.index + 1, #trip.legs do
        total = total + trip.legs[k].cost
    end
    return total
end

-- Flèche, chemin et repères vers l'étape en cours.
function Guide:ShowTripLeg()
    local trip = self.trip
    local leg = trip and trip.legs and trip.legs[trip.index]
    if not leg then
        return
    end
    local text = self:TripLegText(leg)
    local nextLeg = trip.legs[trip.index + 1]
    if leg.kind == "walk" and nextLeg then
        text = text .. " - " .. self:TripLegText(nextLeg)
    end
    local to = leg.to
    self:PointTo({ map = to.map, x = to.x, y = to.y, f = to.f }, text,
        { trip = true, noRoute = leg.kind ~= "walk" })
    trip.target = self.pointTarget
    if self.DrawMapRoute then
        self:DrawMapRoute()
    end
end

-- Destination choisie : point de carte { map, x, y[, f] } (pour cent).
function Guide:StartTrip(point, label, quiet)
    if not (self.enabled and point) then
        return false
    end
    local instance, north, west = Navigation.WorldPosition(point.map, point.x, point.y, point.f)
    if not instance then
        ns:Print(L["This place cannot be reached: pick it on a zone or continent map."])
        return false
    end
    if not self:TravelData() then
        ns:Print(L["Trips need the NextStep - Nav addon: enable it, then restart the game."])
        return false
    end
    local previous = self.trip
    self.trip = {
        point = { map = point.map, x = point.x, y = point.y, f = point.f },
        to = { instance = instance, north = north, west = west },
        label = label or L["your destination"],
    }
    if not self:PlanTrip() then
        self.trip = previous
        ns:Print(L["No way found to %s from here."]:format(label or L["your destination"]))
        return false
    end
    self.char.trip = { map = point.map, x = point.x, y = point.y, f = point.f, label = label }
    self:ShowTripLeg()
    if not quiet then
        ns:Print(L["Trip to %s: about %s. The guide waits until you arrive (/ns trip stop to cancel)."]
            :format(self.trip.label, minutes(self.trip.cost)))
    end
    self:UpdatePins()
    if self.window then
        self:UpdateWindow(self.result)
    end
    return true
end

-- Fin du voyage : arrivée ou annulation ; le guide reprend.
function Guide:EndTrip(arrived)
    local trip = self.trip
    if not trip then
        self.char.trip = nil
        return
    end
    self.trip = nil
    self.char.trip = nil
    if self.pointTarget and self.pointTarget.trip then
        self:PointTo(nil)
    end
    ns:Print(arrived and L["You have arrived: %s. The guide resumes."]:format(trip.label)
        or L["Trip cancelled. The guide resumes."])
    self:UpdatePins()
    if self.DrawMapRoute then
        self:DrawMapRoute()
    end
    if self.window then
        self:UpdateWindow(self.result)
    end
end

function Guide:ReplanTrip(force)
    local trip = self.trip
    if not trip then
        return
    end
    local old = { legs = trip.legs, cost = trip.cost, index = trip.index, unknown = trip.unknown }
    local remaining = self:TripRemaining()
    if not self:PlanTrip() then
        trip.legs, trip.cost, trip.index, trip.unknown = old.legs, old.cost, old.index, old.unknown
        return
    end
    if not force and remaining and trip.cost > remaining - REPLAN_GAIN then
        trip.legs, trip.cost, trip.index, trip.unknown = old.legs, old.cost, old.index, old.unknown
        return
    end
    self:ShowTripLeg()
    self:UpdatePins()
    if self.window then
        self:UpdateWindow(self.result)
    end
end

-- Vérification périodique (Route.lua, 4 fois par seconde).
function Guide:UpdateTrip()
    -- Voyage repris après /reload ou reconnexion.
    if not self.trip and self.char and self.char.trip and not self.tripRestored then
        local here = Navigation.PlayerPosition()
        if here then
            self.tripRestored = true
            local saved = self.char.trip
            if not self:StartTrip(saved, saved.label, true) then
                self.char.trip = nil
            end
        end
        return
    end
    local trip = self.trip
    if not trip then
        return
    end
    if not self.enabled then
        return
    end
    -- La flèche rendue au guide ou tournée ailleurs : le voyage s'arrête.
    if self.pointTarget ~= trip.target then
        self:EndTrip(false)
        return
    end
    if onTaxi() then
        return
    end
    local instance, north, west = Navigation.PlayerPosition()
    if not instance then
        return
    end
    -- Étape atteinte, même en sautant celles d'avant (vol pris de soi-même...).
    for k = #trip.legs, trip.index, -1 do
        local to = trip.legs[k].to
        local reach = k == #trip.legs and ARRIVED or REACH[trip.legs[k].kind] or REACH.walk
        if to.instance == instance and distance(north, west, to.north, to.west) <= reach then
            if k == #trip.legs then
                self:EndTrip(true)
            else
                trip.index = k + 1
                self:ShowTripLeg()
                self:UpdatePins()
                if self.window then
                    self:UpdateWindow(self.result)
                end
            end
            return
        end
    end
    local leg = trip.legs[trip.index]
    local from, to = leg.from, leg.to
    local lost = from.instance ~= instance and to.instance ~= instance
    if not lost and leg.kind ~= "walk" and from.instance == instance and ownSpeed() > 0
        and distance(north, west, from.north, from.west) > LEFT_BEHIND
        and (to.instance ~= instance or distance(north, west, to.north, to.west) > LEFT_BEHIND) then
        lost = leg.kind ~= "ride" or distance(north, west, from.north, from.west) > 5 * LEFT_BEHIND
    end
    if lost then
        self:ReplanTrip(true)
    elseif leg.kind == "walk" and now() - (trip.planned or 0) >= REPLAN_PERIOD then
        self:ReplanTrip(false)
    end
end

-- Repères : les étapes restantes du voyage, l'étape en cours en doré.
function Guide:TripPinPoints()
    local trip, list = self.trip, {}
    if not (trip and trip.legs) then
        return list
    end
    local target
    for k = trip.index, #trip.legs do
        local leg = trip.legs[k]
        local pin = {
            instance = leg.to.instance, north = leg.to.north, west = leg.to.west, kind = "place",
            label = self:TripLegText(leg),
        }
        if k == trip.index then
            pin.target = true
            target = pin
        else
            list[#list + 1] = pin
        end
    end
    for _, place in ipairs(trip.unknown or {}) do
        list[#list + 1] = {
            instance = place.instance, north = place.north, west = place.west, kind = "unknown",
            label = L["Flight point not discovered yet: %s"]:format(self:TripPlaceName(place)),
        }
    end
    list[#list + 1] = target
    return list
end

-- Lignes du voyage pour la carte du monde (hors chemin à pied en cours) :
-- { { instance, points = { { nord, ouest }, ... } }, ... }.
function Guide:TripOverview(myNorth, myWest, walkingRoute)
    local trip, lines = self.trip, {}
    if not (trip and trip.legs) then
        return lines
    end
    local tracks = _G.NextStepFlightTracks
    for k = trip.index, #trip.legs do
        local leg = trip.legs[k]
        local from = leg.from
        if k == trip.index and myNorth then
            from = { instance = leg.from.instance, north = myNorth, west = myWest }
        end
        if leg.kind == "fly" then
            for h = 1, #leg.hops - 1 do
                local a, b = leg.hops[h], leg.hops[h + 1]
                local track = tracks and tracks[a.node] and tracks[a.node][b.node]
                local points = {}
                if track then
                    for i = 1, #track - 1, 2 do
                        points[#points + 1] = { track[i], track[i + 1] }
                    end
                else
                    points = { { a.north, a.west }, { b.north, b.west } }
                end
                lines[#lines + 1] = { instance = a.instance, points = points }
            end
        elseif from.instance == leg.to.instance and not (k == trip.index and leg.kind == "walk" and walkingRoute) then
            lines[#lines + 1] = {
                instance = from.instance,
                points = { { from.north, from.west }, { leg.to.north, leg.to.west } },
            }
        end
    end
    return lines
end

---------------------------------------------------------------------------
-- Choix de la destination : Ctrl+clic sur la carte du monde
---------------------------------------------------------------------------

function Guide:MapPointLabel(mapID, x, y)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    local name = info and info.name or "?"
    return ("%s (%d, %d)"):format(name, math.floor(x + 0.5), math.floor(y + 0.5))
end

-- Gestionnaire de clic du canevas (true : le clic est pris).
function Guide:OnMapCanvasClick(map, button)
    if button ~= "LeftButton" or not (IsControlKeyDown and IsControlKeyDown())
        or (IsShiftKeyDown and IsShiftKeyDown()) or (IsAltKeyDown and IsAltKeyDown()) then
        return false
    end
    local mapID = map:GetMapID()
    local x, y = map:GetNormalizedCursorPosition()
    if not (mapID and x and y) then
        return false
    end
    x, y = x * 100, y * 100
    self:StartTrip({ map = mapID, x = x, y = y }, self:MapPointLabel(mapID, x, y))
    return true
end

function Guide:AttachMapClicks()
    local map = WorldMapFrame
    if self.mapClicks or not (map and map.AddCanvasClickHandler and map.GetNormalizedCursorPosition) then
        return
    end
    map:AddCanvasClickHandler(function(canvas, button)
        local ok, taken = pcall(self.OnMapCanvasClick, self, canvas, button)
        return ok and taken == true
    end)
    self.mapClicks = true
end

-- Ouvre la carte du monde avec la marche à suivre.
function Guide:ChooseTripDestination()
    if WorldMapFrame and not WorldMapFrame:IsShown() and ToggleWorldMap then
        pcall(ToggleWorldMap)
    end
    ns:Print(L["Ctrl+click on the world map to choose your destination."])
end

---------------------------------------------------------------------------
-- Durée restante pendant un vol
---------------------------------------------------------------------------

-- À l'ouverture de la carte des vols : noms des points (langue du client) et
-- emplacement de chacun dans la liste (pour savoir quel vol est pris).
function Guide:RecordTaxiMap(uiMapID)
    if not (C_TaxiMap and C_TaxiMap.GetAllTaxiNodes) then
        return
    end
    self.db.taxiNames = self.db.taxiNames or {}
    local slots, origin = {}, nil
    for _, node in ipairs(C_TaxiMap.GetAllTaxiNodes(uiMapID) or {}) do
        if node.nodeID then
            if type(node.name) == "string" and node.name ~= "" then
                self.db.taxiNames[node.nodeID] = node.name
            end
            if node.slotIndex then
                slots[node.slotIndex] = node.nodeID
            end
            if Enum and Enum.FlightPathState and node.state == Enum.FlightPathState.Current then
                origin = node.nodeID
            end
        end
    end
    -- En secours : le point de vol le plus proche du joueur.
    local places = not origin and self:TripPlaces()
    local instance, north, west = Navigation.PlayerPosition()
    if places and instance then
        local best = 100
        for id, place in pairs(places.taxi) do
            local d = place.instance == instance and distance(north, west, place.north, place.west)
            if d and d < best then
                origin, best = id, d
            end
        end
    end
    self.taxiSlots, self.taxiOrigin = slots, origin
    if self.trip then
        self:ReplanTrip(true)
    end
end

-- Durée d'un vol de a à b (points de vol) : apprise, sinon estimée sur le plus court
-- enchaînement de vols connus.
function Guide:FlightDuration(a, b)
    local times = self.db.flightTimes
    local learned = times and times[a .. "-" .. b]
    if learned then
        return learned
    end
    local places = self:TripPlaces()
    if not places then
        return nil
    end
    local known = self.char.taxi or {}
    local dist, done = { [a] = 0 }, {}
    while true do
        local u, best = nil, math.huge
        for node, d in pairs(dist) do
            if not done[node] and d < best then
                u, best = node, d
            end
        end
        if not u or u == b then
            break
        end
        done[u] = true
        for _, flight in ipairs(places.flights[u] or {}) do
            if flight.to == b or known[flight.to] then
                local d = best + flight.yards / FLIGHT_SPEED + FLIGHT_STOP
                if not dist[flight.to] or d < dist[flight.to] then
                    dist[flight.to] = d
                end
            end
        end
    end
    return dist[b]
end

-- Vol pris (TakeTaxiNode) : départ et arrivée retenus.
function Guide:OnTakeTaxi(slot)
    local destination = self.taxiSlots and self.taxiSlots[slot]
    -- En secours : le nom du point choisi, retrouvé parmi ceux de la carte des vols.
    if not destination and TaxiNodeName then
        local ok, name = pcall(TaxiNodeName, slot)
        for id, known in pairs(ok and self.db.taxiNames or {}) do
            if known == name then
                destination = id
            end
        end
    end
    if destination and self.taxiOrigin then
        self.flight = {
            from = self.taxiOrigin, to = destination, asked = now(),
            duration = self:FlightDuration(self.taxiOrigin, destination),
        }
    end
end

function Guide:CreateFlightTimer()
    if self.flightTimer then
        return
    end
    local frame = CreateFrame("Frame", "NextStepFlightTimer", UIParent)
    frame:SetSize(260, 20)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -170)
    frame:SetFrameStrata("MEDIUM")
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    frame.text = text
    frame:Hide()
    self.flightTimer = frame
    if hooksecurefunc and _G.TakeTaxiNode then
        hooksecurefunc("TakeTaxiNode", function(slot)
            ns.SafeCall(self.OnTakeTaxi, self, slot)
        end)
    end
end

-- Appelé 4 fois par seconde : début, fin et affichage du vol.
function Guide:UpdateFlightTimer()
    local frame = self.flightTimer
    if not frame then
        return
    end
    local flight = self.flight
    if onTaxi() then
        if not flight or (flight.started == nil and now() - flight.asked > 30) then
            flight = { asked = now() }
            self.flight = flight
        end
        flight.started = flight.started or now()
        local name = flight.to and self.tripPlaces and self.tripPlaces.taxi[flight.to]
        local label = name and self:TripPlaceName(name) or nil
        local text
        if flight.duration then
            local left = flight.duration - (now() - flight.started)
            text = left > 0 and minutes(left) or L["landing soon"]
        else
            text = minutes(now() - flight.started)
        end
        frame.text:SetText(label and L["Flight to %s: %s"]:format(label, text) or L["Flight: %s"]:format(text))
        frame:Show()
        return
    end
    frame:Hide()
    if flight and flight.started then
        -- Atterri : la durée réelle sert aux prochains vols.
        local took = now() - flight.started
        if flight.from and flight.to and took > 10 then
            self.db.flightTimes = self.db.flightTimes or {}
            self.db.flightTimes[flight.from .. "-" .. flight.to] = math.floor(took + 0.5)
        end
        self.flight = nil
    end
end
