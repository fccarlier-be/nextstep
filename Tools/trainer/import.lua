-- Import des sorts de classe de What's Training (tables Classes/Camelot, celles de
-- WoW Forever) vers les données de NextStep.
--
--   luajit Tools/trainer/import.lua <dossier What's Training> [fichier whatstraining.lock]
--
-- À lancer depuis la racine du dépôt (Tools\trainer\run.ps1 le fait). Les fichiers de
-- What's Training sont exécutés dans un environnement isolé, sans accès aux fichiers
-- ni au système ; seule la table spellsByLevel de chaque classe est lue.
--
-- Produit addon/NextStep/Data/Imported/WhatsTraining/Spells.lua (format :
-- docs/DATA_FORMAT.md, « Sorts des maîtres de classe »), la notice MIT à côté
-- (LICENSE-DATA.txt) et le rapport Tools/trainer/last-import.md.

local SOURCE = assert(arg[1], "usage: import.lua <What's Training checkout> [whatstraining.lock]")
local LOCK_PATH = arg[2] or "Tools/trainer/whatstraining.lock"

local OUT_DIR = "addon/NextStep/Data/Imported/WhatsTraining/"
local REPORT_PATH = "Tools/trainer/last-import.md"

local CLASSES = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }
local FILES = {
    DRUID = "Druid", HUNTER = "Hunter", MAGE = "Mage", PALADIN = "Paladin", PRIEST = "Priest",
    ROGUE = "Rogue", SHAMAN = "Shaman", WARLOCK = "Warlock", WARRIOR = "Warrior",
}

-- Identifiants de race du client -> jetons de NextStep (raceFile de UnitRace en majuscules).
local RACES = {
    [1] = "HUMAN", [2] = "ORC", [3] = "DWARF", [4] = "NIGHTELF", [5] = "SCOURGE",
    [6] = "TAUREN", [7] = "GNOME", [8] = "TROLL", [95] = "SKYBORNE", [96] = "SKYBORNE",
}

-- Champs repris de chaque sort ; tout autre champ arrête l'import (format inconnu).
local FIELDS = { id = true, cost = true, requiredIds = true, requiredTalentId = true, race = true, races = true,
    faction = true, skills = true }

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

-- Exécute un fichier de classe dans un environnement isolé ; renvoie la table de la classe.
local function loadClass(path, className)
    local chunk = assert(loadstring(readFile(path), "@" .. path))
    local classes = {}
    local wt = {
        forClass = function(name)
            classes[name] = classes[name] or {}
            return classes[name]
        end,
    }
    setfenv(chunk, { ipairs = ipairs, pairs = pairs })
    chunk("WhatsTraining", wt)
    return assert(classes[className], path .. " : classe " .. className .. " absente")
end

local function racesOf(spell, where)
    local ids = spell.races or (spell.race and { spell.race })
    if not ids then
        return nil
    end
    local list, seen = {}, {}
    for _, id in ipairs(ids) do
        local token = assert(RACES[id], where .. " : race inconnue " .. tostring(id))
        if not seen[token] then
            seen[token] = true
            list[#list + 1] = token
        end
    end
    return list
end

local function serializeList(list, quote)
    local parts = {}
    for i, value in ipairs(list) do
        parts[i] = quote and ("%q"):format(value) or tostring(value)
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
end

-- Un sort : { id, coût, req = { prérequis }, talent = id, races = { jetons }, faction = "...",
-- skill = { ligne de compétence, rang } }.
local function serializeSpell(spell, where)
    for key in pairs(spell) do
        assert(FIELDS[key], where .. " : champ inconnu " .. tostring(key))
    end
    assert(type(spell.id) == "number" and type(spell.cost) == "number", where .. " : id et cost attendus")
    local parts = { ("id = %d"):format(spell.id), ("cost = %d"):format(spell.cost) }
    if spell.requiredIds and #spell.requiredIds > 0 then
        parts[#parts + 1] = "req = " .. serializeList(spell.requiredIds)
    end
    if spell.requiredTalentId then
        parts[#parts + 1] = ("talent = %d"):format(spell.requiredTalentId)
    end
    local races = racesOf(spell, where)
    if races then
        parts[#parts + 1] = "races = " .. serializeList(races, true)
    end
    if spell.skills then
        -- Compétence requise (les poisons du voleur) : une seule, { ligne, rang }.
        assert(#spell.skills == 1 and spell.skills[1].skill and spell.skills[1].level, where .. " : compétence")
        parts[#parts + 1] = ("skill = { %d, %d }"):format(spell.skills[1].skill, spell.skills[1].level)
    end
    if spell.faction then
        assert(spell.faction == "Alliance" or spell.faction == "Horde", where .. " : faction inconnue")
        parts[#parts + 1] = ("faction = %q"):format(spell.faction)
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
end

local function main()
    local lock = readLock(LOCK_PATH)
    local license = readFile(SOURCE .. "/LICENSE")
    assert(license:find("MIT License", 1, true), "licence de What's Training changée : revoir les crédits")

    local out = {
        "-- Généré par Tools/trainer/import.lua depuis What's Training (" .. lock.commit:sub(1, 12) .. ", "
            .. lock.date .. "). Ne pas modifier :",
        "-- relancer Tools\\trainer\\run.ps1. Données sous licence MIT (Copyright (c) 2019, What's Training) :",
        "-- LICENSE-DATA.txt dans ce dossier. Format : docs/DATA_FORMAT.md.",
        "",
        "local DB = NextStep.DB",
        "",
        ("DB:SetSource({ name = \"What's Training\", commit = %q, date = %q })"):format(lock.commit, lock.date),
        "",
    }
    local report = {
        "# Dernier import de What's Training",
        "",
        ("Source : %s, commit `%s` (%s). Tables `Classes/Camelot`."):format(lock.repository, lock.commit, lock.date),
        "",
        "| Classe | Niveaux | Sorts | Propres à une race | Propres à une faction | Talent requis |",
        "|---|---|---|---|---|---|",
    }
    local total = 0
    for _, className in ipairs(CLASSES) do
        local path = ("%s/Classes/Camelot/%s.lua"):format(SOURCE, FILES[className])
        local class = loadClass(path, className)
        local byLevel = assert(class.spellsByLevel, path .. " : spellsByLevel absent")
        local levels = {}
        for level in pairs(byLevel) do
            levels[#levels + 1] = level
        end
        table.sort(levels)
        local count, racial, factional, talents = 0, 0, 0, 0
        out[#out + 1] = ("DB:AddTrainerSpells(%q, function() return {"):format(className)
        for _, level in ipairs(levels) do
            local lines = {}
            for index, spell in ipairs(byLevel[level]) do
                local where = ("%s niveau %d sort %d"):format(className, level, index)
                lines[#lines + 1] = "\t\t" .. serializeSpell(spell, where) .. ","
                count = count + 1
                racial = racial + ((spell.race or spell.races) and 1 or 0)
                factional = factional + (spell.faction and 1 or 0)
                talents = talents + (spell.requiredTalentId and 1 or 0)
            end
            out[#out + 1] = ("\t[%d] = {"):format(level)
            for _, line in ipairs(lines) do
                out[#out + 1] = line
            end
            out[#out + 1] = "\t},"
        end
        out[#out + 1] = "} end)"
        out[#out + 1] = ""
        report[#report + 1] = ("| %s | %d | %d | %d | %d | %d |"):format(className, #levels, count, racial, factional,
            talents)
        total = total + count
    end
    report[#report + 1] = ""
    report[#report + 1] = ("Total : %d sorts."):format(total)
    report[#report + 1] = ""

    local content = table.concat(out, "\n")
    -- Relecture : le fichier produit doit se charger.
    assert(loadstring(content, "Spells.lua"))
    writeFile(OUT_DIR .. "Spells.lua", content)
    writeFile(OUT_DIR .. "LICENSE-DATA.txt",
        "Données des sorts de classe reprises de What's Training\n"
        .. "(" .. lock.repository .. ", commit " .. lock.commit .. "), sous licence MIT :\n\n" .. license)
    writeFile(REPORT_PATH, table.concat(report, "\n"))
    print(("What's Training : %d sorts importés."):format(total))
end

main()
