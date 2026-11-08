-- Journal du guide (docs/DESIGN.md, « Journal ») : grande fenêtre à onglets.
--
--   Routes : tous les guides du personnage par catégorie (leveling, classe, métiers,
--            réputation, collection...), avec en tête de la catégorie Leveling
--            « Choisis ton chemin » (guides conseillés, guides suivants) ; niveau
--            coloré selon le personnage, avancement, détail du guide choisi et
--            bouton pour le suivre.
--   Sorts de classe : les sorts du maître, maintenant et aux niveaux à venir
--            (SpellsWindow.lua).
--   Onglets ajoutés par d'autres modules (Guide:AddJournalTab) : Donjons et
--            Équipement du module Items.
--   Options : ouvre les options de NextStep.
--
-- Ouvert par le menu du bouton NextStep, /ns journal ou un raccourci clavier ;
-- déplaçable, fermé par Échap ou la croix, listes défilant à la molette.

local _, ns = ...
local L = ns.L

local Guide = ns.Modules:Get("Guide")
local Labels = ns.GuideLabels

local WIDTH, HEIGHT = 880, 520
local PADDING = 12
local CATEGORY_WIDTH = 180
local LIST_WIDTH = 330
local DETAIL_WIDTH = WIDTH - CATEGORY_WIDTH - LIST_WIDTH - 3 * PADDING - 2
local HEADER_HEIGHT = 26
local CARD_HEIGHT = 46
local SPELL_HEIGHT = 26

-- Icônes des catégories (icônes du jeu classique).
local CATEGORY_ICONS = {
    Leveling = "Interface\\Icons\\INV_Misc_Map_01",
    Class = "Interface\\Icons\\INV_Misc_Book_11",
    Professions = "Interface\\Icons\\Trade_BlackSmithing",
    Reputation = "Interface\\Icons\\INV_Shirt_GuildTabard_01",
    Collectibles = "Interface\\Icons\\Ability_Mount_RidingHorse",
    Exploration = "Interface\\Icons\\INV_Misc_Spyglass_02",
    Miscellaneous = "Interface\\Icons\\INV_Misc_QuestionMark",
    Legacy = "Interface\\Icons\\INV_Misc_Book_06",
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
    return self:GuideProgress(guide)
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

-- Part des étapes passées d'un guide (0 à 1), qu'il soit suivi ou non.
function Guide:GuideProgress(guide)
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

local function plainTitle(guide)
    return (Labels.Guide(guide):gsub(" %d+%-%d+$", ""))
end

local function zoneName(guide)
    local zone = guide.zone and ns.DB:GetName("zone", guide.zone, guide)
    return zone ~= "?" and zone or nil
end

local function guideRow(self, guide, level, pick)
    local status = self:GuideStatus(guide)
    local title = plainTitle(guide)
    return {
        guide = guide,
        pick = pick,
        title = title,
        range = self:LevelRange(guide, level),
        status = status,
        progress = status == "active" and self:GuideProgress(guide) or nil,
        sub = zoneName(guide),
        text = ("%s %s%s"):format(self:LevelRange(guide, level), title, statusText(status)),
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
            rows[#rows + 1] = { header = L["Choose your path"], star = true }
            for _, guide in ipairs(picks) do
                rows[#rows + 1] = guideRow(self, guide, level, true)
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

-- Détail d'un guide pour le panneau de droite : titre, tranche, zone, argument,
-- récompenses (nom, icône), guide suivant, avancement.
function Guide:GuideInfo(guide, state)
    state = state or self.state
    local info = {
        title = plainTitle(guide),
        range = self:LevelRange(guide, state and state:Level()),
        zone = zoneName(guide),
        why = guide.why and (ns.DB:Render(guide.why, guide) or guide.why) or nil,
        status = self:GuideStatus(guide),
        progress = self:GuideProgress(guide),
        rewards = {},
    }
    for _, reward in ipairs(guide.reward or {}) do
        if reward.spell then
            info.rewards[#info.rewards + 1] = {
                name = ns.DB:GetName("spell", reward.spell, guide) or reward.spellName or ("#" .. reward.spell),
                icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(reward.spell) or nil,
            }
        elseif reward.item then
            info.rewards[#info.rewards + 1] = {
                name = ns.DB:GetName("item", reward.item, guide) or ("#" .. reward.item),
                icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(reward.item) or nil,
            }
        end
    end
    local nexts = {}
    for _, id in ipairs(guide.next or {}) do
        local nextGuide = ns.DB:GetGuide(id)
        if nextGuide then
            nexts[#nexts + 1] = Labels.Guide(nextGuide)
        end
    end
    info.next = #nexts > 0 and table.concat(nexts, ", ") or nil
    return info
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
    self:StartSideGuide(guide.id)
    self:SetWindowShown(true)
end

---------------------------------------------------------------------------
-- Cadre (style sombre et doré, Core/Style.lua)
---------------------------------------------------------------------------

local Style = ns.Style
local C = Style.COLORS

local function setColor(region, color)
    region:SetTextColor(color[1], color[2], color[3])
end

local function setFill(texture, color)
    texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
end

-- Icône d'une catégorie ; la catégorie Classe prend l'emblème de la classe.
local function categoryIcon(button, key, state)
    local icon = button.icon
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if key == "Class" and state and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[state:Class()] then
        icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        icon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[state:Class()]))
    else
        icon:SetTexture(CATEGORY_ICONS[key] or CATEGORY_ICONS.Miscellaneous)
    end
end

-- Liste à hauteur variable : les lignes à partir de offset, tant qu'il y a de la place.
-- build(row) renvoie un cadre placé (pool géré par l'appelant) et sa hauteur.
local function layout(area, rows, offset, build, finish)
    local y, height = 0, area:GetHeight() or 0
    local index = offset + 1
    while rows[index] and y < height do
        local frame, h = build(rows[index], index - offset)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", area, "TOPLEFT", 0, -y)
        frame:SetPoint("RIGHT", area, "RIGHT", 0, 0)
        frame:Show()
        y = y + h
        index = index + 1
    end
    finish(index - offset - 1)
end

local function hidePool(pool, from)
    for index = from, #pool do
        pool[index]:Hide()
    end
end

-- En-tête de section : texte doré et trait.
local function sectionHeader(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(HEADER_HEIGHT)
    frame.star = frame:CreateTexture(nil, "ARTWORK")
    frame.star:SetSize(14, 14)
    frame.star:SetPoint("LEFT", 2, -2)
    frame.star:SetTexture("Interface\\COMMON\\ReputationStar")
    frame.star:SetTexCoord(0, 0.5, 0, 0.5)
    frame.text = Style.Text(frame, "GameFontNormal", C.gold)
    frame.text:SetPoint("LEFT", frame.star, "RIGHT", 4, 0)
    frame.right = Style.Text(frame, "GameFontHighlightSmall", C.muted, "RIGHT")
    frame.right:SetPoint("RIGHT", -4, -2)
    local line = Style.Line(frame, C.goldDim)
    line:SetPoint("BOTTOMLEFT", 0, 3)
    line:SetPoint("BOTTOMRIGHT", 0, 3)
    return frame
end

-- Carte d'un guide : fond, tranche de niveaux, titre, sous-titre, barre d'avancement.
local function guideCard(self, parent)
    local card = CreateFrame("Button", nil, parent)
    card:SetHeight(CARD_HEIGHT)
    card.bg = Style.Fill(card, C.card)
    card.bg:SetPoint("BOTTOMRIGHT", 0, 3)
    card.edge = card:CreateTexture(nil, "ARTWORK")
    card.edge:SetTexture("Interface\\Buttons\\WHITE8X8")
    card.edge:SetPoint("TOPLEFT")
    card.edge:SetPoint("BOTTOMLEFT", 0, 3)
    card.edge:SetWidth(3)
    card.range = Style.Text(card, "GameFontNormalSmall", C.gold)
    card.range:SetPoint("TOPLEFT", 10, -6)
    card.title = Style.Text(card, "GameFontHighlight", C.text)
    card.title:SetPoint("LEFT", card.range, "RIGHT", 6, 0)
    card.title:SetPoint("RIGHT", -70, 0)
    if card.title.SetWordWrap then
        card.title:SetWordWrap(false)
    end
    card.badge = Style.Text(card, "GameFontNormalSmall", C.blue, "RIGHT")
    card.badge:SetPoint("TOPRIGHT", -8, -6)
    card.sub = Style.Text(card, "GameFontHighlightSmall", C.muted)
    card.sub:SetPoint("BOTTOMLEFT", 10, 9)
    card.sub:SetPoint("RIGHT", -70, 0)
    card.bar = Style.Progress(card, 60, 4)
    card.bar:SetPoint("BOTTOMRIGHT", -8, 11)
    card:SetScript("OnEnter", function(button)
        if button.guide and button.guide.id ~= self.journalSelected then
            setFill(button.bg, C.cardHover)
        end
    end)
    card:SetScript("OnLeave", function(button)
        local selected = button.guide and button.guide.id == self.journalSelected
        setFill(button.bg, selected and C.cardSelected or C.card)
    end)
    card:SetScript("OnClick", function(button)
        if button.guide then
            self.journalSelected = button.guide.id
            self:UpdateJournal()
        end
    end)
    return card
end

local function fillCard(self, card, row)
    card.guide = row.guide
    local selected = row.guide.id == self.journalSelected
    setFill(card.bg, selected and C.cardSelected or C.card)
    setFill(card.edge, selected and C.gold or (row.pick and C.goldDim or C.card))
    card.range:SetText(row.range)
    card.title:SetText(row.title)
    card.sub:SetText(row.sub or "")
    local status = row.status
    if status == "active" then
        card.badge:SetText(L["Following"])
        setColor(card.badge, C.blue)
        card.bar:SetValue(row.progress or 0)
        card.bar:Show()
    elseif status == "done" then
        card.badge:SetText(L["Finished"])
        setColor(card.badge, C.green)
        card.bar:SetValue(1)
        card.bar:Show()
    elseif status > 0 then
        card.badge:SetText(("%d %%"):format(math.floor(status * 100 + 0.5)))
        setColor(card.badge, C.muted)
        card.bar:SetValue(status)
        card.bar:Show()
    else
        card.badge:SetText("")
        card.bar:Hide()
    end
end

---------------------------------------------------------------------------
-- Onglets des autres modules et liste de lignes commune
---------------------------------------------------------------------------

-- Onglet ajouté par un autre module : { key, label, create(parent) -> cadre, update(cadre) }.
-- Le cadre occupe tout le corps du journal (Guide.JOURNAL_BODY).
Guide.journalTabs = {}
function Guide:AddJournalTab(tab)
    self.journalTabs[#self.journalTabs + 1] = tab
end

Guide.JOURNAL_BODY = { width = WIDTH - 2 * PADDING - 2, height = HEIGHT - 37 - 2 * PADDING,
    list = LIST_WIDTH, padding = PADDING }

local ROW_HEIGHT = 22

-- Liste défilante de lignes, pour les onglets des autres modules. SetRows(rows), où
-- chaque ligne est un en-tête { header = true, text, right, color, star } ou
-- { text, right, icon, color, rightColor, indent, selected, tooltip = fn(tooltip) | lien,
--   onClick = fn }.
function Guide.RowList(parent, width, height)
    local list = CreateFrame("Frame", nil, parent)
    list:SetSize(width, height)
    list:EnableMouseWheel(true)
    list.headers, list.lines, list.offset, list.rows = {}, {}, 0, {}
    list:SetScript("OnMouseWheel", function(_, delta)
        list.offset = math.max(0, math.min(list.offset - delta * 3, #list.rows - 1))
        list:Render()
    end)

    local function newLine()
        local line = CreateFrame("Button", nil, list)
        line:SetHeight(ROW_HEIGHT)
        line.bg = Style.Fill(line, C.card)
        line.bg:SetPoint("BOTTOMRIGHT", 0, 2)
        line.icon = Style.Icon(line, 16)
        line.text = Style.Text(line, "GameFontHighlightSmall", C.text)
        line.right = Style.Text(line, "GameFontHighlightSmall", C.text, "RIGHT")
        line.right:SetPoint("RIGHT", -8, 1)
        if line.text.SetWordWrap then
            line.text:SetWordWrap(false)
        end
        line:SetScript("OnEnter", function(frame)
            setFill(frame.bg, C.cardHover)
            local row = frame.row
            if row and row.tooltip and GameTooltip then
                GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
                if type(row.tooltip) == "function" then
                    row.tooltip(GameTooltip)
                else
                    GameTooltip:SetHyperlink(row.tooltip)
                end
                GameTooltip:Show()
            end
        end)
        line:SetScript("OnLeave", function(frame)
            setFill(frame.bg, frame.row and frame.row.selected and C.cardSelected or C.card)
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)
        line:SetScript("OnClick", function(frame)
            if frame.row and frame.row.onClick then
                frame.row.onClick()
            end
        end)
        return line
    end

    function list.Render(self)
        local headers, lines = 0, 0
        layout(self, self.rows, self.offset, function(row)
            if row.header then
                headers = headers + 1
                local header = self.headers[headers] or sectionHeader(self)
                self.headers[headers] = header
                header.text:SetText(row.text)
                setColor(header.text, row.color or C.gold)
                header.star:SetShown(row.star == true)
                header.right:SetText(row.right or "")
                return header, HEADER_HEIGHT
            end
            lines = lines + 1
            local line = self.lines[lines] or newLine()
            self.lines[lines] = line
            line.row = row
            setFill(line.bg, row.selected and C.cardSelected or C.card)
            local indent = 8 + (row.indent or 0) * 14
            line.icon:ClearAllPoints()
            line.icon:SetPoint("LEFT", indent, 1)
            line.icon:SetTexture(row.icon)
            line.icon:SetShown(row.icon ~= nil)
            line.text:ClearAllPoints()
            if row.icon then
                line.text:SetPoint("LEFT", line.icon, "RIGHT", 6, 0)
            else
                line.text:SetPoint("LEFT", line, "LEFT", indent, 1)
            end
            line.text:SetPoint("RIGHT", line.right, "LEFT", -6, 0)
            line.text:SetText(row.text)
            setColor(line.text, row.color or C.text)
            line.right:SetText(row.right or "")
            setColor(line.right, row.rightColor or C.muted)
            return line, ROW_HEIGHT
        end, function()
            hidePool(self.headers, headers + 1)
            hidePool(self.lines, lines + 1)
        end)
    end

    function list.SetRows(self, rows, keepOffset)
        self.rows = rows
        if not keepOffset then
            self.offset = 0
        end
        self.offset = math.max(0, math.min(self.offset, #rows - 1))
        self:Render()
    end
    return list
end

function Guide:CreateJournal()
    local frame = Style.Window("NextStepJournalFrame", WIDTH, HEIGHT, L["NextStep journal"])

    -- Onglets, dans la barre de titre.
    frame.tabs = {}
    local tabs = {
        { key = "routes", label = L["Routes"] },
        { key = "spells", label = L["Class spells"] },
    }
    for _, tab in ipairs(self.journalTabs) do
        tabs[#tabs + 1] = tab
    end
    local previous
    for index = #tabs, 1, -1 do
        local tab = tabs[index]
        local button = Style.Button(frame.header, tab.label, 88, 26, function()
            self:ShowJournalTab(tab.key)
        end)
        button.text:SetFontObject("GameFontNormalSmall")
        if previous then
            button:SetPoint("RIGHT", previous, "LEFT", -4, 0)
        else
            button:SetPoint("RIGHT", frame.header, "RIGHT", -40, 0)
        end
        frame.tabs[tab.key] = button
        previous = button
    end
    local options = Style.Button(frame.header, L["Options"], 80, 26, function()
        ns.Options:Open()
    end)
    options:SetPoint("RIGHT", previous, "LEFT", -12, 0)
    options.text:SetFontObject("GameFontHighlightSmall")

    -- Colonne des catégories.
    local side = CreateFrame("Frame", nil, frame)
    side:SetPoint("TOPLEFT", 1, -37)
    side:SetPoint("BOTTOMLEFT", 1, 1)
    side:SetWidth(CATEGORY_WIDTH)
    Style.Fill(side, C.panel)
    frame.side = side
    frame.categoryButtons = {}
    for index = 1, #CATEGORIES do
        local button = CreateFrame("Button", nil, side)
        button:SetHeight(30)
        button:SetPoint("TOPLEFT", 0, -PADDING - (index - 1) * 32)
        button:SetPoint("RIGHT")
        button.bg = Style.Fill(button, { 0, 0, 0, 0 })
        button.mark = button:CreateTexture(nil, "ARTWORK")
        button.mark:SetTexture("Interface\\Buttons\\WHITE8X8")
        button.mark:SetPoint("TOPLEFT")
        button.mark:SetPoint("BOTTOMLEFT")
        button.mark:SetWidth(3)
        setFill(button.mark, C.gold)
        button.icon = Style.Icon(button, 20)
        button.icon:SetPoint("LEFT", 10, 0)
        button.text = Style.Text(button, "GameFontNormal", C.text)
        button.text:SetPoint("LEFT", button.icon, "RIGHT", 8, 0)
        button.count = Style.Text(button, "GameFontHighlightSmall", C.muted, "RIGHT")
        button.count:SetPoint("RIGHT", -8, 0)
        button:SetScript("OnEnter", function(b)
            if b.key ~= self.journalCategory then
                setFill(b.bg, C.cardHover)
            end
        end)
        button:SetScript("OnLeave", function(b)
            setFill(b.bg, b.key == self.journalCategory and C.cardSelected or { 0, 0, 0, 0 })
        end)
        button:SetScript("OnClick", function(b)
            self.journalCategory = b.key
            self.journalOffset = 0
            self.journalSelected = nil
            self:UpdateJournal()
        end)
        frame.categoryButtons[index] = button
    end

    -- Liste des guides.
    local list = CreateFrame("Frame", nil, frame)
    list:SetPoint("TOPLEFT", CATEGORY_WIDTH + PADDING + 1, -37 - PADDING)
    list:SetSize(LIST_WIDTH, HEIGHT - 37 - 2 * PADDING)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        self.journalOffset = math.max(0, (self.journalOffset or 0) - delta * 2)
        self:UpdateJournal()
    end)
    frame.list, frame.cards, frame.headers = list, {}, {}

    -- Détail du guide choisi.
    local detail = CreateFrame("Frame", nil, frame)
    detail:SetPoint("TOPLEFT", list, "TOPRIGHT", PADDING, 0)
    detail:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)
    Style.Fill(detail, C.panel)
    Style.Border(detail, { 0.3, 0.26, 0.15, 1 })
    frame.detail = detail
    detail.title = Style.Text(detail, "GameFontNormalLarge", C.gold)
    detail.title:SetPoint("TOPLEFT", 12, -12)
    detail.title:SetPoint("RIGHT", -12, 0)
    detail.range = Style.Text(detail, "GameFontNormal", C.text)
    detail.range:SetPoint("TOPLEFT", detail.title, "BOTTOMLEFT", 0, -6)
    detail.zone = Style.Text(detail, "GameFontHighlightSmall", C.muted)
    detail.zone:SetPoint("TOPLEFT", detail.range, "BOTTOMLEFT", 0, -4)
    detail.bar = Style.Progress(detail, DETAIL_WIDTH - 24, 6)
    detail.bar:SetPoint("TOPLEFT", detail.zone, "BOTTOMLEFT", 0, -10)
    detail.progress = Style.Text(detail, "GameFontHighlightSmall", C.muted)
    detail.progress:SetPoint("TOPLEFT", detail.bar, "BOTTOMLEFT", 0, -4)
    local line = Style.Line(detail, C.goldDim)
    line:SetPoint("TOPLEFT", detail.progress, "BOTTOMLEFT", 0, -10)
    line:SetPoint("RIGHT", -12, 0)
    detail.why = Style.Text(detail, "GameFontHighlight", C.text)
    detail.why:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -10)
    detail.why:SetPoint("RIGHT", -12, 0)
    if detail.why.SetWordWrap then
        detail.why:SetWordWrap(true)
    end
    detail.rewardLabel = Style.Text(detail, "GameFontNormalSmall", C.gold)
    detail.rewardLabel:SetPoint("TOPLEFT", detail.why, "BOTTOMLEFT", 0, -12)
    detail.rewardLabel:SetText(L["Reward"])
    detail.rewards = {}
    detail.nextText = Style.Text(detail, "GameFontHighlightSmall", C.muted)
    detail.nextText:SetPoint("RIGHT", -12, 0)
    if detail.nextText.SetWordWrap then
        detail.nextText:SetWordWrap(true)
    end
    detail.empty = Style.Text(detail, "GameFontHighlight", C.muted, "CENTER")
    detail.empty:SetPoint("CENTER")
    detail.empty:SetText(L["Pick a guide in the list."])
    detail.follow = Style.Button(detail, L["Follow this guide"], DETAIL_WIDTH - 24, 28, function()
        local guide = self.journalSelected and ns.DB:GetGuide(self.journalSelected)
        if guide then
            self:FollowFromJournal(guide)
            self:UpdateJournal()
        end
    end)
    detail.follow:SetPoint("BOTTOM", 0, 12)
    frame.follow = detail.follow

    -- Onglet des sorts.
    local spells = CreateFrame("Frame", nil, frame)
    -- Taille fixe : la hauteur est connue dès le premier affichage.
    spells:SetPoint("TOPLEFT", PADDING + 1, -37 - PADDING)
    spells:SetSize(WIDTH - 2 * PADDING - 2, HEIGHT - 37 - 2 * PADDING)
    spells:EnableMouseWheel(true)
    spells:SetScript("OnMouseWheel", function(_, delta)
        self.spellsOffset = math.max(0, (self.spellsOffset or 0) - delta * 3)
        self:UpdateJournal()
    end)
    spells.headers, spells.lines = {}, {}
    frame.spells = spells

    -- Onglets des autres modules.
    frame.extra = {}
    for _, tab in ipairs(self.journalTabs) do
        local body = tab.create(frame)
        body:SetPoint("TOPLEFT", PADDING + 1, -37 - PADDING)
        body:SetSize(WIDTH - 2 * PADDING - 2, HEIGHT - 37 - 2 * PADDING)
        body:Hide()
        frame.extra[tab.key] = { body = body, tab = tab }
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

function Guide:UpdateJournal()
    local frame = self.journal
    if not (frame and frame:IsShown()) then
        return
    end
    local tab = self.journalTab or "routes"
    for key, button in pairs(frame.tabs) do
        button:SetActive(key == tab)
    end
    local routes = tab == "routes"
    frame.side:SetShown(routes)
    frame.list:SetShown(routes)
    frame.detail:SetShown(routes)
    frame.spells:SetShown(tab == "spells")
    for key, extra in pairs(frame.extra) do
        extra.body:SetShown(key == tab)
    end
    if routes then
        self:UpdateJournalRoutes()
    elseif tab == "spells" then
        self:UpdateJournalSpells()
    elseif frame.extra[tab] then
        frame.extra[tab].tab.update(frame.extra[tab].body)
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
            categoryIcon(button, category.key, self.state)
            button.text:SetText(category.label)
            button.count:SetText(category.count)
            local selected = category.key == self.journalCategory
            setFill(button.bg, selected and C.cardSelected or { 0, 0, 0, 0 })
            button.mark:SetShown(selected)
            setColor(button.text, selected and C.gold or C.text)
            button:Show()
        else
            button:Hide()
        end
    end

    local rows = self.journalCategory and self:JournalRows(self.journalCategory) or {}
    self.journalRows = rows   -- pour les tests
    local offset = math.max(0, math.min(self.journalOffset or 0, #rows - 1))
    self.journalOffset = offset
    local cards, headers = 0, 0
    layout(frame.list, rows, offset, function(row)
        if row.header then
            headers = headers + 1
            local header = frame.headers[headers] or sectionHeader(frame.list)
            frame.headers[headers] = header
            header.text:SetText(row.header)
            header.star:SetShown(row.star == true)
            header.right:SetText(row.count or "")
            return header, HEADER_HEIGHT
        end
        cards = cards + 1
        local card = frame.cards[cards] or guideCard(self, frame.list)
        frame.cards[cards] = card
        fillCard(self, card, row)
        return card, CARD_HEIGHT
    end, function()
        hidePool(frame.cards, cards + 1)
        hidePool(frame.headers, headers + 1)
    end)

    self:UpdateJournalDetail()
end

function Guide:UpdateJournalDetail()
    local detail = self.journal.detail
    local guide = self.journalSelected and ns.DB:GetGuide(self.journalSelected)
    local parts = { detail.title, detail.range, detail.zone, detail.bar, detail.progress, detail.why,
        detail.rewardLabel, detail.nextText, detail.follow }
    for _, region in ipairs(parts) do
        region:SetShown(guide ~= nil)
    end
    detail.empty:SetShown(guide == nil)
    for _, reward in ipairs(detail.rewards) do
        reward:Hide()
    end
    if not guide then
        return
    end
    local info = self:GuideInfo(guide)
    detail.title:SetText(info.title)
    detail.range:SetText(L["Levels %s"]:format(info.range))
    detail.zone:SetText(info.zone or "")
    local status = info.status
    local value = status == "done" and 1 or (status == "active" and (info.progress or 0)) or status
    detail.bar:SetValue(value)
    if status == "active" then
        detail.progress:SetText("|cff66ccff" .. L["You are following this guide."] .. "|r")
    elseif status == "done" then
        detail.progress:SetText("|cff66e666" .. L["You finished this guide."] .. "|r")
    else
        detail.progress:SetText(L["Progress: %d %%"]:format(math.floor(value * 100 + 0.5)))
    end
    detail.why:SetText(info.why or "")

    -- Récompenses : icône et nom, une par ligne.
    local anchor = detail.rewardLabel
    detail.rewardLabel:SetShown(#info.rewards > 0)
    for index, reward in ipairs(info.rewards) do
        local line = detail.rewards[index]
        if not line then
            line = CreateFrame("Frame", nil, detail)
            line:SetSize(DETAIL_WIDTH - 24, 22)
            line.icon = Style.Icon(line, 18)
            line.icon:SetPoint("LEFT")
            line.text = Style.Text(line, "GameFontHighlightSmall", C.text)
            line.text:SetPoint("LEFT", line.icon, "RIGHT", 6, 0)
            line.text:SetPoint("RIGHT")
            detail.rewards[index] = line
        end
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, index == 1 and -4 or -2)
        line.icon:SetTexture(reward.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        line.text:SetText(reward.name)
        line:Show()
        anchor = line
    end
    detail.nextText:ClearAllPoints()
    detail.nextText:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
    detail.nextText:SetPoint("RIGHT", -12, 0)
    detail.nextText:SetText(info.next and L["Then: %s"]:format(info.next) or "")
    detail.follow:SetLabel(status == "active" and L["Following"] or L["Follow this guide"])
    detail.follow:SetEnabled(status ~= "active")
end

local function spellIcon(id)
    return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id) or "Interface\\Icons\\INV_Misc_Book_09"
end

function Guide:UpdateJournalSpells()
    local spells = self.journal.spells
    local rows = self:SpellsWindowRows()
    self.spellsWindowRows = rows   -- pour les tests
    local offset = math.max(0, math.min(self.spellsOffset or 0, #rows - 1))
    self.spellsOffset = offset
    local headers, lines = 0, 0
    layout(spells, rows, offset, function(row)
        if row.header then
            headers = headers + 1
            local header = spells.headers[headers] or sectionHeader(spells)
            spells.headers[headers] = header
            header.text:SetText(row.text)
            setColor(header.text, row.color)
            header.star:Hide()
            header.right:SetText(row.cost or "")
            return header, HEADER_HEIGHT
        end
        lines = lines + 1
        local line = spells.lines[lines]
        if not line then
            line = CreateFrame("Frame", nil, spells)
            line:SetHeight(SPELL_HEIGHT)
            line.bg = Style.Fill(line, C.card)
            line.bg:SetPoint("BOTTOMRIGHT", 0, 2)
            line.icon = Style.Icon(line, 18)
            line.icon:SetPoint("LEFT", 8, 1)
            line.text = Style.Text(line, "GameFontHighlight", C.text)
            line.text:SetPoint("LEFT", line.icon, "RIGHT", 8, 0)
            line.cost = Style.Text(line, "GameFontHighlightSmall", C.text, "RIGHT")
            line.cost:SetPoint("RIGHT", -10, 1)
            -- Infobulle du sort au survol.
            line:EnableMouse(true)
            line:SetScript("OnEnter", function(frame)
                setFill(frame.bg, C.cardHover)
                if frame.spellID and GameTooltip then
                    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
                    if GameTooltip.SetSpellByID then
                        GameTooltip:SetSpellByID(frame.spellID)
                    else
                        GameTooltip:SetHyperlink("spell:" .. frame.spellID)
                    end
                    if frame.costText then
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine(L["Trainer cost: %s"]:format(frame.costText), 1, 0.82, 0)
                    end
                    GameTooltip:Show()
                end
            end)
            line:SetScript("OnLeave", function(frame)
                setFill(frame.bg, C.card)
                if GameTooltip then
                    GameTooltip:Hide()
                end
            end)
            spells.lines[lines] = line
        end
        line.spellID, line.costText = row.id, row.cost
        line.icon:SetTexture(row.id and spellIcon(row.id) or nil)
        line.text:SetText(row.text)
        setColor(line.text, row.color)
        line.cost:SetText(row.cost or "")
        return line, SPELL_HEIGHT
    end, function()
        hidePool(spells.headers, headers + 1)
        hidePool(spells.lines, lines + 1)
    end)
end

-- Ouvre le journal sur un onglet ("routes", "spells" ou celui d'un autre module), ou le
-- ferme s'il y est déjà.
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
