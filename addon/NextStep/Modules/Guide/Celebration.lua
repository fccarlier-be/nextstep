-- Célébration de niveau (docs/DESIGN.md, « Célébration de niveau ») : à chaque niveau
-- gagné, un bandeau doré en haut de l'écran, un son du jeu, les sorts que le maître
-- a maintenant (nombre et coût), une quête de classe devenue disponible, et la zone
-- conseillée quand le guide suivi est dépassé.
--
-- Le bandeau se ferme seul après DURATION secondes, ou d'un clic (clic sur la ligne des
-- sorts : onglet Sorts de classe du journal). Jamais en combat : il attend la fin du
-- combat. Options « Célébrer chaque niveau » et « Son de la célébration ».

local _, ns = ...
local L = ns.L

local Guide = ns.Modules:Get("Guide")
local Style = ns.Style
local C = Style.COLORS

local DURATION = 10        -- secondes
local DELAY = 0.5          -- le niveau du client change juste après l'événement
local QUEST_SOUND = 619    -- SOUNDKIT.IG_QUEST_LIST_COMPLETE

-- Lignes de la célébration du niveau level : { text, color, action }.
function Guide:CelebrationLines(level, state)
    state = state or self.state
    local lines = {}
    local plan = state and self:SpellPlan(state)
    local now = plan and plan[1]
    if now and #now.spells > 0 then
        lines[#lines + 1] = {
            text = L["New spells at your trainer: %d (%s)"]:format(#now.spells, Guide.FormatMoney(now.total)),
            color = C.green, action = "spells",
        }
    end
    if state then
        for _, guide in ipairs(self:ClassGuides(state)) do
            if (guide.minLevel or 1) == level then
                lines[#lines + 1] = { text = L["Class quest available: %s"]:format(ns.GuideLabels.Guide(guide)),
                    color = C.blue, action = "journal" }
            end
        end
    end
    -- Guide de leveling dépassé : la suite conseillée.
    local active = self:ActiveGuide()
    if state and (not active or (active.category == "Leveling" and level > (active.maxLevel or 60))) then
        local next
        for _, id in ipairs(self.result and self.result.next or {}) do
            next = next or ns.DB:GetGuide(id)
        end
        for _, guide in ipairs(self:Suggest(state)) do
            if not next and guide ~= active then
                next = guide
            end
        end
        if next then
            lines[#lines + 1] = { text = L["Suggested next: %s"]:format(ns.GuideLabels.Guide(next)), color = C.gold,
                action = "journal" }
        end
    end
    return lines
end

function Guide:CreateCelebration()
    local frame = CreateFrame("Button", "NextStepLevelBanner", UIParent)
    frame:SetSize(420, 60)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -150)
    frame:SetFrameStrata("HIGH")
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame:Hide()
    Style.Frame(frame, C.gold)
    frame.title = Style.Text(frame, "GameFontNormalHuge", C.gold, "CENTER")
    frame.title:SetPoint("TOP", 0, -10)
    frame.lines = {}
    frame:SetScript("OnClick", function()
        frame:Hide()
    end)
    self.celebration = frame
    return frame
end

function Guide:Celebrate(level)
    if not (self.enabled and self.db.celebration) then
        return
    end
    -- En combat : le bandeau attend la fin du combat.
    if InCombatLockdown and InCombatLockdown() then
        self.pendingLevel = level
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            local pending = self.pendingLevel
            self.pendingLevel = nil
            if pending then
                self:Celebrate(pending)
            end
        end)
        return
    end
    local frame = self.celebration or self:CreateCelebration()
    frame.title:SetText(L["Level %d!"]:format(level))
    local lines = self:CelebrationLines(level)
    for index, line in ipairs(lines) do
        local button = frame.lines[index]
        if not button then
            button = CreateFrame("Button", nil, frame)
            button:SetHeight(18)
            button.text = Style.Text(button, "GameFontHighlight", C.text, "CENTER")
            button.text:SetAllPoints()
            frame.lines[index] = button
        end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 10, -36 - (index - 1) * 20)
        button:SetPoint("TOPRIGHT", -10, -36 - (index - 1) * 20)
        button.text:SetText(line.text)
        button.text:SetTextColor(line.color[1], line.color[2], line.color[3])
        button:SetScript("OnClick", function()
            frame:Hide()
            self:ToggleJournal(line.action == "spells" and "spells" or "routes")
        end)
        button:Show()
    end
    for index = #lines + 1, #frame.lines do
        frame.lines[index]:Hide()
    end
    frame:SetHeight(44 + #lines * 20)
    frame:Show()
    self.celebrationLines = lines   -- pour les tests
    if PlaySound and self.db.celebrationSound then
        PlaySound(SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_COMPLETE or QUEST_SOUND)
    end
    self.celebrationToken = (self.celebrationToken or 0) + 1
    local token = self.celebrationToken
    if C_Timer and C_Timer.After then
        C_Timer.After(DURATION, function()
            if self.celebrationToken == token then
                frame:Hide()
            end
        end)
    end
end

function Guide:OnLevelUp(level)
    level = tonumber(ns.Usable(level) and level)
    if not level then
        return
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(DELAY, function()
            ns.SafeCall(self.Celebrate, self, level)
        end)
    else
        self:Celebrate(level)
    end
end
