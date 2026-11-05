local wow = require("wow")

-- Repères du guide sur la minimap et la carte du monde (Modules/Guide/Pins.lua).
local MAP = 1429
local GUIDE_ID = "test/pins"

local function close(a, b)
    return math.abs(a - b) < 1e-6
end

-- Minimap simulée : 140 pixels de large, 200 yards de rayon.
local function installMinimap(world)
    local minimap = setmetatable({}, { __index = function() return function() end end })
    function minimap.GetWidth() return 140 end
    function minimap.GetViewRadius() return 200 end
    function minimap.GetFrameLevel() return 1 end
    _G.Minimap = minimap
    world.cvars = { rotateMinimap = "0" }
    _G.C_CVar = { GetCVar = function(name) return world.cvars[name] end }
end

local function addGuide(ns)
    ns.DB.AddGuide(function() return {
        id = GUIDE_ID, title = "Pins", category = "Test", minLevel = 1, maxLevel = 10,
        steps = {
            { title = "Wolves and saw", goals = {
                { t = "kill", quest = 33, npc = 69, count = 8, map = MAP, x = 50, y = 40, f = "e",
                    spotsPacked = "51,43,,54,6;52,39,,45,3;48,38,,53,7" },
                { t = "collect", quest = 91733, item = 247813, map = MAP, x = 60, y = 50, f = "e" },
            } },
        },
    } end)
end

local function boot(world)
    world = world or {}
    local game = wow.boot({
        faction = "Alliance",
        beforeInit = function(ns)
            installMinimap(world)
            addGuide(ns)
        end,
    })
    local Guide = game.ns.Modules:Get("Guide")
    -- Textures de la minimap enregistrées : position et visibilité.
    world.textures = {}
    if Guide.minimapPins then
        rawset(Guide.minimapPins, "CreateTexture", function()
            local texture = setmetatable({}, { __index = function() return function() end end })
            function texture.SetPoint(self, _, _, _, x, y) self.x, self.y = x, y end
            function texture.SetSize(self, size) self.size = size end
            function texture.Show(self) self.shown = true end
            function texture.Hide(self) self.shown = false end
            function texture.SetRotation(self, angle) self.rotation = angle end
            function texture.SetTexture(self, file) self.file = file end
            world.textures[#world.textures + 1] = texture
            return texture
        end)
    end
    return game, Guide, world
end

-- Position monde (nord, ouest, continent) d'un point de la carte, d'après son cadre « era ».
local function worldOf(ns, x, y)
    local box = ns.DB.mapFrames.era[MAP]
    return { box.top + (box.bottom - box.top) * y / 100, box.left + (box.right - box.left) * x / 100, box.c }
end

local function shown(world)
    local list = {}
    for _, texture in ipairs(world.textures) do
        if texture.shown then
            list[#list + 1] = texture
        end
    end
    return list
end

describe("Repères du guide", function()
    it("place un point sur la minimap selon l'écart et le regard", function()
        local _, Guide = boot()
        local x, y = Guide.MinimapOffset(10, 0, nil, 2)
        expect(close(x, 0) and close(y, 20), "au nord : en haut")
        x, y = Guide.MinimapOffset(0, 10, nil, 2)
        expect(close(x, -20) and close(y, 0), "à l'ouest : à gauche")
        -- Minimap tournante, regard vers l'ouest : l'ouest est en haut.
        x, y = Guide.MinimapOffset(0, 10, math.pi / 2, 2)
        expect(close(x, 0) and close(y, 20), "à l'ouest, regard à l'ouest : en haut")
    end)

    it("donne tous les points des objectifs ouverts, la cible en dernier", function()
        local game, Guide = boot()
        game.player.position = worldOf(game.ns, 49, 40)
        game:acceptQuest(33, { { text = "Wolf Meat: 0/8", finished = false } })
        game:acceptQuest(91733, { { text = "Waterlogged Saw: 0/1", finished = false } })
        game:fire("QUEST_LOG_UPDATE")
        Guide:Start(GUIDE_ID)
        local points = Guide.pinPoints
        expect_eq(#points, 5, "position et 3 zones des loups, position de la scie")
        local kinds = {}
        for _, pin in ipairs(points) do
            kinds[pin.kind] = (kinds[pin.kind] or 0) + 1
        end
        expect_eq(kinds, { place = 2, zone = 3 })
        expect(points[#points].target, "la cible est dessinée en dernier")
        expect_eq(#game.errors, 0)
    end)

    it("affiche les points proches sur la minimap et colle la cible au bord", function()
        local game, Guide, world = boot()
        game.player.position = worldOf(game.ns, 60, 50)
        game:acceptQuest(91733, { { text = "Waterlogged Saw: 0/1", finished = false } })
        game:fire("QUEST_LOG_UPDATE")
        Guide:Start(GUIDE_ID)
        Guide:UpdateMinimapPins()
        -- Le joueur est sur la scie (cible) ; les loups, loin, sont hors de la minimap.
        local list = shown(world)
        expect_eq(#list, 1, "seule la cible est visible")
        expect(close(list[1].x, 0) and close(list[1].y, 0), "au centre")

        -- Loin de tout : une flèche dorée au bord (rayon 70 - 12), tournée vers l'est.
        game.player.position = worldOf(game.ns, 20, 50)
        Guide:UpdateMinimapPins()
        list = shown(world)
        expect_eq(#list, 1, "la flèche seule")
        expect(list[1].file:find("MinimapArrow", 1, true), "texture de flèche")
        local distance = math.sqrt(list[1].x ^ 2 + list[1].y ^ 2)
        expect(close(distance, 58), "au bord : " .. distance)
        expect(list[1].x > 0, "la scie est à l'est")
        expect(close(list[1].rotation, -math.pi / 2), "flèche tournée vers la droite")

        -- Minimap carrée : la flèche suit le bord du carré.
        _G.GetMinimapShape = function() return "SQUARE" end
        game.player.position = worldOf(game.ns, 20, 20)
        Guide:UpdateMinimapPins()
        list = shown(world)
        expect(close(math.max(math.abs(list[1].x), math.abs(list[1].y)), 58), "sur le bord du carré")
        _G.GetMinimapShape = nil

        Guide:SetMinimapPinsShown(false)
        expect_eq(#shown(world), 0, "option désactivée")
    end)

    it("projette un point monde sur une carte du client", function()
        local game, Guide = boot()
        _G.CreateVector2D = function(x, y)
            return { GetXY = function() return x, y end }
        end
        -- Carte 1 : nord 1000 à 0, ouest 500 à -500 (continent 0).
        _G.C_Map.GetWorldPosFromMapPos = function(_, pos)
            local x, y = pos:GetXY()
            return 0, _G.CreateVector2D(1000 - 1000 * y, 500 - 1000 * x)
        end
        local x, y = Guide.MapPosition(1, 0, 750, 0)
        expect(close(x, 0.5) and close(y, 0.25), "au quart haut, au milieu")
        expect_eq(Guide.MapPosition(1, 1, 750, 0), nil, "autre continent")
        expect_eq(Guide.MapPosition(1, 0, 2000, 0), nil, "hors de la carte")
        expect_eq(#game.errors, 0)
    end)
end)
