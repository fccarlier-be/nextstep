-- Configuration de luacheck (https://github.com/lunarmodules/luacheck).
std = "lua51"
max_line_length = 120
-- Une méthode déclarée avec « : » qui n'utilise pas self n'est pas une erreur.
self = false
exclude_files = { "Tools/bin/**", "addon/NextStep/Libs/**" }

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
