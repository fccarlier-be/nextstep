local wow = require("wow")

-- Cadre simulé qui retient ce que le radar lui fait.
local function newWidget(fields)
    local widget = {
        shown = true, protected = false, points = {}, width = 0, height = 0, scale = 1, alpha = 1,
        strata = "MEDIUM", level = 1, mouse = true, wheel = true,
    }
    for key, value in pairs(fields or {}) do
        widget[key] = value
    end
    function widget.Show(self) self.shown = true end
    function widget.Hide(self) self.shown = false end
    function widget.IsShown(self) return self.shown end
    function widget.IsProtected(self) return self.protected end
    function widget.SetParent(self, parent) self.parent = parent end
    function widget.GetParent(self) return self.parent end
    function widget.ClearAllPoints(self) self.points = {} end
    function widget.SetPoint(self, ...) self.points[#self.points + 1] = { ... } end
    function widget.GetNumPoints(self) return #self.points end
    function widget.GetPoint(self, index) return unpack(self.points[index]) end
    function widget.SetSize(self, width, height) self.width, self.height = width, height end
    function widget.GetWidth(self) return self.width end
    function widget.GetHeight(self) return self.height end
    function widget.SetScale(self, scale) self.scale = scale end
    function widget.GetScale(self) return self.scale end
    function widget.SetAlpha(self, alpha) self.alpha = alpha end
    function widget.GetAlpha(self) return self.alpha end
    function widget.SetFrameStrata(self, strata) self.strata = strata end
    function widget.GetFrameStrata(self) return self.strata end
    function widget.SetFrameLevel(self, level) self.level = level end
    function widget.GetFrameLevel(self) return self.level end
    function widget.EnableMouse(self, enabled) self.mouse = enabled end
    function widget.IsMouseEnabled(self) return self.mouse end
    function widget.EnableMouseWheel(self, enabled) self.wheel = enabled end
    function widget.IsMouseWheelEnabled(self) return self.wheel end
    return widget
end

local function installWorld(world)
    world.cvars = { rotateMinimap = "0" }
    world.cluster = newWidget()
    world.button = newWidget()                          -- bouton d'un autre addon
    world.hiddenButton = newWidget({ shown = false })   -- déjà caché : il doit le rester
    world.secure = newWidget({ protected = true })      -- protégé : jamais touché
    local minimap = newWidget({
        parent = world.cluster, width = 140, height = 140, scale = 1.2, alpha = 1, zoom = 3,
        strata = "LOW", level = 5,
    })
    minimap.points = { { "TOPRIGHT", world.cluster, "TOPRIGHT", -10, -20 } }
    function minimap.SetZoom(self, zoom) self.zoom = zoom end
    function minimap.GetZoom(self) return self.zoom end
    function minimap.SetMaskTexture(self, mask) self.mask = mask end
    function minimap.GetChildren()
        return world.button, world.hiddenButton, world.secure
    end
    world.minimap = minimap

    _G.Minimap = minimap
    _G.UIParent = newWidget({ height = 1000 })
    _G.C_CVar = {
        GetCVar = function(name) return world.cvars[name] end,
        SetCVar = function(name, value) world.cvars[name] = value end,
    }
    _G.GetPlayerFacing = function() return world.facing end
    _G.GetMinimapShape = world.shape and function() return world.shape end

    -- Cadres créés par le module : taille, points, lettres.
    local create = _G.CreateFrame
    _G.CreateFrame = function(...)
        local frame = create(...)
        local widget = newWidget({ shown = false })
        for _, name in ipairs({ "SetSize", "GetWidth", "Show", "Hide", "IsShown", "SetAlpha" }) do
            rawset(frame, name, widget[name])
        end
        rawset(frame, "width", 0)
        rawset(frame, "shown", false)
        rawset(frame, "GetFrameLevel", function() return 2 end)
        rawset(frame, "CreateFontString", function()
            local letter = newWidget({ shown = false })
            function letter.SetText(self, text) self.text = text end
            return letter
        end)
        world.radarFrame = frame
        return frame
    end
end

local function boot(world, options)
    options = options or {}
    options.beforeInit = function()
        installWorld(world)
    end
    local game = wow.boot(options)
    -- Minimap ronde, celle du client : le module Minimap (carrée) est testé à part.
    game.ns.Modules:SetEnabled("Minimap", false)
    return game, game.ns.Modules:Get("Radar")
end

local function letter(radar, text)
    for _, fontString in ipairs(radar.frame.letters) do
        if fontString.text == text then
            return fontString
        end
    end
end

-- Minimap centrée sur le cadre du radar (comparaison par référence : le cadre a des cycles).
local function centered(world, radar)
    local points = world.minimap.points
    local point = points[1]
    return #points == 1 and point[1] == "CENTER" and point[2] == radar.frame and point[3] == "CENTER"
end

local function near(a, b)
    return math.abs(a - b) < 1e-6
end

describe("Radar de récolte", function()
    it("est activé par défaut et répond à /ns radar", function()
        local world = {}
        local _, radar = boot(world)
        expect(radar.enabled)
        SlashCmdList.NEXTSTEP("radar")
        expect(radar.active, "radar ouvert")
        SlashCmdList.NEXTSTEP("radar")
        expect(not radar.active, "radar fermé")
    end)

    it("place la minimap au centre, en grand, transparente et sans souris", function()
        local world = {}
        local _, radar = boot(world)
        radar:Toggle()
        local minimap = world.minimap
        expect_eq(minimap.parent, radar.frame)
        expect(centered(world, radar), "centrée")
        expect_eq(minimap.width, 600, "60 % de la hauteur de l'écran")
        expect_eq(minimap.scale, 1)
        expect_eq(minimap.alpha, 0.7)
        expect_eq(minimap.strata, "BACKGROUND")
        expect_eq(minimap.mouse, false)
        expect_eq(minimap.wheel, false)
        expect_eq(minimap.zoom, 0, "vue la plus large")
        expect_eq(minimap.mask, "Interface\\AddOns\\NextStep\\Media\\RadarMask", "terrain caché")
        expect_eq(world.cvars.rotateMinimap, "1")
        expect(radar.frame.shown)
    end)

    it("cache les enfants affichés et non protégés de la minimap, puis les rend", function()
        local world = {}
        local _, radar = boot(world)
        radar:Toggle()
        expect(not world.button.shown)
        expect(world.secure.shown, "cadre protégé laissé tel quel")
        radar:Toggle()
        expect(world.button.shown)
        expect(not world.hiddenButton.shown, "un cadre déjà caché le reste")
    end)

    it("rétablit exactement la minimap à la fermeture", function()
        local world = {}
        local _, radar = boot(world)
        radar:Toggle()
        radar:Toggle()
        local minimap = world.minimap
        expect_eq(minimap.parent, world.cluster)
        expect_eq(minimap.points, { { "TOPRIGHT", world.cluster, "TOPRIGHT", -10, -20 } })
        expect_eq(minimap.width, 140)
        expect_eq(minimap.height, 140)
        expect_eq(minimap.scale, 1.2)
        expect_eq(minimap.alpha, 1)
        expect_eq(minimap.strata, "LOW")
        expect_eq(minimap.level, 5)
        expect_eq(minimap.mouse, true)
        expect_eq(minimap.zoom, 3)
        expect_eq(minimap.mask, "Textures\\MinimapMask")
        expect_eq(world.cvars.rotateMinimap, "0")
        expect(not radar.frame.shown)
    end)

    it("rend le masque carré quand la minimap est déclarée carrée", function()
        local world = { shape = "SQUARE" }
        local _, radar = boot(world)
        radar:Toggle()
        radar:Toggle()
        expect_eq(world.minimap.mask, "Interface\\ChatFrame\\ChatFrameBackground")
    end)

    it("suit les réglages : terrain, rotation, opacité, taille", function()
        local world = {}
        local _, radar = boot(world, {
            saved = { NextStepDB = { schema = 1, modules = {
                Radar = { terrain = true, rotate = false, alpha = 5, size = 0.4 },
            } } },
        })
        radar:Toggle()
        expect_eq(world.minimap.mask, "Textures\\MinimapMask", "terrain visible")
        expect_eq(world.cvars.rotateMinimap, "0", "rotation laissée au réglage du joueur")
        expect_eq(world.minimap.alpha, 1, "opacité bornée à 100 %")
        expect_eq(world.minimap.width, 400)
        radar:SetSizeSetting(0.8)
        expect_eq(world.minimap.width, 800, "nouvelle taille appliquée")
        expect(centered(world, radar), "toujours centrée")
        radar:SetLook("terrain", false)
        expect_eq(world.minimap.mask, "Interface\\AddOns\\NextStep\\Media\\RadarMask")
        radar:Toggle()
        expect_eq(world.minimap.parent, world.cluster, "état d'origine conservé après la nouvelle taille")
        expect_eq(world.minimap.zoom, 3)
    end)

    it("place les points cardinaux selon l'orientation du personnage", function()
        local world = { facing = 0 }
        local _, radar = boot(world)
        radar:Toggle()
        local north = letter(radar, "N")
        local radius = 600 / 2 - 14
        expect(near(north.points[1][4], 0) and near(north.points[1][5], radius), "nord en haut")
        -- Le personnage regarde vers l'ouest : le nord passe à droite, l'est en bas.
        world.facing = math.pi / 2
        radar:UpdateCompass()
        expect(near(north.points[1][4], radius) and near(north.points[1][5], 0), "nord à droite")
        local east = letter(radar, "E")
        expect(near(east.points[1][4], 0) and near(east.points[1][5], -radius), "est en bas")
    end)

    it("cache les points cardinaux quand l'orientation est inconnue", function()
        local world = { facing = nil }
        local _, radar = boot(world)
        radar:Toggle()
        expect(not letter(radar, "N").shown)
    end)

    it("traduit l'ouest en français", function()
        local world = {}
        local _, radar = boot(world, { locale = "frFR" })
        radar:Toggle()
        expect(letter(radar, "O"), "lettre O")
    end)

    it("attend la fin du combat si la minimap est protégée", function()
        local world = {}
        local game, radar = boot(world)
        world.minimap.protected = true
        game.inCombat = true
        radar:Toggle()
        expect(not radar.active)
        expect(game:chatText():find("after combat", 1, true))
        radar:Toggle()   -- second appui : on annule
        expect_eq(radar.pending, false)
        radar:Toggle()
        game.inCombat = false
        game:fire("PLAYER_REGEN_ENABLED")
        expect(radar.active, "ouvert après le combat")
        expect(not game:isEventRegistered("PLAYER_REGEN_ENABLED"))
    end)

    it("se ferme quand le module est désactivé, et refuse de s'ouvrir ensuite", function()
        local world = {}
        local game, radar = boot(world)
        radar:Toggle()
        SlashCmdList.NEXTSTEP("disable Radar")
        expect(not radar.active)
        expect_eq(world.minimap.parent, world.cluster)
        SlashCmdList.NEXTSTEP("radar")
        expect(not radar.active)
        expect(game:chatText():find("is disabled", 1, true))
    end)

    it("rend l'option de rotation à la déconnexion", function()
        local world = {}
        local game, radar = boot(world)
        radar:Toggle()
        expect_eq(world.cvars.rotateMinimap, "1")
        game:fire("PLAYER_LOGOUT")
        expect_eq(world.cvars.rotateMinimap, "0")
    end)

    it("se met de côté si FarmHud est chargé", function()
        local world = {}
        local _, radar = boot(world, { loaded = { "FarmHud" } })
        expect(not radar.enabled)
        expect_eq(radar.blockedBy, "FarmHud")
    end)

    it("déclare son raccourci clavier", function()
        local world = {}
        boot(world, { locale = "frFR" })
        expect_eq(BINDING_HEADER_NEXTSTEP, "NextStep")
        expect_eq(BINDING_NAME_NEXTSTEP_RADAR, "Affiche ou cache le radar de récolte")
    end)
end)
