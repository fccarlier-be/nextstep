-- Carte des donjons (docs/DESIGN.md, « Carte des donjons ») : en donjon, la carte du
-- monde s'ouvre sur l'étage du donjon, avec les boss, les boss rares, l'entrée, les
-- passages d'étage et les PNJ de quêtes (positions de DungeonJournal, importées dans
-- DB.dungeonMaps).
--
-- La carte native reste en place : sur un étage qui a une carte du client, le client y
-- dessine lui-même les membres du groupe, et NextStep ajoute ses repères par un
-- fournisseur de données, sous ceux du groupe. Un étage sans carte du client (donjons
-- propres à Forever) s'affiche sur un panneau posé sur la carte, avec l'image de
-- DungeonJournal (lue dans son dossier, s'il est installé) : le groupe n'y apparaît pas.
--
-- [À vérifier] sur Forever : membres du groupe dessinés par la carte native en donjon ;
-- SetMapID sans souillure à l'ouverture de la carte ; chemins des images de
-- DungeonJournal lisibles par un autre addon ; ENCOUNTER_END (numéro de rencontre)
-- pour les boss classiques et ceux de Forever.

local _, ns = ...
local L = ns.L

local DungeonMap = ns.Modules:New("DungeonMap", {
    title = L["Dungeon map"],
    description = L["In a dungeon, the world map opens on the dungeon's map, with bosses, rare bosses, "
        .. "quest NPCs, the entrance and the ways between levels. Group members stay on the map."],
    defaults = {
        autoOpen = true,   -- carte du donjon à l'ouverture de la carte du monde
        rares = true,      -- boss rares
        quests = true,     -- PNJ de quêtes et marques de quête
    },
    charDefaults = {
        killed = {},       -- { instance = instanceID, names = { [nom] = true } }
    },
})

local ICONS = {
    boss = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull",
    rare = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1",
    turnin = "Interface\\GossipFrame\\ActiveQuestIcon",
    quest = "Interface\\GossipFrame\\AvailableQuestIcon",
    arrow = "Interface\\AddOns\\NextStep\\Media\\Arrow",
}
local SIZES = { boss = 22, rare = 18, turnin = 18, entrance = 20, transition = 20 }
local COLORS = {
    boss = { 1, 0.82, 0.2 }, killed = { 0.45, 0.45, 0.45 }, rare = { 0.85, 0.9, 1 },
    entrance = { 0.3, 1, 0.3 }, transition = { 0.3, 1, 0.3 },
}
local PIN_LEVEL = 1500        -- au-dessus de la carte, sous les membres du groupe
local IMAGE_ASPECT = 1002 / 668

---------------------------------------------------------------------------
-- Données
---------------------------------------------------------------------------

-- Cherche un étage de DB.dungeonMaps : key, aile, étage pour une carte du client.
function DungeonMap.FloorOfMap(mapID)
    if not mapID then
        return nil
    end
    for key, wings in pairs(ns.DB.dungeonMaps or {}) do
        for wingIndex, wing in ipairs(wings) do
            for floorIndex, floor in ipairs(wing.floors) do
                if floor.map == mapID then
                    return key, wingIndex, floorIndex
                end
            end
        end
    end
end

local function dungeonName(dungeon)
    local name = C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(dungeon.area)
    return ns.Usable(name) and name ~= "" and name or nil
end

-- Donjon où se trouve le personnage : key, aile, étage (étage nil s'il est inconnu).
-- Par la carte du client, puis l'instance, puis le nom (localisé, ou anglais).
function DungeonMap:Current()
    if not (IsInInstance and GetInstanceInfo) then
        return nil
    end
    local inside, kind = IsInInstance()
    if not inside or (kind ~= "party" and kind ~= "raid") then
        return nil
    end
    local best = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local key, wingIndex, floorIndex = DungeonMap.FloorOfMap(ns.Usable(best) and best or nil)
    if key then
        return key, wingIndex, floorIndex
    end
    local name, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    local maps = ns.DB.dungeonMaps or {}
    for _, dungeon in ipairs(ns.DB.dungeons or {}) do
        if maps[dungeon.key] and ((dungeon.instance and dungeon.instance == instanceID)
            or (ns.Usable(name) and name == dungeonName(dungeon))) then
            return dungeon.key, 1, nil
        end
    end
    if ns.Usable(name) then
        for mapKey, wings in pairs(maps) do
            for index, wing in ipairs(wings) do
                if wing.name == name then
                    return mapKey, index, nil
                end
            end
        end
    end
end

local function dungeonOf(key)
    for _, dungeon in ipairs(ns.DB.dungeons or {}) do
        if dungeon.key == key then
            return dungeon
        end
    end
end

-- Nom d'un boss dans la langue du client.
function DungeonMap.BossName(boss)
    return boss.npc and ns.DB:GetName("npc", boss.npc) or boss.name
end

-- Boss tués dans l'instance en cours (mémorisés par personnage, oubliés dans une autre).
function DungeonMap:Killed()
    local instanceID = GetInstanceInfo and select(8, GetInstanceInfo())
    local killed = self.char.killed
    if killed.instance ~= instanceID or not killed.names then
        killed.instance, killed.names = instanceID, {}
    end
    return killed.names
end

function DungeonMap:IsKilled(boss)
    local names = self:Killed()
    return names[boss.name] or names[DungeonMap.BossName(boss)] or false
end

-- Boss de la carte par numéro de rencontre (DungeonJournal) : liste de boss.
local byEncounter
function DungeonMap.BossesOfEncounter(encounterID)
    if not byEncounter then
        byEncounter = {}
        for _, wings in pairs(ns.DB.dungeonMaps or {}) do
            for _, wing in ipairs(wings) do
                for _, boss in ipairs(wing.bosses) do
                    for _, id in ipairs(boss.encounters or {}) do
                        byEncounter[id] = byEncounter[id] or {}
                        table.insert(byEncounter[id], boss)
                    end
                end
            end
        end
    end
    return byEncounter[encounterID] or {}
end

-- Un boss tué est reconnu par son numéro de rencontre, le même dans toutes les langues
-- du client ; le nom donné par l'événement sert pour les boss sans numéro connu.
function DungeonMap:OnEncounterEnd(_, encounterID, name, _, _, success)
    if success ~= 1 then
        return
    end
    local names = self:Killed()
    if ns.Usable(encounterID) then
        for _, boss in ipairs(DungeonMap.BossesOfEncounter(encounterID)) do
            names[boss.name] = true
        end
    end
    if ns.Usable(name) and name then
        names[name] = true
    end
    self:Refresh()
end

-- Quêtes du journal qui visent un boss (d'après DungeonJournal).
local function questsInLog(boss)
    local list = {}
    for _, quest in ipairs(boss.quests or {}) do
        local inLog = C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(quest)
        if inLog then
            list[#list + 1] = quest
        end
    end
    return list
end

-- Repères d'un étage : { kind, x, y, label, boss, to } dans l'ordre d'affichage.
function DungeonMap:Points(wing, floorIndex)
    local points = {}
    for _, entrance in ipairs(wing.entrances or {}) do
        if entrance[1] == floorIndex then
            points[#points + 1] = { kind = "entrance", x = entrance[2], y = entrance[3], label = L["Entrance"] }
        end
    end
    for _, step in ipairs(wing.transitions or {}) do
        if step[1] == floorIndex then
            local target = wing.floors[step[2]]
            points[#points + 1] = { kind = "transition", x = step[3], y = step[4], to = step[2],
                label = L["Way to %s"]:format(target and target.label or L["floor %d"]:format(step[2])) }
        end
    end
    if self.db.quests then
        for _, npc in ipairs(wing.turnins or {}) do
            if npc[2] == floorIndex then
                points[#points + 1] = { kind = "turnin", x = npc[3], y = npc[4],
                    label = L["%s (quests)"]:format(npc[1]) }
            end
        end
    end
    for _, boss in ipairs(wing.bosses) do
        if boss.f == floorIndex and (self.db.rares or not boss.rare) then
            points[#points + 1] = { kind = boss.rare and "rare" or "boss", x = boss.x, y = boss.y, boss = boss }
        end
    end
    return points
end

-- Infobulle d'un repère.
function DungeonMap:Tooltip(point)
    local lines = {}
    if not point.boss then
        return { { point.label, 1, 1, 1 } }
    end
    local boss = point.boss
    lines[1] = { DungeonMap.BossName(boss), 1, 0.82, 0 }
    if boss.rare then
        lines[#lines + 1] = { boss.alt and L["Rare boss (one of its spawn points)"] or L["Rare boss"], 0.75, 0.8, 1 }
    end
    if self:IsKilled(boss) then
        lines[#lines + 1] = { L["Killed in this instance"], 0.6, 0.6, 0.6 }
    end
    if self.db.quests then
        for _, quest in ipairs(questsInLog(boss)) do
            local title = ns.DB:GetName("quest", quest) or ("#" .. quest)
            lines[#lines + 1] = { L["Quest: %s"]:format(title), 1, 0.82, 0 }
        end
    end
    lines[#lines + 1] = { L["Click: open the dungeon in the journal"], 0.5, 0.5, 0.5 }
    return lines
end

---------------------------------------------------------------------------
-- Repères
---------------------------------------------------------------------------

local function showTooltip(button)
    if not (button.point and GameTooltip) then
        return
    end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    for index, line in ipairs(DungeonMap:Tooltip(button.point)) do
        if index == 1 then
            GameTooltip:SetText(line[1], line[2], line[3], line[4], 1, true)
        else
            GameTooltip:AddLine(line[1], line[2], line[3], true)
        end
    end
    GameTooltip:Show()
end

local function hideTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

function DungeonMap:OnPinClick(point)
    if point.to then
        self:ShowFloor(self.shown.key, self.shown.wing, point.to)
    elseif point.boss then
        local items = ns.Modules:Get("Items")
        if items and items.enabled and items.OpenJournal and dungeonOf(self.shown.key) then
            items.dungeonSelected = self.shown.key
            items:OpenJournal("dungeons")
        end
    end
end

local function pinButton(self, pool, parent, index)
    local button = pool[index]
    if not button then
        button = CreateFrame("Button", nil, parent)
        button.icon = button:CreateTexture(nil, "OVERLAY")
        button.icon:SetAllPoints()
        button.mark = button:CreateTexture(nil, "OVERLAY", nil, 1)
        button.mark:SetTexture(ICONS.quest)
        button.mark:SetPoint("TOPRIGHT", button, "TOPRIGHT", 6, 6)
        button:SetScript("OnEnter", showTooltip)
        button:SetScript("OnLeave", hideTooltip)
        button:SetScript("OnClick", function(clicked)
            ns.SafeCall(self.OnPinClick, self, clicked.point)
        end)
        pool[index] = button
    end
    return button
end

-- Dessine les repères d'un étage sur parent (largeur × hauteur), à l'échelle scale.
function DungeonMap:DrawPins(pool, parent, width, height, scale, wing, floorIndex, level)
    local used = 0
    for _, point in ipairs(self:Points(wing, floorIndex)) do
        used = used + 1
        local button = pinButton(self, pool, parent, used)
        local size = (SIZES[point.kind] or 18) / scale
        button:SetSize(size, size)
        button:ClearAllPoints()
        button:SetPoint("CENTER", parent, "TOPLEFT", point.x * width, -point.y * height)
        if level then
            button:SetFrameLevel(level + (point.boss and 2 or 1))
        end
        local killed = point.boss and self:IsKilled(point.boss)
        local color = killed and COLORS.killed or COLORS[point.kind]
        if point.kind == "entrance" or point.kind == "transition" then
            button.icon:SetTexture(ICONS.arrow)
        else
            button.icon:SetTexture(ICONS[point.kind])
        end
        button.icon:SetDesaturated(killed and true or false)
        if color then
            button.icon:SetVertexColor(color[1], color[2], color[3])
        else
            button.icon:SetVertexColor(1, 1, 1)
        end
        local marked = point.boss and self.db.quests and #questsInLog(point.boss) > 0
        button.mark:SetSize(size * 0.6, size * 0.6)
        button.mark:SetShown(marked and true or false)
        button.point = point
        button:Show()
    end
    for index = used + 1, #pool do
        pool[index]:Hide()
    end
    return used
end

---------------------------------------------------------------------------
-- Carte native : retouches, image complète, repères
---------------------------------------------------------------------------

-- Retouches de DungeonJournal et image de remplacement sur un étage du client.
function DungeonMap:DrawArt(canvas, width, height, floor)
    self.artTextures = self.artTextures or {}
    local used = 0
    local function texture()
        used = used + 1
        local region = self.artTextures[used]
        if not region then
            region = self.artFrame:CreateTexture(nil, "ARTWORK")
            self.artTextures[used] = region
        end
        region:ClearAllPoints()
        return region
    end
    if not DungeonMap.HasJournalArt() then
        floor = {}
    end
    if floor.image then
        local region = texture()
        region:SetTexture(floor.image)
        region:SetTexCoord(0, floor.right or 1, 0, floor.bottom or 1)
        region:SetAllPoints(canvas)
        region:SetAlpha(1)
        region:Show()
    end
    for _, patch in ipairs(floor.patches or {}) do
        local region = texture()
        region:SetTexture(patch[1])
        region:SetTexCoord(0, 1, 0, 1)
        region:SetPoint("TOPLEFT", canvas, "TOPLEFT", patch[2] * width, -patch[3] * height)
        region:SetPoint("BOTTOMRIGHT", canvas, "TOPLEFT", patch[4] * width, -patch[5] * height)
        region:SetAlpha(patch[6] or 1)
        region:Show()
    end
    for index = used + 1, #self.artTextures do
        self.artTextures[index]:Hide()
    end
end

function DungeonMap:UpdateCanvas()
    local map = WorldMapFrame
    if not (self.provider and map and map:IsShown()) then
        return
    end
    local key, wingIndex, floorIndex = DungeonMap.FloorOfMap(map:GetMapID())
    if not (self.enabled and key) then
        self:HideCanvas()
        return
    end
    local wing = ns.DB.dungeonMaps[key][wingIndex]
    local canvas = map:GetCanvas()
    local width, height = canvas:GetWidth(), canvas:GetHeight()
    local scale = map.GetCanvasScale and map:GetCanvasScale() or 1
    if not (scale and scale > 0) then
        scale = 1
    end
    self.shown = { key = key, wing = wingIndex, floor = floorIndex }
    self.artFrame:SetParent(canvas)
    self.artFrame:SetAllPoints(canvas)
    self.artFrame:SetFrameLevel((canvas:GetFrameLevel() or 0) + 1)
    self.artFrame:Show()
    self:DrawArt(canvas, width, height, wing.floors[floorIndex])
    self:DrawPins(self.canvasPins, canvas, width, height, scale, wing, floorIndex,
        (canvas:GetFrameLevel() or 0) + PIN_LEVEL)
    self:UpdateCredit(wing.floors[floorIndex])
end

function DungeonMap:HideCanvas()
    for _, button in ipairs(self.canvasPins or {}) do
        button:Hide()
    end
    if self.artFrame then
        self.artFrame:Hide()
    end
    if not (self.panel and self.panel:IsShown()) then
        self:UpdateCredit(nil)
    end
end

---------------------------------------------------------------------------
-- Panneau des étages sans carte du client
---------------------------------------------------------------------------

function DungeonMap:CreatePanel()
    local map = WorldMapFrame
    local panel = CreateFrame("Frame", nil, map.ScrollContainer or map)
    panel:SetAllPoints(map.ScrollContainer or map)
    panel:SetFrameLevel(((map.ScrollContainer or map):GetFrameLevel() or 1) + 30)
    panel:EnableMouse(true)
    local back = panel:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, 1)
    panel.art = CreateFrame("Frame", nil, panel)
    if panel.art.SetClipsChildren then
        panel.art:SetClipsChildren(true)
    end
    panel.tiles = {}
    for index = 1, 12 do
        panel.tiles[index] = panel.art:CreateTexture(nil, "BORDER")
    end
    panel.image = panel.art:CreateTexture(nil, "ARTWORK")
    panel.image:SetAllPoints()
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.title:SetPoint("TOP", panel, "TOP", 0, -12)
    panel.missing = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.missing:SetPoint("CENTER")
    panel.missing:SetText(L["Install DungeonJournal to see this map's artwork."])
    panel.previous = ns.Style.Button(panel, "<", 24, 22, function()
        self:ShowFloor(self.shown.key, self.shown.wing, self.shown.floor - 1)
    end)
    panel.previous:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
    panel.next = ns.Style.Button(panel, ">", 24, 22, function()
        self:ShowFloor(self.shown.key, self.shown.wing, self.shown.floor + 1)
    end)
    panel.next:SetPoint("LEFT", panel.previous, "RIGHT", 4, 0)
    panel.pins = {}
    panel:Hide()
    self.panel = panel
end

-- Les images et les retouches sont lues dans le dossier de DungeonJournal : il doit
-- être installé (activé ou non).
function DungeonMap.HasJournalArt()
    if not C_AddOns then
        return false
    end
    if C_AddOns.DoesAddOnExist then
        return C_AddOns.DoesAddOnExist("ForeverDungeonJournal") and true or false
    end
    return C_AddOns.IsAddOnLoaded("ForeverDungeonJournal") and true or false
end

function DungeonMap:UpdatePanel()
    local panel, shown = self.panel, self.shown
    local wing = shown and ns.DB.dungeonMaps[shown.key][shown.wing]
    local floor = wing and wing.floors[shown.floor]
    if not (panel and floor) then
        return
    end
    -- L'image garde ses proportions, centrée.
    local width, height = panel:GetWidth() or 0, panel:GetHeight() or 0
    if width > 0 and height > 0 then
        if width / height > IMAGE_ASPECT then
            width = height * IMAGE_ASPECT
        else
            height = width / IMAGE_ASPECT
        end
    end
    panel.art:ClearAllPoints()
    panel.art:SetPoint("CENTER")
    panel.art:SetSize(width, height)
    local loaded = floor.image and DungeonMap.HasJournalArt()
    if loaded then
        panel.image:SetTexture(floor.image)
    end
    panel.image:SetTexCoord(0, floor.right or 1, 0, floor.bottom or 1)
    panel.image:SetShown(loaded and true or false)
    -- Sans image de DungeonJournal, les tuiles du client (4 × 3 de 256 pixels, dont
    -- 1002 × 668 utiles) quand la carte elle-même lui manque.
    local tiled = not loaded and floor.tiles ~= nil
    for index, tile in ipairs(panel.tiles) do
        if tiled then
            local column, row = (index - 1) % 4, math.floor((index - 1) / 4)
            tile:SetTexture(floor.tiles .. index)
            tile:ClearAllPoints()
            tile:SetPoint("TOPLEFT", panel.art, "TOPLEFT", column * 256 / 1002 * width, -row * 256 / 668 * height)
            tile:SetSize(256 / 1002 * width, 256 / 668 * height)
        end
        tile:SetShown(tiled)
    end
    panel.missing:SetShown(not loaded and not tiled)
    local title = wing.name
    local dungeon = dungeonOf(shown.key)
    if dungeon and dungeonName(dungeon) then
        title = dungeonName(dungeon)
    end
    if #wing.floors > 1 then
        title = ("%s : %s"):format(title, floor.label or L["floor %d"]:format(shown.floor))
    end
    panel.title:SetText(title)
    panel.previous:SetShown(shown.floor > 1)
    panel.next:SetShown(shown.floor < #wing.floors)
    self:DrawPins(panel.pins, panel.art, width, height, 1, wing, shown.floor, (panel:GetFrameLevel() or 0) + 5)
    self:UpdateCredit(floor)
end

---------------------------------------------------------------------------
-- Choix de l'étage, bouton de bascule, mention de l'auteur
---------------------------------------------------------------------------

-- Le client connaît-il cette carte ? DungeonJournal donne les numéros de WoW Classic :
-- une carte absente du client de Forever (sans infos ou sans couches d'image) casse la
-- carte du monde si on la lui donne (erreurs « layers » et « mapInfo »).
function DungeonMap.ClientHasMap(mapID)
    if not (mapID and C_Map and C_Map.GetMapInfo) then
        return false
    end
    local ok, info = pcall(C_Map.GetMapInfo, mapID)
    if not (ok and type(info) == "table") then
        return false
    end
    if C_Map.GetMapArtLayers then
        local okLayers, layers = pcall(C_Map.GetMapArtLayers, mapID)
        if not (okLayers and type(layers) == "table" and layers[1]) then
            return false
        end
    end
    return true
end

-- Affiche un étage : sur la carte native si le client a sa carte, sinon sur le panneau.
function DungeonMap:ShowFloor(key, wingIndex, floorIndex)
    local wing = ns.DB.dungeonMaps[key] and ns.DB.dungeonMaps[key][wingIndex]
    local floor = wing and wing.floors[floorIndex]
    if not floor then
        return
    end
    self.shown = { key = key, wing = wingIndex, floor = floorIndex }
    if DungeonMap.ClientHasMap(floor.map) then
        if self.panel then
            self.panel:Hide()
        end
        if WorldMapFrame:GetMapID() ~= floor.map then
            WorldMapFrame:SetMapID(floor.map)
        else
            self:UpdateCanvas()
        end
    else
        if not self.panel then
            self:CreatePanel()
        end
        self:HideCanvas()
        self.panel:Show()
        self:UpdatePanel()
    end
    self:UpdateToggle()
end

-- Étage à montrer pour le donjon en cours : celui du personnage, sinon le premier.
function DungeonMap:ShowCurrent()
    local key, wingIndex, floorIndex = self:Current()
    if not key then
        return false
    end
    self:ShowFloor(key, wingIndex, floorIndex or 1)
    return true
end

function DungeonMap:ShowWorld()
    if self.panel then
        self.panel:Hide()
    end
    local map = WorldMapFrame
    local current = map:GetMapID()
    if DungeonMap.FloorOfMap(current) then
        local info = C_Map.GetMapInfo(current)
        local parent = info and info.parentMapID
        if parent and parent ~= 0 then
            map:SetMapID(parent)
        end
    end
    self:UpdateToggle()
end

function DungeonMap:DungeonShown()
    return (self.panel and self.panel:IsShown()) or DungeonMap.FloorOfMap(WorldMapFrame:GetMapID()) ~= nil
end

function DungeonMap:UpdateToggle()
    if not self.toggle then
        return
    end
    local inside = self.enabled and self:Current() ~= nil
    self.toggle:SetShown(inside)
    if inside then
        self.toggle:SetText(self:DungeonShown() and L["World map"] or L["Dungeon map"])
    end
end

function DungeonMap:UpdateCredit(floor)
    if not self.credit then
        return
    end
    local text
    if floor and floor.reyes then
        text = L["Map: Santiago Reyes (sreyesmaps.com), via DungeonJournal"]
    elseif floor and (floor.image or floor.patches) then
        text = L["Map details: DungeonJournal (Exehn)"]
    end
    self.credit:SetText(text or "")
    self.credit:SetShown(text ~= nil)
end

-- DungeonJournal pose sa propre carte au-dessus de celle du jeu : un message, une fois.
function DungeonMap:WarnOverlay()
    if self.warned or not (C_AddOns and C_AddOns.IsAddOnLoaded("ForeverDungeonJournal")) then
        return
    end
    local db = _G.ForeverDungeonJournalDB
    if type(db) == "table" and db.worldMapOverlay ~= false then
        self.warned = true
        ns:Print(L["DungeonJournal shows its own dungeon map over the world map, which hides your group. "
            .. "Turn off its world map option to see NextStep's dungeon map."])
    end
end

---------------------------------------------------------------------------
-- Accroche à la carte du monde
---------------------------------------------------------------------------

function DungeonMap:OnMapShown()
    if not self.enabled then
        return
    end
    if self.db.autoOpen and self:Current() then
        self:WarnOverlay()
        if not self:DungeonShown() then
            self:ShowCurrent()
        end
        -- La carte peut remettre sa carte précédente juste après l'ouverture : on revérifie.
        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, function()
                if self.enabled and WorldMapFrame:IsShown() and not self:DungeonShown() then
                    ns.SafeCall(self.ShowCurrent, self)
                end
            end)
        end
    end
    self:UpdateToggle()
end

function DungeonMap:OnMapHidden()
    if self.panel then
        self.panel:Hide()
    end
end

function DungeonMap:Refresh()
    if self.provider then
        self:UpdateCanvas()
    end
    if self.panel and self.panel:IsShown() then
        self:UpdatePanel()
    end
    self:UpdateToggle()
end

function DungeonMap:Attach()
    if self.provider then
        return true
    end
    local map = WorldMapFrame
    if not (map and map.AddDataProvider and map.GetCanvas and MapCanvasDataProviderMixin and CreateFromMixins) then
        return false
    end
    local provider = CreateFromMixins(MapCanvasDataProviderMixin)
    provider.RefreshAllData = function()
        ns.SafeCall(self.UpdateCanvas, self)
        ns.SafeCall(self.UpdateToggle, self)
    end
    provider.RemoveAllData = function()
        ns.SafeCall(self.HideCanvas, self)
    end
    provider.OnCanvasScaleChanged = provider.RefreshAllData
    provider.OnCanvasSizeChanged = provider.RefreshAllData
    map:AddDataProvider(provider)
    self.provider = provider
    self.canvasPins = {}
    self.artFrame = CreateFrame("Frame", nil, map:GetCanvas())
    self.artFrame:EnableMouse(false)

    local owner = map.ScrollContainer or map
    self.toggle = ns.Style.Button(owner, L["World map"], 130, 22, function()
        if self:DungeonShown() then
            self:ShowWorld()
        else
            self:ShowCurrent()
        end
    end)
    self.toggle:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -10, -10)
    self.toggle:SetFrameLevel((owner:GetFrameLevel() or 1) + 40)
    self.toggle:Hide()

    self.credit = owner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.credit:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -10, 8)
    self.credit:Hide()

    map:HookScript("OnShow", function()
        ns.SafeCall(self.OnMapShown, self)
    end)
    map:HookScript("OnHide", function()
        ns.SafeCall(self.OnMapHidden, self)
    end)
    return true
end

function DungeonMap:OnEnable()
    if not self:Attach() then
        self:RegisterEvent("ADDON_LOADED", function(_, _, name)
            if name == "Blizzard_WorldMap" and self:Attach() then
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
    self:RegisterEvent("ENCOUNTER_END", self.OnEncounterEnd)
    self:RegisterEvent("QUEST_LOG_UPDATE", function()
        if WorldMapFrame and WorldMapFrame:IsShown() then
            self:Refresh()
        end
    end)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        self:Killed()
        self:UpdateToggle()
    end)
end

function DungeonMap:OnDisable()
    self:HideCanvas()
    if self.panel then
        self.panel:Hide()
    end
    if self.toggle then
        self.toggle:Hide()
    end
    self:UpdateCredit(nil)
end

function DungeonMap:BuildOptions(panel, anchor)
    local Options = ns.Options
    local below = Options.AddCheck(panel, anchor, L["Open the dungeon map with the world map"],
        function() return self.db.autoOpen end,
        function(value) self.db.autoOpen = value end)
    below = Options.AddCheck(panel, below, L["Show rare bosses"],
        function() return self.db.rares end,
        function(value)
            self.db.rares = value
            self:Refresh()
        end)
    below = Options.AddCheck(panel, below, L["Show quest NPCs and quest marks"],
        function() return self.db.quests end,
        function(value)
            self.db.quests = value
            self:Refresh()
        end)
    return below
end
