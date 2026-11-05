local wow = require("wow")

-- Module Minimap (Modules/UI/Minimap.lua) et bouton NextStep (Modules/UI/AddonsMenu.lua).

local function newMinimap(world)
    local minimap = setmetatable({ zoom = 2, wheel = false, mask = "Textures\\MinimapMask", hooks = {} },
        { __index = function() return function() end end })
    function minimap.SetMaskTexture(self, mask) self.mask = mask end
    function minimap.GetZoom(self) return self.zoom end
    function minimap.SetZoom(self, zoom) self.zoom = zoom end
    function minimap.GetZoomLevels() return 6 end
    function minimap.EnableMouseWheel(self, enabled) self.wheel = enabled end
    function minimap.IsMouseWheelEnabled(self) return self.wheel end
    function minimap.HookScript(self, name, fn) self.hooks[name] = fn end
    function minimap.GetWidth() return 140 end
    function minimap.GetFrameLevel() return 1 end
    function minimap.IsProtected() return false end
    function minimap.GetChildren() return unpack(world.children or {}) end
    return minimap
end

local function boot(world, options)
    world = world or {}
    options = options or {}
    options.beforeInit = function()
        world.minimap = newMinimap(world)
        _G.Minimap = world.minimap
        _G.GetMinimapShape = world.shape and function() return world.shape end
    end
    local game = wow.boot(options)
    return game, game.ns.Modules:Get("Minimap"), game.ns.Modules:Get("AddonsMenu"), world
end

-- Bouton d'un autre addon, enfant de la minimap.
local function addonButton(name)
    local button = setmetatable({ shown = true, hooks = {} }, { __index = function() return function() end end })
    function button.GetName() return name end
    function button.Show(self) self.shown = true; if self.hooks.OnShow then self.hooks.OnShow(self) end end
    function button.Hide(self) self.shown = false end
    function button.SetShown(self, shown) if shown then self:Show() else self:Hide() end end
    function button.HookScript(self, script, fn) self.hooks[script] = fn end
    return button
end

describe("Minimap", function()
    it("est carrée par défaut et le déclare aux autres addons", function()
        local game, module, _, world = boot()
        expect(module.enabled, "module actif")
        expect_eq(world.minimap.mask, "Interface\\ChatFrame\\ChatFrameBackground")
        expect_eq(GetMinimapShape(), "SQUARE")
        expect_eq(#game.errors, 0)
    end)

    it("remet le masque carré quand le client remet le sien", function()
        local _, module, _, world = boot()
        world.minimap:SetMaskTexture("Textures\\MinimapMask")
        expect_eq(world.minimap.mask, "Interface\\ChatFrame\\ChatFrameBackground")
        module:SetSquare(false)
        world.minimap:SetMaskTexture("Textures\\MinimapMask")
        expect_eq(world.minimap.mask, "Textures\\MinimapMask", "ronde en option : rien n'est forcé")
    end)

    it("redevient ronde en option ou à la désactivation", function()
        local game, module, _, world = boot()
        module:SetSquare(false)
        expect_eq(world.minimap.mask, "Textures\\MinimapMask")
        expect_eq(GetMinimapShape, nil, "plus de forme déclarée")
        module:SetSquare(true)
        game.ns.Modules:SetEnabled("Minimap", false)
        expect_eq(world.minimap.mask, "Textures\\MinimapMask")
        expect_eq(GetMinimapShape, nil)
        expect_eq(world.minimap.wheel, false, "molette rendue")
    end)

    it("rend la forme déclarée par un autre addon", function()
        local game = boot({ shape = "ROUND" })
        expect_eq(GetMinimapShape(), "SQUARE")
        game.ns.Modules:SetEnabled("Minimap", false)
        expect_eq(GetMinimapShape(), "ROUND")
    end)

    it("pose l'icône jour / nuit sur le coin du carré, et la rend en rond", function()
        local icon = { points = { { "TOPRIGHT", "MinimapCluster", "TOPRIGHT", -10, -5 } }, scale = 1 }
        function icon.GetNumPoints(self) return #self.points end
        function icon.GetPoint(self, index) return unpack(self.points[index]) end
        function icon.ClearAllPoints(self) self.points = {} end
        function icon.SetPoint(self, ...) self.points[#self.points + 1] = { ... } end
        function icon.GetScale(self) return self.scale end
        function icon.SetScale(self, scale) self.scale = scale end
        local _, module, _, world = boot()
        _G.GameTimeFrame = icon
        module:Apply()
        expect_eq(icon.points[1][1], "CENTER")
        expect_eq(icon.points[1][2], world.minimap, "sur la minimap")
        expect_eq(icon.points[1][3], "TOPRIGHT", "coin en haut à droite")
        module:SetSquare(false)
        expect_eq(icon.points, { { "TOPRIGHT", "MinimapCluster", "TOPRIGHT", -10, -5 } }, "place d'origine rendue")
        expect_eq(icon.scale, 1)
        _G.GameTimeFrame = nil
    end)

    it("zoome à la molette, dans les limites", function()
        local _, module, _, world = boot()
        expect_eq(world.minimap.wheel, true, "molette active")
        local wheel = world.minimap.hooks.OnMouseWheel
        wheel(world.minimap, 1)
        expect_eq(world.minimap.zoom, 3)
        for _ = 1, 10 do
            wheel(world.minimap, 1)
        end
        expect_eq(world.minimap.zoom, 5, "zoom le plus proche")
        module:SetWheelZoom(false)
        wheel(world.minimap, -1)
        expect_eq(world.minimap.zoom, 5, "molette désactivée")
    end)
end)

describe("Bouton NextStep", function()
    it("se place sur le cercle ou sur le bord du carré", function()
        local _, _, menu = boot()
        local x, y = menu.ButtonOffset(0, 70, false)
        expect(math.abs(x - 80) < 1e-6 and math.abs(y) < 1e-6, "à droite")
        x, y = menu.ButtonOffset(45, 70, true)
        expect(math.abs(x - 80) < 1e-6 and math.abs(y - 80) < 1e-6, "dans le coin du carré")
    end)

    it("liste les addons chargés avec l'action qui ouvre leurs paramètres", function()
        local game, _, menu = boot()
        local addons = {
            { "Bagnon", "|cff00ff00Bagnon|r" }, { "Details", "Details!" }, { "Atlas", "Atlas" },
            { "Silent", "Silent" }, { "Unloaded", "Unloaded" }, { "NextStep_Alliance", "NextStep - Alliance" },
        }
        local opened = {}
        _G.C_AddOns.GetNumAddOns = function() return #addons end
        _G.C_AddOns.GetAddOnInfo = function(i) return addons[i][1], addons[i][2] end
        _G.C_AddOns.IsAddOnLoaded = function(name) return name ~= "Unloaded" end
        local metadata = _G.C_AddOns.GetAddOnMetadata
        _G.C_AddOns.GetAddOnMetadata = function(name, key)
            if name == "Atlas" and key == "AddonCompartmentFunc" then
                return "Atlas_OnClick"
            end
            return metadata(name, key)
        end
        _G.Atlas_OnClick = function(name) opened[#opened + 1] = "compartment " .. name end
        local details = addonButton("LibDBIcon10_Details")
        details.GetScript = function() return function() opened[#opened + 1] = "button Details" end end
        _G.LibDBIcon10_Details = details
        _G.SettingsPanel = { GetAllCategories = function()
            return { { GetName = function() return "Bagnon" end, GetID = function() return 42 end } }
        end }
        _G.Settings = { OpenToCategory = function(id) opened[#opened + 1] = "settings " .. id end }

        local list = menu.Addons()
        local titles = {}
        for _, addon in ipairs(list) do
            titles[#titles + 1] = addon.title
        end
        expect_eq(titles, { "Atlas", "Bagnon", "Details!", "Silent" }, "triés, sans NextStep ni addon non chargé")
        for _, addon in ipairs(list) do
            if addon.action then
                addon.action()
            end
        end
        expect_eq(opened, { "compartment Atlas", "settings 42", "button Details" })
        expect_eq(list[4].action, nil, "Silent n'a pas de paramètres")

        -- Le menu : radar, options, puis les addons ; Silent grisé.
        local entries = {}
        local root = {}
        function root.CreateTitle(_, text) entries[#entries + 1] = "# " .. text end
        function root.CreateDivider() entries[#entries + 1] = "--" end
        function root.CreateButton(_, text)
            local entry = { text = text, enabled = true }
            entries[#entries + 1] = entry
            return { SetEnabled = function(_, enabled) entry.enabled = enabled end }
        end
        menu:Fill(root)
        expect_eq(entries[1], "# NextStep")
        expect_eq(entries[2].text, "Farming radar")
        expect_eq(entries[#entries].text, "Silent")
        expect_eq(entries[#entries].enabled, false)
        expect_eq(#game.errors, 0)
        _G.LibDBIcon10_Details, _G.Atlas_OnClick, _G.SettingsPanel = nil, nil, nil
    end)

    it("masque les boutons LibDBIcon des autres addons, de façon réversible", function()
        local world = {}
        local button = addonButton("LibDBIcon10_Bagnon")
        local blizzard = addonButton("MinimapZoomIn")
        world.children = { button, blizzard }
        local _, _, menu = boot(world)
        expect_eq(button.shown, false, "bouton d'addon masqué")
        expect_eq(blizzard.shown, true, "bouton de Blizzard intact")
        button:Show()
        expect_eq(button.shown, false, "reste masqué si l'addon le réaffiche")
        menu:SetHideButtons(false)
        expect_eq(button.shown, true, "option désactivée : il revient")
    end)
end)
