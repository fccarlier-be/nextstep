-- Données de la carte sans brouillard, à partir des tables du client décodées par Export.
--
--   luajit Tools/worldmap/generate.lua <dossier des TSV> [worldmap.lock]
--
-- À lancer depuis la racine du dépôt (Tools\worldmap\run.ps1 le fait). Lit overlays.tsv
-- et tiles.tsv, vérifie la grille de tuiles de chaque superposition, écrit le fichier de
-- données de l'addon, le relit et le compare à la source, puis écrit le rapport.
-- Le format produit est décrit dans docs/DATA_FORMAT.md.

local SOURCE = assert(arg[1], "usage: generate.lua <tsv dir> [worldmap.lock]")
local LOCK_PATH = arg[2] or "Tools/worldmap/worldmap.lock"
local OUT_PATH = "addon/NextStep/Data/Imported/Client/MapOverlays.lua"
local REPORT_PATH = "Tools/worldmap/last-import.md"
local TILE_SIZE = 256

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

local function readTSV(path)
    local rows = {}
    for line in readFile(path):gmatch("[^\r\n]+") do
        local fields = {}
        for field in (line .. "\t"):gmatch("([^\t]*)\t") do
            fields[#fields + 1] = field
        end
        rows[#rows + 1] = fields
    end
    return rows
end

local function int(value)
    return assert(tonumber(value), "not a number: " .. tostring(value))
end

---------------------------------------------------------------------------
-- Lecture
---------------------------------------------------------------------------

local lock = readLock(LOCK_PATH)
local warnings = {}
local function warn(fmt, ...)
    warnings[#warnings + 1] = fmt:format(...)
end

local overlays, overlayList = {}, {}
for _, f in ipairs(readTSV(SOURCE .. "/overlays.tsv")) do
    local overlay = {
        id = int(f[1]), art = int(f[2]), width = int(f[3]), height = int(f[4]),
        x = int(f[5]), y = int(f[6]), condition = int(f[7]), flags = int(f[8]), areas = f[9] or "",
        tiles = {},
    }
    assert(not overlays[overlay.id], "duplicate overlay " .. overlay.id)
    overlays[overlay.id] = overlay
    overlayList[#overlayList + 1] = overlay
end

local tileCount, otherLayers, orphans = 0, 0, 0
for _, f in ipairs(readTSV(SOURCE .. "/tiles.tsv")) do
    local overlayID, row, col, layer, fileDataID = int(f[2]), int(f[3]), int(f[4]), int(f[5]), int(f[6])
    local overlay = overlays[overlayID]
    if not overlay then
        orphans = orphans + 1
    elseif layer ~= 0 then
        otherLayers = otherLayers + 1
        warn("Tuile %s de la superposition %d sur la couche %d : ignorée", f[1], overlayID, layer)
    else
        local key = row * 1000 + col
        assert(not overlay.tiles[key], ("duplicate tile %d,%d in overlay %d"):format(row, col, overlayID))
        overlay.tiles[key] = fileDataID
        overlay.rows = math.max(overlay.rows or 0, row + 1)
        overlay.cols = math.max(overlay.cols or 0, col + 1)
        tileCount = tileCount + 1
    end
end
if orphans > 0 then
    warn("%d tuile(s) sans superposition : ignorées", orphans)
end

---------------------------------------------------------------------------
-- Conversion : [UiMapArtID] = { { largeur, hauteur, x, y, fichiers... } }
---------------------------------------------------------------------------

local byArt, arts, skipped, conditional = {}, {}, {}, {}
local kept, keptTiles = 0, 0
for _, overlay in ipairs(overlayList) do
    if not overlay.rows then
        skipped[#skipped + 1] = overlay
    else
        local files = {}
        for row = 0, overlay.rows - 1 do
            for col = 0, overlay.cols - 1 do
                local fileDataID = overlay.tiles[row * 1000 + col]
                assert(fileDataID, ("overlay %d: tile %d,%d missing"):format(overlay.id, row, col))
                files[#files + 1] = fileDataID
            end
        end
        local wantCols = math.ceil(overlay.width / TILE_SIZE)
        local wantRows = math.ceil(overlay.height / TILE_SIZE)
        if wantCols ~= overlay.cols or wantRows ~= overlay.rows then
            warn("Superposition %d : %dx%d pixels mais %d colonne(s) et %d rangée(s) de tuiles", overlay.id,
                overlay.width, overlay.height, overlay.cols, overlay.rows)
        end
        if overlay.condition ~= 0 or overlay.flags ~= 0 then
            conditional[#conditional + 1] = overlay
        end
        local list = byArt[overlay.art]
        if not list then
            list = {}
            byArt[overlay.art] = list
            arts[#arts + 1] = overlay.art
        end
        local entry = { overlay.width, overlay.height, overlay.x, overlay.y }
        for _, fileDataID in ipairs(files) do
            entry[#entry + 1] = fileDataID
        end
        list[#list + 1] = entry
        kept = kept + 1
        keptTiles = keptTiles + #files
    end
end
table.sort(arts)

---------------------------------------------------------------------------
-- Écriture
---------------------------------------------------------------------------

local out = {
    ("-- Généré par Tools/worldmap/generate.lua depuis les tables du client WoW Forever %s. Ne pas modifier :")
        :format(lock.build),
    "-- relancer Tools\\worldmap\\run.ps1. Format : docs/DATA_FORMAT.md.",
    "-- [UiMapArtID] = { { largeur, hauteur, décalage X, décalage Y, FileDataID des tuiles (rangée par rangée) } }",
    "",
    "local DB = NextStep.DB",
    "",
    ('DB:SetSource({ name = "Client Forever", version = "%s", tables = "WorldMapOverlay, WorldMapOverlayTile" })')
        :format(lock.build),
}
for _, art in ipairs(arts) do
    out[#out + 1] = ""
    out[#out + 1] = ("DB:AddMapOverlays(%d, function() return {"):format(art)
    for _, entry in ipairs(byArt[art]) do
        out[#out + 1] = "\t{ " .. table.concat(entry, ", ") .. " },"
    end
    out[#out + 1] = "} end)"
end
out[#out + 1] = ""
local content = table.concat(out, "\n")
writeFile(OUT_PATH, content)

---------------------------------------------------------------------------
-- Relecture : le fichier produit redonne exactement les données converties
---------------------------------------------------------------------------

local loaded, sources = {}, {}
local fakeDB = {
    SetSource = function(_, source) sources[#sources + 1] = source end,
    AddMapOverlays = function(_, art, build)
        assert(not loaded[art], "art " .. art .. " defined twice")
        loaded[art] = build()
    end,
}
local chunk = assert(loadstring(readFile(OUT_PATH), "=" .. OUT_PATH))
setfenv(chunk, { NextStep = { DB = fakeDB } })
chunk()
assert(#sources == 1 and sources[1].version == lock.build, "source not recorded")
for _, art in ipairs(arts) do
    local a, b = byArt[art], assert(loaded[art], "art " .. art .. " missing after reload")
    assert(#a == #b, "art " .. art .. ": overlay count differs after reload")
    for i = 1, #a do
        assert(table.concat(a[i], ",") == table.concat(b[i], ","), "art " .. art .. ": overlay differs after reload")
    end
end
for art in pairs(loaded) do
    assert(byArt[art], "unexpected art " .. art .. " after reload")
end

---------------------------------------------------------------------------
-- Rapport
---------------------------------------------------------------------------

local report = {
    "# Dernière extraction de la carte",
    "",
    "Généré par `Tools/worldmap/generate.lua`. Ne pas modifier à la main.",
    "",
    ("- Client : WoW Forever %s (produit `%s`)"):format(lock.build, lock.product),
    ("- Outils : TACTSharp `%s`, WoWDBDefs `%s`, DBCD (NuGet, voir `Export/Export.csproj`)")
        :format(lock.tactsharp_commit, lock.wowdbdefs_commit),
    ("- Cartes (UiMapArtID) : %d"):format(#arts),
    ("- Superpositions : %d lues, %d gardées, %d sans tuiles"):format(#overlayList, kept, #skipped),
    ("- Tuiles : %d lues sur la couche 0, %d gardées ; autres couches : %d"):format(tileCount, keptTiles, otherLayers),
    "- Vérifications : grille complète pour chaque superposition, nombre de tuiles attendu d'après la taille "
        .. "(256 pixels), relecture exacte du fichier produit.",
    "",
    ("## Superpositions sans tuiles (%d)"):format(#skipped),
    "",
    "Absentes des données : rien à afficher.",
    "",
}
if #skipped > 0 then
    report[#report + 1] = "| ID | UiMapArtID | Taille | AreaID |"
    report[#report + 1] = "|---|---|---|---|"
    for _, o in ipairs(skipped) do
        report[#report + 1] = ("| %d | %d | %dx%d | %s |"):format(o.id, o.art, o.width, o.height, o.areas)
    end
    report[#report + 1] = ""
end
report[#report + 1] = ("## Superpositions conditionnelles (%d)"):format(#conditional)
report[#report + 1] = ""
report[#report + 1] = "Gardées dans les données ; `PlayerConditionID` ou `Flags` non nuls, à examiner pour le module."
report[#report + 1] = ""
if #conditional > 0 then
    report[#report + 1] = "| ID | UiMapArtID | PlayerConditionID | Flags |"
    report[#report + 1] = "|---|---|---|---|"
    for _, o in ipairs(conditional) do
        report[#report + 1] = ("| %d | %d | %d | %d |"):format(o.id, o.art, o.condition, o.flags)
    end
    report[#report + 1] = ""
end
report[#report + 1] = ("## Avertissements (%d)"):format(#warnings)
report[#report + 1] = ""
for _, line in ipairs(warnings) do
    report[#report + 1] = "- " .. line
end
writeFile(REPORT_PATH, table.concat(report, "\n") .. "\n")

print(("%d cartes, %d superpositions, %d tuiles -> %s (%d avertissement(s), rapport : %s)"):format(#arts, kept,
    keptTiles, OUT_PATH, #warnings, REPORT_PATH))
