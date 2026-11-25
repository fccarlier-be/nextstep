-- Banc d'essai du calculateur de chemins importé (addon/NextStep_Nav*), hors du jeu.
--
-- Usage : luajit Tools/import/navcheck.lua [chemin de zlib1.dll]
--
-- Charge NextStep_Nav comme le client (ses cartes de continent à la demande), avec
-- une simulation minimale de l'API (C_EncodingUtil par zlib via FFI, C_Timer), puis
-- demande quelques trajets connus et vérifie qu'un chemin revient, plus long que la
-- ligne droite mais pas absurde. À lancer après chaque Tools/import/nav.py.

local ffi = require("ffi")

local ZLIB = arg[1] or "C:/Program Files/Git/mingw64/bin/zlib1.dll"
ffi.cdef([[
int uncompress(unsigned char *dest, unsigned long *destLen, const unsigned char *source, unsigned long sourceLen);
]])
local zlib = ffi.load(ZLIB)

---------------------------------------------------------------------------
-- API simulée
---------------------------------------------------------------------------

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local decode = {}
for i = 1, #B64 do
    decode[B64:byte(i)] = i - 1
end

local function decodeBase64(text)
    local out, bits, count = {}, 0, 0
    for i = 1, #text do
        local value = decode[text:byte(i)]
        if value then
            bits = bits * 64 + value
            count = count + 6
            if count >= 8 then
                count = count - 8
                local byte = math.floor(bits / 2 ^ count) % 256
                out[#out + 1] = string.char(byte)
                bits = bits % 2 ^ count
            end
        end
    end
    return table.concat(out)
end

local function decompress(data)
    local size = math.max(#data * 8, 4096)
    for _ = 1, 8 do
        local dest = ffi.new("unsigned char[?]", size)
        local length = ffi.new("unsigned long[1]", size)
        local result = zlib.uncompress(dest, length, data, #data)
        if result == 0 then
            return ffi.string(dest, length[0])
        elseif result == -5 then   -- Z_BUF_ERROR : tampon trop petit
            size = size * 4
        else
            return nil
        end
    end
end

C_EncodingUtil = { DecodeBase64 = decodeBase64, DecompressString = function(data) return decompress(data) end }
Enum = { CompressionMethod = { Zlib = 1 } }

local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local start = os.clock()
debugprofilestop = function() return (os.clock() - start) * 1000 end
GetTime = function() return os.clock() - start end
InCombatLockdown = function() return false end
local function stubFrame()
    return setmetatable({}, { __index = function() return function() end end })
end
CreateFrame = stubFrame

local ROOT = "addon/"
local loaded = {}

local function loadAddOn(name)
    if loaded[name] then
        return true
    end
    loaded[name] = true
    local ns = {}
    local toc = assert(io.open(ROOT .. name .. "/" .. name .. ".toc"))
    for line in toc:lines() do
        line = line:gsub("\r$", "")
        if line:match("%S") and not line:match("^#") then
            local file = line:gsub("\\", "/")
            if file:match("%.xml$") then
                local dir = file:match("^(.*)/") or ""
                local xml = assert(io.open(ROOT .. name .. "/" .. file)):read("*a")
                for script in xml:gmatch('<Script file="([^"]+)"') do
                    assert(loadfile(ROOT .. name .. "/" .. dir .. "/" .. script:gsub("\\", "/")))(name, ns)
                end
            else
                assert(loadfile(ROOT .. name .. "/" .. file))(name, ns)
            end
        end
    end
    toc:close()
    return true
end
C_AddOns = { LoadAddOn = loadAddOn }

---------------------------------------------------------------------------
-- Essais
---------------------------------------------------------------------------

local t0 = os.clock()
loadAddOn("NextStep_Nav")
local Path = assert(NextStep_NavEngine, "NextStep_NavEngine absent")
print(("NextStep_Nav chargé en %.1f s"):format(os.clock() - t0))

-- { nom, instance, départ { nord, ouest }, arrivée, longueur maximale admise (fois la ligne droite) }
local TRIPS = {
    { "Abbaye de Comté-du-Nord -> Goldshire", 0, { -8913, -137 }, { -9465, 64 }, 2.5 },
    { "Goldshire -> Mine de la Fosse", 0, { -9465, 64 }, { -9800, 150 }, 3 },
    { "Darnassus (porte) -> Dolanaar", 1, { 9947, 2600 }, { 9850, 970 }, 3 },
}

local failures = 0
for _, trip in ipairs(TRIPS) do
    local name, map, from, to, factor = trip[1], trip[2], trip[3], trip[4], trip[5]
    local done, points, reason
    local t1 = os.clock()
    Path.Find(map, { x = from[1], y = from[2] }, { x = to[1], y = to[2] }, function(p, r)
        done, points, reason = true, p, r
    end, { waterWalking = false, profile = "Alliance" })
    local rounds = 0
    while not done and rounds < 100000 do
        rounds = rounds + 1
        local list = timers
        timers = {}
        for _, fn in ipairs(list) do
            fn()
        end
        if #timers == 0 and not done then
            break
        end
    end
    local straight = math.sqrt((to[1] - from[1]) ^ 2 + (to[2] - from[2]) ^ 2)
    if type(points) == "table" and #points >= 2 then
        local length = 0
        for i = 2, #points do
            length = length + math.sqrt((points[i].x - points[i - 1].x) ^ 2 + (points[i].y - points[i - 1].y) ^ 2)
        end
        local ok = length >= straight * 0.95 and length <= straight * factor
        print(("%s %s : %d points, %.0f yd (ligne droite %.0f), %.1f s"):format(ok and "OK " or "KO ", name,
            #points, length, straight, os.clock() - t1))
        if not ok then
            failures = failures + 1
        end
    else
        print(("KO  %s : pas de chemin (%s)"):format(name, tostring(reason)))
        failures = failures + 1
    end
end
os.exit(failures == 0 and 0 or 1)
