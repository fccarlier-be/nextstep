-- Configuration de luacheck (https://github.com/lunarmodules/luacheck).
std = "lua51"
max_line_length = 120
-- Une méthode déclarée avec « : » qui n'utilise pas self n'est pas une erreur.
self = false
-- .lua et .luarocks : installations de Lua faites par l'intégration continue.
exclude_files = {
    "Tools/bin/**", "Tools/import/cache/**", "addon/NextStep/Libs/**", ".lua/**", ".luarocks/**",
    -- Données générées par Tools/import/import.lua
    "addon/NextStep/Data/Imported/**", "addon/NextStep_Alliance/Data/**", "addon/NextStep_Horde/Data/**",
}

-- Code de l'addon : seules les globales listées ici sont permises.
files["addon/**"] = {
    globals = {
        -- Écrites par l'addon
        "NextStep", "NextStepDB", "NextStepCharDB",
        "SLASH_NEXTSTEP1", "SLASH_NEXTSTEP2", "SlashCmdList",
    },
    read_globals = {
        -- API du jeu utilisée (à compléter au fil des modules)
        "C_AddOns",
        "C_Item",
        "C_Map",
        "C_QuestLog",
        "C_Spell",
        "C_TooltipInfo",
        "CreateFrame",
        "DEFAULT_CHAT_FRAME",
        "GetLocale",
        "geterrorhandler",
        "InCombatLockdown",
        "issecretvalue",
        "Settings",
        "UNKNOWNOBJECT",
        "UnitFactionGroup",
        "UnitGUID",
        "UnitName",
    },
}

-- Addon de diagnostic (outil de développement, jamais livré).
files["Tools/diagnostic/**"] = {
    globals = { "NextStepDiagDB", "SLASH_NEXTSTEPDIAG1", "SlashCmdList" },
    read_globals = {
        "C_AddOns", "C_CVar", "C_Item", "C_Map", "C_NamePlate", "C_QuestLog", "C_Spell", "C_TaxiMap", "C_Timer",
        "C_TooltipInfo", "AbbreviateNumbers", "ChatFontNormal", "CLOSE", "CreateFrame", "DEFAULT_CHAT_FRAME",
        "GetAddOnMemoryUsage", "GetBindLocation", "GetBuildInfo", "GetLocale", "GetMoney", "GetNumSkillLines",
        "GetPlayerFacing", "GetSubZoneText", "GetZoneText", "InCombatLockdown", "Minimap", "UIParent",
        "UnitClass", "UnitExists", "UnitFactionGroup", "UnitGUID", "UnitHealth", "UnitHealthMax",
        "UnitHealthPercent", "UnitLevel", "UnitName", "UnitPower", "UnitRace", "UnitXP", "UnitXPMax",
        "UpdateAddOnMemoryUsage", "WorldMapFrame", "time",
        -- Maîtres, butin, exploration de la carte, journal des donjons.
        "C_MapExplorationInfo", "EJ_GetInstanceByIndex", "EJ_GetNumTiers", "EJ_SelectTier", "GetLootSlotLink",
        "GetLootSlotType", "GetLootSourceInfo", "GetNumLootItems", "GetNumTrainerServices", "GetTime",
        "GetTrainerServiceCost", "GetTrainerServiceInfo", "GetTrainerServiceLevelReq", "GetTrainerServiceTypeFilter",
        "IsInInstance", "date",
    },
}

-- Tests : la simulation du jeu définit et remplace des globales à volonté.
files["tests/**"] = {
    ignore = { "11." },
}
