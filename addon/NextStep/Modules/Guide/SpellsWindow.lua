-- Sorts de classe (docs/DESIGN.md, « Sorts à apprendre ») : ce que le maître a
-- maintenant pour le personnage, puis chaque niveau à venir qui apporte de nouveaux
-- sorts, avec le prix de chacun et le total du niveau. Affichés dans l'onglet
-- « Sorts de classe » du journal (menu du bouton NextStep ou /ns spells).

local _, ns = ...
local L = ns.L

local Guide = ns.Modules:Get("Guide")

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
-- Ouverture : l'onglet « Sorts de classe » du journal (Journal.lua)
---------------------------------------------------------------------------

function Guide:ToggleSpellsWindow()
    self:ToggleJournal("spells")
end

function Guide:UpdateSpellsWindow()
    self:UpdateJournal()
end
