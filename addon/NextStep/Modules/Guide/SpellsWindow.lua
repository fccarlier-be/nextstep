-- Fenêtre des sorts de classe (docs/DESIGN.md, « Sorts à apprendre ») : ce que le
-- maître a maintenant pour le personnage, puis chaque niveau à venir qui apporte de
-- nouveaux sorts, avec le prix de chacun et le total du niveau. Ouverte par le menu
-- du bouton NextStep ou /ns spells ; déplaçable, fermée par Échap ou la croix,
-- défilement à la molette.

local _, ns = ...
local L = ns.L

local Guide = ns.Modules:Get("Guide")

local WIDTH, HEIGHT = 340, 420
local PADDING = 12
local HEADER = 30
local ROW_HEIGHT = 16

local COLORS = {
    title = { 1, 0.82, 0 },
    now = { 0.4, 1, 0.4 },
    short = { 1, 0.5, 0.25 },
    text = { 1, 1, 1 },
    muted = { 0.65, 0.65, 0.65 },
}

local function spellLabel(id)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    name = name or ns.DB:GetName("spell", id) or ("#" .. id)
    local rank = C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id)
    if rank and rank ~= "" then
        return ("%s (%s)"):format(name, rank)
    end
    return name
end

-- Lignes de la fenêtre : { text, cost, color }, d'après le plan des sorts.
function Guide:SpellsWindowRows(state)
    state = state or self.state
    local plan = self:SpellPlan(state)
    local rows = {}
    if not plan then
        rows[1] = { text = L["No trainer data for your class."], color = COLORS.muted }
        return rows
    end
    local money = state:Money() or 0
    for index, group in ipairs(plan) do
        local header
        if index == 1 then
            header = #group.spells > 0 and L["Now: %d spells"]:format(#group.spells)
                or L["Nothing to learn at your trainer for now."]
        else
            header = L["Level %d: %d new spells"]:format(group.level, #group.spells)
        end
        rows[#rows + 1] = {
            text = header,
            cost = #group.spells > 0 and Guide.FormatMoney(group.total) or nil,
            color = COLORS.title,
            header = true,
        }
        local color = COLORS.text
        if index == 1 then
            color = money >= group.total and COLORS.now or COLORS.short
        end
        for _, spell in ipairs(group.spells) do
            rows[#rows + 1] = { text = spellLabel(spell.id), cost = Guide.FormatMoney(spell.cost), color = color }
        end
    end
    return rows
end

---------------------------------------------------------------------------
-- Cadre
---------------------------------------------------------------------------

local function createRow(parent)
    local row = {}
    row.text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetJustifyH("LEFT")
    row.cost = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.cost:SetJustifyH("RIGHT")
    return row
end

function Guide:CreateSpellsWindow()
    local frame = CreateFrame("Frame", "NextStepSpellsFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", -200, 40)
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
        frame:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
        frame:SetBackdropBorderColor(0.6, 0.5, 0.3, 1)
    end
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", PADDING, -10)
    title:SetText(L["Class spells"])
    frame.title = title

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    -- Défilement à la molette : décalage en lignes.
    frame.offset = 0
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        frame.offset = math.max(0, frame.offset - delta * 3)
        self:UpdateSpellsWindow()
    end)
    frame:SetScript("OnShow", function()
        frame.offset = 0
        self:UpdateSpellsWindow()
    end)

    frame.rows = {}
    frame.visibleRows = math.floor((HEIGHT - HEADER - PADDING) / ROW_HEIGHT)
    for index = 1, frame.visibleRows do
        local row = createRow(frame)
        local y = -HEADER - (index - 1) * ROW_HEIGHT
        row.text:SetPoint("TOPLEFT", PADDING, y)
        row.text:SetPoint("RIGHT", frame, "RIGHT", -PADDING - 90, 0)
        row.cost:SetPoint("TOPRIGHT", -PADDING, y)
        frame.rows[index] = row
    end

    -- Échap ferme la fenêtre.
    if UISpecialFrames then
        table.insert(UISpecialFrames, "NextStepSpellsFrame")
    end
    self.spellsWindow = frame
    return frame
end

function Guide:UpdateSpellsWindow()
    local frame = self.spellsWindow
    if not (frame and frame:IsShown()) then
        return
    end
    local rows = self:SpellsWindowRows()
    self.spellsWindowRows = rows   -- pour les tests
    local maxOffset = math.max(0, #rows - frame.visibleRows)
    frame.offset = math.min(frame.offset or 0, maxOffset)
    for index, row in ipairs(frame.rows) do
        local entry = rows[index + frame.offset]
        if entry then
            local indent = entry.header and 0 or 10
            row.text:SetPoint("TOPLEFT", PADDING + indent, -HEADER - (index - 1) * ROW_HEIGHT)
            row.text:SetText(entry.text)
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

function Guide:ToggleSpellsWindow()
    if not (self.enabled and self.state) then
        ns:Print(L["%s is disabled: enable it in the options."]:format(self.title))
        return
    end
    local frame = self.spellsWindow or self:CreateSpellsWindow()
    frame:SetShown(not frame:IsShown())
end
