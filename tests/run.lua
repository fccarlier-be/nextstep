-- Lance les tests hors jeu, depuis la racine du dépôt :
--   lua tests/run.lua          (ou luajit)
-- Code de sortie 1 si un test échoue.

package.path = "./tests/?.lua;" .. package.path

local SPECS = {
    "events",
    "storage",
    "modules",
    "factions",
    "slash",
    "locale",
    "data",
    "names",
    "map_reveal",
    "zone_levels",
    "radar",
    "minimap",
    "quest_items",
    "junk",
    "clock",
    "unit_text",
    "windows",
    "engine",
    "guide",
    "guide_live",
    "pins",
    "spells",
    "journal",
    "items",
    "dungeons",
    "celebration",
    "autoplay",
    "diagnostic",
}

local wow
local passed, failed = 0, 0
local suite = ""

-- Comparaison profonde, pour les tables.
local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return a == b
    end
    for key, value in pairs(a) do
        if not same(value, b[key]) then
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

function describe(name, fn)
    suite = name
    fn()
end

function expect_eq(actual, expected, message)
    if not same(actual, expected) then
        error(("%s\n    attendu : %s\n    obtenu  : %s"):format(
            message or "valeurs différentes", tostring(expected), tostring(actual)), 2)
    end
end

function expect(value, message)
    if not value then
        error(message or "condition fausse", 2)
    end
end

function it(name, fn)
    local ok, err = xpcall(fn, debug.traceback)
    wow.reset()
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print(("ÉCHEC  %s : %s\n    %s"):format(suite, name, err))
    end
end

-- Chargé après les fonctions globales ci-dessus, pour que wow.reset() les conserve.
wow = require("wow")

for _, spec in ipairs(SPECS) do
    dofile("tests/spec/" .. spec .. "_spec.lua")
end

print(("%d réussi(s), %d échoué(s)"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
