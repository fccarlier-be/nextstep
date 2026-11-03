-- Chargement des données de faction : seul l'addon de la faction du personnage
-- (NextStep_Alliance ou NextStep_Horde) est chargé, à la connexion.

local _, ns = ...
local L = ns.L

local Factions = {}
ns.Factions = Factions

local DATA_ADDONS = {
    Alliance = "NextStep_Alliance",
    Horde = "NextStep_Horde",
}

-- [faction] = données enregistrées par l'addon de faction.
Factions.data = {}

-- Appelé par Data.lua de chaque addon de faction.
function Factions:Register(faction, data)
    self.data[faction] = data
end

local function onFactionChanged(self, _, unit)
    if unit == "player" then
        self:Load()
    end
end

-- Charge les données de la faction du personnage. Si la faction n'est pas encore
-- connue (personnage neutre), réessaie dès qu'elle change. Envoie le message
-- NEXTSTEP_FACTION_LOADED (faction) en cas de succès.
function Factions:Load()
    local faction = UnitFactionGroup("player")
    local addon = DATA_ADDONS[faction]
    if not addon then
        ns.Events:Register("UNIT_FACTION", self, onFactionChanged)
        return false
    end
    ns.Events:Unregister("UNIT_FACTION", self)
    self.faction = faction

    local loaded, reason = C_AddOns.LoadAddOn(addon)
    if not loaded then
        ns:Print(L["Could not load %s (%s)."]:format(addon, tostring(reason)))
        return false
    end
    ns.Events:SendMessage("NEXTSTEP_FACTION_LOADED", faction)
    return true
end
