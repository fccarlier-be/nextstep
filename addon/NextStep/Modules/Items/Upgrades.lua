-- Équipement à venir (docs/DESIGN.md, « 7. Items ») : onglet « Équipement » du journal.
--
--   Prochains jalons : sorts chez le maître, quêtes de classe, sacs, monture (seuils
--                      ci-dessous, MILESTONES) ;
--   À ne pas rater   : les objets de leveling portables d'ici quelques niveaux qui
--                      amélioreraient l'équipement, avec leur provenance (quête et son
--                      donneur, boss et son donjon, artisanat).
--
-- Les récompenses qui améliorent l'équipement sont aussi signalées sur les lignes du
-- guide (Items:QuestRewardTag) et dans l'onglet Donjons.
--
-- Données : DB.itemSources, DB.itemQuests, DB.itemStats (Data/Imported/Polestar/Dungeons.lua).

local _, ns = ...
local L = ns.L
local Score = ns.Score

local Items = ns.Modules:Get("Items")
local Guide = ns.Modules:Get("Guide")
local C = ns.Style.COLORS

local AHEAD = 5          -- niveaux d'avance pour « à ne pas rater »
local MAX_UPGRADES = 25

-- Seuils des jalons. [À vérifier] sur Forever : niveau et prix de la monte.
Items.MILESTONES = {
    bags = { level = 5, slots = 10 },             -- sacs : moins de 10 places, ou emplacement vide
    mount = { level = 40, cost = 900000 },        -- monte et première monture (90 po environ)
}

local PROFESSIONS = {
    L["Alchemy"], L["Blacksmithing"], L["Enchanting"], L["Engineering"], L["Leatherworking"], L["Tailoring"],
    L["Jewelcrafting"], L["Mining"], L["Herbalism"], L["Skinning"], L["Cooking"], L["First Aid"], L["Fishing"],
}

---------------------------------------------------------------------------
-- Provenance
---------------------------------------------------------------------------

-- Index inverse : [quête] = { objets }.
local function rewardsByQuest()
    if not Items.rewardIndex then
        local index = {}
        for item, text in pairs(ns.DB.itemSources or {}) do
            for quest in text:gmatch("q(%d+)") do
                quest = tonumber(quest)
                index[quest] = index[quest] or {}
                table.insert(index[quest], item)
            end
        end
        for quest, data in pairs(ns.DB.dungeonQuests or {}) do
            for _, list in ipairs({ data.ch or {}, data.it or {} }) do
                for _, item in ipairs(list) do
                    index[quest] = index[quest] or {}
                    table.insert(index[quest], item)
                end
            end
        end
        Items.rewardIndex = index
    end
    return Items.rewardIndex
end

-- Récompense d'une quête qui améliore l'équipement : « récompense +12 % », ou nil.
function Items:QuestRewardTag(quest)
    local best
    local seen = {}
    for _, item in ipairs(rewardsByQuest()[quest] or {}) do
        if not seen[item] then
            seen[item] = true
            local up, _, pct = Score.IsUpgrade(Score.LinkOf(item), self.db.threshold)
            local result = up and Score.Compare(Score.LinkOf(item))
            if up then
                local value = result.empty and math.huge or (pct or 0)
                if not best or value > best then
                    best = value
                end
            end
        end
    end
    if not best then
        return nil
    end
    return best == math.huge and L["reward: new slot"] or L["reward %s"]:format(Items.GainText(best))
end

local function dungeonOfZone(zone)
    for _, dungeon in ipairs(ns.DB.dungeons or {}) do
        if dungeon.area == zone then
            return dungeon
        end
    end
end

-- Textes de provenance d'un objet, et lieu à pointer (donneur de la quête).
function Items:SourceTexts(item, facts)
    local texts, place = {}, nil
    for source in ((ns.DB.itemSources or {})[item] or ""):gmatch("[^|]+") do
        local quest = source:match("^q(%d+)$")
        local npc, chance, zone = source:match("^d(%d+)x(%d+)z(%d+)$")
        local spell, profession, skill = source:match("^c(%d+)p(%d+)s(%d+)$")
        if quest then
            quest = tonumber(quest)
            local info = (ns.DB.itemQuests or {})[quest]
            local data = (ns.DB.dungeonQuests or {})[quest]
            local side = info and info[3]
            local sideOK = not side or side == 3 or not facts.side or side == facts.side
            if sideOK and not facts.done[quest] then
                local title = ns.DB:GetName("quest", quest) or (info and info[1]) or ("#" .. quest)
                local where = data and data.st and Items.PlaceText(data.st)
                    or (info and Items.AreaName(info[4]))
                texts[#texts + 1] = where and L["Quest: %s, %s"]:format(title, where) or L["Quest: %s"]:format(title)
                place = place or (data and data.st and data.st.map and data.st)
            end
        elseif npc then
            local dungeon = dungeonOfZone(tonumber(zone))
            local name = ns.DB:GetName("npc", tonumber(npc))
            if not name and dungeon then
                for _, boss in ipairs(dungeon.bosses or {}) do
                    if boss.npc == tonumber(npc) then
                        name = boss.name
                    end
                end
            end
            texts[#texts + 1] = L["Drop: %s, %s (%d %%)"]:format(name or ("#" .. npc),
                Items.AreaName(tonumber(zone)), math.floor(tonumber(chance) / 10 + 0.5))
        elseif spell then
            texts[#texts + 1] = L["Crafted: %s (%d)"]:format(PROFESSIONS[tonumber(profession)] or "?", tonumber(skill))
        end
    end
    return texts, place
end

-- Objets de leveling à ne pas rater : portables d'ici AHEAD niveaux, meilleurs que
-- l'équipement porté. -> { { item, pct, empty, req, sources, place } }, triés par gain.
function Items:UpcomingUpgrades(facts)
    local level = Score.Player().level
    local list = {}
    for item in pairs(ns.DB.itemSources or {}) do
        local result = Score.Compare(Score.LinkOf(item))
        if result and result.usable and not result.equipped and result.delta and result.delta > 0
            and (result.minLevel or 0) <= level + AHEAD
            and (result.empty or (result.pct or 0) >= (self.db.threshold or 0)) then
            local sources, place = self:SourceTexts(item, facts)
            if #sources > 0 then
                list[#list + 1] = { item = item, pct = result.pct, empty = result.empty, delta = result.delta,
                    req = result.minLevel or 0, sources = sources, place = place }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.delta ~= b.delta then
            return a.delta > b.delta
        end
        return a.item < b.item
    end)
    for index = #list, MAX_UPGRADES + 1, -1 do
        list[index] = nil
    end
    return list
end

---------------------------------------------------------------------------
-- Jalons
---------------------------------------------------------------------------

local function money(copper)
    local format = Guide and Guide.FormatMoney
    return format and format(copper) or tostring(copper)
end

-- Jalons à venir : { text, right, color }.
function Items:Milestones(facts)
    local list = {}
    local level = facts.level
    -- Sorts chez le maître (module Guide).
    local plan = Guide and Guide.enabled and Guide.state and Guide:SpellPlan(Guide.state)
    if plan then
        for index, group in ipairs(plan) do
            if #group.spells > 0 then
                local text = index == 1 and L["Spells to learn now: %d"]:format(#group.spells)
                    or L["Level %d: %d new spells"]:format(group.level, #group.spells)
                list[#list + 1] = { text = text, right = money(group.total), color = index == 1 and C.green or C.text }
                if index > 1 then
                    break
                end
            end
        end
    end
    -- Quêtes de classe.
    if Guide and Guide.enabled and Guide.state then
        for _, guide in ipairs(Guide:ClassGuides(Guide.state)) do
            list[#list + 1] = { text = L["Class quest: %s"]:format(ns.DB:Translate(guide.title or guide.id, guide)),
                right = L["level %d"]:format(guide.minLevel or 1), color = C.blue }
        end
    end
    -- Sacs.
    local bags = Items.MILESTONES.bags
    if level >= bags.level and C_Container and C_Container.GetContainerNumSlots then
        local missing, small = 0, 0
        for bag = 1, 4 do
            local slots = C_Container.GetContainerNumSlots(bag) or 0
            if slots == 0 then
                missing = missing + 1
            elseif slots < bags.slots then
                small = small + 1
            end
        end
        if missing > 0 then
            list[#list + 1] = { text = L["Bags: %d bag slots are empty"]:format(missing), color = C.orange }
        elseif small > 0 then
            list[#list + 1] = { text = L["Bags: %d bags have fewer than %d slots"]:format(small, bags.slots),
                color = C.muted }
        end
    end
    -- Monture.
    local mount = Items.MILESTONES.mount
    if level < mount.level then
        local have = GetMoney and GetMoney() or 0
        list[#list + 1] = { text = L["Level %d: riding and a first mount, about %s"]:format(mount.level,
            money(mount.cost)), right = L["saved: %d %%"]:format(math.min(100, math.floor(have / mount.cost * 100))),
            color = level >= mount.level - 5 and C.gold or C.muted }
    end
    return list
end

---------------------------------------------------------------------------
-- Onglet du journal
---------------------------------------------------------------------------

function Items:GearRows(facts)
    local rows = {}
    local spec = Items.SpecName((Score.Spec()))
    rows[#rows + 1] = { header = true, text = L["Next milestones"] }
    local milestones = self:Milestones(facts)
    if #milestones == 0 then
        rows[#rows + 1] = { text = L["Nothing to plan for now."], color = C.muted }
    end
    for _, milestone in ipairs(milestones) do
        rows[#rows + 1] = milestone
    end
    rows[#rows + 1] = { header = true, text = L["Gear not to miss (%s)"]:format(spec),
        right = L["up to level %d"]:format(Score.Player().level + AHEAD) }
    local list = self:UpcomingUpgrades(facts)
    if #list == 0 then
        rows[#rows + 1] = { text = L["No known upgrade for the next levels."], color = C.muted }
    end
    for _, entry in ipairs(list) do
        local name, link, color, icon = Items.ItemDisplay(entry.item)
        local gain = entry.empty and L["new"] or Items.GainText(entry.pct or 0)
        if entry.req > Score.Player().level then
            gain = gain .. " " .. L["(level %d)"]:format(entry.req)
        end
        local row = { text = name, icon = icon, color = color, right = gain, rightColor = C.green, tooltip = link }
        rows[#rows + 1] = row
        for _, source in ipairs(entry.sources) do
            local sourceRow = { text = source, indent = 2, color = C.muted }
            if entry.place and Guide and Guide.enabled then
                local place = entry.place
                sourceRow.onClick = function()
                    Guide:PointTo(place, name)
                    ns:Print(L["The arrow points to %s."]:format(Items.PlaceText(place)))
                end
            end
            rows[#rows + 1] = sourceRow
        end
    end
    return rows
end

function Items:UpdateGearTab(body)
    body = body or self.gearBody
    if not (body and body:IsShown()) then
        return
    end
    body.list:SetRows(self:GearRows(self:QuestFacts()), true)
end

-- Rafraîchit l'onglet ouvert (après un changement d'équipement, d'objets reçus...).
function Items:RefreshJournal()
    if self.dungeonsBody and self.dungeonsBody:IsShown() then
        self:UpdateDungeonsTab()
    end
    if self.gearBody and self.gearBody:IsShown() then
        self:UpdateGearTab()
    end
end

if Guide then
    Guide:AddJournalTab({
        key = "gear",
        label = L["Gear"],
        create = function(parent)
            local size = Guide.JOURNAL_BODY
            local body = CreateFrame("Frame", nil, parent)
            body.list = Guide.RowList(body, size.width, size.height)
            body.list:SetPoint("TOPLEFT")
            Items.gearBody = body
            return body
        end,
        update = function(body)
            if Items.enabled then
                Items:UpdateGearTab(body)
            else
                body.list:SetRows({ { text = L["%s is disabled: enable it in the options."]:format(Items.title),
                    color = C.muted } })
            end
        end,
    })
end
