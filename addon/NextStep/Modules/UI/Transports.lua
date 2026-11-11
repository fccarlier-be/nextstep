-- Horaires des bateaux, zeppelins et du tram (docs/DESIGN.md, « Transports ») : près
-- d'un quai, un encart dit dans combien de temps part le prochain transport.
--
-- Le jeu ne donne ni la position des transports ni leur horaire. Chacun suit pourtant
-- un tour fixe : NauticusClassicResurrected (MIT, voir CREDITS.md) en a relevé la
-- durée, l'ordre des escales et l'instant où le transport arrive à chaque quai et en
-- repart. Il suffit donc de voir partir le transport une fois pour situer son tour et
-- prévoir tous ses départs, à chaque escale.
--
-- Le départ se voit quand le joueur est à bord : sa position avance alors qu'il ne
-- marche pas (GetUnitSpeed nul, hors trajet de vol). Un mouvement qui part d'un quai
-- (Travel.DOCKS) et dure 8 secondes est un départ de ce quai : le quai, et pour le
-- tram la voie, désignent le transport. L'arrivée n'est pas attendue.
--
-- Partage : chaque départ vu est envoyé au groupe et à la guilde (message d'addon
-- « NextStepTr »), et à la connexion l'addon demande les horaires connus. Les heures
-- sont celles du serveur (GetServerTime), communes à tous les joueurs.
--
-- Observations communes aux personnages, par royaume (db.realms). Un redémarrage du
-- serveur peut décaler les tours : une observation de plus de 24 h n'est plus utilisée.

local _, ns = ...
local L = ns.L
local Style = ns.Style
local Travel = ns.Travel

local Transports = ns.Modules:New("Transports", {
    title = L["Boat and zeppelin times"],
    description = L["Near a dock, shows when the next boat, zeppelin or tram leaves, learned from trips "
        .. "and shared with your group and guild."],
    defaults = {
        realms = {},   -- [royaume] = { [transport] = { start, seen } }
        trace = {},    -- derniers départs et arrivées détectés (diagnostic)
        share = true,  -- envoyer et recevoir les horaires
    },
})

local SAMPLE = 0.5          -- secondes entre deux relevés de position
local MOVING = 3            -- yards par seconde : au-delà, le transport avance
local STOPPED = 0.5         -- yards par seconde : en deçà, il est à quai
local STOP_SAMPLES = 3      -- relevés immobiles d'affilée pour une arrivée
local CONFIRM = 8           -- secondes de trajet à bord qui confirment un départ
local DOCK_RADIUS = 150     -- yards : un départ à cette distance d'un point d'accostage
local MAX_AGE = 24 * 3600   -- secondes : au-delà, l'horaire appris est trop vieux
local DISPLAY_RADIUS = 250  -- yards : l'encart s'affiche près d'un point d'accostage
local PREFIX = "NextStepTr"

Transports.MAX_AGE = MAX_AGE
Transports.PREFIX = PREFIX

-- Tours (NauticusClassicResurrected, version Forever) : durée en secondes, escales dans
-- l'ordre du trajet : quai (Travel.DOCKS), arrivée et départ comptés depuis le début du
-- tour, et point d'accostage (nord, ouest ; continent du quai). Deux transports d'un
-- même port accostent à des pontons ou des plateformes distincts : c'est ce point,
-- pas le quai, qui les distingue (et, pour le tram, la voie).
local ROUTES = {
    { id = "tirisfal-durotar", kind = "zeppelin", faction = "Horde", period = 356.288,
        { "durotar", 0, 60, 1310.3, -4648.5 }, { "tirisfal", 191.139, 251.139, 2073.6, 298.1 } },
    { id = "gromgol-durotar", kind = "zeppelin", faction = "Horde", period = 303.467,
        { "durotar", 0, 60, 1372.8, -4634.6 }, { "gromgol", 138.314, 198.314, -12461.4, 219.5 } },
    { id = "tirisfal-gromgol", kind = "zeppelin", faction = "Horde", period = 335.298,
        { "tirisfal", 0, 60, 2051.7, 229.6 }, { "gromgol", 155.978, 215.978, -12398.7, 202.7 } },
    { id = "bootyBay-ratchet", kind = "boat", period = 350.823,
        { "ratchet", 0, 60, -1008.3, -3840.1 }, { "bootyBay", 166.808, 226.808, -14280.7, 583.8 } },
    -- Sur Forever, ce bateau fait escale à Austrivage (tour de 8 min, pas 5).
    { id = "menethil-auberdine", kind = "boat", faction = "Alliance", period = 486.226,
        { "menethil", 0, 60, -3710.8, -572.4 }, { "southshore", 202.265, 262.276, -1102.5, -551.6 },
        { "auberdine", 345.796, 404.997, 6407.6, 826.1 } },
    { id = "menethil-theramore", kind = "boat", faction = "Alliance", period = 329.316,
        { "menethil", 0, 60, -3908.0, -587.2 }, { "theramore", 164.003, 224.003, -4018.8, -4738.7 } },
    { id = "rutheran-auberdineTeldrassil", kind = "boat", faction = "Alliance", period = 316.254,
        { "rutheran", 0, 60, 8533.5, 1028.0 }, { "auberdineTeldrassil", 164.465, 224.465, 6593.8, 756.9 } },
    { id = "feathermoon-forgottenCoast", kind = "boat", faction = "Alliance", period = 317.045,
        { "feathermoon", 0, 60, -4197.4, 3289.6 }, { "forgottenCoast", 119.881, 179.881, -4344.8, 2444.6 } },
    { id = "stormwind-auberdineWest", kind = "boat", faction = "Alliance", period = 246.5,
        { "stormwind", 17.469, 77.105, -8650.8, 1345.8 }, { "auberdineWest", 135.092, 195.091, 6547.1, 943.0 } },
    { id = "tram-north", kind = "tram", period = 143.334,
        { "tramStormwind", 0, 12.1, 4.5, 2490.8 }, { "tramIronforge", 70.735, 84.685, 4.5, 8.5 } },
    { id = "tram-south", kind = "tram", period = 143.334,
        { "tramStormwind", 0, 13.95, -45.4, 2492.8 }, { "tramIronforge", 72.582, 84.682, -45.4, 9.8 } },
}
Transports.ROUTES = ROUTES

local byId = {}
for _, route in ipairs(ROUTES) do
    byId[route.id] = route
    for _, stop in ipairs(route) do
        stop.dock, stop.arrive, stop.depart, stop.north, stop.west = stop[1], stop[2], stop[3], stop[4], stop[5]
    end
end

function Transports.RouteById(id)
    return byId[id]
end

-- Escale d'un quai sur un tour : index, escale (ou nil).
local function stopOf(route, dock)
    for index, stop in ipairs(route) do
        if stop.dock == dock then
            return index, stop
        end
    end
end
Transports.StopOf = stopOf

---------------------------------------------------------------------------
-- Quais
---------------------------------------------------------------------------

local function distance(n1, w1, n2, w2)
    local dn, dw = n1 - n2, w1 - w2
    return math.sqrt(dn * dn + dw * dw)
end

-- Quais à moins de radius yards d'une position : { [id] = distance }.
function Transports.DocksNear(instance, north, west, radius)
    local found = {}
    for id, dock in pairs(Travel.DOCKS) do
        local i, n, w = Travel.Where(dock)
        if i and i == instance then
            local d = distance(north, west, n, w)
            if d <= radius then
                found[id] = d
            end
        end
    end
    return found
end

-- Point d'accostage le plus proche d'une position, à moins de radius yards :
-- tour, index de l'escale, distance (ou nil).
-- Distance d'une position au point d'accostage d'une escale (nil sur un autre continent).
local function berthDistance(stop, instance, north, west)
    if stop.instance == nil then
        stop.instance = Travel.Where(Travel.DOCKS[stop.dock]) or false
    end
    if stop.instance == instance then
        return distance(north, west, stop.north, stop.west)
    end
end

local function nearestBerth(instance, north, west, radius)
    local best, bestIndex, bestDistance
    for _, route in ipairs(ROUTES) do
        for index, stop in ipairs(route) do
            local d = berthDistance(stop, instance, north, west)
            if d then
                if d <= radius and (not bestDistance or d < bestDistance) then
                    best, bestIndex, bestDistance = route, index, d
                end
            end
        end
    end
    return best, bestIndex, bestDistance
end
Transports.NearestBerth = nearestBerth

---------------------------------------------------------------------------
-- Détection à bord (pure : relevés en entrée, événements en sortie)
---------------------------------------------------------------------------

local Tracker = {}
Tracker.__index = Tracker
Transports.Tracker = Tracker

function Tracker.New()
    return setmetatable({ moving = false, still = 0, trace = {} }, Tracker)
end

-- Quai le plus proche (identifiant, distance) : pour la trace.
local function nearest(instance, north, west)
    local best, bestDistance
    for id, d in pairs(Transports.DocksNear(instance, north, west, math.huge)) do
        if not bestDistance or d < bestDistance then
            best, bestDistance = id, d
        end
    end
    return best, bestDistance
end

-- Trace des départs et arrivées détectés (les 8 derniers), pour /ns transports.
function Tracker:Note(t, what, instance, north, west, detail)
    local dock, d = nearest(instance, north, west)
    table.insert(self.trace, 1, { t = t, what = what, instance = instance, north = math.floor(north + 0.5),
        west = math.floor(west + 0.5), dock = dock, distance = d and math.floor(d + 0.5), detail = detail })
    self.trace[9] = nil
end

-- Départ confirmé : CONFIRM secondes transporté (sans marcher) depuis un quai, sans
-- attendre l'arrivée (on descend souvent du tram ou du bateau en marchant).
local function confirm(self)
    local departure = self.departure
    if not departure or departure.sent or departure.ridden < CONFIRM then
        return nil
    end
    departure.sent = true
    local route, index = departure.route, departure.index
    departure.note.detail = route.id
    return { link = route.id, from = route[index].dock, to = route[index % #route + 1].dock,
        departed = departure.t }
end

-- Un relevé : t (secondes), position (nil hors du monde), vitesse propre du joueur,
-- en trajet de vol. Renvoie un événement ou nil : { link, from, to, departed }.
function Tracker:Feed(t, instance, north, west, ownSpeed, onTaxi)
    if not instance or onTaxi then
        if onTaxi then
            self.moving, self.departure = false, nil
        end
        self.last = nil
        return nil
    end
    local last = self.last
    self.last = { t = t, instance = instance, north = north, west = west }
    if not last or last.instance ~= instance or t <= last.t then
        -- Changement de continent en pleine traversée : on continue sur l'autre.
        return nil
    end
    if ownSpeed and ownSpeed > 0 then
        -- Le joueur marche (sur le pont ou à terre) : rien à conclure de ce relevé.
        self.still = 0
        return nil
    end
    local event
    local rate = distance(north, west, last.north, last.west) / (t - last.t)
    if rate >= MOVING then
        self.still = 0
        if not self.moving then
            self.moving = true
            self:Note(last.t, "start", last.instance, last.north, last.west)
            local route, index = nearestBerth(last.instance, last.north, last.west, DOCK_RADIUS)
            self.departure = route and { t = last.t, route = route, index = index, note = self.trace[1],
                ridden = 0 } or nil
        end
        if self.departure then
            self.departure.ridden = self.departure.ridden + (t - last.t)
            event = confirm(self)
        end
    elseif rate <= STOPPED and self.moving then
        self.still = self.still + 1
        if self.still >= STOP_SAMPLES then
            self.moving = false
            self.still = 0
            local departure = self.departure
            self.departure = nil
            self:Note(t - (STOP_SAMPLES * SAMPLE), "stop", instance, north, west,
                not departure and "no dock at start" or not departure.sent and "too short" or nil)
        end
    end
    return event
end

---------------------------------------------------------------------------
-- Apprentissage et prévision (pures)
---------------------------------------------------------------------------

-- Début du tour (heure serveur) d'après un départ observé, ou nil.
local function startOf(route, dock, departed)
    local _, stop = stopOf(route, dock)
    return stop and departed - stop.depart
end

-- Mémorise un départ observé (ou reçu) dans les données d'un royaume :
-- event = { link, from, departed } ou { link, start, seen }.
function Transports.Learn(realm, event)
    local route = byId[event.link]
    if not route then
        return
    end
    local start, seen = event.start, event.seen
    if not start then
        start, seen = startOf(route, event.from, event.departed), event.departed
    end
    if not start then
        return
    end
    local data = realm[route.id]
    if not (data and data.seen and data.seen > seen) then
        realm[route.id] = { start = start, seen = seen }
    end
end

-- Données d'une version précédente (dernier départ vu d'un quai) : converties.
function Transports.Migrate(realm)
    for id, data in pairs(realm) do
        local route = byId[id]
        local last = type(data) == "table" and data.last
        if route and last and not data.start then
            local start = startOf(route, last.dock, last.t)
            realm[id] = start and { start = start, seen = last.t } or nil
        elseif not route or type(data) ~= "table" or not data.start then
            realm[id] = nil
        end
    end
end

-- Prochain départ du quai dock : secondes d'attente et « à quai » (le transport y est
-- déjà), ou nil si le tour est inconnu ou trop vieux.
function Transports.NextDeparture(data, route, dock, now)
    if not (data and data.start and data.seen) or now - data.seen > MAX_AGE then
        return nil
    end
    local _, stop = stopOf(route, dock)
    if not stop then
        return nil
    end
    local period = route.period
    local phase = (now - data.start) % period
    local wait = (stop.depart - phase) % period
    return wait, wait <= stop.depart - stop.arrive
end

---------------------------------------------------------------------------
-- Partage (pur : texte des messages)
---------------------------------------------------------------------------

-- « T|transport|début du tour|heure de l'observation » (dixièmes de seconde pour le début).
function Transports.Encode(id, data)
    return ("T|%s|%.1f|%d"):format(id, data.start, data.seen)
end

-- Message reçu -> départ à apprendre, ou nil s'il est invalide ou trop vieux.
function Transports.Decode(text, now)
    local id, start, seen = tostring(text or ""):match("^T|([%w%-]+)|(%-?[%d%.]+)|(%d+)$")
    if not (id and byId[id]) then
        return nil
    end
    start, seen = tonumber(start), tonumber(seen)
    if not (start and seen) or seen > now + 60 or now - seen > MAX_AGE then
        return nil
    end
    return { link = id, start = start, seen = seen }
end

---------------------------------------------------------------------------
-- En jeu
---------------------------------------------------------------------------

local function serverNow()
    if GetServerTime then
        local t = GetServerTime()
        if ns.Usable(t) then
            return t
        end
    end
    return (time or os.time)()
end

function Transports:Realm()
    local name = GetRealmName and GetRealmName() or "?"
    if not ns.Usable(name) then
        name = "?"
    end
    self.db.realms[name] = self.db.realms[name] or {}
    return self.db.realms[name]
end

-- Canaux de partage disponibles.
local function channels()
    local list = {}
    if IsInGroup and IsInGroup() then
        list[#list + 1] = (IsInRaid and IsInRaid()) and "RAID" or "PARTY"
    end
    if IsInGuild and IsInGuild() then
        list[#list + 1] = "GUILD"
    end
    return list
end

local function send(text)
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
        return
    end
    for _, channel in ipairs(channels()) do
        C_ChatInfo.SendAddonMessage(PREFIX, text, channel)
    end
end

function Transports:Share(id)
    if not self.db.share then
        return
    end
    local data = self:Realm()[id]
    if data and data.start then
        send(Transports.Encode(id, data))
    end
end

-- Réponse à une demande : nos horaires récents, sauf ceux qu'un autre a déjà donnés.
function Transports:Answer()
    local now = serverNow()
    for id, data in pairs(self:Realm()) do
        local heard = self.heard and self.heard[id]
        if data.seen and now - data.seen <= MAX_AGE and not (heard and heard >= data.seen) then
            send(Transports.Encode(id, data))
        end
    end
end

function Transports:OnAddonMessage(prefix, text, _, sender)
    if prefix ~= PREFIX or not self.db.share then
        return
    end
    local me = UnitName and UnitName("player")
    if sender and me and (sender == me or sender:match("^([^%-]+)") == me) then
        return
    end
    if text == "Q" then
        -- Réponse décalée, pour laisser répondre les autres d'abord.
        self.heard = {}
        if C_Timer and C_Timer.After then
            C_Timer.After(1 + math.random() * 7, function()
                self:Answer()
            end)
        end
        return
    end
    local event = Transports.Decode(text, serverNow())
    if event then
        self.heard = self.heard or {}
        self.heard[event.link] = math.max(self.heard[event.link] or 0, event.seen)
        Transports.Learn(self:Realm(), event)
    end
end

function Transports:Sample()
    local instance, north, west = ns.Navigation.PlayerPosition()
    local speed = GetUnitSpeed and GetUnitSpeed("player") or 0
    if not ns.Usable(speed) then
        speed = 0
    end
    local onTaxi = UnitOnTaxi and UnitOnTaxi("player") or false
    local event = self.tracker:Feed(serverNow(), instance, north, west, speed, onTaxi)
    if event then
        Transports.Learn(self:Realm(), event)
        self:Share(event.link)
    end
    self.aboard = self.tracker.moving
    self.db.trace = self.tracker.trace
end

-- /ns transports : état de la détection et derniers départs ou arrivées vus.
function Transports:Report()
    local instance, north, west = ns.Navigation.PlayerPosition()
    local speed = GetUnitSpeed and GetUnitSpeed("player")
    ns:Print(("Transports : position %s %s %s, vitesse propre %s, à bord %s"):format(tostring(instance),
        tostring(north and math.floor(north)), tostring(west and math.floor(west)), tostring(speed),
        tostring(self.aboard)))
    if instance then
        local dock, d = nearest(instance, north, west)
        ns:Print(("  quai le plus proche : %s (%s m)"):format(tostring(dock), tostring(d and math.floor(d))))
    end
    for _, entry in ipairs(self.tracker and self.tracker.trace or {}) do
        ns:Print(("  %s %s : %s %s %s, quai %s à %s m %s"):format(date and date("%H:%M:%S", entry.t) or entry.t,
            entry.what, tostring(entry.instance), entry.north, entry.west, tostring(entry.dock),
            tostring(entry.distance), entry.detail or ""))
    end
end

local function duration(seconds)
    seconds = math.floor(seconds + 0.5)
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local KINDS = { boat = "Boat to %s", zeppelin = "Zeppelin to %s", tram = "Tram to %s" }

-- Escales suivantes d'un quai, dans l'ordre du trajet : « Austrivage puis Auberdine ».
local function destinations(route, index)
    local names = {}
    for k = 1, #route - 1 do
        local stop = route[(index + k - 1) % #route + 1]
        names[#names + 1] = L[Travel.DOCKS[stop.dock].name]
    end
    return table.concat(names, L[" then "])
end

-- Lignes de l'encart pour une position : { { text, wait, docked } }, vide loin d'un quai.
-- Les rames du tram vers la même destination n'en font qu'une : la prochaine qui part.
function Transports:Lines(instance, north, west, faction, now)
    local lines, byLabel = {}, {}
    if not instance then
        return lines
    end
    local realm = self:Realm()
    for _, route in ipairs(ROUTES) do
        if not route.faction or route.faction == faction then
            for index, stop in ipairs(route) do
                local d = berthDistance(stop, instance, north, west)
                if d and d <= DISPLAY_RADIUS then
                    local label = L[KINDS[route.kind]]:format(destinations(route, index))
                    local wait, docked = Transports.NextDeparture(realm[route.id], route, stop.dock, now)
                    local line = byLabel[label]
                    if not line then
                        line = { label = label }
                        byLabel[label] = line
                        lines[#lines + 1] = line
                    end
                    if wait and (not line.wait or wait < line.wait) then
                        line.wait, line.docked = wait, docked
                    end
                end
            end
        end
    end
    for _, line in ipairs(lines) do
        if line.wait then
            line.text = (line.docked and L["%s: at the dock, leaves in %s"] or L["%s: leaves in %s"])
                :format(line.label, duration(line.wait))
        else
            line.text = L["%s: time unknown, ride it once to learn it"]:format(line.label)
        end
    end
    return lines
end

function Transports:CreateFrame()
    local frame = CreateFrame("Frame", "NextStepTransports", UIParent)
    frame:SetSize(320, 24)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -150)
    frame:SetFrameStrata("MEDIUM")
    Style.Frame(frame)
    frame.texts = {}
    frame:Hide()
    self.frame = frame
    return frame
end

function Transports:UpdateFrame()
    local lines = {}
    if not self.aboard then
        local instance, north, west = ns.Navigation.PlayerPosition()
        lines = self:Lines(instance, north, west, UnitFactionGroup("player"), serverNow())
    end
    local frame = self.frame or self:CreateFrame()
    if #lines == 0 then
        frame:Hide()
        return
    end
    local width = 0
    for index, line in ipairs(lines) do
        local text = frame.texts[index]
        if not text then
            text = Style.Text(frame, "GameFontHighlight", Style.COLORS.text, "CENTER")
            text:SetPoint("TOP", frame, "TOP", 0, -6 - (index - 1) * 16)
            frame.texts[index] = text
        end
        text:SetText(line.text)
        text:Show()
        width = math.max(width, text:GetStringWidth() or 0)
    end
    for index = #lines + 1, #frame.texts do
        frame.texts[index]:Hide()
    end
    frame:SetSize(math.max(200, width + 24), 12 + #lines * 16)
    frame:Show()
end

function Transports:OnInitialize()
    ns.Slash:Add("transports", function()
        self:Report()
    end, L["Boat and tram detection state"])
end

function Transports:OnEnable()
    self.tracker = self.tracker or Tracker.New()
    self.tracker.trace = self.db.trace or self.tracker.trace
    for _, realm in pairs(self.db.realms) do
        Transports.Migrate(realm)
    end
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
    self:RegisterEvent("CHAT_MSG_ADDON", function(_, _, ...)
        self:OnAddonMessage(...)
    end)
    if C_Timer and C_Timer.NewTicker then
        self.ticker = C_Timer.NewTicker(SAMPLE, function()
            self:Sample()
            self.tick = (self.tick or 0) + 1
            if self.tick % 2 == 0 then
                self:UpdateFrame()
            end
        end)
    end
    -- À la connexion : demander les horaires connus du groupe et de la guilde.
    if C_Timer and C_Timer.After and self.db.share then
        C_Timer.After(10 + math.random() * 10, function()
            if self.enabled then
                send("Q")
            end
        end)
    end
end

function Transports:OnDisable()
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    if self.frame then
        self.frame:Hide()
    end
end
