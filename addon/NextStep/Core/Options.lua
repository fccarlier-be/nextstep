-- Panneau d'options dans le menu Options > AddOns du jeu.
-- Squelette : les réglages des modules s'y ajouteront au fil des phases.

local _, ns = ...
local L = ns.L

local Options = {}
ns.Options = Options

function Options:Init()
    -- [À vérifier] API Settings du client moderne sur Forever.
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then
        return
    end

    local panel = CreateFrame("Frame")

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("NextStep")

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    version:SetText(L["Version %s"]:format(ns.version))

    self.category = Settings.RegisterCanvasLayoutCategory(panel, "NextStep")
    Settings.RegisterAddOnCategory(self.category)
end

function Options:Open()
    if self.category then
        Settings.OpenToCategory(self.category:GetID())
    end
end
