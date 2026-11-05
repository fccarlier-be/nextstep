-- Minimap (docs/DESIGN.md, « Minimap ») : carrée par défaut, ronde en option, et
-- zoom à la molette. La forme est déclarée aux autres addons (et au radar) par
-- GetMinimapShape, absente de Forever.
--
-- Tout ce que le module change est rétabli à sa désactivation : masque rond,
-- décorations rondes du client, molette. Les changements sont différés à la sortie
-- du combat si la minimap est protégée.
--
-- [À vérifier] sur Forever : noms des décorations rondes (ROUND_DECORATIONS) ;
-- minimap protégée en combat ; GetZoomLevels.

local _, ns = ...
local L = ns.L

local MinimapModule = ns.Modules:New("Minimap", {
    title = L["Minimap"],
    description = L["Square minimap (round as an option) and zoom with the mouse wheel."],
    defaults = { square = true, wheelZoom = true },
    conflicts = { "SexyMap", "BasicMinimap", "Chinchilla" },
})

local MASK_ROUND = "Textures\\MinimapMask"
local MASK_SQUARE = "Interface\\ChatFrame\\ChatFrameBackground"
local BORDER = 1

-- Décorations prévues pour une minimap ronde, cachées en carré (si elles existent).
local ROUND_DECORATIONS = { "MinimapBorder", "MinimapBorderTop", "MinimapCompassTexture" }

local function squareShape()
    return "SQUARE"
end

function MinimapModule:OnInitialize()
    self.hidden = {}   -- décorations cachées par le module : [cadre] = true
end

function MinimapModule:OnEnable()
    self:Apply()
    if not self.maskHooked and Minimap and hooksecurefunc then
        -- Le client remet son masque rond (connexion, changement de zone...) : on
        -- remet le masque carré juste après.
        self.maskHooked = true
        hooksecurefunc(Minimap, "SetMaskTexture", function(_, texture)
            if texture ~= MASK_SQUARE then
                self:ApplyMask()
            end
        end)
    end
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "ApplyMask")
    if C_Timer and C_Timer.After then
        C_Timer.After(1, function()
            self:ApplyMask()
        end)
    end
    if not self.wheelHooked and Minimap and Minimap.HookScript then
        self.wheelHooked = true
        Minimap:HookScript("OnMouseWheel", function(_, delta)
            if self.enabled and self.db.wheelZoom then
                self:Zoom(delta)
            end
        end)
    end
end

function MinimapModule:OnDisable()
    self:Restore()
end

-- Le radar emprunte la minimap : il rétablit lui-même la forme à sa fermeture.
local function radarOpen()
    local radar = ns.Modules:Get("Radar")
    return radar and radar.active
end

local function deferred(self, method)
    if InCombatLockdown and InCombatLockdown() and Minimap:IsProtected() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            self[method](self)
        end)
        return true
    end
    return false
end

function MinimapModule:Apply()
    if not Minimap or deferred(self, "Apply") then
        return
    end
    local square = self.db.square
    -- Ronde : on rend la déclaration d'origine (celle d'un autre addon, ou aucune).
    if square then
        if GetMinimapShape ~= squareShape then
            self.previousShape = GetMinimapShape
            _G.GetMinimapShape = squareShape
        end
    elseif GetMinimapShape == squareShape then
        _G.GetMinimapShape = self.previousShape
    end
    if not radarOpen() then
        Minimap:SetMaskTexture(square and MASK_SQUARE or MASK_ROUND)
    end
    for _, name in ipairs(ROUND_DECORATIONS) do
        local frame = _G[name]
        if frame and frame.Hide then
            if square and frame:IsShown() then
                frame:Hide()
                self.hidden[frame] = true
            elseif not square and self.hidden[frame] then
                frame:Show()
                self.hidden[frame] = nil
            end
        end
    end
    self:UpdateBorder()
    self:PlaceMenuButton()
    if self.savedWheel == nil then
        self.savedWheel = Minimap:IsMouseWheelEnabled() == true
    end
    Minimap:EnableMouseWheel(self.db.wheelZoom or self.savedWheel)
end

function MinimapModule:Restore()
    if not Minimap or deferred(self, "Restore") then
        return
    end
    if GetMinimapShape == squareShape then
        _G.GetMinimapShape = self.previousShape
    end
    if not radarOpen() then
        Minimap:SetMaskTexture(MASK_ROUND)
    end
    for frame in pairs(self.hidden) do
        frame:Show()
    end
    self.hidden = {}
    if self.border then
        self.border:Hide()
    end
    self:PlaceMenuButton()
    if self.savedWheel ~= nil then
        Minimap:EnableMouseWheel(self.savedWheel)
        self.savedWheel = nil
    end
end

-- Masque carré, si la minimap est carrée et que le radar ne l'emprunte pas.
function MinimapModule:ApplyMask()
    if self.enabled and self.db.square and Minimap and not radarOpen() and not self.masking then
        self.masking = true
        Minimap:SetMaskTexture(MASK_SQUARE)
        self.masking = false
    end
end

-- Le bouton NextStep suit la forme de la minimap (cercle ou bord du carré).
function MinimapModule:PlaceMenuButton()
    local menu = ns.Modules:Get("AddonsMenu")
    if menu and menu.enabled then
        menu:PlaceButton()
    end
end

-- Liseré sombre autour de la minimap carrée.
function MinimapModule:UpdateBorder()
    if not self.border then
        local border = CreateFrame("Frame", nil, Minimap, BackdropTemplateMixin and "BackdropTemplate" or nil)
        border:SetPoint("TOPLEFT", -BORDER, BORDER)
        border:SetPoint("BOTTOMRIGHT", BORDER, -BORDER)
        border:SetFrameLevel(math.max((Minimap:GetFrameLevel() or 1) - 1, 0))
        if border.SetBackdrop then
            border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = BORDER })
            border:SetBackdropBorderColor(0, 0, 0, 1)
        end
        self.border = border
    end
    self.border:SetShown(self.db.square)
end

-- Molette : un cran de zoom, entre le plus large (0) et le plus proche.
function MinimapModule:Zoom(delta)
    local levels = Minimap.GetZoomLevels and Minimap:GetZoomLevels() or 6
    local zoom = Minimap:GetZoom() + (delta > 0 and 1 or -1)
    Minimap:SetZoom(math.max(0, math.min(levels - 1, zoom)))
end

function MinimapModule:SetSquare(square)
    self.db.square = square
    if self.enabled then
        self:Apply()
    end
end

function MinimapModule:SetWheelZoom(enabled)
    self.db.wheelZoom = enabled
    if self.enabled then
        self:Apply()
    end
end

function MinimapModule:BuildOptions(panel, anchor)
    local Options = ns.Options
    local square = Options.AddCheck(panel, anchor, L["Square minimap"],
        function() return self.db.square end,
        function(value) self:SetSquare(value) end)
    return Options.AddCheck(panel, square, L["Zoom with the mouse wheel"],
        function() return self.db.wheelZoom end,
        function(value) self:SetWheelZoom(value) end)
end
