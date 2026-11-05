-- Carte sans brouillard : les zones inexplorées de la carte du monde sont affichées,
-- dans une teinte atténuée, à côté de celles que le joueur a explorées.
--
-- Le client ne donne que les textures déjà explorées (C_MapExplorationInfo). Les
-- autres viennent de DB.mapOverlays, extraites des tables du client (Tools/worldmap) :
-- par carte (UiMapArtID), { largeur, hauteur, décalage X, décalage Y, FileDataID... },
-- tuiles rangée par rangée. Une superposition explorée se reconnaît à sa taille et à
-- son décalage.
--
-- Après chaque rafraîchissement de la punaise d'exploration de la carte du monde, le
-- module dessine, sur cette punaise et sous ses propres textures, les superpositions
-- inexplorées. Code propre à NextStep (Leatrix Maps et Mapster ne sont pas libres).

local _, ns = ...
local L = ns.L

local MapReveal = ns.Modules:New("MapReveal", {
    title = L["Map without fog"],
    description = L["Shows the unexplored areas of the world map, dimmed."],
    defaults = { brightness = 0.6 },
    conflicts = { "Leatrix_Maps", "Mapster" },
})

local PIN_TEMPLATE = "MapExplorationPinTemplate"
local TILE_SIZE = 256
local MIN_BRIGHTNESS, MAX_BRIGHTNESS = 0.2, 1

-- Plus petite puissance de 2 (au moins 16) qui contient size : taille du fichier
-- d'une tuile incomplète, au bord droit ou bas d'une superposition.
local function fileSize(size)
    local file = 16
    while file < size do
        file = file * 2
    end
    return file
end

local function overlayKey(width, height, x, y)
    return width .. ":" .. height .. ":" .. x .. ":" .. y
end

-- Superpositions déjà explorées de la carte, par clé.
local function exploredKeys(mapID)
    local keys = {}
    for _, info in ipairs(C_MapExplorationInfo.GetExploredMapTextures(mapID) or {}) do
        keys[overlayKey(info.textureWidth, info.textureHeight, info.offsetX, info.offsetY)] = true
    end
    return keys
end

-- Taille des tuiles de la couche affichée (256 sur les cartes du Classic).
local function tileSize(pin, mapID)
    local layers = C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(mapID)
    local container = pin:GetMap().GetCanvasContainer and pin:GetMap():GetCanvasContainer()
    -- Protégé : avant le premier affichage de la carte, le conteneur n'a pas encore
    -- ses niveaux de zoom et GetCurrentLayerIndex lève une erreur.
    local ok, index = false, nil
    if container and container.GetCurrentLayerIndex then
        ok, index = pcall(container.GetCurrentLayerIndex, container)
    end
    index = ok and index or 1
    local layer = layers and layers[index]
    return layer and layer.tileWidth or TILE_SIZE, layer and layer.tileHeight or TILE_SIZE
end

function MapReveal:OnInitialize()
    self.textures = {}   -- textures créées sur la punaise, réutilisées d'un affichage à l'autre
    self.used = 0
    self.hooked = false
end

function MapReveal:OnEnable()
    if not self:Attach() then
        -- Carte du monde chargée à la demande : on attend son chargement.
        self:RegisterEvent("ADDON_LOADED", function(_, _, name)
            if name == "Blizzard_WorldMap" and self:Attach() then
                self:UnregisterEvent("ADDON_LOADED")
                self:Refresh()
            end
        end)
    end
    self:Refresh()
end

function MapReveal:OnDisable()
    self:Release()
end

-- Trouve la punaise d'exploration et s'y accroche (une seule fois : hooksecurefunc ne
-- se retire pas, le crochet ne fait rien quand le module est désactivé).
function MapReveal:Attach()
    if self.pin then
        return true
    end
    local map = WorldMapFrame
    if not (map and map.EnumeratePinsByTemplate) then
        return false
    end
    -- Une seule punaise d'exploration par carte. L'énumération suit la forme de pairs.
    for pin in map:EnumeratePinsByTemplate(PIN_TEMPLATE) do
        self.pin = self.pin or pin
    end
    if not self.pin then
        return false
    end
    if not self.hooked then
        self.hooked = true
        hooksecurefunc(self.pin, "RefreshOverlays", function()
            if self.enabled then
                ns.SafeCall(self.Refresh, self)
            end
        end)
    end
    return true
end

-- Cache toutes les textures du module.
function MapReveal:Release()
    for _, texture in ipairs(self.textures) do
        texture:Hide()
    end
    self.used = 0
end

function MapReveal:AcquireTexture()
    self.used = self.used + 1
    local texture = self.textures[self.used]
    if not texture then
        -- Couche BORDER : sous les textures explorées dessinées par le client.
        texture = self.pin:CreateTexture(nil, "BORDER")
        self.textures[self.used] = texture
    end
    return texture
end

-- Dessine les superpositions inexplorées de la carte affichée.
function MapReveal:Refresh()
    self:Release()
    local pin = self.pin
    -- Carte fermée : rien à dessiner, le crochet de RefreshOverlays redessine à l'ouverture.
    if not (self.enabled and pin and pin:GetMap():IsShown()) then
        return
    end
    local mapID = pin:GetMap():GetMapID()
    local overlays = mapID and ns.DB.mapOverlays[C_Map.GetMapArtID(mapID)]
    if not overlays then
        return
    end
    local explored = exploredKeys(mapID)
    local tileWidth, tileHeight = tileSize(pin, mapID)
    local brightness = self:GetBrightness()
    for _, overlay in ipairs(overlays) do
        local width, height, x, y = overlay[1], overlay[2], overlay[3], overlay[4]
        if not explored[overlayKey(width, height, x, y)] then
            self:DrawOverlay(overlay, width, height, x, y, tileWidth, tileHeight, brightness)
        end
    end
end

function MapReveal:DrawOverlay(overlay, width, height, x, y, tileWidth, tileHeight, brightness)
    local columns, rows = math.ceil(width / tileWidth), math.ceil(height / tileHeight)
    for row = 1, rows do
        -- Dernière rangée : la tuile n'est remplie que sur le reste de la hauteur.
        local pixelHeight = row < rows and tileHeight or (height - tileHeight * (rows - 1))
        local fileHeight = row < rows and tileHeight or fileSize(pixelHeight)
        for column = 1, columns do
            local pixelWidth = column < columns and tileWidth or (width - tileWidth * (columns - 1))
            local fileWidth = column < columns and tileWidth or fileSize(pixelWidth)
            local fileDataID = overlay[4 + (row - 1) * columns + column]
            if fileDataID then
                local texture = self:AcquireTexture()
                texture:SetTexture(fileDataID, nil, nil, "TRILINEAR")
                texture:SetSize(pixelWidth, pixelHeight)
                texture:SetTexCoord(0, pixelWidth / fileWidth, 0, pixelHeight / fileHeight)
                texture:ClearAllPoints()
                texture:SetPoint("TOPLEFT", self.pin, "TOPLEFT", x + tileWidth * (column - 1),
                    -(y + tileHeight * (row - 1)))
                texture:SetVertexColor(brightness, brightness, brightness)
                texture:Show()
            end
        end
    end
end

function MapReveal:GetBrightness()
    local value = tonumber(self.db.brightness) or 0.6
    return math.max(MIN_BRIGHTNESS, math.min(MAX_BRIGHTNESS, value))
end

-- Luminosité des zones inexplorées, de 0,2 (sombre) à 1 (comme les zones explorées).
function MapReveal:SetBrightness(value)
    self.db.brightness = math.max(MIN_BRIGHTNESS, math.min(MAX_BRIGHTNESS, value))
    local brightness = self:GetBrightness()
    for index = 1, self.used do
        self.textures[index]:SetVertexColor(brightness, brightness, brightness)
    end
end

-- Réglage dans le panneau d'options : curseur de luminosité, sans modèle du client
-- ([À vérifier] modèles de curseur disponibles sur Forever).
function MapReveal:BuildOptions(panel, anchor)
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
    slider:SetMinMaxValues(MIN_BRIGHTNESS, MAX_BRIGHTNESS)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)

    local function refresh()
        local brightness = self:GetBrightness()
        label:SetText(L["Unexplored areas brightness: %d%%"]:format(math.floor(brightness * 100 + 0.5)))
        slider:SetValue(brightness)
    end
    slider:SetScript("OnValueChanged", function(_, value)
        self:SetBrightness(value)
        label:SetText(L["Unexplored areas brightness: %d%%"]:format(math.floor(self:GetBrightness() * 100 + 0.5)))
    end)
    panel:HookScript("OnShow", refresh)
    refresh()

    self.brightnessSlider, self.brightnessLabel = slider, label
    return label
end
