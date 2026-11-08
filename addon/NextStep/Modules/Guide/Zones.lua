-- Onglet « Zones » du journal (docs/ROADMAP.md, phase 10) : à gauche les zones, celles
-- du niveau du personnage en tête, avec le nombre de quêtes qu'il peut y prendre ; à
-- droite la zone choisie : sa tranche de niveaux, les guides de leveling qui s'y
-- passent (à suivre d'un clic), les donjons dont l'entrée s'y trouve, et les quêtes
-- disponibles avec leur donneur (un clic y pointe la flèche).

local _, ns = ...
local L = ns.L

local Guide = ns.Modules:Get("Guide")
local C = ns.Style.COLORS

local function mapName(map)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    return info and ns.Usable(info.name) and info.name or ("#" .. map)
end

local function zoneLevels()
    return ns.Modules:Get("ZoneLevels")
end

-- Tranche d'une zone : celle du module Niveau des zones, sinon celle de ses quêtes.
local function rangeOf(map, quests)
    local module = zoneLevels()
    local low, high
    if module then
        low, high = module:Range(map)
    end
    if low then
        return low, high
    end
    for _, quest in ipairs(quests or {}) do
        low = math.min(low or quest.level, quest.level)
        high = math.max(high or quest.level, quest.level)
    end
    return low, high
end

-- Zones : { map, name, low, high, quests = { quête disponible } }, à son niveau d'abord.
function Guide:ZoneList(state)
    state = state or self.state
    local byMap = {}
    local function zone(map)
        local entry = byMap[map]
        if not entry then
            entry = { map = map, quests = {} }
            byMap[map] = entry
        end
        return entry
    end
    for _, quest in ipairs(self:AvailableQuests(state)) do
        table.insert(zone(quest.map).quests, quest)
    end
    for _, guide in ns.DB:IterateGuides() do
        if guide.category == "Leveling" and guide.zone and (not guide.faction or guide.faction == state:Faction()) then
            zone(guide.zone)
        end
    end
    local level = state:Level()
    local list = {}
    for map, entry in pairs(byMap) do
        entry.name = mapName(map)
        entry.low, entry.high = rangeOf(map, entry.quests)
        entry.fits = entry.low and level >= entry.low - 2 and level <= entry.high + 2
        if entry.low then
            list[#list + 1] = entry
        end
    end
    table.sort(list, function(a, b)
        if a.fits ~= b.fits then
            return a.fits
        end
        if a.low ~= b.low then
            return a.low < b.low
        end
        return a.name < b.name
    end)
    return list
end

function Guide:ZoneListRows(state)
    local rows = {}
    local fits = false
    for index, zone in ipairs(self:ZoneList(state)) do
        if index == 1 and zone.fits then
            rows[#rows + 1] = { header = true, text = L["For your level"], star = true }
            fits = true
        elseif fits and not zone.fits then
            rows[#rows + 1] = { header = true, text = L["Other zones"] }
            fits = false
        end
        rows[#rows + 1] = {
            text = ("[%d-%d] %s"):format(zone.low, zone.high, zone.name),
            right = #zone.quests > 0 and L["%d quests"]:format(#zone.quests) or nil,
            color = zone.fits and C.text or C.muted,
            selected = zone.map == self.zoneSelected,
            onClick = function()
                self.zoneSelected = zone.map
                self:UpdateZonesTab()
            end,
        }
    end
    return rows
end

function Guide:ZoneDetailRows(map, state)
    state = state or self.state
    local rows = {}
    local zone
    for _, entry in ipairs(self:ZoneList(state)) do
        if entry.map == map then
            zone = entry
        end
    end
    if not zone then
        return { { text = L["Pick a zone in the list."], color = C.muted } }
    end
    rows[#rows + 1] = { header = true, text = zone.name, right = L["Levels %d-%d"]:format(zone.low, zone.high) }
    -- Guides de leveling de la zone.
    local guides = {}
    for _, guide in ns.DB:IterateGuides() do
        if guide.category == "Leveling" and guide.zone == map
            and (not guide.faction or guide.faction == state:Faction()) then
            guides[#guides + 1] = guide
        end
    end
    table.sort(guides, function(a, b) return (a.minLevel or 0) < (b.minLevel or 0) end)
    for _, guide in ipairs(guides) do
        rows[#rows + 1] = { text = L["Guide: %s"]:format(ns.GuideLabels.Guide(guide)), color = C.blue,
            onClick = function()
                self:FollowFromJournal(guide)
                self:UpdateZonesTab()
            end }
    end
    -- Donjons dont l'entrée est dans la zone.
    local items = ns.Modules:Get("Items")
    for _, dungeon in ipairs(ns.DB.dungeons or {}) do
        local entrance = items and items.AreaName and items.AreaName(dungeon.zone)
        if entrance == zone.name then
            rows[#rows + 1] = { text = L["Dungeon: %s (%d-%d)"]:format(items.DungeonName(dungeon), dungeon.min,
                dungeon.max), color = C.gold, onClick = function()
                    items.dungeonSelected = dungeon.key
                    self:ShowJournalTab("dungeons")
                end }
        end
    end
    -- Ressources de la zone pour les métiers de récolte du personnage.
    local professions = ns.Modules:Get("Professions")
    if professions and professions.enabled and professions.ZoneResources then
        for _, text in ipairs(professions:ZoneResources(map)) do
            rows[#rows + 1] = { text = L["To gather: %s"]:format(text), color = C.green }
        end
    end
    rows[#rows + 1] = { header = true, text = L["Quests you can take"], right = tostring(#zone.quests) }
    if #zone.quests == 0 then
        rows[#rows + 1] = { text = L["No quest to take here for now."], color = C.muted }
    end
    for _, quest in ipairs(zone.quests) do
        rows[#rows + 1] = { text = self:AdviceText(quest), onClick = function() self:PointToQuest(quest) end,
            tooltip = function(tooltip)
                tooltip:SetText(Guide.AdviceTitle(quest))
                tooltip:AddLine(L["Given by %s"]:format(Guide.AdviceGiver(quest)), 1, 1, 1)
                tooltip:AddLine(L["Click: point the arrow to the giver"], 1, 0.82, 0)
            end }
    end
    return rows
end

function Guide:UpdateZonesTab(body)
    body = body or self.zonesBody
    if not (body and body:IsShown() and self.state) then
        return
    end
    if not self.zoneSelected then
        local first = self:ZoneList()[1]
        self.zoneSelected = first and first.map
    end
    body.list:SetRows(self:ZoneListRows(), true)
    body.detail:SetRows(self.zoneSelected and self:ZoneDetailRows(self.zoneSelected) or {},
        body.detailMap == self.zoneSelected)
    body.detailMap = self.zoneSelected
end

Guide:AddJournalTab({
    key = "zones",
    label = L["Zones"],
    create = function(parent)
        local size = Guide.JOURNAL_BODY
        local body = CreateFrame("Frame", nil, parent)
        body.list = Guide.RowList(body, 260, size.height)
        body.list:SetPoint("TOPLEFT")
        body.detail = Guide.RowList(body, size.width - 260 - size.padding, size.height)
        body.detail:SetPoint("TOPLEFT", body.list, "TOPRIGHT", size.padding, 0)
        Guide.zonesBody = body
        return body
    end,
    update = function(body)
        Guide:UpdateZonesTab(body)
    end,
})
