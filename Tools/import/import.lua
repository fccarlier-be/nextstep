-- Import des guides compilés de Polestar vers le format de données de NextStep.
--
--   luajit Tools/import/import.lua <dossier Polestar> [fichier polestar.lock]
--
-- À lancer depuis la racine du dépôt (Tools\import\run.ps1 le fait). Les fichiers de
-- Polestar sont exécutés dans un environnement isolé : aucun accès aux fichiers ni au
-- système, et les fonctions Polestar.* sont remplacées par des fonctions de capture.
-- Le format produit est décrit dans docs/DATA_FORMAT.md.
--
-- Étapes : lecture → conversion → écriture → relecture des fichiers produits et
-- comparaison avec la source. Toute anomalie arrête l'import avant d'écrire, ou le
-- signale dans le rapport.

local SOURCE = assert(arg[1], "usage: import.lua <polestar checkout> [polestar.lock]")
local LOCK_PATH = arg[2] or "Tools/import/polestar.lock"

local OUT = {
    common = "addon/NextStep/Data/Imported/Polestar/",
    Alliance = "addon/NextStep_Alliance/Data/",
    Horde = "addon/NextStep_Horde/Data/",
}
local REPORT_PATH = "Tools/import/last-import.md"

-- Packs de guides lus, et la destination de leurs guides.
local GUIDE_PACKS = {
    { dir = "Polestar_Guides", out = "common" },
    { dir = "Polestar_Guides_Alliance", out = "Alliance" },
    { dir = "Polestar_Guides_Horde", out = "Horde" },
}
local LOCALES = { "frFR" }

-- Jetons de race : ceux de UnitRace (raceFile) en majuscules.
local RACES = {
    Human = "HUMAN", Dwarf = "DWARF", Gnome = "GNOME", NightElf = "NIGHTELF",
    Orc = "ORC", Troll = "TROLL", Tauren = "TAUREN", Scourge = "SCOURGE", Undead = "SCOURGE",
    Skyborne = "SKYBORNE",
}

-- Champs de noms anglais retirés des objectifs : leur valeur rejoint la table des noms.
-- [champ du nom] = { genre, champ de l'identifiant }
local NAME_FIELDS = {
    npcName = { "npc", "npc" },
    itemName = { "item", "item" },
    objName = { "object", "object" },
    spellName = { "spell", "spell" },
    factionName = { "faction", "faction" },
}

---------------------------------------------------------------------------
-- Utilitaires
---------------------------------------------------------------------------

local function readFile(path)
    local file = assert(io.open(path, "rb"), "cannot read " .. path)
    local content = file:read("*a")
    file:close()
    return content
end

local function writeFile(path, content)
    local file = assert(io.open(path, "wb"), "cannot write " .. path .. " (missing folder?)")
    file:write(content)
    file:close()
end

local function readLock(path)
    local lock = {}
    for line in readFile(path):gmatch("[^\r\n]+") do
        local key, value = line:match("^%s*([^#=]-)%s*=%s*(.-)%s*$")
        if key and key ~= "" then
            lock[key] = value
        end
    end
    return lock
end

local function tocMetadata(dir)
    local meta = {}
    for line in readFile(SOURCE .. "/addon/" .. dir .. "/" .. dir .. ".toc"):gmatch("[^\r\n]+") do
        local key, value = line:match("^##%s*([^:]+):%s*(.-)%s*$")
        if key then
            meta[key] = value
        end
    end
    return meta
end

local function sortedKeys(t)
    local keys = {}
    for key in pairs(t) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then
            return a < b
        end
        return type(a) == "number"
    end)
    return keys
end

local function deepEqual(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return a == b
    end
    for key, value in pairs(a) do
        if not deepEqual(value, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end

local function copy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, inner in pairs(value) do
        result[key] = copy(inner)
    end
    return result
end

---------------------------------------------------------------------------
-- Exécution isolée
---------------------------------------------------------------------------

local function shallowCopy(t)
    local result = {}
    for key, value in pairs(t) do
        result[key] = value
    end
    return result
end

local SAFE_GLOBALS = {
    "assert", "error", "ipairs", "next", "pairs", "rawget", "rawset", "select",
    "setmetatable", "getmetatable", "tonumber", "tostring", "type", "unpack",
}

-- api : table servant de « Polestar » dans le fichier exécuté. Toute fonction
-- inconnue arrête l'import : le format a changé et l'import doit être revu.
local function runSandboxed(path, api, globals)
    local code = readFile(path)
    -- Du bytecode précompilé pourrait contourner l'isolation : refusé.
    assert(code:byte(1) ~= 27, "precompiled chunk refused: " .. path)
    local chunk = assert(loadstring(code, "@" .. path))

    local env = {}
    for _, name in ipairs(SAFE_GLOBALS) do
        env[name] = _G[name]
    end
    env.string, env.table, env.math = shallowCopy(string), shallowCopy(table), shallowCopy(math)
    for key, value in pairs(globals or {}) do
        env[key] = value
    end
    env.Polestar = setmetatable(api, {
        __index = function(_, key)
            error(("unknown Polestar.%s called by %s: the format has changed"):format(key, path), 2)
        end,
    })
    env._G = env
    setfenv(chunk, env)
    chunk("Polestar_Import", {})
end

---------------------------------------------------------------------------
-- Lecture de Polestar
---------------------------------------------------------------------------

local lock = readLock(LOCK_PATH)
local report = { warnings = {} }

local function warn(message)
    report.warnings[#report.warnings + 1] = message
end

local function checkFormat()
    local meta = tocMetadata("Polestar_Guides")
    local format = meta["X-Polestar-Format"]
    assert(format == lock.format, ("Polestar guide format is %s, the importer knows format %s: "
        .. "review the conversion before changing polestar.lock"):format(tostring(format), lock.format))
    assert(meta.Version == lock.version, ("Polestar version is %s, polestar.lock says %s"):format(
        tostring(meta.Version), lock.version))
    local pack
    runSandboxed(SOURCE .. "/addon/Polestar_Guides/Pack.lua", {
        RegisterPack = function(t)
            pack = t
        end,
    })
    assert(pack and tostring(pack.format) == lock.format, "Pack.lua format mismatch")
    return meta
end

-- Licence attendue des dossiers de Polestar lus. Si elle change, l'import s'arrête :
-- CREDITS.md, docs/DATA_SOURCES.md et les notices doivent être revus d'abord.
local POLESTAR_LICENSE = "GPL-3.0-only"

local function checkLicences()
    local dirs = {}
    for _, pack in ipairs(GUIDE_PACKS) do
        dirs[#dirs + 1] = pack.dir
    end
    for _, locale in ipairs(LOCALES) do
        dirs[#dirs + 1] = "Polestar_" .. locale
    end
    for _, dir in ipairs(dirs) do
        local license = tocMetadata(dir)["X-License"]
        assert(license == POLESTAR_LICENSE, ("%s is licensed %s, the importer expects %s: "
            .. "review CREDITS.md and docs/DATA_SOURCES.md first"):format(dir, tostring(license), POLESTAR_LICENSE))
    end
end

-- Mention de copyright de Polestar (première ligne « Copyright » de son LICENSE), à conserver
-- dans les fichiers produits (GPL-3.0, section 4).
local function readCopyright()
    for line in readFile(SOURCE .. "/LICENSE"):gmatch("[^\r\n]+") do
        local notice = line:match("^%s*(Copyright .-)%s*$")
        if notice then
            return notice
        end
    end
    error("no copyright line in Polestar's LICENSE")
end

local copyright = readCopyright()

local function readGuides()
    local guides, retired = {}, {}
    for _, pack in ipairs(GUIDE_PACKS) do
        runSandboxed(SOURCE .. "/addon/" .. pack.dir .. "/Guides.lua", {
            RegisterGuide = function(guide)
                guides[#guides + 1] = { source = guide, out = pack.out }
            end,
            RetireGuides = function(_, list)
                for _, id in ipairs(list) do
                    retired[#retired + 1] = id
                end
            end,
        })
    end
    return guides, retired
end

local function readMapFrames()
    local frames
    runSandboxed(SOURCE .. "/addon/Polestar_Guides/MapFrames.lua", {
        RegisterMapFrames = function(t)
            frames = t
        end,
    })
    return assert(frames and frames.era, "no era map frames")
end

-- Names.lua : blocs de lignes « <id>\t<nom> », caractères spéciaux en %XX.
local function readLocaleNames(locale)
    local names = {}
    runSandboxed(SOURCE .. "/addon/Polestar_" .. locale .. "/Names.lua", {
        Names = {
            AddChunk = function(_, kind, _, _, text)
                names[kind] = names[kind] or {}
                for id, name in text:gmatch("(%d+)\t([^\n]*)") do
                    name = name:gsub("%%(%x%x)", function(hex)
                        return string.char(tonumber(hex, 16))
                    end)
                    names[kind][tonumber(id)] = name
                end
            end,
        },
    })
    return names
end

local function readLocaleTexts(locale)
    local texts
    runSandboxed(SOURCE .. "/addon/Polestar_" .. locale .. "/Texts.lua", {
        RegisterGuideTexts = function(_, _, t)
            texts = t
        end,
    })
    return assert(texts, "no texts for " .. locale)
end

---------------------------------------------------------------------------
-- Conversion
---------------------------------------------------------------------------

local englishNames = {}   -- [genre][id] = nom anglais

local warned = {}

local function addName(kind, id, name)
    if id == nil or name == nil or name == "" then
        return
    end
    englishNames[kind] = englishNames[kind] or {}
    local known = englishNames[kind][id]
    if known and known ~= name then
        local message = ("two English names for %s:%s: %q and %q (first kept)"):format(
            kind, tostring(id), known, name)
        if not warned[message] then
            warned[message] = true
            warn(message)
        end
        return
    end
    englishNames[kind][id] = name
end

-- Noms d'un guide (table names de Polestar), traités après tous les objectifs :
-- les noms des objectifs font référence. Un nom de guide différent (souvent sans
-- article, pour s'insérer dans une phrase) reste propre au guide.
local function guideNameOverrides(names)
    local overrides
    for _, key in ipairs((function()
        local keys = {}
        for k in pairs(names or {}) do
            keys[#keys + 1] = k
        end
        table.sort(keys)
        return keys
    end)()) do
        local kind, id = key:match("^(%a+):(%d+)$")
        if not kind then
            warn(("unexpected name key %q"):format(key))
        else
            id = tonumber(id)
            local known = englishNames[kind] and englishNames[kind][id]
            if known == nil then
                addName(kind, id, names[key])
            elseif known ~= names[key] then
                overrides = overrides or {}
                overrides[key] = names[key]
            end
        end
    end
    return overrides
end

local function convertRaces(list, where)
    if not list then
        return nil
    end
    local result = {}
    for i, race in ipairs(list) do
        result[i] = RACES[race] or error(("unknown race %q in %s"):format(tostring(race), where))
    end
    return result
end

local function convertOnly(only, where)
    if not only then
        return nil
    end
    local result = copy(only)
    result.races = convertRaces(only.races, where)
    return result
end

-- Retire les noms anglais d'un objectif ou d'une fiche de maître et les range dans la table des noms.
local function extractNames(record)
    for field, spec in pairs(NAME_FIELDS) do
        if record[field] ~= nil then
            addName(spec[1], record[spec[2]], record[field])
            record[field] = nil
        end
    end
    if record.quest and record.title then
        -- Le titre d'un objectif lié à une quête est le titre de la quête.
        if type(record.quest) == "number" then
            addName("quest", record.quest, record.title)
            record.title = nil
        end
    end
    if record.preTitles then
        for questID, title in pairs(record.preTitles) do
            addName("quest", questID, title)
        end
        record.preTitles = nil
    end
    if record.from and record.fromId and record.fromKind then
        addName(record.fromKind, record.fromId, record.from)
        record.from = nil
    end
end

local function convertGoal(source, pool, poolIndex, where)
    local goal = copy(source)
    goal.only = convertOnly(source.only, where)
    if source.candidates then
        local refs = {}
        for i, record in ipairs(source.candidates) do
            local index = poolIndex[record]
            if not index then
                local converted = copy(record)
                extractNames(converted)
                pool[#pool + 1] = converted
                index = #pool
                poolIndex[record] = index
            end
            refs[i] = index
        end
        goal.candidates = refs
    end
    extractNames(goal)
    return goal
end

local function convertGuide(source)
    local where = source.id
    local guide = copy(source)
    local pool, poolIndex = {}, {}

    -- Champs propres à Polestar ou désormais dans les tables de noms.
    -- names est traité après tous les guides (guideNameOverrides).
    guide.author, guide.pack, guide.written, guide.names, guide.zoneName = nil, nil, nil, nil, nil
    addName("zone", source.zone, source.zoneName)

    guide.races = convertRaces(source.races, where)
    if type(source.next) == "string" then
        guide.next = { source.next }
    end

    guide.steps = {}
    for s, step in ipairs(source.steps or {}) do
        local converted = copy(step)
        converted.only = convertOnly(step.only, where .. " step " .. s)
        converted.goals = {}
        for g, goal in ipairs(step.goals or {}) do
            converted.goals[g] = convertGoal(goal, pool, poolIndex, where .. " step " .. s)
        end
        guide.steps[s] = converted
    end
    if #pool > 0 then
        guide.pool = pool
    end
    return guide
end

---------------------------------------------------------------------------
-- Écriture
---------------------------------------------------------------------------

-- Ordre des clés dans les fichiers produits (les autres suivent, triées).
local KEY_ORDER = {}
for rank, key in ipairs({
    "id", "t", "k", "title", "category", "folder", "faction", "races", "classes", "factions",
    "minLevel", "maxLevel", "zone", "next", "label", "only", "when", "along", "skipto",
    "quest", "npc", "object", "item", "spell", "count", "map", "x", "y", "z", "f", "r",
    "optional", "note", "text",
}) do
    KEY_ORDER[key] = rank
end

local function keyBefore(a, b)
    local ra, rb = KEY_ORDER[a] or 1000, KEY_ORDER[b] or 1000
    if ra ~= rb then
        return ra < rb
    end
    if type(a) == type(b) then
        return a < b
    end
    return type(a) == "number"
end

local function formatNumber(n)
    if n == math.floor(n) and math.abs(n) < 2 ^ 53 then
        return ("%d"):format(n)
    end
    return ("%.14g"):format(n)
end

local function formatString(s)
    return (("%q"):format(s):gsub("\\\n", "\\n"))
end

local function formatKey(key)
    if type(key) == "string" and key:match("^[%a_][%w_]*$") then
        return key
    end
    if type(key) == "number" then
        return "[" .. formatNumber(key) .. "]"
    end
    return "[" .. formatString(key) .. "]"
end

local function isList(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count == #t
end

local inline

local function formatValue(value)
    local kind = type(value)
    if kind == "string" then
        return formatString(value)
    elseif kind == "number" then
        return formatNumber(value)
    elseif kind == "boolean" then
        return tostring(value)
    elseif kind == "table" then
        return inline(value)
    end
    error("cannot serialize a " .. kind)
end

-- Table sur une seule ligne.
inline = function(t)
    if next(t) == nil then
        return "{}"
    end
    local parts = {}
    if isList(t) then
        for i, value in ipairs(t) do
            parts[i] = formatValue(value)
        end
    else
        local keys = {}
        for key in pairs(t) do
            keys[#keys + 1] = key
        end
        table.sort(keys, keyBefore)
        for i, key in ipairs(keys) do
            parts[i] = formatKey(key) .. " = " .. formatValue(t[key])
        end
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
end

local function orderedKeys(t, skip)
    local keys = {}
    for key in pairs(t) do
        if not skip[key] then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys, keyBefore)
    return keys
end

-- Un guide par fonction : la limite de constantes de Lua 5.1 s'applique par fonction.
local function writeGuide(out, guide)
    out[#out + 1] = "G(function() return {"
    for _, key in ipairs(orderedKeys(guide, { steps = true, pool = true })) do
        out[#out + 1] = ("\t%s = %s,"):format(formatKey(key), formatValue(guide[key]))
    end
    if guide.pool then
        out[#out + 1] = "\tpool = {"
        for _, record in ipairs(guide.pool) do
            out[#out + 1] = "\t\t" .. inline(record) .. ","
        end
        out[#out + 1] = "\t},"
    end
    out[#out + 1] = "\tsteps = {"
    for _, step in ipairs(guide.steps) do
        out[#out + 1] = "\t\t{"
        for _, key in ipairs(orderedKeys(step, { goals = true })) do
            out[#out + 1] = ("\t\t\t%s = %s,"):format(formatKey(key), formatValue(step[key]))
        end
        out[#out + 1] = "\t\t\tgoals = {"
        for _, goal in ipairs(step.goals) do
            out[#out + 1] = "\t\t\t\t" .. inline(goal) .. ","
        end
        out[#out + 1] = "\t\t\t},"
        out[#out + 1] = "\t\t},"
    end
    out[#out + 1] = "\t},"
    out[#out + 1] = "} end)"
    out[#out + 1] = ""
end

local HEADER = table.concat({
    "-- Généré par Tools/import/import.lua depuis Polestar %s (%s, %s). Ne pas modifier :",
    "-- relancer Tools\\import\\run.ps1.",
    "-- %s. Données sous licence GPL-3.0-only ; sources tierces :",
    "-- LICENSE-DATA.txt dans ce dossier, et CREDITS.md. Format : docs/DATA_FORMAT.md.",
    "",
}, "\n")

local function header()
    return HEADER:format(lock.version, lock.commit:sub(1, 12), lock.date, copyright)
end

---------------------------------------------------------------------------
-- Notices
---------------------------------------------------------------------------

-- Notices de Polestar recopiées à côté des données, sans modification : elles portent les
-- mentions et licences de ses sources (dont la notice MIT de pfQuest, et les crédits de DingDB
-- que la permission de son auteur demande de garder à côté de ses données).
local NOTICES = {
    common = { "Polestar_Guides/LICENSE-DATA.txt" },
    Alliance = { "Polestar_Guides_Alliance/LICENSE-DATA.txt" },
    Horde = { "Polestar_Guides_Horde/LICENSE-DATA.txt" },
}
for _, locale in ipairs(LOCALES) do
    table.insert(NOTICES.common, "Polestar_" .. locale .. "/LICENSE-DATA.txt")
    table.insert(NOTICES.common, "Polestar_" .. locale .. "/CREDITS.md")
end

local NOTICE_INTRO = table.concat({
    "NextStep : données importées de Polestar",
    "========================================",
    "",
    "Les fichiers de données de ce dossier sont générés par Tools/import/import.lua de",
    "NextStep (https://github.com/fccarlier-be/nextstep) à partir de Polestar %s",
    "(https://github.com/fitzforge/polestar), puis convertis au format de NextStep.",
    "Commit de Polestar : %s (%s).",
    "",
    "%s",
    "Polestar est distribué sous la GNU General Public License, version 3",
    "(GPL-3.0-only). Le texte de la licence est dans le fichier LICENSE.txt de l'addon",
    "NextStep.",
    "",
    "Les notices de Polestar sur ses sources tierces sont reproduites ci-dessous sans",
    "modification.",
    "",
}, "\n")

local RULE = string.rep("-", 80)

local function writeNotices(out)
    local parts = { NOTICE_INTRO:format(lock.version, lock.commit, lock.date, copyright) }
    for _, file in ipairs(NOTICES[out]) do
        local text = readFile(SOURCE .. "/addon/" .. file):gsub("\r\n", "\n"):gsub("%s+$", "")
        parts[#parts + 1] = table.concat({ RULE, "Polestar : addon/" .. file, RULE, "", text, "" }, "\n")
    end
    writeFile(OUT[out] .. "LICENSE-DATA.txt", table.concat(parts, "\n"))
end

local function writeGuideFile(path, guides)
    local out = { header(), "local G = NextStep.DB.AddGuide", "" }
    for _, guide in ipairs(guides) do
        writeGuide(out, guide)
    end
    writeFile(path, table.concat(out, "\n"))
end

local CHUNK_SIZE = 2000

-- Table [clé] = valeur, découpée en fonctions de CHUNK_SIZE entrées.
-- prefix est le début de l'appel, par exemple 'DB:AddNames("enUS", "npc", '.
local function writeChunks(out, prefix, map)
    local keys = sortedKeys(map)
    for first = 1, #keys, CHUNK_SIZE do
        out[#out + 1] = prefix .. "function() return {"
        for i = first, math.min(first + CHUNK_SIZE - 1, #keys) do
            out[#out + 1] = ("\t[%s] = %s,"):format(formatValue(keys[i]), formatValue(map[keys[i]]))
        end
        out[#out + 1] = "} end)"
        out[#out + 1] = ""
    end
end

local function writeNamesFile(path, locale, names, guarded)
    local out = { header() }
    if guarded then
        out[#out + 1] = ("if GetLocale() ~= %q then\n\treturn\nend\n"):format(locale)
    end
    out[#out + 1] = "local DB = NextStep.DB\n"
    for _, kind in ipairs(sortedKeys(names)) do
        writeChunks(out, ("DB:AddNames(%q, %q, "):format(locale, kind), names[kind])
    end
    writeFile(path, table.concat(out, "\n"))
end

local function writeTextsFile(path, locale, shared, perGuide)
    local out = {
        header(),
        ("if GetLocale() ~= %q then\n\treturn\nend\n"):format(locale),
        "local DB = NextStep.DB\n",
    }
    writeChunks(out, ("DB:AddTexts(%q, nil, "):format(locale), shared)
    for _, guideID in ipairs(sortedKeys(perGuide)) do
        writeChunks(out, ("DB:AddTexts(%q, %q, "):format(locale, guideID), perGuide[guideID])
    end
    writeFile(path, table.concat(out, "\n"))
end

local function writeMetaFile(path, retired, frames)
    local out = {
        header(),
        "local DB = NextStep.DB\n",
        ("DB:SetSource(%s)\n"):format(inline({
            name = "Polestar", version = lock.version, commit = lock.commit, date = lock.date,
            format = tonumber(lock.format),
        })),
        "DB:RetireGuides({",
    }
    for _, id in ipairs(retired) do
        out[#out + 1] = "\t" .. formatString(id) .. ","
    end
    out[#out + 1] = "})\n"
    out[#out + 1] = "-- Repères « era » des cartes, pour convertir en jeu les coordonnées marquées f = \"e\"."
    out[#out + 1] = "DB:AddMapFrames(\"era\", function() return {"
    for _, map in ipairs(sortedKeys(frames)) do
        out[#out + 1] = ("\t[%d] = %s,"):format(map, inline(frames[map]))
    end
    out[#out + 1] = "} end)\n"
    writeFile(path, table.concat(out, "\n"))
end

---------------------------------------------------------------------------
-- Vérification : relecture des fichiers produits
---------------------------------------------------------------------------

local function reloadGuides(path)
    local loaded = {}
    local code = readFile(path)
    local chunk = assert(loadstring(code, "@" .. path))
    setfenv(chunk, {
        NextStep = { DB = { AddGuide = function(build)
            loaded[#loaded + 1] = build()
        end } },
    })
    chunk()
    return loaded
end

local function countGoals(guide)
    local count = 0
    for _, step in ipairs(guide.steps or {}) do
        count = count + #(step.goals or {})
    end
    return count
end

-- Champs qui doivent passer à l'identique de la source à NextStep.
local KEPT_GOAL_FIELDS = { "t", "quest", "npc", "object", "item", "count", "map", "x", "y", "z", "f", "optional" }

local function verifyAgainstSource(entry)
    local source, guide = entry.source, entry.guide
    assert(#source.steps == #guide.steps, source.id .. ": step count differs")
    for s, step in ipairs(source.steps) do
        assert(#step.goals == #guide.steps[s].goals, ("%s step %d: goal count differs"):format(source.id, s))
        for g, goal in ipairs(step.goals) do
            local converted = guide.steps[s].goals[g]
            for _, field in ipairs(KEPT_GOAL_FIELDS) do
                assert(deepEqual(goal[field], converted[field]),
                    ("%s step %d goal %d: field %s differs"):format(source.id, s, g, field))
            end
        end
    end
end

---------------------------------------------------------------------------
-- Programme principal
---------------------------------------------------------------------------

local function collectPlaceholders(value, found)
    if type(value) == "string" then
        for kind, id in value:gmatch("{(%a+):(%d+)}") do
            found[kind] = found[kind] or {}
            found[kind][tonumber(id)] = true
        end
    elseif type(value) == "table" then
        for _, inner in pairs(value) do
            collectPlaceholders(inner, found)
        end
    end
end

local function main()
    checkFormat()
    checkLicences()

    local entries, retired = readGuides()
    local byOut = { common = {}, Alliance = {}, Horde = {} }
    local totals = { guides = 0, steps = 0, goals = 0 }
    local seen = {}
    for _, entry in ipairs(entries) do
        assert(not seen[entry.source.id], "duplicate guide id " .. entry.source.id)
        seen[entry.source.id] = true
        entry.guide = convertGuide(entry.source)
        verifyAgainstSource(entry)
        local list = byOut[entry.out]
        list[#list + 1] = entry.guide
        totals.guides = totals.guides + 1
        totals.steps = totals.steps + #entry.guide.steps
        totals.goals = totals.goals + countGoals(entry.guide)
    end
    for _, entry in ipairs(entries) do
        entry.guide.names = guideNameOverrides(entry.source.names)
    end

    -- Noms : anglais (tous ceux rencontrés) et traduits (seulement ceux que les guides utilisent).
    local referenced = {}
    collectPlaceholders(byOut, referenced)
    for kind, ids in pairs(englishNames) do
        referenced[kind] = referenced[kind] or {}
        for id in pairs(ids) do
            referenced[kind][id] = true
        end
    end

    local localeNames, localeTexts = {}, {}
    for _, locale in ipairs(LOCALES) do
        local all = readLocaleNames(locale)
        local kept = {}
        for kind, ids in pairs(referenced) do
            for id in pairs(ids) do
                local name = all[kind] and all[kind][id]
                if name then
                    kept[kind] = kept[kind] or {}
                    kept[kind][id] = name
                end
            end
        end
        localeNames[locale] = kept

        -- Traductions : une table commune ; une table par guide seulement en cas de désaccord.
        local raw = readLocaleTexts(locale)
        local shared, perGuide = {}, {}
        -- Parcours trié : la traduction commune doit être la même à chaque import.
        local rawGuides = raw.guides or {}
        for _, guideID in ipairs(sortedKeys(rawGuides)) do
            local map = rawGuides[guideID]
            for _, english in ipairs(sortedKeys(map)) do
                local translated = map[english]
                if shared[english] == nil then
                    shared[english] = translated
                elseif shared[english] ~= translated then
                    perGuide[guideID] = perGuide[guideID] or {}
                    perGuide[guideID][english] = translated
                end
            end
        end
        for english, translated in pairs(raw.pack or {}) do
            if shared[english] == nil then
                shared[english] = translated
            end
        end
        localeTexts[locale] = { shared = shared, perGuide = perGuide }
    end

    -- Écriture
    writeGuideFile(OUT.common .. "Guides.lua", byOut.common)
    writeGuideFile(OUT.Alliance .. "Guides.lua", byOut.Alliance)
    writeGuideFile(OUT.Horde .. "Guides.lua", byOut.Horde)
    writeNamesFile(OUT.common .. "Names_enUS.lua", "enUS", englishNames, false)
    for _, locale in ipairs(LOCALES) do
        writeNamesFile(OUT.common .. "Names_" .. locale .. ".lua", locale, localeNames[locale], true)
        writeTextsFile(OUT.common .. "Texts_" .. locale .. ".lua", locale,
            localeTexts[locale].shared, localeTexts[locale].perGuide)
    end
    writeMetaFile(OUT.common .. "Meta.lua", retired, readMapFrames())
    for out in pairs(OUT) do
        writeNotices(out)
    end

    -- Relecture : les fichiers produits redonnent exactement les guides convertis.
    for out, list in pairs(byOut) do
        local reloaded = reloadGuides(OUT[out] .. "Guides.lua")
        assert(#reloaded == #list, out .. ": reloaded guide count differs")
        for i, guide in ipairs(list) do
            assert(deepEqual(guide, reloaded[i]), out .. ": guide " .. guide.id .. " differs after reload")
        end
    end

    -- Couverture des noms
    local coverage = {}
    for _, kind in ipairs(sortedKeys(referenced)) do
        local total, english = 0, 0
        local translated = {}
        for id in pairs(referenced[kind]) do
            total = total + 1
            if englishNames[kind] and englishNames[kind][id] then
                english = english + 1
            end
            for _, locale in ipairs(LOCALES) do
                if localeNames[locale][kind] and localeNames[locale][kind][id] then
                    translated[locale] = (translated[locale] or 0) + 1
                end
            end
        end
        coverage[#coverage + 1] = { kind = kind, total = total, english = english, translated = translated }
    end

    -- Rapport
    local lines = {
        "# Dernier import",
        "",
        "Généré par `Tools/import/import.lua`. Ne pas modifier à la main.",
        "",
        ("- Source : Polestar %s, commit `%s` (%s), format %s"):format(
            lock.version, lock.commit, lock.date, lock.format),
        ("- Guides : %d (communs %d, Alliance %d, Horde %d)"):format(totals.guides, #byOut.common,
            #byOut.Alliance, #byOut.Horde),
        ("- Étapes : %d"):format(totals.steps),
        ("- Objectifs : %d"):format(totals.goals),
        ("- Guides retirés (anciens identifiants) : %d"):format(#retired),
        "- Vérifications : nombre d'étapes et d'objectifs par guide, champs clés de chaque objectif, "
            .. "relecture exacte des fichiers produits.",
        "",
        "## Noms référencés",
        "",
        "Les genres absents des tables (zones, régions, sorts, compétences) sont fournis par le client en jeu.",
        "",
        "| Genre | Référencés | Anglais | " .. table.concat(LOCALES, " | ") .. " |",
        "|---|---|---|" .. ("---|"):rep(#LOCALES),
    }
    for _, row in ipairs(coverage) do
        local cells = {}
        for i, locale in ipairs(LOCALES) do
            cells[i] = tostring(row.translated[locale] or 0)
        end
        lines[#lines + 1] = ("| %s | %d | %d | %s |"):format(
            row.kind, row.total, row.english, table.concat(cells, " | "))
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = ("## Avertissements (%d)"):format(#report.warnings)
    lines[#lines + 1] = ""
    table.sort(report.warnings)
    for i = 1, math.min(#report.warnings, 50) do
        lines[#lines + 1] = "- " .. report.warnings[i]
    end
    if #report.warnings > 50 then
        lines[#lines + 1] = ("- … et %d autres"):format(#report.warnings - 50)
    end
    lines[#lines + 1] = ""
    writeFile(REPORT_PATH, table.concat(lines, "\n"))

    print(("Imported %d guides, %d steps, %d goals; %d warnings. Report: %s"):format(
        totals.guides, totals.steps, totals.goals, #report.warnings, REPORT_PATH))
end

main()
