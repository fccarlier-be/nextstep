-- Horaires des bateaux, zeppelins et du tram (docs/DESIGN.md, « Transports ») : près
-- d'un quai, un encart dit dans combien de temps part le prochain transport.
--
-- Le jeu ne donne ni la position des transports ni leur horaire. Ils tournent pourtant
-- en boucle, à durée fixe : la durée d'un tour est connue (mesurée par NauticusClassic,
-- MIT, voir CREDITS.md) et l'addon apprend où en est chaque transport en voyant le
-- joueur à bord : la position du joueur avance alors qu'il ne marche pas (GetUnitSpeed
-- nul, hors trajet de vol).
--   départ  : le mouvement commence près d'un quai connu (Travel.DOCKS) ;
--   arrivée : il s'arrête près d'un autre quai : durée de la traversée ;
--   escale  : resté à bord, le départ suivant donne la durée de l'escale.
-- Une liaison sans durée connue (Hurlevent–Auberdine, ajout de Forever) l'estime :
-- traversée + escale à chaque bout (escale de 60 s présumée, heure « environ ») ; deux
-- départs du même quai fixent le tour.
--
-- Partage : chaque traversée apprise est envoyée au groupe et à la guilde (message
-- d'addon « NextStepTr »), et à la connexion l'addon demande les horaires connus.
-- Les heures sont celles du serveur (GetServerTime), communes à tous les joueurs.
--
-- Observations communes aux personnages, par royaume (db.realms). Un redémarrage du
-- serveur décale les horaires : une observation de plus de 24 h n'est plus utilisée.

local _, ns = ...
local L = ns.L
local Style = ns.Style
local Travel = ns.Travel

local Transports = ns.Modules:New("Transports", {
    title = L["Boat and zeppelin times"],
    description = L["Near a dock, shows when the next boat, zeppelin or tram leaves, learned from trips "
        .. "and shared with your group and guild."],
    defaults = {
        realms = {},   -- [royaume] = { [liaison] = { last = { dock, t }, ride, dwell, period } }
        trace = {},    -- derniers départs et arrivées détectés (diagnostic)
        share = true,  -- envoyer et recevoir les horaires
    },
})

local SAMPLE = 0.5          -- secondes entre deux relevés de position
local MOVING = 3            -- yards par seconde : au-delà, le transport avance
local STOPPED = 0.5         -- yards par seconde : en deçà, il est à quai
local STOP_SAMPLES = 3      -- relevés immobiles d'affilée pour une arrivée
local DOCK_RADIUS = 350     -- yards : un quai est « ici » à cette distance (le bateau accoste
                            -- souvent au bout d'un long ponton)
local DWELL_RADIUS = 30     -- yards : resté sur place entre l'arrivée et le départ
local DEFAULT_DWELL = 60    -- secondes d'escale présumées
local MAX_AGE = 24 * 3600   -- secondes : au-delà, l'horaire appris est trop vieux
local DISPLAY_RADIUS = 150  -- yards : l'encart s'affiche près d'un quai
local PREFIX = "NextStepTr"

Transports.DEFAULT_DWELL = DEFAULT_DWELL
Transports.MAX_AGE = MAX_AGE
Transports.PREFIX = PREFIX

-- Durée d'un tour complet (secondes), mesurée par NauticusClassic (rtts).
local PERIODS = {
    ["tirisfal-durotar"] = 356.288,
    ["gromgol-durotar"] = 303.467,
    ["tirisfal-gromgol"] = 335.298,
    ["bootyBay-ratchet"] = 350.823,
    ["menethil-auberdine"] = 295.581,
    ["menethil-theramore"] = 329.316,
    ["rutheran-auberdineTeldrassil"] = 316.254,
    ["feathermoon-forgottenCoast"] = 317.045,
    ["tram-north"] = 143.334,
    ["tram-south"] = 143.334,
}
Transports.PERIODS = PERIODS

---------------------------------------------------------------------------
-- Quais et liaisons
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

local function linkById(id)
    for _, link in ipairs(Travel.LINKS) do
        if link.id == id then
            return link
        end
    end
end
Transports.LinkById = linkById

-- Liaison entre deux ensembles de quais (la voie la plus proche quand plusieurs
-- rames partagent les mêmes quais) : la liaison, le quai de départ, d'arrivée.
local function linkBetween(fromDocks, toDocks, laneNorth)
    local best, bestFrom, bestTo, bestGap
    for _, link in ipairs(Travel.LINKS) do
        for side = 1, 2 do
            local a, b = link[side], link[3 - side]
            if fromDocks[a.id] and toDocks[b.id] then
                local gap = (link.lane and laneNorth) and math.abs(link.lane - laneNorth) or 0
                if not bestGap or gap < bestGap then
                    best, bestFrom, bestTo, bestGap = link, a.id, b.id, gap
                end
            end
        end
    end
    return best, bestFrom, bestTo
end

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

-- Un relevé : t (secondes), position (nil hors du monde), vitesse propre du joueur,
-- en trajet de vol. Renvoie un événement ou nil :
--   { link, from, to, departed, arrived, ride, dwell? }
function Tracker:Feed(t, instance, north, west, ownSpeed, onTaxi)
    if not instance or onTaxi then
        if onTaxi then
            self.moving, self.departure, self.docked = false, nil, nil
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
    local rate = distance(north, west, last.north, last.west) / (t - last.t)
    if rate >= MOVING then
        self.still = 0
        if not self.moving then
            self.moving = true
            self:Note(last.t, "start", last.instance, last.north, last.west)
            local docks = Transports.DocksNear(last.instance, last.north, last.west, DOCK_RADIUS)
            if next(docks) then
                local dwell
                local docked = self.docked
                if docked and docked.instance == last.instance
                    and distance(docked.north, docked.west, last.north, last.west) <= DWELL_RADIUS then
                    dwell = last.t - docked.t
                end
                self.departure = { t = last.t, docks = docks, dwell = dwell, dockedLink = docked and docked.link,
                    lane = north }
            else
                self.departure = nil
            end
            self.docked = nil
        end
    elseif rate <= STOPPED then
        if self.moving then
            self.still = self.still + 1
            if self.still >= STOP_SAMPLES then
                self.moving = false
                self.still = 0
                local departure = self.departure
                self.departure = nil
                local docks = Transports.DocksNear(instance, north, west, DOCK_RADIUS)
                local arrived = t - (STOP_SAMPLES * SAMPLE)
                self:Note(arrived, "stop", instance, north, west,
                    not departure and "no dock at start" or not next(docks) and "no dock here" or nil)
                if departure and next(docks) then
                    local link, from, to = linkBetween(departure.docks, docks, departure.lane)
                    if link then
                        self.docked = { t = arrived, instance = instance, north = north, west = west,
                            link = link.id }
                        self.trace[1].detail = link.id
                        return { link = link.id, from = from, to = to, departed = departure.t,
                            arrived = arrived, ride = arrived - departure.t,
                            dwell = departure.dockedLink == link.id and departure.dwell or nil }
                    end
                end
            end
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Apprentissage et prévision (pures)
---------------------------------------------------------------------------

-- Durée d'un tour : secondes, exacte (ou nil).
function Transports.Period(data, link)
    if PERIODS[link.id] then
        return PERIODS[link.id], true
    end
    if data.period then
        return data.period, true
    end
    local a, b = link[1].id, link[2].id
    local rideA, rideB = data.ride and data.ride[a], data.ride and data.ride[b]
    local ride = rideA or rideB
    if not ride then
        return nil
    end
    local dwellA, dwellB = data.dwell and data.dwell[a], data.dwell and data.dwell[b]
    local exact = rideA ~= nil and rideB ~= nil and dwellA ~= nil and dwellB ~= nil
    return (rideA or ride) + (rideB or ride) + (dwellA or dwellB or DEFAULT_DWELL)
        + (dwellB or dwellA or DEFAULT_DWELL), exact
end

local function slot(realm, id)
    local data = realm[id] or {}
    realm[id] = data
    data.ride = data.ride or {}
    data.dwell = data.dwell or {}
    return data
end

-- Mémorise une traversée observée (ou reçue) dans les données d'un royaume.
function Transports.Learn(realm, event)
    local link = linkById(event.link)
    if not link then
        return
    end
    local data = slot(realm, event.link)
    if event.ride then
        data.ride[event.from] = math.floor(event.ride + 0.5)
    end
    if event.dwell then
        data.dwell[event.from] = math.floor(event.dwell + 0.5)
    end
    -- Deux départs du même quai : un nombre entier de tours les sépare.
    local last = data.last
    local estimate = Transports.Period(data, link)
    if last and last.dock == event.from and estimate and not PERIODS[link.id] then
        local elapsed = event.departed - last.t
        local turns = math.floor(elapsed / estimate + 0.5)
        if turns >= 1 and math.abs(elapsed / turns - estimate) <= estimate * 0.15 then
            data.period = math.floor(elapsed / turns + 0.5)
        end
    end
    if not last or event.departed >= last.t then
        data.last = { dock = event.from, t = event.departed }
    end
end

-- Prochain départ du quai dock sur une liaison : secondes d'attente, exact (ou nil).
function Transports.NextDeparture(data, link, dock, now)
    local last = data and data.last
    if not last or now - last.t > MAX_AGE then
        return nil
    end
    local period, exact = Transports.Period(data, link)
    if not period or period <= 0 then
        return nil
    end
    local first = last.t
    if dock ~= last.dock then
        -- Départ du quai d'en face : traversée depuis le dernier départ, puis escale ;
        -- sans mesure, la moitié du tour.
        local ride = data.ride[last.dock] or data.ride[dock]
        local dwell = data.dwell[dock]
        if ride and dwell then
            first = last.t + ride + dwell
            exact = exact and data.ride[last.dock] ~= nil
        elseif ride then
            first = last.t + ride + (PERIODS[link.id] and math.max(0, period / 2 - ride) or DEFAULT_DWELL)
            exact = false
        else
            first = last.t + period / 2
            exact = false
        end
    end
    local wait = (first - now) % period
    return wait, exact
end

---------------------------------------------------------------------------
-- Partage (pur : texte des messages)
---------------------------------------------------------------------------

-- « S|liaison|quai|heure|traversée|escale » (traversée et escale : 0 si inconnues).
function Transports.Encode(id, data)
    local last = data.last
    return ("S|%s|%s|%d|%d|%d"):format(id, last.dock, last.t, data.ride[last.dock] or 0,
        data.dwell[last.dock] or 0)
end

-- Message reçu -> traversée à apprendre, ou nil s'il est invalide ou trop vieux.
function Transports.Decode(text, now)
    local id, dock, t, ride, dwell = tostring(text or ""):match("^S|([%w%-]+)|(%w+)|(%d+)|(%d+)|(%d+)$")
    local link = id and linkById(id)
    if not link or (link[1].id ~= dock and link[2].id ~= dock) then
        return nil
    end
    t, ride, dwell = tonumber(t), tonumber(ride), tonumber(dwell)
    if t > now + 60 or now - t > MAX_AGE then
        return nil
    end
    return { link = id, from = dock, departed = t, ride = ride > 0 and ride or nil,
        dwell = dwell > 0 and dwell or nil }
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
    if data and data.last then
        send(Transports.Encode(id, data))
    end
end

-- Réponse à une demande : nos horaires récents, sauf ceux qu'un autre a déjà donnés.
function Transports:Answer()
    local now = serverNow()
    for id, data in pairs(self:Realm()) do
        local heard = self.heard and self.heard[id]
        if data.last and now - data.last.t <= MAX_AGE and not (heard and heard >= data.last.t) then
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
        self.heard[event.link] = math.max(self.heard[event.link] or 0, event.departed)
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

-- Lignes de l'encart pour une position : { { text, wait, exact } }, vide loin d'un quai.
-- Les rames du tram vers la même destination n'en font qu'une : la prochaine qui part.
function Transports:Lines(instance, north, west, faction, now)
    local lines, byLabel = {}, {}
    if not instance then
        return lines
    end
    local near = Transports.DocksNear(instance, north, west, DISPLAY_RADIUS)
    local realm = self:Realm()
    for _, link in ipairs(Travel.LINKS) do
        if not link.faction or link.faction == faction then
            for side = 1, 2 do
                local dock, other = link[side], link[3 - side]
                if near[dock.id] then
                    local label = L[KINDS[link.kind]]:format(L[other.name])
                    local wait, exact = Transports.NextDeparture(realm[link.id], link, dock.id, now)
                    local line = byLabel[label]
                    if not line then
                        line = { label = label }
                        byLabel[label] = line
                        lines[#lines + 1] = line
                    end
                    if wait and (not line.wait or wait < line.wait) then
                        line.wait, line.exact = wait, exact
                    end
                end
            end
        end
    end
    for _, line in ipairs(lines) do
        if line.wait then
            line.text = (line.exact and L["%s: leaves in %s"] or L["%s: leaves in about %s"])
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
