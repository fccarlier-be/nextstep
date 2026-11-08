-- Import des poids de stats et des aptitudes d'équipement de Polestar (Gear/Weights.lua
-- et Gear/SpecData.lua) vers les données de NextStep.
--
--   luajit Tools/import/gear.lua <checkout de Polestar> [polestar.lock]
--
-- À lancer depuis la racine du dépôt (Tools\import\run.ps1 le fait). Les deux fichiers
-- de Polestar sont exécutés dans un environnement isolé, sans accès aux fichiers ni au
-- système ; seules les tables Gear.CLASSES, WEIGHTS, PROFICIENCY, WEIGHT_BANDS et
-- RACIALS sont lues.
--
-- Produit addon/NextStep/Data/Imported/Polestar/Gear.lua (format : docs/DATA_FORMAT.md,
-- « Poids de stats ») et recopie la notice des données (MIT : ForeverLevelingBiS,
-- wowsims) dans Gear-LICENSE-DATA.txt, à côté.

local SOURCE = assert(arg[1], "usage: gear.lua <Polestar checkout> [polestar.lock]")
local LOCK_PATH = arg[2] or "Tools/import/polestar.lock"

local GEAR_DIR = SOURCE .. "/addon/Polestar/Gear/"
local OUT_DIR = "addon/NextStep/Data/Imported/Polestar/"

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

local lock = {}
for line in readFile(LOCK_PATH):gmatch("[^\r\n]+") do
    local key, value = line:match("^%s*([^#=]-)%s*=%s*(.-)%s*$")
    if key then
        lock[key] = value
    end
end

-- Exécute un fichier de Polestar avec un espace de noms factice.
local ns = { Gear = {} }
local function run(name)
    local chunk = assert(loadstring(readFile(GEAR_DIR .. name), "@" .. name))
    setfenv(chunk, { pairs = pairs, ipairs = ipairs, select = select, type = type, math = math })
    chunk("Polestar", ns)
end
run("Weights.lua")
run("SpecData.lua")
local Gear = ns.Gear
assert(Gear.CLASSES and Gear.WEIGHTS and Gear.PROFICIENCY, "Weights.lua: tables manquantes")
assert(Gear.WEIGHT_BANDS and Gear.RACIALS, "SpecData.lua: tables manquantes")

---------------------------------------------------------------------------
-- Sérialisation déterministe
---------------------------------------------------------------------------

local function sortedKeys(t)
    local keys = {}
    for key in pairs(t) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b)
        if type(a) ~= type(b) then
            return type(a) == "number"
        end
        return a < b
    end)
    return keys
end

-- Liste : clés 1..n sans trou (une table d'ensemble { [4] = true, [5] = true } n'en est pas une).
local function isList(t)
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    for i = 1, n do
        if t[i] == nil then
            return false
        end
    end
    return true
end

local function number(value)
    if value == math.floor(value) then
        return ("%d"):format(value)
    end
    return (("%.4f"):format(value):gsub("0+$", ""))
end

local serialize
local function key(k)
    if type(k) == "number" then
        return "[" .. k .. "]"
    end
    if k:match("^[%a_][%w_]*$") then
        return k
    end
    return ("[%q]"):format(k)
end

function serialize(value, indent)
    local kind = type(value)
    if kind == "number" then
        return number(value)
    elseif kind == "string" then
        return ("%q"):format(value)
    elseif kind == "boolean" then
        return tostring(value)
    end
    assert(kind == "table", "valeur inattendue : " .. kind)
    local parts = {}
    if isList(value) then
        for _, item in ipairs(value) do
            parts[#parts + 1] = serialize(item, indent .. "\t")
        end
    else
        for _, k in ipairs(sortedKeys(value)) do
            parts[#parts + 1] = key(k) .. " = " .. serialize(value[k], indent .. "\t")
        end
    end
    local flat = "{ " .. table.concat(parts, ", ") .. " }"
    if #parts == 0 then
        return "{}"
    end
    -- Une table de poids ou un ensemble tient sur une ligne, même longue.
    local set = true
    for _, item in pairs(value) do
        set = set and item == true
    end
    if #flat + #indent * 4 <= 110 or set or (value.sta and not value.weapons) then
        return flat
    end
    return "{\n" .. indent .. "\t" .. table.concat(parts, ",\n" .. indent .. "\t") .. ",\n" .. indent .. "}"
end

---------------------------------------------------------------------------
-- Tables retenues
---------------------------------------------------------------------------

local classes = {}
for class, meta in pairs(Gear.CLASSES) do
    local specs = {}
    for _, spec in ipairs(meta.specs) do
        specs[#specs + 1] = { key = spec.key, names = spec.names }
    end
    classes[class] = { bit = meta.bit, default = meta.default, specs = specs }
end

-- Tranches de niveau : seuil, poids et origine (Polestar seul ou mêlé à wowsims).
local bands = {}
for class, specs in pairs(Gear.WEIGHT_BANDS) do
    bands[class] = {}
    for spec, list in pairs(specs) do
        local out = {}
        for _, band in ipairs(list) do
            out[#out + 1] = {
                upTo = band.upTo,
                source = band.source:match("^wowsims") and "wowsims" or band.source,
                weights = band.weights,
            }
        end
        bands[class][spec] = out
    end
end

-- Traits raciaux : sans les noms anglais des talents, inutiles en jeu.
local racials = {}
for race, traits in pairs(Gear.RACIALS) do
    local out = {}
    if traits.weaponCrit then
        out.weaponCrit = { pct = traits.weaponCrit.pct, subclasses = traits.weaponCrit.subclasses }
    end
    out.statMult = traits.statMult
    racials[race] = out
end

local data = {
    classes = classes,
    weights = Gear.WEIGHTS,
    bands = bands,
    proficiency = Gear.PROFICIENCY,
    racials = racials,
}

local header = ([[
-- Généré par Tools/import/gear.lua depuis Polestar %s (%s, %s), Gear/Weights.lua et
-- Gear/SpecData.lua. Ne pas modifier : relancer Tools\import\run.ps1.
-- Polestar : Copyright (c) 2026 The Polestar authors, GPL-3.0-only. Poids mêlés aux
-- simulations de wowsims (MIT) et traits raciaux de ForeverLevelingBiS (MIT) :
-- Gear-LICENSE-DATA.txt dans ce dossier. Format : docs/DATA_FORMAT.md.

local DB = NextStep.DB

DB.gear = ]]):format(lock.version or "?", (lock.commit or "?"):sub(1, 12), lock.date or "?")

writeFile(OUT_DIR .. "Gear.lua", header .. serialize(data, "") .. "\n")
writeFile(OUT_DIR .. "Gear-LICENSE-DATA.txt", readFile(GEAR_DIR .. "LICENSE-DATA.txt"))

local count = 0
for _, specs in pairs(bands) do
    for _ in pairs(specs) do
        count = count + 1
    end
end
print(("gear: %d classes, %d spécialisations avec tranches"):format(#sortedKeys(classes), count))
