-- Trajet vers l'autre continent : quand la cible de l'étape n'est pas sur le
-- continent du joueur, le guide choisit le bateau ou le zeppelin à prendre, la
-- flèche pointe le quai de départ et la fenêtre l'écrit en clair (avec « rejoignez
-- d'abord… » quand le quai est loin).
--
-- Choix : distance du joueur au quai de départ, plus celle du quai d'arrivée à la
-- cible. Le premier trajet compte pour moitié : on le fait souvent en vol, alors
-- que l'arrivée sur l'autre continent se fait à pied, sans trajets de vol connus.
--
-- Quais en repère « era » (f = "e"), relevés dans les étapes « Boat to… » et
-- « Zeppelin to… » des guides importés. Les liaisons de Forever qui ne mènent
-- pas d'un continent à l'autre (dirigeables) n'entrent pas en compte.

local _, ns = ...
local L = ns.L

local Navigation = ns.Navigation
local Guide = ns.Modules:Get("Guide")

local Travel = {}
ns.Travel = Travel

local DOCKS = {
    stormwind = { name = "Stormwind Harbor", map = 1453, x = 26.12, y = 47.06, f = "e" },
    auberdineWest = { name = "Auberdine", map = 1439, x = 30.7, y = 41, f = "e" },
    menethil = { name = "Menethil Harbor", map = 1437, x = 4.78, y = 57.02, f = "e" },
    auberdine = { name = "Auberdine", map = 1439, x = 32.4, y = 43.8, f = "e" },
    theramore = { name = "Theramore", map = 1445, x = 71.6, y = 56.4, f = "e" },
    bootyBay = { name = "Booty Bay", map = 1434, x = 25.8, y = 73.1, f = "e" },
    ratchet = { name = "Ratchet", map = 1413, x = 63.4, y = 38.5, f = "e" },
    tirisfal = { name = "the Tirisfal zeppelin tower", map = 1420, x = 60.7, y = 58.9, f = "e" },
    gromgol = { name = "Grom'gol", map = 1434, x = 31.4, y = 29.9, f = "e" },
    durotar = { name = "the Orgrimmar zeppelin tower", map = 1411, x = 50.8, y = 13.5, f = "e" },
    -- Liaisons sur un même continent (horaires seulement, pas de traversée).
    rutheran = { name = "Rut'theran Village", map = 1438, x = 55.9, y = 93.5, f = "e" },
    auberdineTeldrassil = { name = "Auberdine", map = 1439, x = 33.2, y = 40.1, f = "e" },
    feathermoon = { name = "Feathermoon", map = 1444, x = 31, y = 39.8, f = "e" },
    forgottenCoast = { name = "the Forgotten Coast", map = 1444, x = 43.3, y = 42.7, f = "e" },
    -- Tram de Forgefer : coordonnées de l'instance 369 (UnitPosition : nord, ouest),
    -- quais relevés dans NauticusClassic (MIT, voir CREDITS.md).
    tramStormwind = { name = "Stormwind", instance = 369, north = -20.45, west = 2491.8 },
    tramIronforge = { name = "Ironforge", instance = 369, north = -20.45, west = 9.15 },
}
Travel.DOCKS = DOCKS
for id, dock in pairs(DOCKS) do
    dock.id = id
end

-- Liaisons dans les deux sens ; faction nil : ouverte à tous.
local LINKS = {
    { kind = "boat", faction = "Alliance", DOCKS.menethil, DOCKS.auberdine },
    { kind = "boat", faction = "Alliance", DOCKS.menethil, DOCKS.theramore },
    { kind = "boat", faction = "Alliance", DOCKS.stormwind, DOCKS.auberdineWest },   -- ajout de Forever
    { kind = "boat", DOCKS.bootyBay, DOCKS.ratchet },
    { kind = "zeppelin", faction = "Horde", DOCKS.tirisfal, DOCKS.durotar },
    { kind = "zeppelin", faction = "Horde", DOCKS.gromgol, DOCKS.durotar },
    { kind = "zeppelin", faction = "Horde", DOCKS.tirisfal, DOCKS.gromgol },
    { kind = "boat", faction = "Alliance", DOCKS.rutheran, DOCKS.auberdineTeldrassil },
    { kind = "boat", faction = "Alliance", DOCKS.feathermoon, DOCKS.forgottenCoast },
    -- Deux rames, chacune sur sa voie (nord de la position).
    { kind = "tram", id = "tram-north", lane = 4.5, DOCKS.tramStormwind, DOCKS.tramIronforge },
    { kind = "tram", id = "tram-south", lane = -45.4, DOCKS.tramStormwind, DOCKS.tramIronforge },
}
Travel.LINKS = LINKS
for _, link in ipairs(LINKS) do
    link.id = link.id or (link[1].id .. "-" .. link[2].id)
end

local DEPARTURE_WEIGHT = 0.5
local NEAR_DOCK = 300   -- yards : au-delà, la phrase dit de rejoindre d'abord le quai
Travel.NEAR_DOCK = NEAR_DOCK

-- Position monde d'un quai (coordonnées d'instance données telles quelles).
local function where(point)
    if point.instance then
        return point.instance, point.north, point.west
    end
    return Navigation.WorldPosition(point.map, point.x, point.y, point.f)
end
Travel.Where = where

local function distance(n1, w1, n2, w2)
    local dn, dw = n1 - n2, w1 - w2
    return math.sqrt(dn * dn + dw * dw)
end

-- Meilleure traversée du joueur (continent, nord, ouest) vers la cible :
-- { kind, from, to } ou nil (même continent, position inconnue, pas de liaison).
function Travel.Crossing(target, faction, instance, north, west)
    local tInstance, tNorth, tWest = where(target)
    if not (tInstance and instance) or tInstance == instance then
        return nil
    end
    local best, bestCost
    for _, link in ipairs(LINKS) do
        if not link.faction or link.faction == faction then
            for side = 1, 2 do
                local from, to = link[side], link[3 - side]
                local fInstance, fNorth, fWest = where(from)
                local aInstance, aNorth, aWest = where(to)
                if fInstance == instance and aInstance == tInstance then
                    local approach = distance(north, west, fNorth, fWest)
                    local cost = approach * DEPARTURE_WEIGHT + distance(aNorth, aWest, tNorth, tWest)
                    if not bestCost or cost < bestCost then
                        best, bestCost = { kind = link.kind, from = from, to = to, approach = approach }, cost
                    end
                end
            end
        end
    end
    return best
end

-- Traversée à faire pour atteindre une cible, depuis la position du joueur.
function Guide:Crossing(target)
    if not target then
        return nil
    end
    local instance, north, west = Navigation.PlayerPosition()
    if not instance then
        return nil
    end
    return Travel.Crossing(target, UnitFactionGroup("player"), instance, north, west)
end

-- Phrase de la fenêtre : « Autre continent : prenez le bateau de X pour Y. »,
-- ou, loin du quai, « rejoignez X (en vol si vous connaissez le trajet), puis… ».
function Travel.Describe(route)
    local zeppelin = route.kind == "zeppelin"
    local text
    if route.approach and route.approach > NEAR_DOCK then
        text = zeppelin
            and L["Other continent: go to %s (by flight path if you know it), then take the zeppelin to %s."]
            or L["Other continent: go to %s (by flight path if you know it), then take the boat to %s."]
    else
        text = zeppelin and L["Other continent: take the zeppelin from %s to %s."]
            or L["Other continent: take the boat from %s to %s."]
    end
    return text:format(L[route.from.name], L[route.to.name])
end
