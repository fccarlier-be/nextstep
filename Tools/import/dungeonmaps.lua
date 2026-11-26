-- Import des cartes des donjons de DungeonJournal (Exehn) vers les données de NextStep :
-- étages, entrées, passages d'un étage à l'autre, PNJ de quêtes, boss et boss rares, avec
-- leur position sur l'étage.
--
--   luajit Tools/import/dungeonmaps.lua [dossier de ForeverDungeonJournal]
--
-- À lancer depuis la racine du dépôt. Par défaut, le dossier est celui de l'addon installé
-- dans WoW Forever. Seules deux tables sont lues, dans un environnement isolé, sans rien
-- exécuter du reste de l'addon :
--   - FDJ.DUNGEON_MAPS, découpée dans Core/Journal.lua (table littérale, évaluée sans
--     aucune globale) ;
--   - FDJ.DB de Data/Dungeons.lua (PNJ des boss, drapeau rare).
-- Les images des cartes ne sont pas copiées : le fichier généré garde leur chemin dans le
-- dossier de DungeonJournal, que le jeu lit si l'addon est installé.
--
-- Produit addon/NextStep/Data/Imported/DungeonJournal/Maps.lua (format :
-- docs/DATA_FORMAT.md, « Cartes des donjons ») et Tools/import/dungeonmaps-report.md.

local SOURCE = arg[1] or "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/ForeverDungeonJournal"
local OUT_DIR = "addon/NextStep/Data/Imported/DungeonJournal/"
local OUT = OUT_DIR .. "Maps.lua"
local REPORT = "Tools/import/dungeonmaps-report.md"
local DUNGEONS = "addon/NextStep/Data/Imported/Polestar/Dungeons.lua"

-- Étages dessinés par Santiago Reyes (MAP_SOURCES_2.0.40.txt de DungeonJournal).
local REYES = {
    BlackmawHoldGroveMap = true, BlackmawHoldFesteringGrottoMap = true, BlackmawHoldFallenGroveMap = true,
    BlackmawHoldEldersMap = true, BlackmawHoldBurrowMap = true, BlackmawHoldForbiddenMagicMap = true,
    DrownedCityAtalByzalMap = true,
}

local function readFile(path)
    local file = assert(io.open(path, "rb"), "cannot read " .. path)
    local content = file:read("*a")
    file:close()
    return content
end

local function writeFile(path, content)
    local file = assert(io.open(path, "wb"), "cannot write " .. path)
    file:write(content)
    file:close()
end

local function lastBracket(src, i, level)
    local _, finish = src:find("]" .. level .. "]", i, true)
    return assert(finish, "unfinished long bracket") + 1
end

-- Texte de la table littérale qui suit `marker`, accolades équilibrées (chaînes et
-- commentaires sautés).
local function extractTable(src, marker)
    local start = assert(src:find(marker, 1, true), "not found: " .. marker)
    local first = src:find("{", start, true)
    local i, depth, n = first, 0, #src
    while i <= n do
        local c = src:sub(i, i)
        if c == "-" and src:sub(i, i + 1) == "--" then
            local level = src:match("^%[(=*)%[", i + 2)
            if level then
                i = lastBracket(src, i + 2, level)
            else
                i = (src:find("\n", i, true) or n) + 1
            end
        elseif c == '"' or c == "'" then
            local j = i + 1
            while src:sub(j, j) ~= c do
                j = j + (src:sub(j, j) == "\\" and 2 or 1)
                assert(j <= n, "unfinished string")
            end
            i = j + 1
        elseif c == "[" and src:match("^%[=*%[", i) then
            i = lastBracket(src, i, src:match("^%[(=*)%[", i))
        else
            if c == "{" then
                depth = depth + 1
            elseif c == "}" then
                depth = depth - 1
                if depth == 0 then
                    return src:sub(first, i)
                end
            end
            i = i + 1
        end
    end
    error("unbalanced table: " .. marker)
end

local function noGlobals(label)
    return setmetatable({}, { __index = function(_, key) error(label .. ": global " .. tostring(key)) end })
end

-- Version de DungeonJournal (TOC).
local version = readFile(SOURCE .. "/ForeverDungeonJournal.toc"):match("## Version:%s*([^\r\n]+)")
assert(version, "version not found in the TOC")

-- Cartes : table littérale, évaluée sans aucune globale.
local mapsChunk = assert(loadstring("return " .. extractTable(readFile(SOURCE .. "/Core/Journal.lua"),
    "FDJ.DUNGEON_MAPS = {"), "=DUNGEON_MAPS"))
setfenv(mapsChunk, noGlobals("DUNGEON_MAPS"))
local maps = mapsChunk()

-- Boss du journal (PNJ, drapeau rare).
local FDJ = { Constants = setmetatable({}, { __index = function() return false end }) }
local dbChunk = assert(loadstring(readFile(SOURCE .. "/Data/Dungeons.lua"), "=Dungeons.lua"))
setfenv(dbChunk, setmetatable({ _G = {} }, getmetatable(noGlobals("Dungeons.lua"))))
dbChunk("ForeverDungeonJournal", FDJ)
assert(type(FDJ.DB) == "table", "Dungeons.lua: FDJ.DB missing")

-- Donjons de NextStep (Polestar / forever-db).
local NS = { DB = {} }
local nsChunk = assert(loadstring(readFile(DUNGEONS), "=" .. DUNGEONS))
setfenv(nsChunk, setmetatable({ NextStep = NS }, getmetatable(noGlobals("Dungeons.lua (NextStep)"))))
nsChunk()

local warnings = {}
local function warn(text)
    warnings[#warnings + 1] = text
end

local function sortedKeys(t)
    local keys = {}
    for key in pairs(t) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function norm(name)
    return (tostring(name or ""):lower():gsub("[^%w]", ""))
end

-- PNJ et drapeau rare d'un boss du journal, par nom ou alias.
local function journalBosses(name)
    local byName = {}
    local entry = FDJ.DB[name]
    for _, boss in ipairs(entry and entry.bosses or {}) do
        if not boss.trash then
            for _, alias in ipairs({ boss.name, unpack(boss.aliases or {}) }) do
                byName[norm(alias)] = boss
            end
        end
    end
    return byName
end

-- Donjons rattachés à la main : ceux dont NextStep ne connaît pas les boss (pas de butin
-- dans Polestar_ItemDB), et ceux de Forever absents de ses données (clé propre, `extra`).
local BY_NAME = {
    ["Blackrock Depths"] = "depths", ["Dire Maul: East"] = "diremaul", ["Dire Maul: North"] = "diremaul",
    ["Dire Maul: West"] = "diremaul", ["Maraudon"] = "maraudon", ["Sunken Temple"] = "temple",
    ["Zul'Farrak"] = "zulfarrak",
}
local EXTRA = {
    ["Alcaz Prison"] = "alcaz", ["Blackmaw Hold"] = "blackmaw", ["Krol'dok Stronghold"] = "kroldok",
    ["Shaper's Terrace"] = "shaper", ["The Drowned City"] = "drowned",
}

-- Donjon de NextStep qui partage le plus de boss (PNJ, puis nom), sinon rattaché à la main.
local function nextStepDungeon(name, journal, mapData)
    if EXTRA[name] then
        return { key = EXTRA[name], extra = true }
    end
    for _, dungeon in ipairs(NS.DB.dungeons) do
        if dungeon.key == BY_NAME[name] then
            return dungeon
        end
    end
    local best, bestScore = nil, 0
    for _, dungeon in ipairs(NS.DB.dungeons) do
        local npcs, names = {}, {}
        for _, boss in ipairs(dungeon.bosses or {}) do
            npcs[boss.npc] = true
            names[norm(boss.name)] = true
        end
        local score = 0
        for _, boss in ipairs(mapData.bosses or {}) do
            local known = journal[norm(boss.name)]
            local npc = boss.npcID or (known and known.npcID)
            if (npc and npcs[npc]) or names[norm(boss.name)] then
                score = score + 1
            end
        end
        if score > bestScore then
            best, bestScore = dungeon, score
        end
    end
    return best
end

local function round(value)
    return math.floor(value * 10000 + 0.5) / 10000
end

---------------------------------------------------------------------------
-- Conversion
---------------------------------------------------------------------------

local result = {}        -- clé NextStep → liste d'ailes
local stats = { dungeons = 0, bosses = 0, rares = 0, floors = 0, nativeFloors = 0, images = 0, reyes = 0,
    turnins = 0, transitions = 0, entrances = 0 }
local credited = {}      -- étages de Santiago Reyes

for _, name in ipairs(sortedKeys(maps)) do
    local data = maps[name]
    local journal = journalBosses(name)
    local dungeon = nextStepDungeon(name, journal, data)
    if not dungeon then
        warn(("« %s » : aucun donjon de NextStep ne partage ses boss, ignoré"):format(name))
    else
        stats.dungeons = stats.dungeons + 1
        if dungeon.extra then
            warn(("« %s » : absent des donjons de NextStep, gardé sous la clé « %s »"):format(name, dungeon.key))
        end
        local wing = { name = name, extra = dungeon.extra, floors = {}, entrances = {}, transitions = {}, turnins = {},
            bosses = {} }

        for i, floor in ipairs(data.floors or {}) do
            local out = { map = floor.uiMapID, tiles = floor.tiles, label = floor.label }
            if floor.texture then
                out.image = floor.texture
                out.right = floor.texRight and round(floor.texRight) or nil
                out.bottom = floor.texBottom and round(floor.texBottom) or nil
                stats.images = stats.images + 1
                local file = floor.texture:match("([^\\]+)$")
                if REYES[file] then
                    out.reyes = true
                    stats.reyes = stats.reyes + 1
                    credited[#credited + 1] = ("%s, étage %d"):format(name, i)
                end
            end
            if floor.patches then
                out.patches = {}
                for _, patch in ipairs(floor.patches) do
                    out.patches[#out.patches + 1] = { patch.tex, round(patch.x0), round(patch.y0), round(patch.x1),
                        round(patch.y1), patch.alpha }
                end
            end
            if floor.uiMapID then
                stats.nativeFloors = stats.nativeFloors + 1
            elseif not floor.texture then
                warn(("« %s », étage %d : ni carte du client ni image"):format(name, i))
            end
            wing.floors[i] = out
            stats.floors = stats.floors + 1
        end

        for _, entrance in ipairs(data.entrances or { data.entrance }) do
            wing.entrances[#wing.entrances + 1] = { entrance.floor or 1, round(entrance.x), round(entrance.y) }
            stats.entrances = stats.entrances + 1
        end
        for _, step in ipairs(data.transitions or {}) do
            wing.transitions[#wing.transitions + 1] = { step.floor or 1, step.to, round(step.x), round(step.y) }
            stats.transitions = stats.transitions + 1
        end
        for _, npc in ipairs(data.turnins or {}) do
            wing.turnins[#wing.turnins + 1] = { npc.npc, npc.floor or 1, round(npc.x), round(npc.y) }
            stats.turnins = stats.turnins + 1
        end

        local nsBosses = {}
        for _, boss in ipairs(dungeon.bosses or {}) do
            nsBosses[norm(boss.name)] = boss.npc
        end
        for _, boss in ipairs(data.bosses or {}) do
            local known = journal[norm(boss.name)]
            local npc = boss.npcID or (known and known.npcID) or nsBosses[norm(boss.name)]
            if not npc then
                warn(("« %s » : boss « %s » sans PNJ connu (nom seul)"):format(name, boss.name))
            end
            local quests = boss.quest
            if type(quests) == "number" then
                quests = { quests }
            end
            local rare = known and known.rare == true or nil
            wing.bosses[#wing.bosses + 1] = { npc = npc, name = boss.name, f = boss.floor or 1,
                x = round(boss.x), y = round(boss.y), rare = rare, alt = boss.alt or nil, quests = quests }
            stats.bosses = stats.bosses + 1
            if rare and not boss.alt then
                stats.rares = stats.rares + 1
            end
        end

        result[dungeon.key] = result[dungeon.key] or {}
        local wings = result[dungeon.key]
        wings[#wings + 1] = wing
    end
end

for _, name in ipairs(sortedKeys(FDJ.DB)) do
    if not maps[name] then
        warn(("« %s » : pas de carte dans DungeonJournal"):format(name))
    else
        local placed = {}
        for _, boss in ipairs(maps[name].bosses or {}) do
            placed[norm(boss.name)] = true
        end
        for _, boss in ipairs(FDJ.DB[name].bosses or {}) do
            if boss.rare and not placed[norm(boss.name)] then
                warn(("« %s » : boss rare « %s » sans position sur la carte"):format(name, boss.name))
            end
        end
    end
end
for _, dungeon in ipairs(NS.DB.dungeons) do
    if not result[dungeon.key] then
        warn(("Donjon « %s » de NextStep sans carte"):format(dungeon.key))
    end
end

---------------------------------------------------------------------------
-- Écriture (ordre fixe : l'import est reproductible)
---------------------------------------------------------------------------

local function str(value)
    return ("%q"):format(value):gsub("\\\n", "\\n")
end

local function num(value)
    return ("%.4f"):format(value):gsub("0+$", ""):gsub("%.$", "")
end

local function list(values)
    local parts = {}
    for i = 1, select("#", unpack(values)) do
        local value = values[i]
        if type(value) == "string" then
            parts[#parts + 1] = str(value)
        elseif type(value) == "number" then
            parts[#parts + 1] = (value % 1 == 0) and tostring(value) or num(value)
        elseif value ~= nil then
            parts[#parts + 1] = tostring(value)
        end
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
end

local lines = {}
local function add(text)
    lines[#lines + 1] = text
end

add(("-- Généré par Tools/import/dungeonmaps.lua depuis DungeonJournal %s (Exehn). Ne pas modifier :"):format(version))
add("-- relancer l'import. Positions sur la carte des donjons (boss, boss rares, entrées, passages,")
add("-- PNJ de quêtes), reprises de DungeonJournal. Les images restent dans le dossier de DungeonJournal")
add("-- (chemins ci-dessous) ; étages marqués « reyes » : cartographie de Santiago Reyes")
add("-- (https://sreyesmaps.com). Format : docs/DATA_FORMAT.md, « Cartes des donjons ».")
add("")
add("local DB = NextStep.DB")
add("")
add("DB.dungeonMaps = {")
for _, key in ipairs(sortedKeys(result)) do
    add(("\t[%s] = {"):format(str(key)))
    for _, wing in ipairs(result[key]) do
        add(("\t\t{ name = %s,%s"):format(str(wing.name), wing.extra and " extra = true," or ""))
        add("\t\t\tfloors = {")
        for _, floor in ipairs(wing.floors) do
            local fields = {}
            if floor.map then fields[#fields + 1] = "map = " .. floor.map end
            if floor.tiles then fields[#fields + 1] = "tiles = " .. str(floor.tiles) end
            if floor.image then fields[#fields + 1] = "image = " .. str(floor.image) end
            if floor.right then fields[#fields + 1] = "right = " .. num(floor.right) end
            if floor.bottom then fields[#fields + 1] = "bottom = " .. num(floor.bottom) end
            if floor.reyes then fields[#fields + 1] = "reyes = true" end
            if floor.label then fields[#fields + 1] = "label = " .. str(floor.label) end
            if floor.patches then
                local patches = {}
                for _, patch in ipairs(floor.patches) do
                    patches[#patches + 1] = list(patch)
                end
                fields[#fields + 1] = "patches = { " .. table.concat(patches, ", ") .. " }"
            end
            add("\t\t\t\t{ " .. table.concat(fields, ", ") .. " },")
        end
        add("\t\t\t},")
        local function rows(field)
            if #wing[field] == 0 then
                return
            end
            local parts = {}
            for _, row in ipairs(wing[field]) do
                parts[#parts + 1] = list(row)
            end
            add(("\t\t\t%s = { %s },"):format(field, table.concat(parts, ", ")))
        end
        rows("entrances")
        rows("transitions")
        rows("turnins")
        add("\t\t\tbosses = {")
        for _, boss in ipairs(wing.bosses) do
            local fields = { "npc = " .. tostring(boss.npc or "nil"), "name = " .. str(boss.name), "f = " .. boss.f,
                "x = " .. num(boss.x), "y = " .. num(boss.y) }
            if not boss.npc then
                table.remove(fields, 1)
            end
            if boss.rare then fields[#fields + 1] = "rare = true" end
            if boss.alt then fields[#fields + 1] = "alt = true" end
            if boss.quests then fields[#fields + 1] = "quests = " .. list(boss.quests) end
            add("\t\t\t\t{ " .. table.concat(fields, ", ") .. " },")
        end
        add("\t\t\t},")
        add("\t\t},")
    end
    add("\t},")
end
add("}")
add("")

os.execute(('mkdir "%s" 2>nul'):format((OUT_DIR:gsub("/", "\\"))))
local output = table.concat(lines, "\n")
writeFile(OUT, output)

-- Relecture : le fichier écrit se charge et redonne les mêmes totaux.
local check = { DB = {} }
local reread = assert(loadstring(readFile(OUT), "=" .. OUT))
setfenv(reread, { NextStep = check })
reread()
local reBosses = 0
for _, wings in pairs(check.DB.dungeonMaps) do
    for _, wing in ipairs(wings) do
        reBosses = reBosses + #wing.bosses
        for _, boss in ipairs(wing.bosses) do
            assert(wing.floors[boss.f], wing.name .. " : étage inconnu pour " .. boss.name)
            assert(boss.x >= 0 and boss.x <= 1 and boss.y >= 0 and boss.y <= 1, wing.name .. " : position hors carte")
        end
    end
end
assert(reBosses == stats.bosses, "relecture : nombre de boss différent")

-- Rapport.
local report = {
    "# Dernier import des cartes des donjons",
    "",
    ("Source : DungeonJournal %s (`%s`). Généré par `Tools/import/dungeonmaps.lua`."):format(version,
        SOURCE:match("[^/\\]+$")),
    "",
    "| | Nombre |",
    "|---|---|",
    ("| Ailes de donjon | %d |"):format(stats.dungeons),
    ("| Étages | %d (carte du client : %d ; image de DungeonJournal : %d, dont %d de Santiago Reyes) |"):format(
        stats.floors, stats.nativeFloors, stats.images, stats.reyes),
    ("| Boss (positions) | %d, dont %d rares |"):format(stats.bosses, stats.rares),
    ("| Entrées | %d |"):format(stats.entrances),
    ("| Passages d'étage | %d |"):format(stats.transitions),
    ("| PNJ de quêtes | %d |"):format(stats.turnins),
    "",
    "## Étages de Santiago Reyes",
    "",
}
for _, line in ipairs(credited) do
    report[#report + 1] = "- " .. line
end
report[#report + 1] = ""
report[#report + 1] = "## Avertissements"
report[#report + 1] = ""
if #warnings == 0 then
    report[#report + 1] = "Aucun."
end
for _, text in ipairs(warnings) do
    report[#report + 1] = "- " .. text
end
report[#report + 1] = ""
writeFile(REPORT, table.concat(report, "\n"))

print(("%d ailes, %d étages, %d boss (%d rares), %d avertissements -> %s"):format(stats.dungeons, stats.floors,
    stats.bosses, stats.rares, #warnings, OUT))
