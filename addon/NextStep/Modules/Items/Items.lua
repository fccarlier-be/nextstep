-- Module Items (docs/DESIGN.md, « 7. Items ») : conseils d'équipement pour le
-- personnage qui monte en niveau. Le score vient de Score.lua ; ce fichier tient les
-- réglages, la spécialisation, l'infobulle des objets et la commande /ns gear.
-- Récompenses de quête : Rewards.lua ; alerte d'amélioration : Alert.lua ; onglets
-- Donjons et Équipement du journal : Dungeons.lua et Upgrades.lua.
--
-- Rien n'est jamais équipé ni choisi automatiquement.

local _, ns = ...
local L = ns.L
local Score = ns.Score

local Items = ns.Modules:New("Items", {
    title = L["Gear upgrades"],
    description = L["Scores gear for your class and spec: gain or loss in item tooltips, the quest reward "
        .. "to take, and an alert when an upgrade lands in your bags."],
    defaults = {
        tooltip = true,
        rewards = true,
        alert = true,
        threshold = 2,        -- pour cent : gain minimal d'une amélioration
        alertDuration = 20,   -- secondes avant la fermeture de l'alerte (0 : jamais)
        spec = {},            -- [classe] = "auto" | clé de spécialisation
        alertPoint = nil,     -- position de l'alerte déplacée
        learnedLoot = {},     -- [donjon] = { [objet] = PNJ (0 : inconnu) } : butin vu en jeu
    },
    charDefaults = { alerted = {} },   -- [lien] = true : déjà signalé
})

-- Noms des spécialisations (clés de Data/Imported/Polestar/Gear.lua).
local SPEC_NAMES = {
    arms = L["Arms"], fury = L["Fury"], protection = L["Protection"], holy = L["Holy"],
    retribution = L["Retribution"], beastmastery = L["Beast Mastery"], marksmanship = L["Marksmanship"],
    survival = L["Survival"], assassination = L["Assassination"], combat = L["Combat"],
    subtlety = L["Subtlety"], discipline = L["Discipline"], shadow = L["Shadow"],
    elemental = L["Elemental"], enhancement = L["Enhancement"], restoration = L["Restoration"],
    arcane = L["Arcane"], fire = L["Fire"], frost = L["Frost"], affliction = L["Affliction"],
    demonology = L["Demonology"], destruction = L["Destruction"], balance = L["Balance"], feral = L["Feral"],
}
Items.SPEC_NAMES = SPEC_NAMES

local REASONS = {
    class = L["reserved for other classes"],
    armor = L["your class cannot wear it"],
    weapon = L["your class cannot use this weapon"],
    skill = L["weapon skill not learned"],
    dualwield = L["dual wield not learned"],
}

local GREEN, RED, GREY, GOLD = { 0.4, 0.9, 0.4 }, { 1, 0.35, 0.3 }, { 0.6, 0.6, 0.62 }, { 1, 0.82, 0 }

function Items.SpecName(key)
    return key and (SPEC_NAMES[key] or key) or "?"
end

-- Gain en quelques caractères : « +12 % », « -8 % », « +<1 % » ; au-delà du double,
-- « grosse amélioration ».
function Items.GainText(pct)
    if pct >= 100 then
        return L["big upgrade"]
    end
    local rounded = math.floor(math.abs(pct) + 0.5)
    if rounded == 0 then
        return pct >= 0 and "+<1 %" or "-<1 %"
    end
    return ("%s%d %%"):format(pct >= 0 and "+" or "-", rounded)
end

---------------------------------------------------------------------------
-- Spécialisation
---------------------------------------------------------------------------

function Items:ApplySpecChoice()
    Score.choices = self.db.spec
    Score.Invalidate("spec")
end

-- « Combat (talents) », « Combat (choisie) », « Combat (par défaut) ».
function Items:SpecLabel()
    local key, source = Score.Spec()
    if not key then
        return L["no weights for your class"]
    end
    local origin = ({ setting = L["chosen"], talents = L["talents"], default = L["default"] })[source] or source
    return ("%s (%s)"):format(Items.SpecName(key), origin)
end

-- Fait défiler le choix : automatique, puis chaque spécialisation de la classe.
function Items:CycleSpec()
    local class = Score.Player().class
    local specs = class and Score.Specs(class) or {}
    if #specs == 0 then
        return
    end
    local current = self.db.spec[class] or "auto"
    local nextKey = specs[1].key
    if current ~= "auto" then
        nextKey = "auto"
        for index, spec in ipairs(specs) do
            if spec.key == current then
                nextKey = specs[index + 1] and specs[index + 1].key or "auto"
            end
        end
    end
    self.db.spec[class] = nextKey
    self:ApplySpecChoice()
    self:Refresh()
end

function Items:SpecButtonLabel()
    local class = Score.Player().class
    local choice = class and self.db.spec[class] or "auto"
    if choice == "auto" then
        return L["Spec: automatic (%s)"]:format(Items.SpecName((Score.Spec())))
    end
    return L["Spec: %s"]:format(Items.SpecName(choice))
end

---------------------------------------------------------------------------
-- Infobulle
---------------------------------------------------------------------------

-- Ligne de l'infobulle d'un objet : texte et couleur, ou nil (pas un équipement).
function Items:TooltipLine(link)
    local result = Score.Compare(link)
    if not result then
        return nil
    end
    if not result.usable then
        return L["NextStep: %s"]:format(REASONS[result.reason] or L["not usable"]), GREY
    end
    local spec = Items.SpecName((Score.Spec()))
    if result.equipped then
        return L["NextStep (%s): equipped"]:format(spec), GOLD
    end
    local level = Score.Player().level
    local suffix = ""
    if (result.minLevel or 0) > level then
        suffix = " " .. L["(level %d)"]:format(result.minLevel)
    end
    if result.empty then
        return L["NextStep (%s): empty slot"]:format(spec) .. suffix, GREEN
    end
    if not result.pct then
        return nil
    end
    local color = result.delta > 0 and GREEN or (result.delta < 0 and RED or GREY)
    return L["NextStep (%s): %s"]:format(spec, Items.GainText(result.pct)) .. suffix, color
end

local function tooltipLink(tooltip, data)
    if tooltip.GetItem then
        local ok, _, link = pcall(tooltip.GetItem, tooltip)
        if ok and ns.Usable(link) and type(link) == "string" then
            return link
        end
    end
    return data and ns.Usable(data.hyperlink) and data.hyperlink or nil
end

function Items:HookTooltip()
    if self.tooltipHooked or not (TooltipDataProcessor and Enum and Enum.TooltipDataType) then
        return
    end
    self.tooltipHooked = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if not (self.enabled and self.db.tooltip) then
            return
        end
        local link = tooltipLink(tooltip, data)
        if not link then
            return
        end
        local text, color = self:TooltipLine(link)
        if text then
            tooltip:AddLine(text, color[1], color[2], color[3])
        end
    end)
end

---------------------------------------------------------------------------
-- Commande /ns gear [lien]
---------------------------------------------------------------------------

function Items:Command(rest)
    rest = rest and rest:match("^%s*(.-)%s*$") or ""
    if rest == "" then
        local _, _, band = Score.Spec()
        ns:Print(L["Gear weights: %s"]:format(self:SpecLabel())
            .. (band and (" — " .. L["up to level %d, %s"]:format(band.upTo, band.source)) or ""))
        return
    end
    local text = self:TooltipLine(rest)
    ns:Print(text or L["Not gear, or its stats are not known yet."])
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

-- Une réponse a pu changer : caches, puis ce qui est affiché.
function Items:Invalidate(what)
    Score.Invalidate(what)
    -- La liste « à ne pas rater » ne dépend que de l'équipement, du niveau, de la
    -- spécialisation et des quêtes faites.
    self.upcoming = nil
    self:Refresh()
end

function Items:Refresh()
    if self.specButton then
        self.specButton:SetLabel(self:SpecButtonLabel())
    end
    if self.RefreshRewards then
        self:RefreshRewards()
    end
    -- Onglets du journal : une seule mise à jour pour une rafale d'événements.
    if self.RefreshJournal and not self.journalPending then
        if C_Timer and C_Timer.After then
            self.journalPending = true
            C_Timer.After(0.3, function()
                self.journalPending = false
                self:RefreshJournal()
            end)
        else
            self:RefreshJournal()
        end
    end
end

-- Ouvre le journal sur un onglet du module (« dungeons » ou « gear »).
function Items:OpenJournal(tab)
    local guide = ns.Modules:Get("Guide")
    if guide and guide.enabled then
        guide:ToggleJournal(tab)
    else
        ns:Print(L["%s is disabled: enable it in the options."]:format(guide and guide.title or "Guide"))
    end
end

function Items:OnInitialize()
    ns.Slash:Add("gear", function(rest)
        if self.enabled then
            self:Command(rest)
        else
            ns:Print(L["%s is disabled: enable it in the options."]:format(self.title))
        end
    end, L["Gear: spec and weights in use, or compare an item link"])
    ns.Slash:Add("dungeons", function()
        self:OpenJournal("dungeons")
    end, L["Dungeons: quests to take before going in, and boss loot"])
end

function Items:OnEnable()
    self:ApplySpecChoice()
    Score.Invalidate("player")
    self:HookTooltip()
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function() self:Invalidate("equipment") end)
    self:RegisterEvent("PLAYER_LEVEL_UP", function()
        self:Invalidate("level")
        -- Le niveau du client change juste après l'événement : nouvelle passe des sacs.
        if C_Timer and C_Timer.After then
            C_Timer.After(1, function()
                Score.Invalidate("level")
                self:ScanBags()
            end)
        end
    end)
    -- Objet reçu du serveur : seul son score est revu, les listes gardent leur ordre.
    self:RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, _, id)
        Score.ItemReceived(id)
        self:Refresh()
    end)
    self:RegisterEvent("SKILL_LINES_CHANGED", function() self:Invalidate("skills") end)
    for _, event in ipairs({ "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED" }) do
        self:RegisterEvent(event, function() self:Invalidate("spec") end)
    end
    self:RegisterEvent("LOOT_OPENED", function()
        ns.SafeCall(self.LearnLoot, self)
    end)
    self:RegisterEvent("QUEST_TURNED_IN", function()
        self.upcoming = nil
        self:Refresh()
    end)
    self:RegisterEvent("BAG_UPDATE_DELAYED", function()
        Score.Invalidate("bags")
        self:ScanBags()
    end)
    self:EnableRewards()
end

function Items:OnDisable()
    self:HideAlert()
    self:DisableRewards()
end

function Items:BuildOptions(panel, anchor)
    local Options = ns.Options
    local below = Options.AddCheck(panel, anchor, L["Gain or loss in item tooltips"],
        function() return self.db.tooltip end,
        function(value) self.db.tooltip = value end)
    below = Options.AddCheck(panel, below, L["Advise the quest reward to take"],
        function() return self.db.rewards end,
        function(value)
            self.db.rewards = value
            self:RefreshRewards()
        end)
    below = Options.AddCheck(panel, below, L["Alert when an upgrade lands in your bags"],
        function() return self.db.alert end,
        function(value)
            self.db.alert = value
            if not value then
                self:HideAlert()
            end
        end)
    below = Options.AddSlider(panel, below, 0, 20, 1,
        function(value) return L["Minimum gain for an upgrade: %d%%"]:format(value) end,
        function() return self.db.threshold end,
        function(value)
            self.db.threshold = value
            Score.Invalidate("spec")
        end)
    below = Options.AddSlider(panel, below, 0, 60, 5,
        function(value)
            return value == 0 and L["The alert stays until closed"]
                or L["The alert closes after %d seconds"]:format(value)
        end,
        function() return self.db.alertDuration end,
        function(value) self.db.alertDuration = value end)
    local button = Options.AddButton(panel, self:SpecButtonLabel(), 260, function()
        self:CycleSpec()
    end)
    button:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -12)
    panel:HookScript("OnShow", function()
        button:SetLabel(self:SpecButtonLabel())
    end)
    self.specButton = button
    return button
end
