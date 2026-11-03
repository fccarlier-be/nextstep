-- Radar de récolte : la minimap, agrandie et transparente, au centre de l'écran,
-- autour du personnage. Les points de suivi (herbes, filons, bancs de poissons)
-- restent visibles sans quitter le personnage des yeux.
--
-- Le client ne laisse pas un addon dessiner le terrain : le radar emprunte le vrai
-- cadre Minimap. À l'ouverture, il mémorise tout ce qu'il change (parent, points,
-- taille, couche, transparence, souris, zoom, rotation, enfants affichés) et le
-- rétablit à la fermeture. Le terrain est masqué par un masque transparent : seuls
-- les points restent, avec un anneau et les points cardinaux dessinés par le module.
--
-- [À vérifier] sur Forever : Minimap déplaçable en combat (sinon, ouverture et
-- fermeture différées à la sortie du combat) ; points de suivi visibles quand le
-- terrain est masqué ; masque d'origine rond (MASK_ROUND).

local _, ns = ...
local L = ns.L

local Radar = ns.Modules:New("Radar", {
    title = L["Farming radar"],
    description = L["Shows the minimap, large and see-through, around your character, to spot herbs, "
        .. "ore and fish while gathering. Toggle it with /ns radar or a key (Key Bindings > NextStep)."],
    defaults = { size = 0.6, alpha = 0.7, terrain = false, rotate = true },
    conflicts = { "FarmHud" },
})

-- Libellés du menu Raccourcis (Bindings.xml).
BINDING_HEADER_NEXTSTEP = "NextStep"
BINDING_NAME_NEXTSTEP_RADAR = L["Show or hide the farming radar"]

local MEDIA = "Interface\\AddOns\\NextStep\\Media\\"
local MASK_HIDDEN = MEDIA .. "RadarMask"
local MASK_ROUND = "Textures\\MinimapMask"
local MASK_SQUARE = "Interface\\ChatFrame\\ChatFrameBackground"

local MIN_SIZE, MAX_SIZE = 0.3, 0.9     -- diamètre, en part de la hauteur de l'écran
local MIN_ALPHA, MAX_ALPHA = 0.2, 1
local LETTER_INSET = 14                 -- distance des lettres au bord de l'anneau

-- Points cardinaux : cap en radians, dans le sens des aiguilles d'une montre depuis le nord.
local CARDINALS = {
    { key = "N", bearing = 0 },
    { key = "E", bearing = math.pi / 2 },
    { key = "S", bearing = math.pi },
    { key = "W", bearing = 3 * math.pi / 2 },
}

local function clamp(value, low, high, default)
    value = tonumber(value) or default
    return math.max(low, math.min(high, value))
end

-- Position à l'écran (x vers la droite, y vers le haut) d'une direction de cap bearing,
-- quand le personnage regarde vers facing (GetPlayerFacing : radians, sens inverse des
-- aiguilles d'une montre depuis le nord) et que la carte tourne avec lui.
function Radar.CompassOffset(facing, bearing, radius)
    local angle = facing + bearing
    return math.sin(angle) * radius, math.cos(angle) * radius
end

function Radar:OnInitialize()
    self.active = false
    self.pending = nil      -- true / false : ouverture / fermeture attendant la fin du combat
    ns.Slash:Add("radar", function()
        self:Toggle()
    end, L["Show or hide the farming radar"])
end

function Radar:OnEnable()
    -- L'option de rotation est sauvegardée par le client : on la rend avant de partir.
    self:RegisterEvent("PLAYER_LOGOUT", function()
        if self.saved then
            C_CVar.SetCVar("rotateMinimap", self.saved.rotate)
        end
    end)
end

function Radar:OnDisable()
    self.pending = nil
    self:Close()
end

function Radar:GetSize()
    return clamp(self.db.size, MIN_SIZE, MAX_SIZE, 0.6)
end

function Radar:GetAlpha()
    return clamp(self.db.alpha, MIN_ALPHA, MAX_ALPHA, 0.7)
end

-- Le déplacement de Minimap est bloqué en combat si le client la protège.
local function blocked()
    return InCombatLockdown() and Minimap:IsProtected()
end

function Radar:Toggle()
    if not self.enabled then
        ns:Print(L["%s is disabled: enable it in the options."]:format(self.title))
        return
    end
    self:SetShown(not (self.pending == nil and self.active or self.pending))
end

function Radar:SetShown(show)
    if blocked() then
        self.pending = show
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            local wanted = self.pending
            self.pending = nil
            if wanted ~= nil then
                self:SetShown(wanted)
            end
        end)
        ns:Print(L["The radar will change after combat."])
        return
    end
    self.pending = nil
    if show then
        self:Open()
    else
        self:Close()
    end
end

-- Cadre du radar : centré, sans souris, sous le reste de l'interface.
function Radar:CreateFrame()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("BACKGROUND")
    frame:EnableMouse(false)
    frame:Hide()

    local ring = frame:CreateTexture(nil, "OVERLAY")
    ring:SetTexture(MEDIA .. "RadarRing")
    ring:SetAllPoints()
    ring:SetVertexColor(1, 0.82, 0.4)
    frame.ring = ring

    frame.letters = {}
    for _, cardinal in ipairs(CARDINALS) do
        local letter = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        letter:SetText(L[cardinal.key])
        letter.bearing = cardinal.bearing
        frame.letters[#frame.letters + 1] = letter
    end

    frame:SetScript("OnUpdate", function()
        self:UpdateCompass()
    end)
    self.frame = frame
    return frame
end

-- Place les lettres autour de l'anneau. Sans cap connu (instance, valeur secrète),
-- elles sont cachées quand la carte tourne.
function Radar:UpdateCompass()
    local frame = self.frame
    local facing = 0
    if self.db.rotate then
        facing = GetPlayerFacing and GetPlayerFacing()
        if facing == nil or (issecretvalue and issecretvalue(facing)) then
            for _, letter in ipairs(frame.letters) do
                letter:Hide()
            end
            return
        end
    end
    local radius = frame:GetWidth() / 2 - LETTER_INSET
    for _, letter in ipairs(frame.letters) do
        local x, y = Radar.CompassOffset(facing, letter.bearing, radius)
        letter:ClearAllPoints()
        letter:SetPoint("CENTER", frame, "CENTER", x, y)
        letter:Show()
    end
end

-- Enfants de Minimap (boutons d'addons, cadres de Blizzard) : cachés pendant le radar.
-- Les cadres protégés sont laissés tels quels, pour ne rien bloquer en combat.
local function hideChildren(saved)
    for _, child in ipairs({ Minimap:GetChildren() }) do
        if child:IsShown() and not child:IsProtected() then
            child:Hide()
            saved[#saved + 1] = child
        end
    end
end

function Radar:Open()
    if self.active then
        return
    end
    local frame = self.frame or self:CreateFrame()
    local size = math.floor(UIParent:GetHeight() * self:GetSize() + 0.5)
    frame:SetSize(size, size)

    local saved = {
        parent = Minimap:GetParent(),
        points = {},
        width = Minimap:GetWidth(),
        height = Minimap:GetHeight(),
        scale = Minimap:GetScale(),
        alpha = Minimap:GetAlpha(),
        strata = Minimap:GetFrameStrata(),
        level = Minimap:GetFrameLevel(),
        mouse = Minimap:IsMouseEnabled(),
        wheel = Minimap:IsMouseWheelEnabled(),
        zoom = Minimap:GetZoom(),
        rotate = C_CVar.GetCVar("rotateMinimap"),
        children = {},
    }
    for index = 1, Minimap:GetNumPoints() do
        saved.points[index] = { Minimap:GetPoint(index) }
    end
    self.saved = saved
    hideChildren(saved.children)

    Minimap:SetParent(frame)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", frame, "CENTER")
    Minimap:SetScale(1)
    Minimap:SetSize(size, size)
    Minimap:SetFrameStrata("BACKGROUND")
    Minimap:SetFrameLevel(frame:GetFrameLevel())
    Minimap:EnableMouse(false)
    Minimap:EnableMouseWheel(false)
    Minimap:SetZoom(0)
    self:ApplyLook()

    self.active = true
    frame:Show()
    self:UpdateCompass()
end

-- Terrain, transparence et rotation, d'après les réglages.
function Radar:ApplyLook()
    Minimap:SetMaskTexture(self.db.terrain and MASK_ROUND or MASK_HIDDEN)
    Minimap:SetAlpha(self:GetAlpha())
    if self.frame then
        self.frame.ring:SetAlpha(self:GetAlpha())
    end
    C_CVar.SetCVar("rotateMinimap", self.db.rotate and "1" or (self.saved and self.saved.rotate or "0"))
end

function Radar:Close()
    if not self.active then
        return
    end
    local saved = self.saved
    self.active = false
    self.saved = nil
    self.frame:Hide()

    Minimap:SetParent(saved.parent)
    Minimap:ClearAllPoints()
    for _, point in ipairs(saved.points) do
        Minimap:SetPoint(unpack(point))
    end
    Minimap:SetScale(saved.scale)
    Minimap:SetSize(saved.width, saved.height)
    Minimap:SetAlpha(saved.alpha)
    Minimap:SetFrameStrata(saved.strata)
    Minimap:SetFrameLevel(saved.level)
    Minimap:EnableMouse(saved.mouse)
    Minimap:EnableMouseWheel(saved.wheel)
    Minimap:SetZoom(saved.zoom)
    -- Forme déclarée par l'addon qui gère la minimap (le module Minimap, en carré).
    local shape = GetMinimapShape and GetMinimapShape()
    Minimap:SetMaskTexture(shape == "SQUARE" and MASK_SQUARE or MASK_ROUND)
    C_CVar.SetCVar("rotateMinimap", saved.rotate)
    for _, child in ipairs(saved.children) do
        child:Show()
    end
end

-- Curseur sans modèle du client ([À vérifier] modèles de curseur sur Forever),
-- comme celui de la carte sans brouillard.
local function addSlider(panel, anchor, low, high, step, format, get, set)
    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)

    local slider = CreateFrame("Slider", nil, panel)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(200, 16)
    slider:SetPoint("LEFT", label, "RIGHT", 12, 0)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    track:SetPoint("LEFT", 0, 0)
    track:SetPoint("RIGHT", 0, 0)
    track:SetHeight(4)
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    local function show()
        label:SetText(format:format(math.floor(get() * 100 + 0.5)))
    end
    slider:SetScript("OnValueChanged", function(_, value)
        set(value)
        show()
    end)
    panel:HookScript("OnShow", function()
        slider:SetValue(get())
        show()
    end)
    slider:SetValue(get())
    show()
    return label, slider
end

local function addCheck(panel, anchor, text, get, set)
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    check:SetChecked(get())
    check:SetScript("OnClick", function(button)
        set(button:GetChecked() and true or false)
    end)
    panel:HookScript("OnShow", function()
        check:SetChecked(get())
    end)
    local label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    label:SetText(text)
    return check
end

function Radar:SetSizeSetting(value)
    self.db.size = clamp(value, MIN_SIZE, MAX_SIZE, 0.6)
    if self.active then
        -- Nouvelle taille : on referme et rouvre, pour tout recalculer.
        self:Close()
        self:Open()
    end
end

function Radar:SetLook(key, value)
    self.db[key] = value
    if self.active then
        self:ApplyLook()
        self:UpdateCompass()
    end
end

function Radar:BuildOptions(panel, anchor)
    local sizeLabel = addSlider(panel, anchor, MIN_SIZE, MAX_SIZE, 0.05, L["Radar size: %d%% of the screen height"],
        function() return self:GetSize() end,
        function(value) self:SetSizeSetting(value) end)
    local alphaLabel = addSlider(panel, sizeLabel, MIN_ALPHA, MAX_ALPHA, 0.05, L["Radar opacity: %d%%"],
        function() return self:GetAlpha() end,
        function(value) self:SetLook("alpha", clamp(value, MIN_ALPHA, MAX_ALPHA, 0.7)) end)
    local terrain = addCheck(panel, alphaLabel, L["Show the terrain"],
        function() return self.db.terrain end,
        function(value) self:SetLook("terrain", value) end)
    local rotate = addCheck(panel, terrain, L["Rotate with the camera"],
        function() return self.db.rotate end,
        function(value) self:SetLook("rotate", value) end)
    return rotate
end
