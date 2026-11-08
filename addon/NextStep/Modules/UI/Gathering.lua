-- Points de récolte (docs/DESIGN.md, « Points de récolte ») : chaque herbe cueillie,
-- chaque filon miné et chaque coffre ouvert est retenu (position monde, nom, type),
-- au niveau du compte ; les points très proches du même nom sont fusionnés. Ils
-- s'affichent sur la minimap et la carte du monde, filtrables par type.
--
-- Détection : UNIT_SPELLCAST_SENT donne le nom de l'objet ciblé et le sort lancé
-- (Cueillette, Minage, Ouverture), UNIT_SPELLCAST_SUCCEEDED confirme la récolte ; la
-- position est celle du joueur à ce moment (UnitPosition). Idée de GatherMate2 (GPL-2.0
-- ou ultérieure), code propre à NextStep ; aucune donnée reprise, rien n'est envoyé.
--
-- [À vérifier] sur Forever : arguments de UNIT_SPELLCAST_SENT (nom de la cible), sorts
-- de récolte, UnitPosition hors instance.

local _, ns = ...
local L = ns.L

local Gathering = ns.Modules:New("Gathering", {
    title = L["Gathering nodes"],
    description = L["Remembers every herb, ore vein and chest you gather, and shows them on the minimap "
        .. "and the world map."],
    defaults = {
        show = { herb = true, ore = true, treasure = true },
        minimap = true,
        worldMap = true,
        nodes = {},   -- [instance] = { { n = nord, w = ouest, name, kind, count } }
    },
})

local Guide = ns.Modules:Get("Guide")
local Navigation = ns.Navigation

-- Sort de récolte -> type ; le nom du sort (traduit par le client) sert à reconnaître
-- tous ses rangs.
local SPELLS = { [2366] = "herb", [2575] = "ore", [3365] = "treasure" }
local ICONS = {
    herb = "Interface\\Icons\\INV_Misc_Flower_02",
    ore = "Interface\\Icons\\INV_Ore_Copper_01",
    treasure = "Interface\\Icons\\INV_Box_01",
}
local MERGE_YARDS = 15
local MINIMAP_SIZE, MAP_SIZE = 12, 14
local UPDATE_PERIOD = 0.1
local MAX_MINIMAP = 60

---------------------------------------------------------------------------
-- Enregistrement
---------------------------------------------------------------------------

-- Type de récolte d'un sort (identifiant ou nom), ou nil.
function Gathering:KindOf(spellID)
    if SPELLS[spellID] then
        return SPELLS[spellID]
    end
    if not self.spellNames then
        self.spellNames = {}
        for id, kind in pairs(SPELLS) do
            local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
            if name then
                self.spellNames[name] = kind
            end
        end
    end
    local name = spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    return name and self.spellNames[name]
end

-- Ajoute (ou renforce) un point : renvoie le point.
function Gathering:Record(instance, north, west, name, kind)
    if not (instance and north and west and name and kind) then
        return nil
    end
    local list = self.db.nodes[instance]
    if not list then
        list = {}
        self.db.nodes[instance] = list
    end
    for _, node in ipairs(list) do
        local dn, dw = node.n - north, node.w - west
        if node.name == name and dn * dn + dw * dw <= MERGE_YARDS * MERGE_YARDS then
            node.count = (node.count or 1) + 1
            return node
        end
    end
    local node = { n = math.floor(north * 10 + 0.5) / 10, w = math.floor(west * 10 + 0.5) / 10, name = name,
        kind = kind, count = 1 }
    list[#list + 1] = node
    return node
end

function Gathering:OnCastSent(unit, target, castGUID, spellID)
    if unit ~= "player" then
        return
    end
    local kind = self:KindOf(spellID)
    if kind and ns.Usable(target) and type(target) == "string" and target ~= "" then
        self.pending = { guid = castGUID, name = target, kind = kind }
    else
        self.pending = nil
    end
end

function Gathering:OnCastSucceeded(unit, castGUID)
    local pending = self.pending
    if unit ~= "player" or not pending or (pending.guid and castGUID and pending.guid ~= castGUID) then
        return
    end
    self.pending = nil
    local instance, north, west = Navigation.PlayerPosition()
    if self:Record(instance, north, west, pending.name, pending.kind) then
        self:UpdateMapPins()
    end
end

-- Points visibles d'une instance (filtre par type).
function Gathering:Visible(instance)
    local list = {}
    for _, node in ipairs(self.db.nodes[instance] or {}) do
        if self.db.show[node.kind] then
            list[#list + 1] = node
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Minimap
---------------------------------------------------------------------------

local function icon(parent, pool, index, size)
    local texture = pool[index]
    if not texture then
        texture = parent:CreateTexture(nil, "OVERLAY")
        texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        pool[index] = texture
    end
    texture:SetSize(size, size)
    return texture
end

function Gathering:UpdateMinimap()
    local frame = self.minimapFrame
    if not frame then
        return
    end
    local used = 0
    local instance, myNorth, myWest = Navigation.PlayerPosition()
    if self.enabled and self.db.minimap and instance and Guide and Guide.MinimapRadius then
        local half = (Minimap:GetWidth() or 0) / 2
        local radius = Guide.MinimapRadius()
        local scale = half / radius
        local square = Guide.MinimapSquare()
        local facing = Guide.MinimapRotates() and GetPlayerFacing() or nil
        if facing ~= nil and not ns.Usable(facing) then
            facing = nil
        end
        for _, node in ipairs(self:Visible(instance)) do
            local dn, dw = node.n - myNorth, node.w - myWest
            if used < MAX_MINIMAP and math.abs(dn) <= radius * 1.5 and math.abs(dw) <= radius * 1.5 then
                local x, y = Guide.MinimapOffset(dn, dw, facing, scale)
                local _, _, inside = Guide.MinimapEdge(x, y, half - MINIMAP_SIZE / 2, square)
                if inside then
                    used = used + 1
                    local texture = icon(frame, frame.icons, used, MINIMAP_SIZE)
                    texture:SetTexture(ICONS[node.kind])
                    texture:ClearAllPoints()
                    texture:SetPoint("CENTER", frame, "CENTER", x, y)
                    texture:Show()
                end
            end
        end
    end
    for index = used + 1, #frame.icons do
        frame.icons[index]:Hide()
    end
end

function Gathering:CreateMinimapFrame()
    if self.minimapFrame or not Minimap then
        return
    end
    local frame = CreateFrame("Frame", nil, Minimap)
    frame:SetAllPoints()
    frame:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 4)
    frame.icons = {}
    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + (delta or 0)
        if elapsed >= UPDATE_PERIOD then
            elapsed = 0
            ns.SafeCall(self.UpdateMinimap, self)
        end
    end)
    self.minimapFrame = frame
end

---------------------------------------------------------------------------
-- Carte du monde
---------------------------------------------------------------------------

function Gathering:AttachWorldMap()
    if self.mapProvider then
        return true
    end
    local map = WorldMapFrame
    if not (map and map.AddDataProvider and map.GetCanvas and MapCanvasDataProviderMixin and CreateFromMixins) then
        return false
    end
    local provider = CreateFromMixins(MapCanvasDataProviderMixin)
    provider.RefreshAllData = function() ns.SafeCall(self.UpdateMapPins, self) end
    provider.RemoveAllData = function() self:HideMapPins() end
    provider.OnCanvasScaleChanged = provider.RefreshAllData
    provider.OnCanvasSizeChanged = provider.RefreshAllData
    map:AddDataProvider(provider)
    self.mapProvider = provider
    self.mapButtons = {}
    return true
end

function Gathering:HideMapPins()
    for _, button in ipairs(self.mapButtons or {}) do
        button:Hide()
    end
end

function Gathering:UpdateMapPins()
    local map = WorldMapFrame
    if not (self.mapProvider and map and map:IsShown()) then
        return
    end
    local used = 0
    local mapID = map:GetMapID()
    if self.enabled and self.db.worldMap and mapID and Guide and Guide.MapPosition then
        local canvas = map:GetCanvas()
        local width, height = canvas:GetWidth(), canvas:GetHeight()
        local scale = map.GetCanvasScale and map:GetCanvasScale() or 1
        if not (scale and scale > 0) then
            scale = 1
        end
        for instance in pairs(self.db.nodes) do
            for _, node in ipairs(self:Visible(instance)) do
                local x, y = Guide.MapPosition(mapID, instance, node.n, node.w)
                if x then
                    used = used + 1
                    local button = self.mapButtons[used]
                    if not button then
                        button = CreateFrame("Frame", nil, canvas)
                        button.texture = button:CreateTexture(nil, "OVERLAY")
                        button.texture:SetAllPoints()
                        button.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                        button:EnableMouse(true)
                        button:SetScript("OnEnter", function(frame)
                            if GameTooltip and frame.node then
                                GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
                                GameTooltip:SetText(frame.node.name)
                                GameTooltip:AddLine(L["Gathered %d times"]:format(frame.node.count or 1), 1, 1, 1)
                                GameTooltip:Show()
                            end
                        end)
                        button:SetScript("OnLeave", function()
                            if GameTooltip then
                                GameTooltip:Hide()
                            end
                        end)
                        self.mapButtons[used] = button
                    end
                    button.node = node
                    button.texture:SetTexture(ICONS[node.kind])
                    button:SetSize(MAP_SIZE / scale, MAP_SIZE / scale)
                    button:ClearAllPoints()
                    button:SetPoint("CENTER", canvas, "TOPLEFT", x * width, -y * height)
                    button:SetFrameLevel(canvas:GetFrameLevel() + 1500)
                    button:Show()
                end
            end
        end
    end
    for index = used + 1, #self.mapButtons do
        self.mapButtons[index]:Hide()
    end
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function Gathering:Count()
    local total = 0
    for _, list in pairs(self.db.nodes) do
        total = total + #list
    end
    return total
end

function Gathering:OnEnable()
    self:CreateMinimapFrame()
    if not self:AttachWorldMap() then
        self:RegisterEvent("ADDON_LOADED", function(_, _, name)
            if name == "Blizzard_WorldMap" and self:AttachWorldMap() then
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
    self:RegisterEvent("UNIT_SPELLCAST_SENT", function(_, _, unit, target, castGUID, spellID)
        self:OnCastSent(unit, target, castGUID, spellID)
    end)
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, _, unit, castGUID)
        self:OnCastSucceeded(unit, castGUID)
    end)
    for _, event in ipairs({ "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
        self:RegisterEvent(event, function(_, _, unit)
            if unit == "player" then
                self.pending = nil
            end
        end)
    end
end

function Gathering:OnDisable()
    self:HideMapPins()
    if self.minimapFrame then
        for _, texture in ipairs(self.minimapFrame.icons) do
            texture:Hide()
        end
    end
end

function Gathering:BuildOptions(panel, anchor)
    local Options = ns.Options
    local below = Options.AddCheck(panel, anchor, L["Show gathering nodes on the minimap"],
        function() return self.db.minimap end,
        function(value) self.db.minimap = value end)
    below = Options.AddCheck(panel, below, L["Show gathering nodes on the world map"],
        function() return self.db.worldMap end,
        function(value) self.db.worldMap = value; self:UpdateMapPins() end)
    for _, kind in ipairs({ "herb", "ore", "treasure" }) do
        local label = ({ herb = L["Herbs"], ore = L["Ore veins"], treasure = L["Chests"] })[kind]
        below = Options.AddCheck(panel, below, label,
            function() return self.db.show[kind] end,
            function(value) self.db.show[kind] = value; self:UpdateMapPins() end)
    end
    return below
end
