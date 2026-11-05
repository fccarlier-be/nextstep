-- Journal du guide (docs/DESIGN.md, « Journal ») : grande fenêtre à onglets.
--
--   Routes : tous les guides du personnage par catégorie (leveling, classe, métiers,
--            réputation, collection...), avec en tête de la catégorie Leveling
--            « Choisis ton chemin » (guides conseillés, guides suivants) ; niveau
--            coloré selon le personnage, avancement, détail du guide choisi et
--            bouton pour le suivre.
--   Sorts de classe : les sorts du maître, maintenant et aux niveaux à venir
--            (SpellsWindow.lua).
--   Options : ouvre les options de NextStep.
--
-- Ouvert par le menu du bouton NextStep, /ns journal ou un raccourci clavier ;
-- déplaçable, fermé par Échap ou la croix, listes défilant à la molette.

local _, ns = ...
local L = ns.L

local Guide = ns.Modules:Get("Guide")
local Labels = ns.GuideLabels

local WIDTH, HEIGHT = 700, 470
local PADDING = 12
local TOP = 62            -- sous le titre et les onglets
local ROW_HEIGHT = 16
local CATEGORY_WIDTH = 140
local LIST_WIDTH = 300
local DETAIL_WIDTH = WIDTH - CATEGORY_WIDTH - LIST_WIDTH - 4 * PADDING

local COLORS = {
    title = { 1, 0.82, 0 },
    text = { 1, 1, 1 },
    muted = { 0.65, 0.65, 0.65 },
    selected = { 0.4, 0.8, 1 },
}

-- Catégories, dans l'ordre du journal.
local CATEGORIES = {
    { key = "Leveling", label = "Leveling" },
    { key = "Class", label = "Class" },
    { key = "Professions", label = "Professions" },
    { key = "Reputation", label = "Reputation" },
    { key = "Collectibles", label = "Collectibles" },
    { key = "Exploration", label = "Exploration" },
    { key = "Miscellaneous", label = "Miscellaneous" },
    { key = "Legacy", label = "Legacy content" },
}

local function contains(list, value)
    for _, item in ipairs(list or {}) do
        if item == value then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Données du journal
---------------------------------------------------------------------------

-- Le guide concerne-t-il le personnage ? Faction et classe toujours ; la race
-- seulement hors leveling (on peut commencer chez une autre race, pas faire la
-- quête de classe d'une autre race).
function Guide:JournalShows(guide, state)
    state = state or self.state
    if ns.DB.retired[guide.id] then
        return false
    end
    if guide.faction and state and guide.faction ~= state:Faction() then
        return false
    end
    if guide.classes and state and not contains(guide.classes, state:Class()) then
        return false
    end
    if guide.category ~= "Leveling" and guide.races and state and not contains(guide.races, state:Race()) then
        return false
    end
    return true
end

-- Catégories qui ont au moins un guide : { key, label, count }.
function Guide:JournalCategories(state)
    local counts = {}
    for _, guide in ns.DB:IterateGuides() do
        if guide.category and self:JournalShows(guide, state) then
            counts[guide.category] = (counts[guide.category] or 0) + 1
        end
    end
    local list = {}
    for _, category in ipairs(CATEGORIES) do
        if counts[category.key] then
            list[#list + 1] = { key = category.key, label = L[category.label], count = counts[category.key] }
        end
    end
    return list
end

-- Avancement d'un guide : "active", "done", ou la part des étapes passées (0 à 1).
local PASSED = { done = true, na = true, jumped = true, along = true, skipped = true }

function Guide:GuideStatus(guide)
    if self.char.active == guide.id then
        return "active"
    end
    if self.char.completed[guide.id] then
        return "done"
    end
    local progress = self.char.progress[guide.id]
    if not progress then
        return 0
    end
    local keys = ns.GuideEngine.Keys(guide)
    local passed = 0
    for _, key in ipairs(keys.steps) do
        if PASSED[progress.outcomes[key]] or progress.skipped[key] then
            passed = passed + 1
        end
    end
    return #keys.steps > 0 and passed / #keys.steps or 0
end

-- Tranche de niveaux, colorée selon le personnage (comme le niveau des quêtes).
function Guide:LevelRange(guide, level)
    local low, high = guide.minLevel or 1, guide.maxLevel or 60
    local difficulty = "normal"
    if level then
        if level < low then
            difficulty = Labels.Difficulty(low, level)
        elseif level > high then
            difficulty = Labels.Difficulty(high, level)
        end
    end
    local text = low == high and ("%d"):format(low) or ("%d-%d"):format(low, high)
    return ("|cff%s[%s]|r"):format(Labels.DIFFICULTY_COLORS[difficulty], text)
end

local function statusText(status)
    if status == "active" then
        return " |cff66ccff" .. L["(following)"] .. "|r"
    elseif status == "done" then
        return " |cff40c040" .. L["(done)"] .. "|r"
    elseif status > 0 then
        return (" |cffa0a0a0(%d %%)|r"):format(math.floor(status * 100 + 0.5))
    end
    return ""
end

local function guideRow(self, guide, level)
    return {
        guide = guide,
        text = ("%s %s%s"):format(self:LevelRange(guide, level), Labels.Guide(guide):gsub(" %d+%-%d+$", ""),
            statusText(self:GuideStatus(guide))),
    }
end

-- Lignes de la liste d'une catégorie : en-têtes (dossiers, « Choisis ton chemin »)
-- et guides { guide, text }.
function Guide:JournalRows(category, state)
    state = state or self.state
    local level = state and state:Level()
    local rows = {}
    if category == "Leveling" and state then
        -- Choisis ton chemin : guides suivants du guide suivi, puis guides conseillés.
        local picks, seen = {}, {}
        local active = self:ActiveGuide()
        for _, id in ipairs(active and active.next or {}) do
            local guide = ns.DB:GetGuide(id)
            if guide and not seen[id] then
                picks[#picks + 1], seen[id] = guide, true
            end
        end
        for _, guide in ipairs(self:Suggest(state)) do
            if #picks < 4 and not seen[guide.id] then
                picks[#picks + 1], seen[guide.id] = guide, true
            end
        end
        if #picks > 0 then
            rows[#rows + 1] = { header = L["Choose your path"] }
            for _, guide in ipairs(picks) do
                rows[#rows + 1] = guideRow(self, guide, level)
            end
            rows[#rows + 1] = { header = L["All guides"] }
        end
    end
    local list = {}
    for _, guide in ns.DB:IterateGuides() do
        if guide.category == category and self:JournalShows(guide, state) then
            list[#list + 1] = guide
        end
    end
    table.sort(list, function(a, b)
        local fa, fb = a.folder or "", b.folder or ""
        if fa ~= fb then
            return fa < fb
        end
        if (a.minLevel or 1) ~= (b.minLevel or 1) then
            return (a.minLevel or 1) < (b.minLevel or 1)
        end
        return a.id < b.id
    end)
    local folder
    for _, guide in ipairs(list) do
        if guide.folder and guide.folder ~= folder then
            folder = guide.folder
            rows[#rows + 1] = { header = ns.DB:Translate(folder) or folder }
        end
        rows[#rows + 1] = guideRow(self, guide, level)
    end
    return rows
end

-- Détail d'un guide : lignes de texte.
function Guide:GuideDetails(guide, state)
    state = state or self.state
    local lines = {}
    local level = state and state:Level()
    lines[#lines + 1] = ("%s %s"):format(self:LevelRange(guide, level), Labels.Guide(guide))
    if guide.zone then
        local zone = ns.DB:GetName("zone", guide.zone, guide)
        if zone and zone ~= "?" then
            lines[#lines + 1] = L["Zone: %s"]:format(zone)
        end
    end
    if guide.why then
        lines[#lines + 1] = "|cffffffff" .. (ns.DB:Render(guide.why, guide) or guide.why) .. "|r"
    end
    local rewards = {}
    for _, reward in ipairs(guide.reward or {}) do
        if reward.spell then
            rewards[#rewards + 1] = ns.DB:GetName("spell", reward.spell, guide) or reward.spellName
                or ("#" .. reward.spell)
        elseif reward.item then
            rewards[#rewards + 1] = ns.DB:GetName("item", reward.item, guide) or ("#" .. reward.item)
        end
    end
    if #rewards > 0 then
        lines[#lines + 1] = L["Reward: %s"]:format(table.concat(rewards, ", "))
    end
    local nexts = {}
    for _, id in ipairs(guide.next or {}) do
        local nextGuide = ns.DB:GetGuide(id)
        if nextGuide then
            nexts[#nexts + 1] = Labels.Guide(nextGuide)
        end
    end
    if #nexts > 0 then
        lines[#lines + 1] = L["Then: %s"]:format(table.concat(nexts, ", "))
    end
    local status = self:GuideStatus(guide)
    if status == "active" then
        lines[#lines + 1] = "|cff66ccff" .. L["You are following this guide."] .. "|r"
    elseif status == "done" then
        lines[#lines + 1] = "|cff40c040" .. L["You finished this guide."] .. "|r"
    elseif status > 0 then
        lines[#lines + 1] = L["Progress: %d %%"]:format(math.floor(status * 100 + 0.5))
    end
    return lines
end

-- Suivre un guide du journal : une quête de classe garde la route à reprendre.
function Guide:FollowFromJournal(guide)
    if guide.category == "Class" then
        self:StartClassGuide(guide.id)
    else
        self.char.returnTo = nil
        self:Start(guide.id)
    end
    self:SetWindowShown(true)
end

---------------------------------------------------------------------------
-- Cadre
---------------------------------------------------------------------------

local function newText(parent, template)
    local text = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    text:SetJustifyH("LEFT")
    return text
end

local function textButton(parent, width, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, ROW_HEIGHT)
    button.text = newText(button)
    button.text:SetPoint("LEFT", 2, 0)
    button.text:SetPoint("RIGHT", -2, 0)
    if button.text.SetWordWrap then
        button.text:SetWordWrap(false)
    end
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    button:SetScript("OnClick", onClick)
    return button
end

local function scrollable(frame, onScroll)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        onScroll(delta > 0 and -3 or 3)
    end)
end

function Guide:CreateJournal()
    local frame = CreateFrame("Frame", "NextStepJournalFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(0.05, 0.05, 0.08, 0.94)
        frame:SetBackdropBorderColor(0.6, 0.5, 0.3, 1)
    end
    frame:Hide()

    local title = newText(frame, "GameFontNormal")
    title:SetPoint("TOPLEFT", PADDING, -10)
    title:SetText(L["NextStep journal"])

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    -- Onglets.
    frame.tabs = {}
    local tabs = {
        { key = "routes", label = L["Routes"] },
        { key = "spells", label = L["Class spells"] },
    }
    local previous
    for _, tab in ipairs(tabs) do
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(130, 22)
        button:SetText(tab.label)
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
        else
            button:SetPoint("TOPLEFT", PADDING, -30)
        end
        button:SetScript("OnClick", function()
            self:ShowJournalTab(tab.key)
        end)
        frame.tabs[tab.key] = button
        previous = button
    end
    local options = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    options:SetSize(90, 22)
    options:SetPoint("TOPRIGHT", -PADDING - 20, -30)
    options:SetText(L["Options"])
    options:SetScript("OnClick", function()
        ns.Options:Open()
    end)

    -- Routes : catégories, liste, détail.
    local visible = math.floor((HEIGHT - TOP - PADDING) / ROW_HEIGHT)
    frame.visible = visible
    frame.categoryButtons, frame.listButtons, frame.detailLines = {}, {}, {}
    for index = 1, #CATEGORIES do
        local button = textButton(frame, CATEGORY_WIDTH, function(b)
            self.journalCategory = b.key
            self.journalOffset = 0
            self.journalSelected = nil
            self:UpdateJournal()
        end)
        button:SetPoint("TOPLEFT", PADDING, -TOP - (index - 1) * (ROW_HEIGHT + 4))
        frame.categoryButtons[index] = button
    end
    local listX = PADDING * 2 + CATEGORY_WIDTH
    local listArea = CreateFrame("Frame", nil, frame)
    listArea:SetPoint("TOPLEFT", listX, -TOP)
    listArea:SetSize(LIST_WIDTH, visible * ROW_HEIGHT)
    scrollable(listArea, function(step)
        self.journalOffset = math.max(0, (self.journalOffset or 0) + step)
        self:UpdateJournal()
    end)
    frame.listArea = listArea
    for index = 1, visible do
        local button = textButton(listArea, LIST_WIDTH, function(b)
            if b.guide then
                self.journalSelected = b.guide.id
                self:UpdateJournal()
            end
        end)
        button:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
        frame.listButtons[index] = button
    end
    local detailX = listX + LIST_WIDTH + PADDING
    local detail = CreateFrame("Frame", nil, frame)
    detail:SetPoint("TOPLEFT", detailX, -TOP)
    detail:SetSize(DETAIL_WIDTH, HEIGHT - TOP - PADDING - 30)
    frame.detail = detail
    local follow = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    follow:SetSize(DETAIL_WIDTH, 22)
    follow:SetPoint("BOTTOMLEFT", detailX, PADDING)
    follow:SetText(L["Follow this guide"])
    follow:SetScript("OnClick", function()
        local guide = self.journalSelected and ns.DB:GetGuide(self.journalSelected)
        if guide then
            self:FollowFromJournal(guide)
            self:UpdateJournal()
        end
    end)
    frame.follow = follow

    -- Sorts : lignes et prix.
    local spells = CreateFrame("Frame", nil, frame)
    spells:SetPoint("TOPLEFT", PADDING, -TOP)
    spells:SetSize(WIDTH - 2 * PADDING, visible * ROW_HEIGHT)
    scrollable(spells, function(step)
        self.spellsOffset = math.max(0, (self.spellsOffset or 0) + step)
        self:UpdateJournal()
    end)
    spells.rows = {}
    for index = 1, visible do
        local text = newText(spells)
        text:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
        text:SetWidth(WIDTH - 2 * PADDING - 120)
        local cost = newText(spells)
        cost:SetJustifyH("RIGHT")
        cost:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)
        spells.rows[index] = { text = text, cost = cost }
    end
    frame.spells = spells

    if UISpecialFrames then
        table.insert(UISpecialFrames, "NextStepJournalFrame")
    end
    frame:SetScript("OnShow", function()
        self:UpdateJournal()
    end)
    self.journal = frame
    return frame
end

function Guide:ShowJournalTab(tab)
    self.journalTab = tab
    self.spellsOffset = 0
    self:UpdateJournal()
end

local function setShown(list, shown)
    for _, region in ipairs(list) do
        region:SetShown(shown)
    end
end

function Guide:UpdateJournal()
    local frame = self.journal
    if not (frame and frame:IsShown()) then
        return
    end
    local tab = self.journalTab or "routes"
    for key, button in pairs(frame.tabs) do
        button:SetEnabled(key ~= tab)
    end
    local routes = tab == "routes"
    setShown(frame.categoryButtons, routes)
    frame.listArea:SetShown(routes)
    frame.detail:SetShown(routes)
    frame.follow:SetShown(routes)
    frame.spells:SetShown(not routes)
    if routes then
        self:UpdateJournalRoutes()
    else
        self:UpdateJournalSpells()
    end
end

function Guide:UpdateJournalRoutes()
    local frame = self.journal
    local categories = self:JournalCategories()
    if not self.journalCategory then
        self.journalCategory = categories[1] and categories[1].key
    end
    for index, button in ipairs(frame.categoryButtons) do
        local category = categories[index]
        if category then
            button.key = category.key
            button.text:SetText(("%s (%d)"):format(category.label, category.count))
            local color = category.key == self.journalCategory and COLORS.title or COLORS.text
            button.text:SetTextColor(color[1], color[2], color[3])
            button:Show()
        else
            button:Hide()
        end
    end

    local rows = self.journalCategory and self:JournalRows(self.journalCategory) or {}
    self.journalRows = rows   -- pour les tests
    local offset = math.min(self.journalOffset or 0, math.max(0, #rows - frame.visible))
    self.journalOffset = offset
    for index, button in ipairs(frame.listButtons) do
        local row = rows[index + offset]
        if row then
            button.guide = row.guide
            if row.header then
                button.text:SetText(row.header)
                button.text:SetTextColor(COLORS.title[1], COLORS.title[2], COLORS.title[3])
                button:EnableMouse(false)
            else
                button.text:SetText("   " .. row.text)
                local color = row.guide.id == self.journalSelected and COLORS.selected or COLORS.text
                button.text:SetTextColor(color[1], color[2], color[3])
                button:EnableMouse(true)
            end
            button:Show()
        else
            button.guide = nil
            button:Hide()
        end
    end

    -- Détail du guide choisi.
    local guide = self.journalSelected and ns.DB:GetGuide(self.journalSelected)
    local lines = guide and self:GuideDetails(guide) or { L["Pick a guide in the list."] }
    local y = 0
    for index, line in ipairs(lines) do
        local text = frame.detailLines[index]
        if not text then
            text = newText(frame.detail)
            text:SetWidth(DETAIL_WIDTH)
            if text.SetWordWrap then
                text:SetWordWrap(true)
            end
            frame.detailLines[index] = text
        end
        text:ClearAllPoints()
        text:SetPoint("TOPLEFT", 0, -y)
        text:SetText(line)
        local color = index == 1 and COLORS.title or COLORS.muted
        text:SetTextColor(color[1], color[2], color[3])
        text:Show()
        y = y + math.max(text:GetStringHeight() or ROW_HEIGHT, ROW_HEIGHT) + 6
    end
    for index = #lines + 1, #frame.detailLines do
        frame.detailLines[index]:Hide()
    end
    frame.follow:SetEnabled(guide ~= nil and self:GuideStatus(guide) ~= "active")
end

function Guide:UpdateJournalSpells()
    local spells = self.journal.spells
    local rows = self:SpellsWindowRows()
    self.spellsWindowRows = rows   -- pour les tests
    local visible = #spells.rows
    local offset = math.min(self.spellsOffset or 0, math.max(0, #rows - visible))
    self.spellsOffset = offset
    for index, row in ipairs(spells.rows) do
        local entry = rows[index + offset]
        if entry then
            row.text:SetText((entry.header and "" or "   ") .. entry.text)
            row.text:SetTextColor(entry.color[1], entry.color[2], entry.color[3])
            row.cost:SetText(entry.cost or "")
            row.text:Show()
            row.cost:Show()
        else
            row.text:Hide()
            row.cost:Hide()
        end
    end
end

-- Ouvre le journal sur un onglet ("routes" ou "spells"), ou le ferme s'il y est déjà.
function Guide:ToggleJournal(tab)
    if not (self.enabled and self.state) then
        ns:Print(L["%s is disabled: enable it in the options."]:format(self.title))
        return
    end
    local frame = self.journal or self:CreateJournal()
    tab = tab or self.journalTab or "routes"
    if frame:IsShown() and (self.journalTab or "routes") == tab then
        frame:Hide()
        return
    end
    self.journalTab = tab
    frame:Show()
    self:UpdateJournal()
end
