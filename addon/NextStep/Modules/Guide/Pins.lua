-- Repères du guide sur la minimap et la carte du monde (docs/DESIGN.md, « Carte du
-- monde et minimap ») : tous les points des objectifs ouverts de l'étape (position,
-- maîtres proposés, zones d'apparition des mobs), la cible de la flèche en doré et
-- plus grande. Sur la minimap, une cible hors de vue devient une flèche dorée au bord.
--
-- Code propre à NextStep, sans HereBeDragons : comme la flèche, tout se calcule en
-- coordonnées monde (Navigation). La carte du monde est projetée par ses bornes,
-- lues une fois par carte avec C_Map.GetWorldPosFromMapPos.
--
-- [À vérifier] sur Forever : Minimap:GetViewRadius, option rotateMinimap, ajout d'un
-- fournisseur de données à WorldMapFrame (AddDataProvider) et son canevas.

local _, ns = ...

local Guide = ns.Modules:Get("Guide")
local Navigation = ns.Navigation

local PIN_TEXTURE = "Interface\\AddOns\\NextStep\\Media\\Pin"
local ARROW_TEXTURE = "Interface\\Minimap\\MinimapArrow"
local MAX_POINTS = 80
local UPDATE_PERIOD = 0.05   -- secondes

-- Taille à l'écran (pixels) : point ordinaire, cible.
local MINIMAP_SIZE, MINIMAP_TARGET_SIZE, MINIMAP_ARROW_SIZE = 10, 16, 24
local MAP_SIZE, MAP_TARGET_SIZE = 14, 22

local COLORS = {
    target = { 1, 0.82, 0 },
    place = { 0.35, 0.75, 1 },
    zone = { 1, 0.35, 0.25 },
}

-- Diamètre de la minimap en yards selon le zoom (0 à 5), dehors et en intérieur :
-- valeurs du client, en secours si Minimap:GetViewRadius n'existe pas.
local MINIMAP_DIAMETERS = {
    outdoor = { 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 },
    indoor = { 300, 240, 180, 120, 80, 50 },
}

local function usable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

---------------------------------------------------------------------------
-- Points à afficher
---------------------------------------------------------------------------

local function sameSpot(a, b)
    return a and b and a.map == b.map and a.x == b.x and a.y == b.y
end

-- Points des objectifs ouverts du résultat : { instance, north, west, kind, step,
-- goal, target }, la cible en dernier (dessinée par-dessus les autres).
function Guide:PinPoints(result)
    local list, target = {}, nil
    if not (result and result.current) then
        return list
    end
    local guide = result.guide
    for _, entry in ipairs(self:OpenGoals(result)) do
        local goal = guide.steps[entry.step].goals[entry.goal]
        for _, point in ipairs(self:GoalPoints(goal, guide)) do
            local instance, north, west = Navigation.WorldPosition(point.map, point.x, point.y, point.f)
            if instance then
                local pin = {
                    instance = instance, north = north, west = west, kind = point.kind,
                    step = entry.step, goal = entry.goal,
                }
                local isTarget = result.target and result.target.step == entry.step
                    and result.target.goal == entry.goal and sameSpot(point, result.target)
                if isTarget and not target then
                    pin.target = true
                    target = pin
                elseif #list < MAX_POINTS then
                    list[#list + 1] = pin
                end
            end
        end
    end
    list[#list + 1] = target
    return list
end

-- Libellé d'un repère (infobulle de la carte du monde).
function Guide:PinLabel(pin)
    local result = self.result
    if not (result and result.guide.steps[pin.step]) then
        return nil
    end
    return self:GoalLabel(result, pin.step, pin.goal)
end

---------------------------------------------------------------------------
-- Minimap
---------------------------------------------------------------------------

-- Position d'un point sur la minimap, en pixels depuis son centre (x vers l'est,
-- y vers le nord), à partir de l'écart en yards (dNorth, dWest), du regard du
-- joueur si la minimap tourne, et de l'échelle (pixels par yard).
function Guide.MinimapOffset(dNorth, dWest, facing, scale)
    local x, y = -dWest * scale, dNorth * scale
    if facing then
        -- Minimap tournante : le regard du joueur est en haut.
        local cos, sin = math.cos(-facing), math.sin(-facing)
        x, y = x * cos - y * sin, x * sin + y * cos
    end
    return x, y
end

-- Rayon de la minimap en yards.
local function minimapRadius()
    if Minimap.GetViewRadius then
        local radius = Minimap:GetViewRadius()
        if usable(radius) and radius > 0 then
            return radius
        end
    end
    local zoom = (Minimap.GetZoom and Minimap:GetZoom() or 0) + 1
    local list = (IsIndoors and IsIndoors()) and MINIMAP_DIAMETERS.indoor or MINIMAP_DIAMETERS.outdoor
    return (list[zoom] or list[1]) / 2
end

local function minimapSquare()
    return GetMinimapShape ~= nil and GetMinimapShape() == "SQUARE"
end

-- Point ramené au bord de la minimap (ronde ou carrée), à limit pixels du centre :
-- x, y, et vrai si le point était déjà dedans.
function Guide.MinimapEdge(x, y, limit, square)
    local reach = square and math.max(math.abs(x), math.abs(y)) or math.sqrt(x * x + y * y)
    if reach <= limit then
        return x, y, true
    end
    return x * limit / reach, y * limit / reach, false
end

local function minimapRotates()
    local value = C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("rotateMinimap")
        or (GetCVar and GetCVar("rotateMinimap"))
    return value == "1"
end

local function pinTexture(frame, pool, index)
    local texture = pool[index]
    if not texture then
        texture = frame:CreateTexture(nil, "OVERLAY")
        texture:SetTexture(PIN_TEXTURE)
        pool[index] = texture
    end
    return texture
end

function Guide:CreateMinimapPins()
    if self.minimapPins or not Minimap then
        return
    end
    local frame = CreateFrame("Frame", nil, Minimap)
    frame:SetAllPoints(Minimap)
    frame:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 5)
    frame:EnableMouse(false)
    frame.textures = {}
    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + (delta or 0)
        if elapsed >= UPDATE_PERIOD then
            elapsed = 0
            self:UpdateMinimapPins()
        end
    end)
    self.minimapPins = frame
end

function Guide:UpdateMinimapPins()
    local frame = self.minimapPins
    if not frame then
        return
    end
    local points = self.pinPoints or {}
    local used, arrowShown = 0, false
    local instance, myNorth, myWest = Navigation.PlayerPosition()
    if instance and self.db.minimapPins and #points > 0 then
        local half = (Minimap:GetWidth() or 0) / 2
        local scale = half / minimapRadius()
        local square = minimapSquare()
        local facing = minimapRotates() and GetPlayerFacing() or nil
        if facing ~= nil and not usable(facing) then
            facing = nil
        end
        for _, pin in ipairs(points) do
            if pin.instance == instance then
                local x, y = Guide.MinimapOffset(pin.north - myNorth, pin.west - myWest, facing, scale)
                local size = pin.target and MINIMAP_TARGET_SIZE or MINIMAP_SIZE
                local _, _, shown = Guide.MinimapEdge(x, y, half - size / 2, square)
                if not shown and pin.target then
                    -- Cible hors de la minimap : une flèche dorée au bord, tournée vers elle.
                    local arrow = self.minimapArrow
                    if not arrow then
                        arrow = frame:CreateTexture(nil, "OVERLAY")
                        arrow:SetTexture(ARROW_TEXTURE)
                        arrow:SetSize(MINIMAP_ARROW_SIZE, MINIMAP_ARROW_SIZE)
                        arrow:SetVertexColor(COLORS.target[1], COLORS.target[2], COLORS.target[3])
                        self.minimapArrow = arrow
                    end
                    local ax, ay = Guide.MinimapEdge(x, y, half - MINIMAP_ARROW_SIZE / 2, square)
                    arrow:ClearAllPoints()
                    arrow:SetPoint("CENTER", frame, "CENTER", ax, ay)
                    arrow:SetRotation(math.atan2(-x, y))
                    arrow:Show()
                    arrowShown = true
                end
                if shown then
                    used = used + 1
                    local texture = pinTexture(frame, frame.textures, used)
                    texture:SetSize(size, size)
                    texture:ClearAllPoints()
                    texture:SetPoint("CENTER", frame, "CENTER", x, y)
                    local color = COLORS[pin.target and "target" or pin.kind] or COLORS.place
                    texture:SetVertexColor(color[1], color[2], color[3])
                    texture:Show()
                end
            end
        end
    end
    for index = used + 1, #frame.textures do
        frame.textures[index]:Hide()
    end
    if self.minimapArrow and not arrowShown then
        self.minimapArrow:Hide()
    end
end

---------------------------------------------------------------------------
-- Carte du monde
---------------------------------------------------------------------------

local bounds = {}   -- [uiMapID] = { instance, nord en haut à gauche, ouest, nord en bas à droite, ouest } ou false

-- Bornes d'une carte du client en coordonnées monde (nil si inconnues).
local function mapBounds(mapID)
    local known = bounds[mapID]
    if known == nil then
        known = false
        if C_Map.GetWorldPosFromMapPos and CreateVector2D then
            local instance, topLeft = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
            local _, bottomRight = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 1))
            if instance and topLeft and bottomRight then
                local north0, west0 = topLeft:GetXY()
                local north1, west1 = bottomRight:GetXY()
                if north0 ~= north1 and west0 ~= west1 then
                    known = { instance, north0, west0, north1, west1 }
                end
            end
        end
        bounds[mapID] = known
    end
    return known or nil
end

-- Position d'un point monde sur une carte (0 à 1), ou nil s'il n'y est pas.
function Guide.MapPosition(mapID, instance, north, west)
    local box = mapBounds(mapID)
    if not box or box[1] ~= instance then
        return nil
    end
    local x = (box[3] - west) / (box[3] - box[5])
    local y = (box[2] - north) / (box[2] - box[4])
    if x < 0 or x > 1 or y < 0 or y > 1 then
        return nil
    end
    return x, y
end

-- Fournisseur de données de la carte du monde : la carte l'appelle à chaque
-- changement de carte et de zoom.
function Guide:AttachWorldMap()
    if self.mapProvider then
        return true
    end
    local map = WorldMapFrame
    if not (map and map.AddDataProvider and map.GetCanvas and MapCanvasDataProviderMixin and CreateFromMixins) then
        return false
    end
    local provider = CreateFromMixins(MapCanvasDataProviderMixin)
    provider.RefreshAllData = function()
        ns.SafeCall(self.UpdateMapPins, self)
    end
    provider.RemoveAllData = function()
        ns.SafeCall(self.HideMapPins, self)
    end
    provider.OnCanvasScaleChanged = provider.RefreshAllData
    provider.OnCanvasSizeChanged = provider.RefreshAllData
    map:AddDataProvider(provider)
    self.mapProvider = provider
    self.mapButtons = {}
    return true
end

local function showTooltip(button)
    if button.label and GameTooltip then
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(button.label, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end
end

local function hideTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function mapButton(self, canvas, index)
    local button = self.mapButtons[index]
    if not button then
        button = CreateFrame("Button", nil, canvas)
        button.texture = button:CreateTexture(nil, "OVERLAY")
        button.texture:SetTexture(PIN_TEXTURE)
        button.texture:SetAllPoints()
        button:SetScript("OnEnter", showTooltip)
        button:SetScript("OnLeave", hideTooltip)
        self.mapButtons[index] = button
    end
    return button
end

function Guide:HideMapPins()
    for _, button in ipairs(self.mapButtons or {}) do
        button:Hide()
    end
end

function Guide:UpdateMapPins()
    local map = WorldMapFrame
    if not (self.mapProvider and map and map:IsShown()) then
        return
    end
    local used = 0
    local mapID = map:GetMapID()
    if self.enabled and self.db.mapPins and mapID then
        local canvas = map:GetCanvas()
        local width, height = canvas:GetWidth(), canvas:GetHeight()
        local canvasScale = map.GetCanvasScale and map:GetCanvasScale() or 1
        if not (canvasScale and canvasScale > 0) then
            canvasScale = 1
        end
        for _, pin in ipairs(self.pinPoints or {}) do
            local x, y = Guide.MapPosition(mapID, pin.instance, pin.north, pin.west)
            if x then
                used = used + 1
                local button = mapButton(self, canvas, used)
                local size = (pin.target and MAP_TARGET_SIZE or MAP_SIZE) / canvasScale
                button:SetSize(size, size)
                button:ClearAllPoints()
                button:SetPoint("CENTER", canvas, "TOPLEFT", x * width, -y * height)
                button:SetFrameLevel(canvas:GetFrameLevel() + (pin.target and 2001 or 2000))
                local color = COLORS[pin.target and "target" or pin.kind] or COLORS.place
                button.texture:SetVertexColor(color[1], color[2], color[3])
                button.label = self:PinLabel(pin)
                button:Show()
            end
        end
    end
    for index = used + 1, #self.mapButtons do
        self.mapButtons[index]:Hide()
    end
end

---------------------------------------------------------------------------
-- Mise à jour
---------------------------------------------------------------------------

function Guide:CreatePins()
    self:CreateMinimapPins()
    if not self:AttachWorldMap() then
        -- Carte du monde chargée à la demande : on attend son chargement.
        self:RegisterEvent("ADDON_LOADED", function(_, _, name)
            if name == "Blizzard_WorldMap" and self:AttachWorldMap() then
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end

-- Nouveau résultat ou nouvelle cible : points recalculés, repères redessinés.
function Guide:UpdatePins()
    self.pinPoints = self.enabled and self:PinPoints(self.result) or {}
    if self.minimapPins then
        self.minimapPins:SetShown(self.enabled and self.db.minimapPins)
        self:UpdateMinimapPins()
    end
    if self.mapProvider then
        self:UpdateMapPins()
    end
end

function Guide:HidePins()
    self.pinPoints = {}
    if self.minimapPins then
        self.minimapPins:Hide()
    end
    self:HideMapPins()
end

function Guide:SetMinimapPinsShown(shown)
    self.db.minimapPins = shown
    self:UpdatePins()
end

function Guide:SetMapPinsShown(shown)
    self.db.mapPins = shown
    self:UpdatePins()
end
