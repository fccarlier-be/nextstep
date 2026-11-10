-- Flèche (version simple, docs/DESIGN.md, « Flèche ») : en haut au centre, elle
-- tourne vers la cible de l'étape (Guide:FindTarget), passe du rouge-orangé (dos
-- à la cible) au doré puis au vert (en face), et affiche la distance. Une coche
-- remplace la flèche à l'arrivée. Cachée sans cible, sans position (instance) ou
-- quand l'option est désactivée.
--
-- Guide:PointTo(point, label) la tourne vers un autre lieu (donneur d'une quête de
-- donjon, choisi dans le journal) jusqu'à l'arrivée ; la cible du guide reprend ensuite.
-- Pour revenir au guide avant : clic droit sur la flèche, la ligne en tête de la
-- fenêtre du guide, un second clic sur le même lieu dans le journal, ou /ns arrow.

local _, ns = ...
local L = ns.L

local Guide = ns.Modules:Get("Guide")
local Navigation = ns.Navigation

local SIZE = 48
local UPDATE_PERIOD = 0.05   -- secondes
local ARRIVED = 5            -- yards

local ARROW_TEXTURE = "Interface\\AddOns\\NextStep\\Media\\Arrow"   -- Tools/arrow/textures.py
local CHECK_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-Ready"

local GREEN, GOLD, RED = { 0.2, 1, 0.2 }, { 1, 0.82, 0 }, { 1, 0.3, 0.1 }

local function mix(a, b, t)
    return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
end

-- Couleur selon l'angle de la cible (0 : devant, pi : derrière).
function Guide.ArrowColor(angle)
    local deviation = angle % (2 * math.pi)
    if deviation > math.pi then
        deviation = 2 * math.pi - deviation
    end
    local t = deviation / math.pi
    if t < 0.5 then
        return mix(GREEN, GOLD, t * 2)
    end
    return mix(GOLD, RED, (t - 0.5) * 2)
end

function Guide:CreateArrow()
    local frame = CreateFrame("Frame", "NextStepArrowFrame", UIParent)
    frame:SetSize(SIZE, SIZE)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -90)
    frame:SetFrameStrata("MEDIUM")
    -- Cliquable seulement vers un lieu choisi (clic droit : retour au guide).
    frame:EnableMouse(false)
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" and self.pointTarget then
            self:BackToGuide()
        end
    end)
    frame:SetScript("OnEnter", function(owner)
        if self.pointTarget and GameTooltip then
            GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
            GameTooltip:SetText(self.pointTarget.label or "")
            GameTooltip:AddLine(L["Right-click: back to the guide"], 1, 0.82, 0)
            GameTooltip:Show()
        end
    end)
    frame:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    frame:Hide()

    local arrow = frame:CreateTexture(nil, "ARTWORK")
    arrow:SetTexture(ARROW_TEXTURE)
    arrow:SetAllPoints()
    frame.arrow = arrow

    local check = frame:CreateTexture(nil, "ARTWORK")
    check:SetTexture(CHECK_TEXTURE)
    check:SetAllPoints()
    check:Hide()
    frame.check = check

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOM", frame, "TOP", 0, 2)
    frame.label = label

    local distance = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    distance:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    frame.distance = distance

    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + (delta or 0)
        if elapsed >= UPDATE_PERIOD then
            elapsed = 0
            self:UpdateArrowDirection()
        end
    end)
    self.arrowFrame = frame
    return frame
end

-- Nouvelle cible : libellé, puis direction.
function Guide:SetArrowTarget(target)
    self.target = target
    local frame = self.arrowFrame
    if not frame then
        return
    end
    frame:EnableMouse(self.pointTarget ~= nil)
    if self.pointTarget and self.enabled then
        frame.label:SetText(self.pointTarget.label or "")
        frame:Show()
        self:UpdateArrowDirection()
        return
    end
    if not (target and self.enabled and self.db.arrow and self.result) then
        frame:Hide()
        return
    end
    local route = self:Crossing(target)
    frame.label:SetText(route and ns.Travel.Describe(route) or self:GoalLabel(self.result, target.step, target.goal))
    frame:Show()
    self:UpdateArrowDirection()
end

-- Pointe un lieu choisi : { map, x, y } (carte du client, pour cent) ; nil rend la
-- flèche au guide.
function Guide:PointTo(point, label)
    if point then
        self.pointTarget = { map = point.map, x = point.x, y = point.y, label = label }
    else
        self.pointTarget = nil
    end
    if not self.arrowFrame then
        self:CreateArrow()
    end
    self:SetArrowTarget(self.target)
    if self.window and self.result then
        self:UpdateWindow(self.result)
    end
end

-- Rend la flèche à l'étape du guide.
function Guide:BackToGuide()
    if self.pointTarget then
        self:PointTo(nil)
        ns:Print(L["The arrow follows the guide again."])
    end
end

-- Le lieu choisi est-il déjà pointé ?
function Guide:IsPointing(point)
    local target = self.pointTarget
    return target ~= nil and point ~= nil and target.map == point.map and target.x == point.x
        and target.y == point.y
end

function Guide:UpdateArrowDirection()
    local frame, target = self.arrowFrame, self.pointTarget or self.target
    if not (frame and target) then
        return
    end
    -- Cible sur l'autre continent : la flèche mène au quai de départ.
    local route = not self.pointTarget and self:Crossing(target)
    if route then
        target = route.from
    end
    local distance, angle = Navigation.Direction(target.map, target.x, target.y, target.f)
    if not distance then
        -- Autre continent, instance, valeur secrète : pas de direction.
        frame.arrow:Hide()
        frame.check:Hide()
        frame.distance:SetText("")
        return
    end
    if distance <= ARRIVED and self.pointTarget then
        -- Lieu choisi atteint : la flèche revient au guide.
        self:PointTo(nil)
        return
    end
    if distance <= ARRIVED then
        frame.arrow:Hide()
        frame.check:Show()
    else
        frame.check:Hide()
        frame.arrow:Show()
        frame.arrow:SetRotation(angle)
        frame.arrow:SetVertexColor(Guide.ArrowColor(angle))
    end
    frame.distance:SetText(L["%d yd"]:format(math.floor(distance + 0.5)))
end

function Guide:SetArrowShown(shown)
    self.db.arrow = shown
    self:SetArrowTarget(self.result and self.result.target)
end

---------------------------------------------------------------------------
-- Interface du guide : fenêtre et flèche, à l'écoute du module
---------------------------------------------------------------------------

function Guide:CreateInterface()
    if not self.window then
        self:CreateWindow()
    end
    if not self.arrowFrame then
        self:CreateArrow()
    end
    self:CreatePins()
    self.window:SetShown(self.db.window.shown)
    self:RegisterMessage("NEXTSTEP_GUIDE_UPDATED", function(_, _, result)
        self:UpdateWindow(result)
        self:SetArrowTarget(result and result.target)
        self:UpdatePins()
        self:UpdateJournal()
    end)
    self:RegisterMessage("NEXTSTEP_TARGET_UPDATED", function(_, _, target)
        self:SetArrowTarget(target)
        self:UpdatePins()
    end)
end

function Guide:HideInterface()
    if self.window then
        self.window:Hide()
    end
    if self.arrowFrame then
        self.arrowFrame:Hide()
    end
    self:HidePins()
end
