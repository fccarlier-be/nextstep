-- Chemin à pied jusqu'à la cible de la flèche (docs/DESIGN.md, « Chemins à pied ») :
-- tracé sur la minimap et la carte du monde, et la flèche qui le suit.
--
-- Le chemin vient du calculateur de Polestar (addon NextStep_Nav, chargé à la demande ;
-- ses cartes de marche dans NextStep_Nav_EK et NextStep_Nav_Kalimdor, chargées par lui
-- sur le continent du joueur). Il est parti de Shortest Path Forever de Cillian
-- Berragan (GPL-3.0-or-later) ; voir CREDITS.md. Son entrée : le global
-- NextStep_NavEngine, Find(instance, départ, arrivée, rappel, options), points en
-- coordonnées monde { x = nord, y = ouest } comme UnitPosition.
--
-- Règles :
--   - la destination est celle de la flèche : lieu choisi, cible de l'étape, ou quai
--     de départ quand la cible est sur l'autre continent (Guide:ArrowGoal) ;
--   - un chemin est demandé quand la destination change, puis quand le joueur s'en
--     écarte de plus de STRAY yards (au plus une fois toutes les RETRY secondes) ;
--     après un échec, de nouveau FAIL_RETRY secondes plus tard ;
--   - rien n'est demandé en combat (le chargement des cartes y est interdit) ;
--   - sans chemin (pas de cartes, hors du maillage, en instance), la flèche pointe
--     tout droit comme avant et rien n'est tracé ;
--   - la flèche vise le point du chemin LOOKAHEAD yards devant le joueur, et sa
--     distance est la longueur du chemin restant.
-- Réglage : Guide.db.routeLines (activé par défaut).

local _, ns = ...

local Guide = ns.Modules:Get("Guide")
local Navigation = ns.Navigation

local STRAY = 25           -- yards : écart au chemin qui en fait demander un autre
local RETRY = 3            -- secondes entre deux demandes pour un écart
local FAIL_RETRY = 10      -- secondes avant de redemander après un échec
local LOOKAHEAD = 15       -- yards : point du chemin visé par la flèche
local CHECK_PERIOD = 0.25  -- secondes entre deux vérifications
local MAP_REDRAW = 0.5     -- secondes entre deux tracés de la carte du monde ouverte
local MAP_MIN_STEP = 3     -- pixels : points plus proches fusionnés sur la carte du monde

local WHITE = "Interface\\Buttons\\WHITE8X8"
local COLOR = { 1, 0.82, 0, 0.95 }
local OUTLINE = { 0, 0, 0, 0.55 }
local MINIMAP_WIDTH, MAP_WIDTH = 3, 4   -- pixels (le contour ajoute 2 de chaque côté)

local function now()
    return GetTime and GetTime() or 0
end

---------------------------------------------------------------------------
-- Géométrie (exposée pour les tests)
---------------------------------------------------------------------------

-- Point le plus proche de (px, py) sur le segment a-b : distance, fraction (0 à 1).
local function toSegment(ax, ay, bx, by, px, py)
    local dx, dy = bx - ax, by - ay
    local length2 = dx * dx + dy * dy
    local t = 0
    if length2 > 0 then
        t = math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / length2))
    end
    local cx, cy = ax + t * dx - px, ay + t * dy - py
    return math.sqrt(cx * cx + cy * cy), t
end

-- Position du joueur sur le chemin : distance au chemin, segment le plus proche
-- (points[i] à points[i + 1]) et fraction sur ce segment.
function Guide.RouteProgress(points, north, west)
    local best, index, fraction = math.huge, 1, 0
    for i = 1, #points - 1 do
        local a, b = points[i], points[i + 1]
        local distance, t = toSegment(a.x, a.y, b.x, b.y, north, west)
        if distance < best then
            best, index, fraction = distance, i, t
        end
    end
    return best, index, fraction
end

-- Point du chemin à ahead yards après la position (index, fraction), et longueur
-- du chemin restant depuis cette position.
function Guide.RouteAhead(points, index, fraction, ahead)
    local a, b = points[index], points[index + 1]
    if not b then
        local last = points[#points]
        return last.x, last.y, 0
    end
    local x, y = a.x + (b.x - a.x) * fraction, a.y + (b.y - a.y) * fraction
    local aimX, aimY
    local walked, remaining = 0, 0
    local fromX, fromY = x, y
    for i = index + 1, #points do
        local p = points[i]
        local step = math.sqrt((p.x - fromX) ^ 2 + (p.y - fromY) ^ 2)
        if not aimX and walked + step >= ahead and step > 0 then
            local t = (ahead - walked) / step
            aimX, aimY = fromX + (p.x - fromX) * t, fromY + (p.y - fromY) * t
        end
        walked = walked + step
        remaining = remaining + step
        fromX, fromY = p.x, p.y
    end
    if not aimX then
        local last = points[#points]
        aimX, aimY = last.x, last.y
    end
    return aimX, aimY, remaining
end

-- Segment (x1, y1)-(x2, y2) ramené dans le disque de rayon r centré sur l'origine
-- (dans le carré de demi-côté r si square) : extrémités coupées, ou nil s'il est dehors.
function Guide.ClipSegment(x1, y1, x2, y2, r, square)
    local dx, dy = x2 - x1, y2 - y1
    local t0, t1 = 0, 1
    if square then
        -- Liang-Barsky sur [-r, r] x [-r, r].
        local p = { -dx, dx, -dy, dy }
        local q = { x1 + r, r - x1, y1 + r, r - y1 }
        for i = 1, 4 do
            if p[i] == 0 then
                if q[i] < 0 then
                    return nil
                end
            else
                local t = q[i] / p[i]
                if p[i] < 0 then
                    if t > t1 then return nil end
                    if t > t0 then t0 = t end
                else
                    if t < t0 then return nil end
                    if t < t1 then t1 = t end
                end
            end
        end
    else
        local a = dx * dx + dy * dy
        local b = 2 * (x1 * dx + y1 * dy)
        local c = x1 * x1 + y1 * y1 - r * r
        if a == 0 then
            if c > 0 then return nil end
        else
            local disc = b * b - 4 * a * c
            if disc < 0 then
                return nil
            end
            local root = math.sqrt(disc)
            local enter, leave = (-b - root) / (2 * a), (-b + root) / (2 * a)
            t0, t1 = math.max(0, enter), math.min(1, leave)
            if t0 >= t1 then
                return nil
            end
        end
    end
    return x1 + dx * t0, y1 + dy * t0, x1 + dx * t1, y1 + dy * t1
end

-- Segment ramené dans le rectangle [0, w] x [0, h] (carte du monde), ou nil.
function Guide.ClipBox(x1, y1, x2, y2, w, h)
    local hw, hh = w / 2, h / 2
    -- Même découpe que le carré, après mise à l'échelle d'un axe.
    local k = hw / hh
    local ax, ay, bx, by = Guide.ClipSegment(x1 - hw, (y1 - hh) * k, x2 - hw, (y2 - hh) * k, hw, true)
    if not ax then
        return nil
    end
    return ax + hw, ay / k + hh, bx + hw, by / k + hh
end

---------------------------------------------------------------------------
-- Calculateur
---------------------------------------------------------------------------

-- Le calculateur, chargé une fois (hors combat). nil s'il manque.
function Guide:RouteEngine()
    if self.navEngine ~= nil then
        return self.navEngine or nil
    end
    local engine = _G.NextStep_NavEngine
    if not engine then
        if InCombatLockdown and InCombatLockdown() then
            return nil
        end
        local load = C_AddOns and C_AddOns.LoadAddOn or _G.LoadAddOn
        if load then
            pcall(load, "NextStep_Nav")
        end
        engine = _G.NextStep_NavEngine
    end
    if type(engine) == "table" and type(engine.Find) == "function" then
        self.navEngine = engine
    else
        self.navEngine = false
    end
    return self.navEngine or nil
end

-- Destination de la flèche, en coordonnées monde : instance, nord, ouest.
function Guide:RouteGoal()
    local goal = self:ArrowGoal()
    if not goal then
        return nil
    end
    return Navigation.WorldPosition(goal.map, goal.x, goal.y, goal.f)
end

local function sameGoal(route, instance, north, west)
    return route and route.instance == instance and math.abs(route.north - north) < 1
        and math.abs(route.west - west) < 1
end

function Guide:ClearRoute()
    local route = self.route
    if route and route.job and self.navEngine and self.navEngine.Cancel then
        pcall(self.navEngine.Cancel, route.job)
    end
    self.route = nil
    if route and route.points then
        self:RouteChanged()
    end
end

-- Chemin utilisable pour la destination actuelle (ou nil).
function Guide:CurrentRoute()
    local route = self.route
    if route and route.points and route.current then
        return route
    end
end

function Guide:RouteChanged()
    if self.minimapPins then
        self:UpdateMinimapPins()
    end
    self:DrawMapRoute()
end

local function playerProfile()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    if faction == "Alliance" or faction == "Horde" then
        return faction
    end
end

-- Vérification périodique : destination, écart au chemin, nouvelle demande.
function Guide:UpdateRoute()
    if not (self.enabled and self.db.routeLines ~= false) then
        if self.route then
            self:ClearRoute()
        end
        return
    end
    local instance, north, west = self:RouteGoal()
    local here, myNorth, myWest = Navigation.PlayerPosition()
    if not (instance and here and instance == here) then
        if self.route then
            self:ClearRoute()
        end
        return
    end
    local engine = self:RouteEngine()
    if not engine or (engine.Available and not engine.Available(instance)) then
        if self.route then
            self:ClearRoute()
        end
        return
    end
    local route = self.route
    local time = now()
    if sameGoal(route, instance, north, west) then
        if route.job then
            return
        end
        if route.points then
            local distance, index, fraction = Guide.RouteProgress(route.points, myNorth, myWest)
            route.index, route.fraction = index, fraction
            route.current = distance <= STRAY
            if route.current or time - route.asked < RETRY then
                return
            end
        elseif time - route.asked < FAIL_RETRY then
            return
        end
    else
        self:ClearRoute()
        route = { instance = instance, north = north, west = west, asked = -math.huge }
        self.route = route
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    route.asked = time
    local answered = false
    local ok, job = pcall(engine.Find, instance, { x = myNorth, y = myWest }, { x = north, y = west },
        function(points, reason)
            answered = true
            ns.SafeCall(function()
                if self.route ~= route then
                    return   -- réponse pour une destination abandonnée
                end
                route.job = nil
                if type(points) == "table" and #points >= 2 then
                    route.points, route.reason = points, nil
                    local _, n, w = Navigation.PlayerPosition()
                    if n then
                        local distance, index, fraction = Guide.RouteProgress(points, n, w)
                        route.index, route.fraction, route.current = index, fraction, distance <= STRAY
                    else
                        route.index, route.fraction, route.current = 1, 0, true
                    end
                else
                    route.points, route.current, route.reason = nil, nil, reason
                end
                self:RouteChanged()
            end)
        end, { waterWalking = false, profile = playerProfile() })
    if not ok then
        route.reason = "error"
    elseif not answered then
        route.job = job
    end
end

-- Pour la flèche : point visé (nord, ouest) et longueur restante, si un chemin vaut.
function Guide:RouteAim()
    local route = self:CurrentRoute()
    if not route then
        return nil
    end
    local _, myNorth, myWest = Navigation.PlayerPosition()
    if not myNorth then
        return nil
    end
    local distance, index, fraction = Guide.RouteProgress(route.points, myNorth, myWest)
    if distance > STRAY then
        return nil
    end
    route.index, route.fraction = index, fraction
    return Guide.RouteAhead(route.points, index, fraction, LOOKAHEAD)
end

-- Points restants du chemin, joueur compris : { { nord, ouest }, ... } dans l'ordre.
function Guide:RouteRemaining(myNorth, myWest)
    local route = self:CurrentRoute()
    if not route then
        return nil
    end
    local list = { { myNorth, myWest } }
    for i = (route.index or 1) + 1, #route.points do
        local p = route.points[i]
        list[#list + 1] = { p.x, p.y }
    end
    return list
end

---------------------------------------------------------------------------
-- Tracé
---------------------------------------------------------------------------

-- Lignes de chaque cadre (tracé de la minimap) : table à part, pas un champ du cadre.
local linePools = setmetatable({}, { __mode = "k" })

local function linePair(owner, pool, index)
    local pair = pool[index]
    if not pair then
        local outline = owner:CreateLine(nil, "ARTWORK", nil, 1)
        outline:SetTexture(WHITE)
        outline:SetVertexColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], OUTLINE[4])
        local core = owner:CreateLine(nil, "ARTWORK", nil, 2)
        core:SetTexture(WHITE)
        core:SetVertexColor(COLOR[1], COLOR[2], COLOR[3], COLOR[4])
        pair = { outline = outline, core = core }
        pool[index] = pair
    end
    return pair
end

-- Un segment du tracé, en pixels depuis le point d'ancrage relativePoint d'owner.
local function drawSegment(owner, pool, index, relativePoint, x1, y1, x2, y2, width)
    local pair = linePair(owner, pool, index)
    for _, line in ipairs({ pair.outline, pair.core }) do
        line:SetStartPoint(relativePoint, owner, x1, y1)
        line:SetEndPoint(relativePoint, owner, x2, y2)
        line:Show()
    end
    pair.outline:SetThickness(width + 2)
    pair.core:SetThickness(width)
end

local function hideFrom(pool, first)
    for index = first, #pool do
        pool[index].outline:Hide()
        pool[index].core:Hide()
    end
end

-- Minimap : appelé par Guide:UpdateMinimapPins (à chaque rafraîchissement des repères).
function Guide:DrawMinimapRoute(frame, half, scale, square, facing, myNorth, myWest)
    local pool, used = linePools[frame], 0
    if not pool then
        pool = {}
        linePools[frame] = pool
    end
    local list = half > 2 and self.db.minimapPins and self:RouteRemaining(myNorth, myWest)
    if list then
        local limit = half - 2
        local px, py = 0, 0
        for i = 2, #list do
            local x, y = Guide.MinimapOffset(list[i][1] - myNorth, list[i][2] - myWest, facing, scale)
            local ax, ay, bx, by = Guide.ClipSegment(px, py, x, y, limit, square)
            if ax then
                used = used + 1
                drawSegment(frame, pool, used, "CENTER", ax, ay, bx, by, MINIMAP_WIDTH)
            elseif (px * px + py * py) > 9 * limit * limit then
                break   -- le chemin s'éloigne loin de la minimap : la suite n'y revient pas ici
            end
            px, py = x, y
        end
    end
    hideFrom(pool, used + 1)
end

-- Carte du monde : sur le canevas, sous les repères.
function Guide:DrawMapRoute()
    local map = WorldMapFrame
    local frame = self.mapRouteFrame
    if not (self.mapProvider and map and map:IsShown()) then
        if frame then
            hideFrom(frame.lines, 1)
        end
        return
    end
    local canvas = map:GetCanvas()
    if not frame then
        frame = CreateFrame("Frame", nil, canvas)
        frame:SetAllPoints(canvas)
        frame.lines = {}
        local elapsed = 0
        frame:SetScript("OnUpdate", function(_, delta)
            elapsed = elapsed + (delta or 0)
            if elapsed >= MAP_REDRAW then
                elapsed = 0
                self:DrawMapRoute()
            end
        end)
        self.mapRouteFrame = frame
    end
    frame:SetFrameLevel(canvas:GetFrameLevel() + 1999)
    local used = 0
    local mapID = map:GetMapID()
    local _, myNorth, myWest = Navigation.PlayerPosition()
    local list = self.enabled and self.db.mapPins and mapID and myNorth and self:RouteRemaining(myNorth, myWest)
    if list then
        local width, height = canvas:GetWidth(), canvas:GetHeight()
        local canvasScale = map.GetCanvasScale and map:GetCanvasScale() or 1
        if not (canvasScale and canvasScale > 0) then
            canvasScale = 1
        end
        local route = self.route
        local px, py
        for i = 1, #list do
            local x, y = Guide.MapPositionUnclamped(mapID, route.instance, list[i][1], list[i][2])
            if not x then
                break
            end
            x, y = x * width, y * height
            if not px then
                px, py = x, y
            elseif i == #list or (x - px) ^ 2 + (y - py) ^ 2 >= (MAP_MIN_STEP / canvasScale) ^ 2 then
                local ax, ay, bx, by = Guide.ClipBox(px, py, x, y, width, height)
                if ax then
                    used = used + 1
                    drawSegment(frame, frame.lines, used, "TOPLEFT", ax, -ay, bx, -by, MAP_WIDTH / canvasScale)
                end
                px, py = x, y
            end
        end
    end
    hideFrom(frame.lines, used + 1)
end

---------------------------------------------------------------------------
-- Mise en route
---------------------------------------------------------------------------

function Guide:CreateRoute()
    if self.routeDriver then
        return
    end
    local driver = CreateFrame("Frame")
    local elapsed = 0
    driver:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + (delta or 0)
        if elapsed >= CHECK_PERIOD then
            elapsed = 0
            ns.SafeCall(self.UpdateRoute, self)
        end
    end)
    self.routeDriver = driver
end

function Guide:SetRouteLinesShown(shown)
    self.db.routeLines = shown
    self:UpdateRoute()
    self:RouteChanged()
end
