-- Donjons (docs/DESIGN.md, « 7. Items », butin des donjons) : onglet « Donjons » du
-- journal. Pour chaque donjon : les quêtes à prendre avant d'y aller, avec les étapes
-- de leur suite de quêtes encore à faire, le donneur et sa zone (un clic y pointe la
-- flèche) ; puis le butin des boss, avec le gain pour la spécialisation.
--
-- Données : Data/Imported/Polestar/Dungeons.lua (DB.dungeons, DB.dungeonQuests), plus
-- le butin appris en jeu (objets vus en ouvrant le butin dans un donjon, db.learnedLoot,
-- au niveau du compte) : la sélection importée n'a que quelques objets par boss.
--
-- [À vérifier] sur Forever : GetInstanceInfo (identifiant de l'instance) et
-- GetLootSourceInfo pour les donjons propres à Forever.

local _, ns = ...
local L = ns.L
local Score = ns.Score

local Items = ns.Modules:Get("Items")
local Guide = ns.Modules:Get("Guide")
local C = ns.Style.COLORS

local QUALITY = {
    [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 },
}
local STATE_COLORS = {
    done = { 0.45, 0.45, 0.47 }, log = C.blue, open = C.text, level = C.orange, locked = C.muted,
}

local function hasBit(mask, bit)
    return math.floor(mask / bit) % 2 == 1
end

---------------------------------------------------------------------------
-- Le personnage face aux quêtes
---------------------------------------------------------------------------

-- { level, side (1 Alliance, 2 Horde), raceBit, classBit, done[q], log[q] }
function Items:QuestFacts()
    local facts = { level = Score.Client.PlayerLevel(), done = {}, log = {} }
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    facts.side = faction == "Alliance" and 1 or (faction == "Horde" and 2 or nil)
    local _, _, raceID = UnitRace("player")
    local _, _, classID = UnitClass("player")
    raceID, classID = tonumber(ns.Usable(raceID) and raceID), tonumber(ns.Usable(classID) and classID)
    facts.raceBit = raceID and 2 ^ (raceID - 1)
    facts.classBit = classID and 2 ^ (classID - 1)
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        for index = 1, C_QuestLog.GetNumQuestLogEntries() or 0 do
            local info = C_QuestLog.GetInfo(index)
            if info and info.questID and not info.isHeader then
                facts.log[info.questID] = true
            end
        end
    end
    setmetatable(facts.done, { __index = function(cache, id)
        local done = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
            and C_QuestLog.IsQuestFlaggedCompleted(id) == true or false
        rawset(cache, id, done)
        return done
    end })
    return facts
end

-- La quête est-elle pour ce personnage (faction, race, classe) ?
function Items.QuestApplies(quest, facts)
    if quest.s and facts.side and quest.s ~= facts.side then
        return false
    end
    if quest.r and facts.raceBit and not hasBit(quest.r, facts.raceBit) then
        return false
    end
    if quest.c and facts.classBit and not hasBit(quest.c, facts.classBit) then
        return false
    end
    return true
end

local function quests()
    return ns.DB.dungeonQuests or {}
end

-- Prérequis remplis : tous ceux de « all », l'un de ceux de « any » (parmi ceux qui
-- concernent le personnage).
local function prereqsDone(quest, facts)
    for _, pre in ipairs(quest.all or {}) do
        if not facts.done[pre] then
            return false
        end
    end
    if quest.any then
        local applicable = false
        for _, pre in ipairs(quest.any) do
            local other = quests()[pre]
            if facts.done[pre] then
                return true
            end
            applicable = applicable or (other and Items.QuestApplies(other, facts))
        end
        return not applicable
    end
    return true
end

-- "done" | "log" | "open" | "level" (niveau trop bas) | "locked" (une étape avant)
function Items.QuestState(id, facts)
    local quest = quests()[id]
    if facts.done[id] then
        return "done"
    end
    if facts.log[id] then
        return "log"
    end
    if quest and not prereqsDone(quest, facts) then
        return "locked"
    end
    if quest and (quest.m or 0) > facts.level then
        return "level"
    end
    return "open"
end

-- Étapes encore à faire pour arriver à la quête id, dans l'ordre, la quête en dernier.
-- Parmi des prérequis au choix (« any »), celui qui est dans le journal, sinon le
-- premier qui concerne le personnage. Les quêtes d'introduction sont laissées de côté.
function Items.QuestChain(id, facts)
    local steps, seen = {}, {}
    local function visit(qid)
        if seen[qid] or facts.done[qid] then
            return
        end
        seen[qid] = true
        local quest = quests()[qid]
        if quest then
            for _, pre in ipairs(quest.all or {}) do
                visit(pre)
            end
            if quest.any then
                local pick, done = nil, false
                for _, pre in ipairs(quest.any) do
                    local other = quests()[pre]
                    done = done or facts.done[pre]
                    if other and Items.QuestApplies(other, facts) then
                        if facts.log[pre] then
                            pick = pre
                        elseif not pick then
                            pick = pre
                        end
                    end
                end
                if pick and not done then
                    visit(pick)
                end
            end
        end
        steps[#steps + 1] = qid
    end
    visit(id)
    return steps
end

-- Suites d'une quête (celles qui l'attendent), qui concernent le personnage.
function Items.QuestFollowUps(id, facts)
    if not Items.followIndex then
        local index = {}
        for qid, quest in pairs(quests()) do
            for _, list in ipairs({ quest.all or {}, quest.any or {} }) do
                for _, pre in ipairs(list) do
                    index[pre] = index[pre] or {}
                    table.insert(index[pre], qid)
                end
            end
        end
        for _, list in pairs(index) do
            table.sort(list)
        end
        Items.followIndex = index
    end
    local list = {}
    for _, qid in ipairs(Items.followIndex[id] or {}) do
        if Items.QuestApplies(quests()[qid], facts) and not facts.done[qid] then
            list[#list + 1] = qid
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Noms
---------------------------------------------------------------------------

function Items.AreaName(area)
    local name = C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(area)
    if ns.Usable(name) and name ~= "" then
        return name
    end
    return (ns.DB.itemZones or {})[area] or ("#" .. area)
end

function Items.MapName(map)
    local info = map and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    return info and ns.Usable(info.name) and info.name or nil
end

function Items.QuestTitle(id)
    local quest = quests()[id]
    return ns.DB:GetName("quest", id) or (quest and quest.t) or ("#" .. id)
end

local KINDS = { n = "npc", o = "object", i = "item" }

-- « Nom (Zone) » d'un donneur ou d'un destinataire.
function Items.PlaceText(place)
    if not place then
        return L["unknown"]
    end
    local name = ns.DB:GetName(KINDS[place.k] or "npc", place.id) or place.name or ("#" .. place.id)
    if place.k == "i" then
        return L["the item %s"]:format(name)
    end
    local zone = Items.MapName(place.map)
    return zone and ("%s (%s)"):format(name, zone) or name
end

function Items.DungeonName(dungeon)
    return Items.AreaName(dungeon.area)
end

-- Nom, icône et couleur d'un objet ; le client le charge à la demande.
function Items.ItemDisplay(id)
    local name, link, quality, icon
    if C_Item and C_Item.GetItemInfo then
        local ok, n, l, q, _, _, _, _, _, _, i = pcall(C_Item.GetItemInfo, id)
        if ok then
            name, link, quality, icon = n, l, q, i
        end
    end
    if not name and C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, id)
    end
    if not quality then
        local info = Score.Info(Score.LinkOf(id))
        quality = info and info.quality
    end
    return name or L["Item %d"]:format(id), link or ("item:" .. id), QUALITY[quality or 1] or QUALITY[1],
        icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Gain d'un objet pour la spécialisation : texte et couleur (nil : rien à dire).
function Items:GainOf(id)
    local result = Score.Compare(Score.LinkOf(id))
    if not result then
        return nil
    end
    if not result.usable then
        return L["not for you"], C.muted
    end
    if result.equipped then
        return L["equipped"], C.gold
    end
    if result.empty then
        return L["new"], C.green
    end
    if result.pct and result.delta > 0 and result.pct >= (self.db.threshold or 0) then
        local text = Items.GainText(result.pct)
        if (result.minLevel or 0) > Score.Player().level then
            text = text .. " " .. L["(level %d)"]:format(result.minLevel)
        end
        return text, C.green
    end
    return nil
end

---------------------------------------------------------------------------
-- Donjons
---------------------------------------------------------------------------

function Items.DungeonByKey(key)
    for _, dungeon in ipairs(ns.DB.dungeons or {}) do
        if dungeon.key == key then
            return dungeon
        end
    end
end

-- Donjons de la faction du personnage, dans l'ordre des niveaux.
function Items:Dungeons(facts)
    local side = facts.side == 1 and "A" or (facts.side == 2 and "H" or nil)
    local list = {}
    for _, dungeon in ipairs(ns.DB.dungeons or {}) do
        if not (dungeon.side and side and dungeon.side ~= side) then
            list[#list + 1] = dungeon
        end
    end
    table.sort(list, function(a, b)
        if a.min ~= b.min then
            return a.min < b.min
        end
        return a.key < b.key
    end)
    return list
end

-- Quêtes du donjon qui concernent le personnage et ne sont pas faites.
function Items:DungeonQuests(dungeon, facts)
    local list = {}
    for _, id in ipairs(dungeon.quests or {}) do
        local quest = quests()[id]
        if quest and Items.QuestApplies(quest, facts) and not facts.done[id] then
            list[#list + 1] = id
        end
    end
    return list
end

-- Donjon conseillé : le niveau du personnage est dans sa tranche.
function Items.Recommended(dungeon, level)
    return level >= dungeon.min - 2 and level <= dungeon.max
end

local function levelColor(dungeon, level)
    if level > dungeon.max then
        return STATE_COLORS.done
    elseif level < dungeon.min - 2 then
        return C.orange
    end
    return C.text
end

-- Lignes de la liste des donjons.
function Items:DungeonListRows(facts)
    local recommended, others = {}, {}
    for _, dungeon in ipairs(self:Dungeons(facts)) do
        local count = #self:DungeonQuests(dungeon, facts)
        local row = {
            text = ("[%d-%d] %s"):format(dungeon.min, dungeon.max, Items.DungeonName(dungeon)),
            right = count > 0 and L["%d quests"]:format(count) or nil,
            color = levelColor(dungeon, facts.level),
            selected = dungeon.key == self.dungeonSelected,
            key = dungeon.key,
            onClick = function()
                self.dungeonSelected = dungeon.key
                self:UpdateDungeonsTab()
            end,
        }
        table.insert(Items.Recommended(dungeon, facts.level) and recommended or others, row)
    end
    local rows = {}
    if #recommended > 0 then
        rows[#rows + 1] = { header = true, text = L["For your level"], star = true }
        for _, row in ipairs(recommended) do
            rows[#rows + 1] = row
        end
    end
    rows[#rows + 1] = { header = true, text = L["All dungeons"] }
    for _, row in ipairs(others) do
        rows[#rows + 1] = row
    end
    return rows
end

local STATE_TEXT = {
    done = L["done"], log = L["in your log"], open = L["to take"], locked = L["earlier step"],
    level = L["level %d"],
}

local function stateText(state, quest)
    if state == "level" then
        return STATE_TEXT.level:format(quest.m or 0)
    end
    return STATE_TEXT[state]
end

local function pointRow(row, place, label)
    if place and place.map and place.x and place.y and Guide and Guide.enabled then
        row.onClick = function()
            -- Second clic sur le même lieu : la flèche revient au guide.
            if Guide:IsPointing(place) then
                Guide:BackToGuide()
                return
            end
            Guide:PointTo(place, label)
            ns:Print(L["The arrow points to %s. Right-click it to go back to the guide."]:format(
                Items.PlaceText(place)))
        end
    end
    return row
end

-- Lignes du détail d'un donjon : quêtes (et leurs étapes), puis butin.
function Items:DungeonDetailRows(dungeon, facts)
    local rows = {}
    rows[#rows + 1] = { header = true, text = Items.DungeonName(dungeon),
        right = L["Levels %d-%d"]:format(dungeon.min, dungeon.max) }
    rows[#rows + 1] = { text = L["Entrance: %s"]:format(Items.AreaName(dungeon.zone)), color = C.muted }

    local list = self:DungeonQuests(dungeon, facts)
    rows[#rows + 1] = { header = true, text = L["Quests to take before going in"],
        right = #list > 0 and tostring(#list) or nil }
    if #list == 0 then
        rows[#rows + 1] = { text = L["No quest left for this dungeon."], color = C.muted }
    end
    for _, id in ipairs(list) do
        local quest = quests()[id]
        local state = Items.QuestState(id, facts)
        local steps = Items.QuestChain(id, facts)
        local reward = self:QuestRewardTag(id)
        rows[#rows + 1] = pointRow({
            text = ("[%d] %s"):format(quest.l or 0, Items.QuestTitle(id))
                .. (reward and (" |cff66e666(" .. reward .. ")|r") or ""),
            right = stateText(state, quest), color = STATE_COLORS[state], rightColor = STATE_COLORS[state],
            tooltip = function(tooltip)
                tooltip:SetText(Items.QuestTitle(id))
                tooltip:AddLine(L["Given by %s"]:format(Items.PlaceText(quest.st)), 1, 1, 1)
                tooltip:AddLine(L["Turned in to %s"]:format(Items.PlaceText(quest.en)), 1, 1, 1)
                if quest.st and quest.st.map then
                    tooltip:AddLine(L["Click: point the arrow to the giver"], 1, 0.82, 0)
                end
            end,
        }, quest.st, Items.QuestTitle(id))
        if #steps > 1 then
            -- Suite de quêtes : chaque étape restante, dans l'ordre.
            rows[#rows + 1] = { text = L["Quest chain: %d steps left"]:format(#steps), indent = 1, color = C.gold }
            for index, step in ipairs(steps) do
                local stepQuest = quests()[step] or {}
                local stepState = Items.QuestState(step, facts)
                rows[#rows + 1] = pointRow({
                    text = ("%d. %s — %s"):format(index, Items.QuestTitle(step), Items.PlaceText(stepQuest.st)),
                    right = stateText(stepState, stepQuest), indent = 2,
                    color = STATE_COLORS[stepState], rightColor = STATE_COLORS[stepState],
                }, stepQuest.st, Items.QuestTitle(step))
            end
        elseif state ~= "log" then
            rows[#rows + 1] = pointRow({ text = L["Given by %s"]:format(Items.PlaceText(quest.st)),
                indent = 1, color = C.muted }, quest.st, Items.QuestTitle(id))
        end
        local follow = Items.QuestFollowUps(id, facts)
        if #follow > 0 then
            local names = {}
            for _, after in ipairs(follow) do
                names[#names + 1] = Items.QuestTitle(after)
            end
            rows[#rows + 1] = { text = L["Then: %s"]:format(table.concat(names, ", ")), indent = 1, color = C.muted }
        end
    end

    -- Butin des boss : sélection importée, puis objets vus en jeu.
    local learned = self.db.learnedLoot[dungeon.key] or {}
    local shown = {}
    rows[#rows + 1] = { header = true, text = L["Boss loot"] }
    local any = false
    for _, boss in ipairs(dungeon.bosses or {}) do
        local bossRows = {}
        for _, drop in ipairs(boss.loot or {}) do
            shown[drop[1]] = true
            bossRows[#bossRows + 1] = self:LootRow(drop[1], drop[2])
        end
        for item, npc in pairs(learned) do
            if npc == boss.npc and not shown[item] then
                shown[item] = true
                bossRows[#bossRows + 1] = self:LootRow(item)
            end
        end
        if #bossRows > 0 then
            any = true
            rows[#rows + 1] = { text = ns.DB:GetName("npc", boss.npc) or boss.name, color = C.gold }
            for _, row in ipairs(bossRows) do
                rows[#rows + 1] = row
            end
        end
    end
    local extra = {}
    for item in pairs(learned) do
        if not shown[item] then
            extra[#extra + 1] = item
        end
    end
    table.sort(extra)
    if #extra > 0 then
        any = true
        rows[#rows + 1] = { text = L["Seen in game"], color = C.gold }
        for _, item in ipairs(extra) do
            rows[#rows + 1] = self:LootRow(item)
        end
    end
    if not any then
        rows[#rows + 1] = { text = L["No loot known yet: loot seen in game will be listed here."], color = C.muted }
    end
    return rows
end

function Items:LootRow(item, chance)
    local name, link, color, icon = Items.ItemDisplay(item)
    local gain, gainColor = self:GainOf(item)
    local right = gain
    if chance then
        local pct = ("%d %%"):format(math.floor(chance / 10 + 0.5))
        right = right and (right .. "  ·  " .. pct) or pct
    end
    return { text = name, icon = icon, color = color, right = right, rightColor = gainColor or C.muted,
        indent = 1, tooltip = link }
end

---------------------------------------------------------------------------
-- Butin appris
---------------------------------------------------------------------------

-- Donjon où se trouve le personnage, d'après l'instance (sinon son nom).
function Items:CurrentDungeon()
    if not (IsInInstance and IsInInstance()) or not GetInstanceInfo then
        return nil
    end
    local name, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    for _, dungeon in ipairs(ns.DB.dungeons or {}) do
        if (dungeon.instance and dungeon.instance == instanceID)
            or (ns.Usable(name) and name == Items.DungeonName(dungeon)) then
            return dungeon
        end
    end
end

function Items:LearnLoot()
    local dungeon = self:CurrentDungeon()
    if not (dungeon and GetNumLootItems and GetLootSlotLink) then
        return
    end
    for slot = 1, GetNumLootItems() or 0 do
        local link = GetLootSlotLink(slot)
        local id = ns.Usable(link) and Score.ItemID(link)
        local info = id and Score.Info(link)
        if info and (info.quality or 0) >= 2 then
            local npc
            if GetLootSourceInfo then
                local guid = GetLootSourceInfo(slot)
                npc = ns.NpcID(guid)
            end
            self.db.learnedLoot[dungeon.key] = self.db.learnedLoot[dungeon.key] or {}
            self.db.learnedLoot[dungeon.key][id] = npc or 0
        end
    end
end

---------------------------------------------------------------------------
-- Onglet du journal
---------------------------------------------------------------------------

function Items:UpdateDungeonsTab(body)
    body = body or self.dungeonsBody
    if not (body and body:IsShown()) then
        return
    end
    local facts = self:QuestFacts()
    if not self.dungeonSelected then
        -- Le premier donjon à son niveau, sinon le premier de la liste.
        local list = self:Dungeons(facts)
        for _, dungeon in ipairs(list) do
            if Items.Recommended(dungeon, facts.level) then
                self.dungeonSelected = dungeon.key
                break
            end
        end
        self.dungeonSelected = self.dungeonSelected or (list[1] and list[1].key)
    end
    body.list:SetRows(self:DungeonListRows(facts), true)
    local dungeon = self.dungeonSelected and Items.DungeonByKey(self.dungeonSelected)
    if dungeon then
        local key = dungeon.key
        body.detail:SetRows(self:DungeonDetailRows(dungeon, facts), body.detailKey == key)
        body.detailKey = key
    else
        body.detail:SetRows({ { text = L["Pick a dungeon in the list."], color = C.muted } })
    end
end

if Guide then
    Guide:AddJournalTab({
        key = "dungeons",
        label = L["Dungeons"],
        create = function(parent)
            local size = Guide.JOURNAL_BODY
            local body = CreateFrame("Frame", nil, parent)
            body.list = Guide.RowList(body, 280, size.height)
            body.list:SetPoint("TOPLEFT")
            body.detail = Guide.RowList(body, size.width - 280 - size.padding, size.height)
            body.detail:SetPoint("TOPLEFT", body.list, "TOPRIGHT", size.padding, 0)
            Items.dungeonsBody = body
            return body
        end,
        update = function(body)
            if Items.enabled then
                Items:UpdateDungeonsTab(body)
            else
                body.list:SetRows({ { text = L["%s is disabled: enable it in the options."]:format(Items.title),
                    color = C.muted } })
                body.detail:SetRows({})
            end
        end,
    })
end
