-- Panneau d'options dans le menu Options > AddOns du jeu : une case par module
-- (ceux qui ont un titre), sa description, puis ses réglages propres
-- (module:BuildOptions(panel, anchor), qui renvoie le nouvel ancrage).

local _, ns = ...
local L = ns.L

local Options = {}
ns.Options = Options

Options.checks = {}   -- [nom du module] = case à cocher

-- Case à cocher d'un réglage de module, sous anchor ; get et set lisent et écrivent
-- le réglage. Pour les BuildOptions des modules.
function Options.AddCheck(panel, anchor, text, get, set)
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    check:SetChecked(get())
    check:SetScript("OnClick", function(button)
        set(button:GetChecked() and true or false)
    end)
    panel:HookScript("OnShow", function()
        check:SetChecked(get())
    end)
    local label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    label:SetText(text)
    return check
end

local function addModule(self, panel, anchor, name, module)
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
    check:SetChecked(module.db.enabled)
    check:SetScript("OnClick", function(button)
        ns.Modules:SetEnabled(name, button:GetChecked() and true or false)
    end)
    self.checks[name] = check

    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    label:SetText(module.title)

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    description:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 30, 0)
    description:SetWidth(560)
    description:SetJustifyH("LEFT")
    description:SetText(module.description or "")

    if module.BuildOptions then
        return module:BuildOptions(panel, description) or description
    end
    return description
end

function Options:Init()
    -- [À vérifier] API Settings du client moderne sur Forever.
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then
        return
    end

    local panel = CreateFrame("Frame")
    self.panel = panel

    -- Avant les modules : SetScript effacerait les HookScript qu'ils ajoutent.
    -- Un module a pu changer d'état par /ns enable ou /ns disable.
    panel:SetScript("OnShow", function()
        for name, check in pairs(self.checks) do
            check:SetChecked(ns.Modules:Get(name).db.enabled)
        end
    end)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("NextStep")

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    version:SetText(L["Version %s"]:format(ns.version))

    local anchor = version
    for name, module in ns.Modules:Iterate() do
        if module.title then
            anchor = addModule(self, panel, anchor, name, module)
        end
    end

    self.category = Settings.RegisterCanvasLayoutCategory(panel, "NextStep")
    Settings.RegisterAddOnCategory(self.category)
end

function Options:Open()
    if self.category then
        Settings.OpenToCategory(self.category:GetID())
    end
end
