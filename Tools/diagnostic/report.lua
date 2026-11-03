-- Convertit les sauvegardes de l'addon de diagnostic en rapport Markdown.
--
--   luajit Tools/diagnostic/report.lua <NextStep_Diagnostic.lua> <rapport.md>
--
-- Le fichier de sauvegarde est exécuté dans un environnement vide : il ne contient
-- qu'une affectation de table (NextStepDiagDB = { ... }).

local input, output = arg[1], arg[2]
assert(input and output, "usage: report.lua <saved variables file> <report.md>")

local file = assert(io.open(input, "rb"))
local code = file:read("*a")
file:close()
assert(code:byte(1) ~= 27, "precompiled chunk refused")
local chunk = assert(loadstring(code, "@" .. input))
local env = {}
setfenv(chunk, env)
chunk()
local db = assert(env.NextStepDiagDB and env.NextStepDiagDB.reports, "no NextStepDiagDB.reports in " .. input)

local ICONS = { ok = "✅", warn = "⚠️", missing = "❌", info = "ℹ️" }
local TITLES = {
    general = "Vérifications hors combat",
    combat = "Capture en combat",
    trainer = "Maître de classe (à l'ouverture)",
    loot = "Derniers butins et récoltes",
}

local function cell(text)
    return (tostring(text or ""):gsub("|", "\\|"):gsub("\n", " "))
end

local lines = {
    "# Rapport de diagnostic",
    "",
    "Généré par `Tools/diagnostic/report.ps1` à partir de l'addon NextStep - Diagnostic.",
    "",
}

for _, kind in ipairs({ "general", "combat", "trainer", "loot" }) do
    local report = db[kind]
    if report then
        local client = report.client
        lines[#lines + 1] = "## " .. TITLES[kind]
        lines[#lines + 1] = ""
        lines[#lines + 1] = ("Client %s, build %s (%s), interface %s, langue %s%s."):format(
            cell(client.version), cell(client.build), cell(client.date), cell(client.interface), cell(client.locale),
            report.time and (", relevé le " .. os.date("%Y-%m-%d %H:%M", report.time)) or "")
        lines[#lines + 1] = ""
        local totals = { ok = 0, warn = 0, missing = 0, info = 0 }
        for _, s in ipairs(report.sections) do
            lines[#lines + 1] = "### " .. s.name
            lines[#lines + 1] = ""
            lines[#lines + 1] = "| | Point vérifié | Valeur | Remarque |"
            lines[#lines + 1] = "|---|---|---|---|"
            for _, r in ipairs(s.results) do
                totals[r.status] = (totals[r.status] or 0) + 1
                lines[#lines + 1] = ("| %s | %s | %s | %s |"):format(ICONS[r.status] or r.status, cell(r.id),
                    cell(r.value), cell(r.note))
            end
            lines[#lines + 1] = ""
        end
        lines[#lines + 1] = ("Total : %d OK, %d à revoir, %d absents, %d informations."):format(
            totals.ok, totals.warn, totals.missing, totals.info)
        lines[#lines + 1] = ""
    end
end

local out = assert(io.open(output, "wb"))
out:write(table.concat(lines, "\n"))
out:close()
print("Report written: " .. output)
