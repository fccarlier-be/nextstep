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
        "CreateFrame",
        "DEFAULT_CHAT_FRAME",
        "GetLocale",
        "geterrorhandler",
        "Settings",
        "UnitFactionGroup",
    },
}

-- Tests : la simulation du jeu définit et remplace des globales à volonté.
files["tests/**"] = {
    ignore = { "11." },
}
