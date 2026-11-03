-- Navigation : positions dans le monde, distance et direction d'une cible.
--
-- Tout se calcule en coordonnées monde (yards), comme UnitPosition :
--   nord   = premier axe (top/bottom des cadres de carte), croissant vers le nord ;
--   ouest  = second axe (left/right), croissant vers l'ouest.
-- Les coordonnées des guides en repère « era » (f = "e") passent par les cadres
-- importés de Polestar (DB.mapFrames.era) : aucune conversion par la carte du
-- client n'est nécessaire pour la distance ni pour la flèche. Les autres passent
-- par C_Map.GetWorldPosFromMapPos.
--
-- [À vérifier] sur Forever : UnitPosition hors instance, et ses axes ; les cadres
-- « era » des cartes modifiées par Forever.

local _, ns = ...

local Navigation = {}
ns.Navigation = Navigation

local function usable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

local positions = {}   -- ["map:x:y:repère"] = { instance, nord, ouest } ou false

-- Position monde d'un point de carte : instance, nord, ouest (nil si inconnue).
function Navigation.WorldPosition(map, x, y, frame)
    if not (map and x and y) then
        return nil
    end
    local key = ("%d:%s:%s:%s"):format(map, x, y, frame or "")
    local known = positions[key]
    if known == nil then
        known = false
        if frame == "e" then
            local box = ns.DB.mapFrames.era and ns.DB.mapFrames.era[map]
            if box then
                known = {
                    box.c,
                    box.top + (box.bottom - box.top) * y / 100,
                    box.left + (box.right - box.left) * x / 100,
                }
            end
        elseif C_Map.GetWorldPosFromMapPos and CreateVector2D then
            local instance, world = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(x / 100, y / 100))
            if instance and world then
                local north, west = world:GetXY()
                known = { instance, north, west }
            end
        end
        positions[key] = known
    end
    if known then
        return known[1], known[2], known[3]
    end
end

-- Position du joueur : instance, nord, ouest (nil en instance ou si secrète).
function Navigation.PlayerPosition()
    local north, west, _, instance = UnitPosition("player")
    if usable(north) and usable(west) and usable(instance) then
        return instance, north, west
    end
end

-- Distance en yards du joueur à un point de carte (nil si incalculable).
function Navigation.DistanceTo(map, x, y, frame)
    local instance, north, west = Navigation.WorldPosition(map, x, y, frame)
    if not instance then
        return nil
    end
    local myInstance, myNorth, myWest = Navigation.PlayerPosition()
    if not myInstance or myInstance ~= instance then
        return nil
    end
    local dn, dw = north - myNorth, west - myWest
    return math.sqrt(dn * dn + dw * dw)
end

-- Cap absolu d'un déplacement (radians, sens inverse des aiguilles d'une montre
-- depuis le nord, comme GetPlayerFacing).
function Navigation.Bearing(dNorth, dWest)
    return math.atan2(dWest, dNorth) % (2 * math.pi)
end

-- Distance et angle de la cible par rapport au regard du joueur (0 : devant ;
-- positif : à gauche). nil si la cible n'est pas sur le même continent.
function Navigation.Direction(map, x, y, frame)
    local instance, north, west = Navigation.WorldPosition(map, x, y, frame)
    local myInstance, myNorth, myWest = Navigation.PlayerPosition()
    if not instance or not myInstance or instance ~= myInstance then
        return nil
    end
    local facing = GetPlayerFacing()
    if not usable(facing) then
        return nil
    end
    local dn, dw = north - myNorth, west - myWest
    local angle = (Navigation.Bearing(dn, dw) - facing) % (2 * math.pi)
    return math.sqrt(dn * dn + dw * dw), angle
end

-- Zones d'apparition des mobs (spotsPacked) : « x,y,z,densité,nombre;… ».
local spotsCache = setmetatable({}, { __mode = "k" })

function Navigation.Spots(goal)
    if not goal.spotsPacked then
        return nil
    end
    local spots = spotsCache[goal]
    if not spots then
        spots = {}
        for x, y in goal.spotsPacked:gmatch("([%d%.%-]+),([%d%.%-]+)[^;]*") do
            spots[#spots + 1] = { x = tonumber(x), y = tonumber(y) }
        end
        spotsCache[goal] = spots
    end
    return spots
end
