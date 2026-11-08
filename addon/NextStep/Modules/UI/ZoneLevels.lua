-- Niveau des zones (docs/DESIGN.md, « Niveau des zones ») : sur la carte du monde, la
-- tranche de niveaux d'une zone s'affiche à côté de son nom au survol (carte d'un
-- continent), et sous le titre quand la carte d'une zone est ouverte. Couleur selon le
-- niveau du personnage : rouge ou orange au-dessus, jaune ou vert dedans, gris en dessous.
--
-- Tranches, dans l'ordre : guides de leveling chargés (propres à Forever, union de leurs
-- tranches par zone), C_Map.GetMapLevels si le client la connaît, puis les tranches du
-- Classic ci-dessous.
--
-- Sans souillure : hooksecurefunc sur l'étiquette de zone de la carte et sur son
-- changement de carte ; les textes sont des régions de NextStep.
--
-- [À vérifier] sur Forever : fournisseur de l'étiquette des zones (Label:SetLabel /
-- ClearLabel) ; C_Map.GetMapLevels.

local _, ns = ...
local L = ns.L

local ZoneLevels = ns.Modules:New("ZoneLevels", {
    title = L["Zone levels"],
    description = L["Shows each zone's level range on the world map."],
    conflicts = { "Leatrix_Maps", "Mapster" },
})

-- Tranches du Classic, par carte du client (uiMapID).
local CLASSIC = {
    [1411] = { 1, 10 }, [1412] = { 1, 10 }, [1413] = { 10, 25 }, [1416] = { 30, 40 }, [1417] = { 30, 40 },
    [1418] = { 35, 45 }, [1419] = { 45, 55 }, [1420] = { 1, 10 }, [1421] = { 10, 20 }, [1422] = { 51, 58 },
    [1423] = { 53, 60 }, [1424] = { 20, 30 }, [1425] = { 40, 50 }, [1426] = { 1, 10 }, [1427] = { 43, 50 },
    [1428] = { 50, 58 }, [1429] = { 1, 10 }, [1430] = { 55, 60 }, [1431] = { 18, 30 }, [1432] = { 10, 20 },
    [1433] = { 15, 25 }, [1434] = { 30, 45 }, [1435] = { 35, 45 }, [1436] = { 10, 20 }, [1437] = { 20, 30 },
    [1438] = { 1, 10 }, [1439] = { 10, 20 }, [1440] = { 18, 30 }, [1441] = { 25, 35 }, [1442] = { 15, 27 },
    [1443] = { 30, 40 }, [1444] = { 40, 50 }, [1445] = { 35, 45 }, [1446] = { 40, 50 }, [1447] = { 45, 55 },
    [1448] = { 48, 55 }, [1449] = { 48, 55 }, [1451] = { 55, 60 }, [1452] = { 55, 60 },
}
ZoneLevels.CLASSIC = CLASSIC

local COLORS = {
    high = { 1, 0.25, 0.1 }, hard = { 1, 0.5, 0.25 }, normal = { 1, 0.82, 0 }, easy = { 0.25, 0.75, 0.25 },
    low = { 0.55, 0.55, 0.55 },
}

-- Tranches tirées des guides de leveling : [uiMapID] = { min, max }.
function ZoneLevels:FromGuides()
    local ranges = {}
    for _, guide in ns.DB:IterateGuides() do
        if guide.category == "Leveling" and guide.zone and guide.minLevel and guide.maxLevel then
            local range = ranges[guide.zone]
            if range then
                range[1] = math.min(range[1], guide.minLevel)
                range[2] = math.max(range[2], guide.maxLevel)
            else
                ranges[guide.zone] = { guide.minLevel, guide.maxLevel }
            end
        end
    end
    return ranges
end

-- Tranche d'une carte : min, max (nil si inconnue).
function ZoneLevels:Range(map)
    if not map then
        return nil
    end
    self.guideRanges = self.guideRanges or self:FromGuides()
    local range = self.guideRanges[map]
    if range then
        return range[1], range[2]
    end
    if C_Map and C_Map.GetMapLevels then
        local ok, low, high = pcall(C_Map.GetMapLevels, map)
        if ok and ns.Usable(low) and type(low) == "number" and low > 0 and ns.Usable(high) then
            return low, high
        end
    end
    range = CLASSIC[map]
    if range then
        return range[1], range[2]
    end
end

-- Couleur de la tranche pour un personnage de niveau level.
function ZoneLevels.Color(low, high, level)
    if level < low - 2 then
        return COLORS.high
    elseif level < low then
        return COLORS.hard
    elseif level <= high - 3 then
        return COLORS.normal
    elseif level <= high then
        return COLORS.easy
    end
    return COLORS.low
end

-- « (10-20) » coloré, ou nil.
function ZoneLevels:Text(map)
    local low, high = self:Range(map)
    if not low then
        return nil
    end
    local level = tonumber(ns.Usable(UnitLevel("player")) and UnitLevel("player")) or 1
    local color = ZoneLevels.Color(low, high, level)
    local text = low == high and tostring(low) or ("%d-%d"):format(low, high)
    return ("|cff%02x%02x%02x(%s)|r"):format(color[1] * 255, color[2] * 255, color[3] * 255, text)
end

-- Carte d'une zone d'après son nom (localisé), parmi les cartes connues.
function ZoneLevels:MapByName(name)
    if not self.byName then
        self.byName = {}
        local maps = {}
        for map in pairs(CLASSIC) do
            maps[map] = true
        end
        for map in pairs(self.guideRanges or self:FromGuides()) do
            maps[map] = true
        end
        for map in pairs(maps) do
            local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
            if info and ns.Usable(info.name) and info.name then
                self.byName[info.name] = map
            end
        end
    end
    return self.byName[name]
end

---------------------------------------------------------------------------
-- Carte du monde
---------------------------------------------------------------------------

-- Étiquette de zone survolée : le texte de NextStep s'affiche juste à droite du nom.
function ZoneLevels:OnAreaLabel(label, name)
    local text = self.enabled and type(name) == "string" and ns.Usable(name)
        and self:Text(self:MapByName(name))
    if not self.hoverText then
        self.hoverText = self.owner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    end
    local region = label.Name or label
    self.hoverText:ClearAllPoints()
    self.hoverText:SetPoint("LEFT", region, "RIGHT", 6, 0)
    self.hoverText:SetText(text or "")
    self.hoverText:SetShown(text ~= nil)
end

-- Carte d'une zone ouverte : sa tranche en haut de la carte.
function ZoneLevels:OnMapChanged()
    local map = WorldMapFrame and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    local text = self.enabled and self:Text(map)
    if not self.titleText then
        self.titleText = self.owner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        self.titleText:SetPoint("TOP", self.owner, "TOP", 0, -12)
    end
    self.titleText:SetText(text and L["Levels %s"]:format(text) or "")
    self.titleText:SetShown(text ~= nil and text ~= false)
    if self.hoverText then
        self.hoverText:Hide()
    end
end

function ZoneLevels:Attach()
    if self.attached then
        return true
    end
    local map = WorldMapFrame
    if not (map and map.ScrollContainer) then
        return false
    end
    self.owner = CreateFrame("Frame", nil, map.ScrollContainer)
    self.owner:SetAllPoints()
    self.owner:SetFrameLevel((map.ScrollContainer:GetFrameLevel() or 1) + 20)
    for provider in pairs(map.dataProviders or {}) do
        local label = type(provider) == "table" and provider.Label
        if label and label.SetLabel and not self.hookedLabel then
            self.hookedLabel = true
            hooksecurefunc(label, "SetLabel", function(frame, _, name)
                ns.SafeCall(self.OnAreaLabel, self, frame, name)
            end)
            if label.ClearLabel then
                hooksecurefunc(label, "ClearLabel", function()
                    if self.hoverText then
                        self.hoverText:Hide()
                    end
                end)
            end
        end
    end
    if map.OnMapChanged then
        hooksecurefunc(map, "OnMapChanged", function()
            ns.SafeCall(self.OnMapChanged, self)
        end)
    end
    self.attached = true
    return true
end

function ZoneLevels:OnEnable()
    if not self:Attach() then
        self:RegisterEvent("ADDON_LOADED", function(_, _, name)
            if name == "Blizzard_WorldMap" and self:Attach() then
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
    -- Les guides d'une faction se chargent après le cœur : tranches recalculées.
    self.guideRanges, self.byName = nil, nil
    if self.attached then
        self:OnMapChanged()
    end
end

function ZoneLevels:OnDisable()
    if self.hoverText then
        self.hoverText:Hide()
    end
    if self.titleText then
        self.titleText:Hide()
    end
end
