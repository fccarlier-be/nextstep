-- Horaires des bateaux et des zeppelins (docs/DESIGN.md, « Transports ») : près d'un
-- quai, un encart dit dans combien de temps part le prochain bateau ou zeppelin.
--
-- Le jeu ne donne ni la position des transports ni leur horaire. Ils tournent pourtant
-- en boucle, à durée fixe : l'addon l'apprend en vous voyant à bord. À bord, la position
-- du joueur avance alors qu'il ne marche pas (GetUnitSpeed nul, hors trajet de vol).
--   départ  : le mouvement commence près d'un quai connu (Travel.DOCKS) ;
--   arrivée : il s'arrête près d'un autre quai : durée de la traversée ;
--   escale  : resté à bord, le départ suivant donne la durée de l'escale.
-- Le tour complet d'une liaison vaut traversée + escale à chaque bout (aller et retour
-- présumés de même durée tant qu'un seul est mesuré, escale de 60 s tant qu'aucune
-- n'est mesurée : l'heure est alors donnée « environ »). Deux départs du même quai
-- l'affinent.
--
-- Observations communes aux personnages, par royaume (db.realms). Un redémarrage du
-- serveur décale les horaires : une observation de plus de 24 h n'est plus utilisée.
-- Le tram de Forgefer se trouve dans une instance (pas de position) : non couvert.

local _, ns = ...
local L = ns.L
local Style = ns.Style
local Travel = ns.Travel
local Navigation = ns.Navigation

local Transports = ns.Modules:New("Transports", {
    title = L["Boat and zeppelin times"],
    description = L["Near a dock, shows when the next boat or zeppelin leaves, learned from your own trips."],
    defaults = {
        realms = {},   -- [royaume] = { [liaison] = { last, ride, dwell, period } }
    },
})

local SAMPLE = 0.5          -- secondes entre deux relevés de position
local MOVING = 3            -- yards par seconde : au-delà, le transport avance
local STOPPED = 0.5         -- yards par seconde : en deçà, il est à quai
local STOP_SAMPLES = 3      -- relevés immobiles d'affilée pour une arrivée
local DOCK_RADIUS = 200     -- yards : un quai est « ici » à cette distance
local DWELL_RADIUS = 30     -- yards : resté sur place entre l'arrivée et le départ
local DEFAULT_DWELL = 60    -- secondes d'escale présumées
local MAX_AGE = 24 * 3600   -- secondes : au-delà, l'horaire appris est trop vieux
local DISPLAY_RADIUS = 150  -- yards : l'encart s'affiche près d'un quai

Transports.DEFAULT_DWELL = DEFAULT_DWELL

---------------------------------------------------------------------------
-- Quais et liaisons
---------------------------------------------------------------------------

local function where(dock)
    return Navigation.WorldPosition(dock.map, dock.x, dock.y, dock.f)
end

local function distance(n1, w1, n2, w2)
    local dn, dw = n1 - n2, w1 - w2
    return math.sqrt(dn * dn + dw * dw)
end

-- Quais à moins de radius yards d'une position : { [id] = distance }.
function Transports.DocksNear(instance, north, west, radius)
    local found = {}
    for id, dock in pairs(Travel.DOCKS) do
        local i, n, w = where(dock)
        if i and i == instance then
            local d = distance(north, west, n, w)
            if d <= radius then
                found[id] = d
            end
        end
    end
    return found
end

-- Liaison entre deux ensembles de quais : la liaison, le quai de départ, d'arrivée.
local function linkBetween(fromDocks, toDocks)
    for _, link in ipairs(Travel.LINKS) do
        for side = 1, 2 do
            local a, b = link[side], link[3 - side]
            if fromDocks[a.id] and toDocks[b.id] then
                return link, a.id, b.id
            end
        end
    end
end

local function linkById(id)
    for _, link in ipairs(Travel.LINKS) do
        if link.id == id then
            return link
        end
    end
end

---------------------------------------------------------------------------
-- Détection à bord (pure : relevés en entrée, événements en sortie)
---------------------------------------------------------------------------

local Tracker = {}
Tracker.__index = Tracker
Transports.Tracker = Tracker

function Tracker.New()
    return setmetatable({ moving = false, still = 0 }, Tracker)
end

-- Un relevé : t (secondes), position (nil hors du monde), vitesse propre du joueur,
-- en trajet de vol. Renvoie un événement ou nil :
--   { kind = "ride", link, from, to, departed, arrived, ride, dwell? }
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
            local docks = Transports.DocksNear(last.instance, last.north, last.west, DOCK_RADIUS)
            if next(docks) then
                local dwell
                local docked = self.docked
                if docked and docked.instance == last.instance
                    and distance(docked.north, docked.west, last.north, last.west) <= DWELL_RADIUS then
                    dwell = last.t - docked.t
                end
                self.departure = { t = last.t, docks = docks, dwell = dwell, dockedLink = docked and docked.link }
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
                if departure and next(docks) then
                    local link, from, to = linkBetween(departure.docks, docks)
                    if link then
                        self.docked = { t = arrived, instance = instance, north = north, west = west,
                            link = link.id }
                        return { kind = "ride", link = link.id, from = from, to = to, departed = departure.t,
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

local function both(link)
    return link[1].id, link[2].id
end

-- Durée estimée d'un tour : { seconds, exact }.
function Transports.Period(data, link)
    if data.period then
        return data.period, true
    end
    local a, b = both(link)
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

-- Mémorise une traversée observée dans les données d'un royaume.
function Transports.Learn(realm, event)
    local link = linkById(event.link)
    if not link then
        return
    end
    local data = realm[event.link] or { ride = {}, dwell = {} }
    realm[event.link] = data
    data.ride = data.ride or {}
    data.dwell = data.dwell or {}
    data.ride[event.from] = math.floor(event.ride + 0.5)
    if event.dwell then
        data.dwell[event.from] = math.floor(event.dwell + 0.5)
    end
    -- Deux départs du même quai : un nombre entier de tours les sépare.
    local last = data.last
    local estimate = Transports.Period(data, link)
    if last and last.dock == event.from and estimate then
        local elapsed = event.departed - last.t
        local turns = math.floor(elapsed / estimate + 0.5)
        if turns >= 1 and math.abs(elapsed / turns - estimate) <= estimate * 0.15 then
            data.period = math.floor(elapsed / turns + 0.5)
        end
    end
    data.last = { dock = event.from, t = event.departed }
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
        local other = dock
        -- Départ du quai d'en face : traversée depuis le dernier départ, puis escale.
        local ride = data.ride[last.dock] or data.ride[other]
        local dwell = data.dwell[other] or data.dwell[last.dock] or DEFAULT_DWELL
        exact = exact and data.ride[last.dock] ~= nil and data.dwell[other] ~= nil
        first = last.t + ride + dwell
    end
    local wait = (first - now) % period
    return wait, exact
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

function Transports:Sample()
    local instance, north, west = Navigation.PlayerPosition()
    local speed = GetUnitSpeed and GetUnitSpeed("player") or 0
    if not ns.Usable(speed) then
        speed = 0
    end
    local onTaxi = UnitOnTaxi and UnitOnTaxi("player") or false
    local event = self.tracker:Feed(serverNow(), instance, north, west, speed, onTaxi)
    if event then
        Transports.Learn(self:Realm(), event)
    end
    self.aboard = self.tracker.moving
end

-- Lignes de l'encart pour une position : { { text, wait, exact } }, vide loin d'un quai.
function Transports:Lines(instance, north, west, faction, now)
    local lines = {}
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
                    local destination = L[other.name]
                    local kind = link.kind == "zeppelin" and L["Zeppelin to %s"] or L["Boat to %s"]
                    local wait, exact = Transports.NextDeparture(realm[link.id], link, dock.id, now)
                    local label = kind:format(destination)
                    local text
                    if wait then
                        local seconds = math.floor(wait + 0.5)
                        local duration = ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
                        text = (exact and L["%s: leaves in %s"] or L["%s: leaves in about %s"])
                            :format(label, duration)
                    else
                        text = L["%s: time unknown, ride it once to learn it"]:format(label)
                    end
                    lines[#lines + 1] = { text = text, wait = wait, exact = exact }
                end
            end
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
    local instance, north, west = Navigation.PlayerPosition()
    local lines = {}
    if not self.aboard then
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

function Transports:OnEnable()
    self.tracker = self.tracker or Tracker.New()
    if C_Timer and C_Timer.NewTicker then
        self.ticker = C_Timer.NewTicker(SAMPLE, function()
            self:Sample()
            self.tick = (self.tick or 0) + 1
            if self.tick % 2 == 0 then
                self:UpdateFrame()
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
