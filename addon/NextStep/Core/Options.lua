-- Options de NextStep (docs/DESIGN.md, « Style des fenêtres ») : une fenêtre au style
-- sombre et doré, avec défilement ; une section par module (ceux qui ont un titre) :
-- interrupteur, description, puis ses réglages propres (module:BuildOptions(panel,
-- anchor), qui renvoie le nouvel ancrage).
--
-- Mise en page sans dérive : le titre d'un module est au bord gauche, sa description
-- et ses réglages sont tous en retrait de INDENT, chacun sous le précédent (x = 0).
--
-- La page NextStep des options du jeu (Options > AddOns) ne contient qu'un bouton
-- qui ouvre cette fenêtre.

local _, ns = ...
local L = ns.L

local Options = {}
ns.Options = Options

Options.checks = {}   -- [nom du module] = interrupteur

local WIDTH, HEIGHT = 640, 600
local PADDING = 16
local INDENT = 28
local CONTENT_WIDTH = WIDTH - 2 * PADDING - 14
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function style()
    return ns.Style, ns.Style.COLORS
end

---------------------------------------------------------------------------
-- Éléments de réglage (pour les BuildOptions des modules)
---------------------------------------------------------------------------

-- Case à cocher au style NextStep : boîte sombre bordée d'or, coche dorée.
local function newCheck(parent, size)
    local Style, C = style()
    local check = CreateFrame("CheckButton", nil, parent)
    check:SetSize(size, size)
    local box = Style.Fill(check, C.track)
    box:SetVertexColor(0, 0, 0, 0.7)
    Style.Border(check, C.goldDim)
    local mark = check:CreateTexture(nil, "OVERLAY")
    mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    mark:SetPoint("TOPLEFT", -4, 4)
    mark:SetPoint("BOTTOMRIGHT", 4, -4)
    check:SetCheckedTexture(mark)
    local glow = check:CreateTexture(nil, "HIGHLIGHT")
    glow:SetTexture(WHITE)
    glow:SetAllPoints()
    glow:SetVertexColor(1, 0.82, 0, 0.15)
    return check
end

-- Case à cocher d'un réglage, sous anchor ; get et set lisent et écrivent le réglage.
function Options.AddCheck(panel, anchor, text, get, set)
    local _, C = style()
    local check = newCheck(panel, 16)
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
    check:SetChecked(get())
    check:SetScript("OnClick", function(button)
        set(button:GetChecked() and true or false)
    end)
    panel:HookScript("OnShow", function()
        check:SetChecked(get())
    end)
    local label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", check, "RIGHT", 8, 0)
    label:SetTextColor(C.text[1], C.text[2], C.text[3])
    label:SetText(text)
    check.label = label
    return check
end

-- Curseur, sous anchor : libellé (format(value) donne le texte) puis barre dorée.
-- Renvoie le libellé (ancrage suivant) et le curseur.
function Options.AddSlider(panel, anchor, low, high, step, format, get, set)
    local Style, C = style()
    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
    label:SetTextColor(C.text[1], C.text[2], C.text[3])

    local slider = CreateFrame("Slider", nil, panel)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(220, 16)
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(WHITE)
    track:SetVertexColor(0, 0, 0, 0.7)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(4)
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(WHITE)
    thumb:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
    thumb:SetSize(8, 14)
    slider:SetThumbTexture(thumb)
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    Style.Border(slider, { 0, 0, 0, 0 })

    local function show()
        label:SetText(format(get()))
    end
    slider:SetScript("OnValueChanged", function(_, value)
        set(value)
        show()
    end)
    panel:HookScript("OnShow", function()
        slider:SetValue(get())
        show()
    end)
    slider:SetValue(get())
    show()
    -- L'ancrage suivant est sous le curseur, pas sous le libellé.
    local below = CreateFrame("Frame", nil, panel)
    below:SetSize(1, 1)
    below:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, 2)
    return below, slider, label
end

-- Bouton plat au style NextStep.
function Options.AddButton(panel, text, width, onClick)
    local Style = style()
    return Style.Button(panel, text, width, 22, onClick)
end

---------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------

local function addModule(self, panel, anchor, name, module, first)
    local Style, C = style()
    if not first then
        local line = Style.Line(panel, C.goldDim)
        line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", first and 0 or -INDENT, -14)
        line:SetWidth(CONTENT_WIDTH)
        anchor = line
    end
    local check = newCheck(panel, 20)
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", first and 0 or 0, first and -6 or -14)
    check:SetChecked(module.db.enabled)
    check:SetScript("OnClick", function(button)
        ns.Modules:SetEnabled(name, button:GetChecked() and true or false)
    end)
    self.checks[name] = check

    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    label:SetPoint("LEFT", check, "RIGHT", 10, 0)
    label:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
    label:SetText(module.title)

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", check, "BOTTOMLEFT", INDENT, -6)
    description:SetWidth(CONTENT_WIDTH - INDENT)
    description:SetJustifyH("LEFT")
    description:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    description:SetText(module.description or "")

    -- Tous les réglages du module sont alignés sur la description (retrait INDENT).
    if module.BuildOptions then
        return module:BuildOptions(panel, description) or description
    end
    return description
end

function Options:CreateWindow()
    local Style, C = style()
    local frame = Style.Window("NextStepOptionsFrame", WIDTH, HEIGHT, L["NextStep options"])

    local version = Style.Text(frame.header, "GameFontHighlightSmall", C.muted, "RIGHT")
    version:SetPoint("RIGHT", -40, 0)
    version:SetText(L["Version %s"]:format(ns.version))

    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", PADDING, -36 - PADDING)
    scroll:SetPoint("BOTTOMRIGHT", -PADDING - 10, PADDING)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(CONTENT_WIDTH, 1)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(box, delta)
        local range = math.max(0, (content:GetHeight() or 0) - (box:GetHeight() or 0))
        box:SetVerticalScroll(math.max(0, math.min(range, box:GetVerticalScroll() - delta * 40)))
    end)

    -- Barre de défilement fine, à droite.
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("TOPRIGHT", -PADDING + 4, -36 - PADDING)
    bar:SetPoint("BOTTOMRIGHT", -PADDING + 4, PADDING)
    bar:SetWidth(4)
    Style.Fill(bar, { 0, 0, 0, 0.5 })
    local knob = bar:CreateTexture(nil, "ARTWORK")
    knob:SetTexture(WHITE)
    knob:SetVertexColor(C.goldDim[1], C.goldDim[2], C.goldDim[3], 1)
    knob:SetWidth(4)
    scroll:SetScript("OnVerticalScroll", function(box)
        local total, visible = content:GetHeight() or 1, box:GetHeight() or 1
        if total <= visible then
            knob:Hide()
            return
        end
        knob:Show()
        local height = math.max(20, visible * visible / total)
        local top = (box:GetVerticalScroll() / (total - visible)) * (visible - height)
        knob:ClearAllPoints()
        knob:SetPoint("TOP", 0, -top)
        knob:SetHeight(height)
    end)

    self.panel, self.scroll, self.window = content, scroll, frame
    return frame, content
end

-- Hauteur du contenu, connue une fois la mise en page faite (au premier affichage).
function Options:UpdateHeight()
    local content, last = self.panel, self.last
    if not (content and last and content.GetTop and last.GetBottom) then
        return
    end
    local top, bottom = content:GetTop(), last:GetBottom()
    if top and bottom then
        content:SetHeight(top - bottom + PADDING)
    end
    local script = self.scroll:GetScript("OnVerticalScroll")
    if script then
        script(self.scroll)
    end
end

function Options:Init()
    local frame, content = self:CreateWindow()

    -- Avant les modules : SetScript effacerait les HookScript qu'ils ajoutent.
    -- Un module a pu changer d'état par /ns enable ou /ns disable.
    content:SetScript("OnShow", function()
        for name, check in pairs(self.checks) do
            check:SetChecked(ns.Modules:Get(name).db.enabled)
        end
    end)
    frame:SetScript("OnShow", function()
        self.scroll:SetVerticalScroll(0)
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                self:UpdateHeight()
            end)
        end
    end)

    local anchor = CreateFrame("Frame", nil, content)
    anchor:SetSize(1, 1)
    anchor:SetPoint("TOPLEFT")
    local first = true
    for name, module in ns.Modules:Iterate() do
        if module.title then
            anchor = addModule(self, content, anchor, name, module, first)
            first = false
        end
    end
    self.last = anchor

    self:RegisterGamePage()
end

-- Page NextStep des options du jeu : un bouton qui ouvre la fenêtre de NextStep.
function Options:RegisterGamePage()
    -- [À vérifier] API Settings du client moderne sur Forever.
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then
        return
    end
    local Style, C = style()
    local page = CreateFrame("Frame")
    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("NextStep")
    local version = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    version:SetText(L["Version %s"]:format(ns.version))
    local open = Style.Button(page, L["Open NextStep options"], 240, 28, function()
        if SettingsPanel and HideUIPanel then
            HideUIPanel(SettingsPanel)
        end
        self:Show()
    end)
    open:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -16)
    local hint = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -10)
    hint:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    hint:SetText(L["Also with /ns options or a right-click on the NextStep minimap button."])
    self.gamePage = page
    self.category = Settings.RegisterCanvasLayoutCategory(page, "NextStep")
    Settings.RegisterAddOnCategory(self.category)
end

function Options:Show()
    if self.window then
        self.window:Show()
    end
end

-- Ouvre (ou ferme) la fenêtre des options de NextStep.
function Options:Open()
    if self.window then
        self.window:SetShown(not self.window:IsShown())
    end
end
