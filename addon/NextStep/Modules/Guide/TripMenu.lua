-- Bouton des voyages au bord de la minimap (docs/DESIGN.md, « Voyages ») : un clic
-- ouvre la liste des destinations, Kalimdor et les Royaumes de l'Est à part, rangées
-- par zone : villes (auberges), points de vol (connus ou non), quais, centre de la zone.
-- Le choix lance le voyage (Trip.lua), comme un Ctrl+clic sur la carte du monde.
--
--   clic gauche : destinations ; clic droit : annule le voyage en cours ;
--   glisser : déplace le bouton autour de la minimap (position mémorisée).

local _, ns = ...
local L = ns.L

local Guide = ns.Modules:Get("Guide")

local ICON = "Interface\\Minimap\\Tracking\\FlightMaster"
local BORDER = "Interface\\Minimap\\MiniMap-TrackingBorder"
local SIZE = 25
local MENU_HEIGHT = 520   -- pixels : au-delà, la liste défile

-- Continents : instance du monde, carte du client.
local CONTINENTS = {
    { instance = 1, map = 1414, name = "Kalimdor" },
    { instance = 0, map = 1415, name = "Eastern Kingdoms" },
}
Guide.TRIP_CONTINENTS = CONTINENTS

local function mapName(map)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    return info and type(info.name) == "string" and info.name ~= "" and info.name or nil
end

local function areaName(area)
    if area and area > 0 and C_Map and C_Map.GetAreaInfo then
        local name = C_Map.GetAreaInfo(area)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
end

-- Destinations d'un continent : { { map, name, places = { { text, point, kind } } } },
-- zones et lieux triés par nom.
function Guide:TripDestinations(instance)
    local data = self:TravelData()
    local places = self:TripPlaces()
    if not (data and places) then
        return {}
    end
    local zones, list = {}, {}
    local function zone(map)
        if not zones[map] then
            local name = mapName(map)
            if not name then
                return nil
            end
            zones[map] = { map = map, name = name, places = {}, seen = {} }
            list[#list + 1] = zones[map]
        end
        return zones[map]
    end
    local function add(map, text, point, kind)
        local entry = zone(map)
        if entry and not entry.seen[text] then
            entry.seen[text] = true
            entry.places[#entry.places + 1] = { text = text, point = point, kind = kind }
        end
    end
    -- Toutes les zones du continent, même sans ville ni point de vol.
    local continent
    for _, c in ipairs(CONTINENTS) do
        if c.instance == instance then
            continent = c
        end
    end
    local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone
    if continent and zoneType and C_Map and C_Map.GetMapChildrenInfo then
        for _, child in ipairs(C_Map.GetMapChildrenInfo(continent.map, zoneType) or {}) do
            zone(child.mapID)
        end
    end
    -- Villes : les auberges.
    for _, inn in ipairs(data.inns or {}) do
        if inn.c == instance then
            local name = areaName(inn.area) or (inn.names and L[inn.names[1]])
            if name then
                add(inn.map, name, { map = inn.map, x = inn.x, y = inn.y, f = inn.f == "e" and "e" or nil }, "town")
            end
        end
    end
    -- Points de vol de la faction, connus ou non.
    local known = self.char.taxi or {}
    for id, place in pairs(places.taxi) do
        if place.instance == instance then
            local name = self:TripPlaceName(place)
            local text = known[id] and L["Flight point: %s"]:format(name)
                or L["Flight point: %s (not discovered)"]:format(name)
            add(place.map, text, { map = place.map, x = place.x, y = place.y, f = place.f },
                known[id] and "taxi" or "unknown")
        end
    end
    -- Quais des bateaux, zeppelins et du tram de la faction.
    for _, place in ipairs(places.list) do
        if place.kind == "dock" and place.instance == instance then
            add(place.map, L["Dock: %s"]:format(self:TripPlaceName(place)),
                { map = place.map, x = place.x, y = place.y, f = place.f }, "dock")
        end
    end
    local order = { town = 1, taxi = 2, unknown = 3, dock = 4 }
    for _, entry in ipairs(list) do
        table.sort(entry.places, function(a, b)
            if order[a.kind] ~= order[b.kind] then
                return order[a.kind] < order[b.kind]
            end
            return a.text < b.text
        end)
        entry.seen = nil
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local KIND_COLORS = { unknown = "|cff999999", dock = "|cff66bbff" }

-- Remplit le menu (root : description de MenuUtil).
function Guide:FillTripMenu(root)
    root:CreateTitle(L["Trip: choose a destination"])
    if self.trip then
        root:CreateButton(L["Cancel the trip to %s"]:format(self.trip.label), function()
            self:EndTrip(false)
        end)
    end
    for _, continent in ipairs(CONTINENTS) do
        local label = mapName(continent.map) or L[continent.name]
        local sub = root:CreateButton(label)
        if sub.SetScrollMode then
            pcall(sub.SetScrollMode, sub, MENU_HEIGHT)
        end
        for _, zone in ipairs(self:TripDestinations(continent.instance)) do
            local zoneButton = sub:CreateButton(zone.name)
            for _, place in ipairs(zone.places) do
                local color = KIND_COLORS[place.kind]
                local text = color and (color .. place.text .. "|r") or place.text
                zoneButton:CreateButton(text, function()
                    local name = place.kind == "town" and place.text or ("%s, %s"):format(place.text, zone.name)
                    self:StartTrip(place.point, name)
                end)
            end
            zoneButton:CreateButton(L["Zone centre"], function()
                self:StartTrip({ map = zone.map, x = 50, y = 50 }, zone.name)
            end)
        end
    end
end

function Guide:OpenTripMenu(owner)
    if not self:TravelData() then
        ns:Print(L["Trips need the NextStep - Nav addon: enable it, then restart the game."])
        return
    end
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner or UIParent, function(_, root)
            self:FillTripMenu(root)
        end)
    else
        self:ChooseTripDestination()
    end
end

---------------------------------------------------------------------------
-- Bouton
---------------------------------------------------------------------------

local function buttonOffset(angle)
    local menu = ns.Modules:Get("AddonsMenu")
    local half = (Minimap:GetWidth() or 140) / 2
    local isSquare = GetMinimapShape ~= nil and GetMinimapShape() == "SQUARE"
    if menu and menu.ButtonOffset then
        return menu.ButtonOffset(angle, half, isSquare)
    end
    local radians = math.rad(angle)
    return math.cos(radians) * (half + 10), math.sin(radians) * (half + 10)
end

function Guide:PlaceTripButton()
    local button = self.tripButton
    if button then
        local x, y = buttonOffset(self.db.tripButtonAngle or 200)
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
end

function Guide:UpdateTripButton()
    if self.tripButton then
        self.tripButton:SetShown(self.enabled and self.db.tripButton ~= false)
    end
end

function Guide:CreateTripButton()
    if self.tripButton or not Minimap then
        self:UpdateTripButton()
        return
    end
    local button = CreateFrame("Button", "NextStepTripButton", Minimap)
    button:SetSize(SIZE, SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture(ICON)
    icon:SetSize(16, 16)
    icon:SetPoint("TOPLEFT", 5, -4)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture(BORDER)
    border:SetSize(43, 43)
    border:SetPoint("TOPLEFT")
    button:SetScript("OnClick", function(frame, mouse)
        if mouse == "RightButton" then
            if self.trip then
                self:EndTrip(false)
            end
        else
            self:OpenTripMenu(frame)
        end
    end)
    button:SetScript("OnEnter", function(frame)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
        GameTooltip:SetText(L["NextStep trips"])
        if self.trip then
            GameTooltip:AddLine(L["Trip to %s"]:format(self.trip.label), 0.35, 0.75, 1)
        end
        GameTooltip:AddLine(L["Click: choose a destination"], 1, 1, 1)
        GameTooltip:AddLine(L["Or Ctrl+click on the world map"], 1, 1, 1)
        if self.trip then
            GameTooltip:AddLine(L["Right-click: cancel the trip"], 1, 1, 1)
        end
        GameTooltip:AddLine(L["Drag: move the button"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    button:SetScript("OnDragStart", function(frame)
        if GameTooltip then
            GameTooltip:Hide()
        end
        frame:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            local cx, cy = Minimap:GetCenter()
            self.db.tripButtonAngle = math.deg(math.atan2(y / scale - cy, x / scale - cx)) % 360
            self:PlaceTripButton()
        end)
    end)
    button:SetScript("OnDragStop", function(frame)
        frame:SetScript("OnUpdate", nil)
    end)
    self.tripButton = button
    self:PlaceTripButton()
    self:UpdateTripButton()
end
