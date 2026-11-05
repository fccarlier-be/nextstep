local wow = require("wow")

-- Carte de test : UiMapArtID 1244, présent dans les données extraites du client.
-- Ses superpositions comprennent { 160, 210, 382, 281, 272826 } (une tuile) et
-- { 315, 256, 101, 247, 272806, 272812 } (deux colonnes, la seconde incomplète).
local MAP_ID, ART_ID = 1429, 1244
local OTHER_MAP, OTHER_ART = 1430, 1194

local function newTexture(layer)
    local texture = { layer = layer, shown = false }
    function texture.SetTexture(self, file)
        self.file = file
    end
    function texture.SetSize(self, width, height)
        self.width, self.height = width, height
    end
    function texture.SetTexCoord(self, left, right, top, bottom)
        self.coords = { left, right, top, bottom }
    end
    function texture.ClearAllPoints(self)
        self.point = nil
    end
    function texture.SetPoint(self, point, _, _, x, y)
        self.point = { point, x, y }
    end
    function texture.SetVertexColor(self, r, g, b)
        self.color = { r, g, b }
    end
    function texture.Show(self)
        self.shown = true
    end
    function texture.Hide(self)
        self.shown = false
    end
    return texture
end

-- Carte du monde simulée : une punaise d'exploration, ses textures, et l'API des cartes.
local function installMap(world)
    world.textures = {}
    world.explored = world.explored or {}
    local map = { mapID = MAP_ID, shown = not world.hidden }
    function map.GetMapID(self)
        return self.mapID
    end
    function map.IsShown(self)
        return self.shown
    end
    local pin = {}
    function pin.GetMap()
        return map
    end
    function pin.CreateTexture(_, _, layer)
        local texture = newTexture(layer)
        world.textures[#world.textures + 1] = texture
        return texture
    end
    function pin.RefreshOverlays() end
    -- Comme le client : pairs sur les punaises actives du modèle (pin = true).
    function map.EnumeratePinsByTemplate(_, template)
        return next, template == "MapExplorationPinTemplate" and { [pin] = true } or {}, nil
    end
    world.map, world.pin = map, pin

    _G.hooksecurefunc = function(target, name, hook)
        local original = target[name]
        target[name] = function(...)
            original(...)
            hook(...)
        end
    end
    _G.C_Map = {
        GetMapArtID = function(mapID)
            return ({ [MAP_ID] = ART_ID, [OTHER_MAP] = OTHER_ART })[mapID]
        end,
        GetMapArtLayers = function()
            return { { tileWidth = 256, tileHeight = 256 } }
        end,
    }
    _G.C_MapExplorationInfo = {
        GetExploredMapTextures = function()
            return world.explored
        end,
    }
    if not world.later then
        _G.WorldMapFrame = map
    end
end

local function boot(world, options)
    options = options or {}
    options.beforeInit = function()
        installMap(world)
    end
    local game = wow.boot(options)
    return game, game.ns.Modules:Get("MapReveal")
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

local function byFile(world, file)
    for _, texture in ipairs(shown(world)) do
        if texture.file == file then
            return texture
        end
    end
end

-- Nombre de tuiles d'une carte d'après les données.
local function tileCount(DB, art)
    local count = 0
    for _, overlay in ipairs(DB.mapOverlays[art]) do
        count = count + #overlay - 4
    end
    return count
end

describe("Carte sans brouillard", function()
    it("est active par défaut et dessine toute une carte inexplorée", function()
        local world = {}
        local game, module = boot(world)
        expect(module.enabled, "module actif")
        expect_eq(#shown(world), tileCount(game.ns.DB, ART_ID), "une texture par tuile")
        expect_eq(#game.errors, 0, "aucune erreur")
    end)

    it("ne redessine pas les zones déjà explorées", function()
        local world = {
            explored = { { textureWidth = 160, textureHeight = 210, offsetX = 382, offsetY = 281 } },
        }
        local game = boot(world)
        expect(not byFile(world, 272826), "zone explorée laissée au client")
        expect_eq(#shown(world), tileCount(game.ns.DB, ART_ID) - 1)
    end)

    it("place les tuiles et rogne la dernière colonne", function()
        local world = {}
        boot(world)
        local first, last = byFile(world, 272806), byFile(world, 272812)
        expect_eq(first.point, { "TOPLEFT", 101, -247 })
        expect_eq({ first.width, first.height }, { 256, 256 })
        expect_eq(first.coords, { 0, 1, 0, 1 })
        expect_eq(last.point, { "TOPLEFT", 357, -247 })
        expect_eq({ last.width, last.height }, { 59, 256 })
        expect_eq(last.coords, { 0, 59 / 64, 0, 1 }, "59 pixels d'un fichier de 64")
        local single = byFile(world, 272826)
        expect_eq({ single.width, single.height }, { 160, 210 })
        expect_eq(single.coords, { 0, 160 / 256, 0, 210 / 256 })
        expect_eq(single.layer, "BORDER", "sous les textures explorées")
    end)

    it("suit le changement de carte", function()
        local world = {}
        local game = boot(world)
        world.map.mapID = OTHER_MAP
        world.pin:RefreshOverlays()
        expect_eq(#shown(world), tileCount(game.ns.DB, OTHER_ART))
        expect(not byFile(world, 272826), "plus rien de la carte précédente")
    end)

    it("n'affiche rien sur une carte sans données", function()
        local world = {}
        local game = boot(world)
        world.map.mapID = 999999
        world.pin:RefreshOverlays()
        expect_eq(#shown(world), 0)
        expect_eq(#game.errors, 0, "aucune erreur")
    end)

    it("efface ses textures quand il est désactivé, et les remet ensuite", function()
        local world = {}
        local game = boot(world)
        local count = #shown(world)
        game.ns.Modules:SetEnabled("MapReveal", false)
        expect_eq(#shown(world), 0)
        world.pin:RefreshOverlays()
        expect_eq(#shown(world), 0, "le crochet ne dessine plus")
        game.ns.Modules:SetEnabled("MapReveal", true)
        expect_eq(#shown(world), count)
    end)

    it("applique la luminosité réglée, bornée", function()
        local world = {}
        local _, module = boot(world)
        expect_eq(byFile(world, 272826).color, { 0.6, 0.6, 0.6 }, "teinte atténuée par défaut")
        module:SetBrightness(0.9)
        expect_eq(byFile(world, 272826).color, { 0.9, 0.9, 0.9 })
        module:SetBrightness(5)
        expect_eq(module:GetBrightness(), 1)
        module:SetBrightness(0)
        expect_eq(module:GetBrightness(), 0.2)
    end)

    it("garde la luminosité d'une session à l'autre", function()
        local _, module = boot({})
        module:SetBrightness(0.4)
        local world = {}
        boot(world, { saved = wow.saved() })
        expect_eq(byFile(world, 272826).color, { 0.4, 0.4, 0.4 })
    end)

    it("attend le chargement de la carte du monde", function()
        local world = { later = true }
        local game = boot(world)
        expect_eq(#world.textures, 0, "pas encore de carte")
        _G.WorldMapFrame = world.map
        game:fire("ADDON_LOADED", "Blizzard_WorldMap")
        expect_eq(#shown(world), tileCount(game.ns.DB, ART_ID))
    end)

    it("ne dessine rien tant que la carte est fermée", function()
        local world = { hidden = true }
        local game = boot(world)
        expect_eq(#shown(world), 0, "carte fermée")
        expect_eq(#game.errors, 0, "aucune erreur à la connexion")
        world.map.shown = true
        world.pin:RefreshOverlays()
        expect_eq(#shown(world), tileCount(game.ns.DB, ART_ID), "dessinée à l'ouverture")
    end)

    it("se met de côté si Leatrix Maps est chargé", function()
        local world = {}
        local _, module = boot(world, { loaded = { "Leatrix_Maps" } })
        expect(not module.enabled, "module inactif")
        expect_eq(#shown(world), 0)
    end)
end)
