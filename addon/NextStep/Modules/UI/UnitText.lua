-- Valeurs de vie et de ressources (docs/DESIGN.md, « Valeurs de vie et de ressources »).
--
-- Sur Forever, la santé des unités est une valeur secrète, même celle du joueur hors
-- combat (rapport de diagnostic du 2026-11-05) : aucun calcul ni comparaison, seulement
-- l'affichage. D'où :
--   cadres d'unité (joueur, cible, familier, groupe) : le texte de statut natif de
--     Blizzard (CVars statusText et statusTextDisplay), qui sait afficher ces valeurs ;
--     les réglages d'origine sont rendus à la désactivation ;
--   barres de nom : un texte de NextStep sous la barre, qui reçoit les valeurs telles
--     quelles. Plusieurs formes sont essayées, chacune protégée (pcall) : la première qui
--     passe est gardée.
--
-- [À vérifier] sur Forever : string.format et AbbreviateNumbers sur une valeur secrète ;
-- UnitHealthPercent ; barres de nom verrouillées (alliés en donjon : IsForbidden).

local _, ns = ...
local L = ns.L

local UnitText = ns.Modules:New("UnitText", {
    title = L["Health and power values"],
    description = L["Health and power values on unit frames (Blizzard's status text) and health on nameplates."],
    defaults = {
        frames = true,
        framesFormat = "BOTH",     -- NUMERIC, PERCENT, BOTH (texte natif)
        nameplates = true,
        plateFormat = "short",     -- short : 4,5k (75 %) ; full : 4 523 / 6 000 ; percent : 75 %
        saved = nil,               -- CVars d'origine : { statusText, statusTextDisplay }
    },
    conflicts = { "Plater", "Kui_Nameplates", "TidyPlates_ThreatPlates" },
})

local FRAME_FORMATS = { "BOTH", "NUMERIC", "PERCENT" }
local PLATE_FORMATS = { "short", "full", "percent" }

---------------------------------------------------------------------------
-- Cadres d'unité : texte de statut natif
---------------------------------------------------------------------------

local function getCVar(name)
    return C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(name)
end

local function setCVar(name, value)
    if C_CVar and C_CVar.SetCVar then
        pcall(C_CVar.SetCVar, name, value)
    end
end

function UnitText:ApplyFrames()
    if not (self.enabled and self.db.frames) then
        self:RestoreFrames()
        return
    end
    if not self.db.saved then
        self.db.saved = { statusText = getCVar("statusText"), statusTextDisplay = getCVar("statusTextDisplay") }
    end
    setCVar("statusText", "1")
    setCVar("statusTextDisplay", self.db.framesFormat)
end

-- Rend les réglages d'origine du joueur.
function UnitText:RestoreFrames()
    local saved = self.db.saved
    if saved then
        if saved.statusText then
            setCVar("statusText", saved.statusText)
        end
        if saved.statusTextDisplay then
            setCVar("statusTextDisplay", saved.statusTextDisplay)
        end
        self.db.saved = nil
    end
end

---------------------------------------------------------------------------
-- Barres de nom
---------------------------------------------------------------------------

-- Formes du texte, de la plus riche à la plus simple ; chacune peut échouer sur une
-- valeur secrète (le pcall la passe alors).
local FORMS = {
    short = {
        function(unit)
            return ("%s (%s%%)"):format(AbbreviateNumbers(UnitHealth(unit)),
                ("%d"):format(UnitHealthPercent(unit, true, CurveConstants and CurveConstants.ScaleTo100)))
        end,
        function(unit) return AbbreviateNumbers(UnitHealth(unit)) end,
    },
    full = {
        function(unit)
            return ("%s / %s"):format(BreakUpLargeNumbers(UnitHealth(unit)), BreakUpLargeNumbers(UnitHealthMax(unit)))
        end,
        function(unit) return ("%s / %s"):format(UnitHealth(unit), UnitHealthMax(unit)) end,
    },
    percent = {
        function(unit)
            return ("%d%%"):format(UnitHealthPercent(unit, true, CurveConstants and CurveConstants.ScaleTo100))
        end,
    },
}
UnitText.FORMS = FORMS

-- Texte de santé d'une unité dans le format donné (nil si aucune forme ne passe).
function UnitText.HealthText(unit, format)
    for _, form in ipairs(FORMS[format] or FORMS.short) do
        local ok, text = pcall(form, unit)
        if ok and text ~= nil then
            return text
        end
    end
    -- Dernier recours : les formes plus simples des autres formats.
    for _, other in ipairs(PLATE_FORMATS) do
        if other ~= format then
            for _, form in ipairs(FORMS[other]) do
                local ok, text = pcall(form, unit)
                if ok and text ~= nil then
                    return text
                end
            end
        end
    end
end

function UnitText:PlateText(unit, plate)
    if not plate or (plate.IsForbidden and plate:IsForbidden()) then
        return nil
    end
    local text = self.texts[plate]
    if not text then
        local holder = CreateFrame("Frame", nil, plate)
        holder:SetAllPoints()
        text = holder:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Small")
        text:SetPoint("TOP", plate, "BOTTOM", 0, 6)
        self.texts[plate] = text
        self.holders[plate] = holder
    end
    self.units[unit] = plate
    return text
end

function UnitText:UpdatePlate(unit)
    local plate = self.units[unit]
    local text = plate and self.texts[plate]
    if not text then
        return
    end
    if not (self.enabled and self.db.nameplates) then
        text:SetText("")
        return
    end
    text:SetText(UnitText.HealthText(unit, self.db.plateFormat) or "")
end

function UnitText:OnPlateAdded(unit)
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
    local ok, text = pcall(self.PlateText, self, unit, plate)
    if ok and text then
        self.holders[plate]:Show()
        self:UpdatePlate(unit)
    end
end

function UnitText:OnPlateRemoved(unit)
    local plate = self.units[unit]
    if plate and self.holders[plate] then
        self.texts[plate]:SetText("")
        self.holders[plate]:Hide()
    end
    self.units[unit] = nil
end

function UnitText:RefreshPlates()
    for unit in pairs(self.units) do
        self:UpdatePlate(unit)
    end
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function UnitText:OnInitialize()
    self.texts, self.holders, self.units = {}, {}, {}
end

function UnitText:OnEnable()
    self:ApplyFrames()
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, _, unit)
        self:OnPlateAdded(unit)
    end)
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED", function(_, _, unit)
        self:OnPlateRemoved(unit)
    end)
    for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH" }) do
        self:RegisterEvent(event, function(_, _, unit)
            if unit and self.units[unit] then
                self:UpdatePlate(unit)
            end
        end)
    end
end

function UnitText:OnDisable()
    self:RestoreFrames()
    for unit in pairs(self.units) do
        self:OnPlateRemoved(unit)
    end
end

-- Choix suivant dans une liste (bouton des options).
local function nextOf(list, value)
    for index, item in ipairs(list) do
        if item == value then
            return list[index % #list + 1]
        end
    end
    return list[1]
end

local FRAME_LABELS = { BOTH = L["value and percent"], NUMERIC = L["value"], PERCENT = L["percent"] }
local PLATE_LABELS = { short = L["short (4.5k)"], full = L["full (4,523 / 6,000)"], percent = L["percent"] }

function UnitText:BuildOptions(panel, anchor)
    local Options = ns.Options
    local below = Options.AddCheck(panel, anchor, L["Show values on unit frames (Blizzard's status text)"],
        function() return self.db.frames end,
        function(value)
            self.db.frames = value
            self:ApplyFrames()
        end)
    local frames = Options.AddButton(panel, L["Unit frames: %s"]:format(FRAME_LABELS[self.db.framesFormat]), 260,
        function(button)
            self.db.framesFormat = nextOf(FRAME_FORMATS, self.db.framesFormat)
            button:SetLabel(L["Unit frames: %s"]:format(FRAME_LABELS[self.db.framesFormat]))
            self:ApplyFrames()
        end)
    frames:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -8)
    below = Options.AddCheck(panel, frames, L["Show health on nameplates"],
        function() return self.db.nameplates end,
        function(value)
            self.db.nameplates = value
            self:RefreshPlates()
        end)
    local plates = Options.AddButton(panel, L["Nameplates: %s"]:format(PLATE_LABELS[self.db.plateFormat]), 260,
        function(button)
            self.db.plateFormat = nextOf(PLATE_FORMATS, self.db.plateFormat)
            button:SetLabel(L["Nameplates: %s"]:format(PLATE_LABELS[self.db.plateFormat]))
            self:RefreshPlates()
        end)
    plates:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -8)
    return plates
end
