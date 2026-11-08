-- Horloge (docs/DESIGN.md, « Horloge ») : alarmes à heure fixe (locale ou serveur),
-- minuteurs nommés, chronomètre. Une alerte s'affiche au centre de l'écran avec un son,
-- même en combat (en petit). Les minuteurs survivent au /reload et à la déconnexion
-- (heure de fin sauvegardée) ; un minuteur terminé hors ligne est signalé à la connexion.
--
-- Ouverture : clic droit sur l'horloge de la minimap, menu du bouton NextStep, /ns clock.
-- Commandes : /ns timer <minutes> [nom], /ns alarm <hh:mm> [nom].

local _, ns = ...
local L = ns.L

local Clock = ns.Modules:New("Clock", {
    title = L["Clock"],
    description = L["Alarms, timers and a stopwatch, opened by right-clicking the minimap clock."],
    charDefaults = {
        alarms = {},   -- { name, hour, minute, server, last } (last : « AAAA-MM-JJ hh:mm » déjà sonné)
        timers = {},   -- { name, ends } (ends : time() de fin)
    },
})

local Style = ns.Style
local C = Style.COLORS

local PERIOD = 1            -- secondes
local ALERT_DURATION = 15
local ALERT_SOUND = 8959    -- SOUNDKIT.RAID_WARNING
local MAX_ROWS = 5

---------------------------------------------------------------------------
-- Temps
---------------------------------------------------------------------------

-- « 7:30 », « 07h30 », « 19 » -> heure, minute (nil si invalide).
function Clock.ParseTime(text)
    text = tostring(text or "")
    local hour, minute = text:match("^%s*(%d%d?)%s*[:hH]%s*(%d%d)%s*$")
    if not hour then
        hour, minute = text:match("^%s*(%d%d?)%s*[hH]?%s*$"), "0"
    end
    hour, minute = tonumber(hour), tonumber(minute)
    if hour and minute and hour < 24 and minute < 60 then
        return hour, minute
    end
end

-- 3725 -> « 1:02:05 », 65 -> « 1:05 ».
function Clock.FormatDuration(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    local hours, minutes, rest = math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60
    if hours > 0 then
        return ("%d:%02d:%02d"):format(hours, minutes, rest)
    end
    return ("%d:%02d"):format(minutes, rest)
end

-- WoW n'a pas la bibliothèque os : time() et date() sont des globales du jeu.
local function now()
    return (time or os.time)()
end

local function clockDate(format, t)
    return (date or os.date)(format, t)
end

local function serverTime()
    if GetGameTime then
        local hour, minute = GetGameTime()
        if ns.Usable(hour) then
            return hour, minute
        end
    end
end

---------------------------------------------------------------------------
-- Alarmes, minuteurs, chronomètre
---------------------------------------------------------------------------

function Clock:AddTimer(seconds, name)
    seconds = tonumber(seconds)
    if not seconds or seconds <= 0 then
        return nil
    end
    local timer = { name = name and name ~= "" and name or L["Timer"], ends = now() + seconds }
    table.insert(self.char.timers, timer)
    self:UpdatePanel()
    return timer
end

function Clock:AddAlarm(hour, minute, name, server)
    local alarm = { name = name and name ~= "" and name or L["Alarm"], hour = hour, minute = minute,
        server = server and true or false }
    table.insert(self.char.alarms, alarm)
    self:UpdatePanel()
    return alarm
end

function Clock:Remove(list, item)
    for index, other in ipairs(list) do
        if other == item then
            table.remove(list, index)
            break
        end
    end
    self:UpdatePanel()
end

-- Vérifie minuteurs et alarmes à l'instant t (heures locale et serveur données pour les
-- tests) ; renvoie les alertes déclenchées.
function Clock:Check(t, localHour, localMinute, serverHour, serverMinute, today)
    t = t or now()
    if not localHour then
        local parts = clockDate("*t", t)
        localHour, localMinute, today = parts.hour, parts.min, clockDate("%Y-%m-%d", t)
    end
    if not serverHour then
        serverHour, serverMinute = serverTime()
    end
    local fired = {}
    for index = #self.char.timers, 1, -1 do
        local timer = self.char.timers[index]
        if t >= timer.ends then
            table.remove(self.char.timers, index)
            fired[#fired + 1] = L["Timer finished: %s"]:format(timer.name)
        end
    end
    for _, alarm in ipairs(self.char.alarms) do
        local hour, minute = localHour, localMinute
        if alarm.server then
            hour, minute = serverHour, serverMinute
        end
        local key = ("%s %02d:%02d"):format(today or "", alarm.hour, alarm.minute)
        if hour == alarm.hour and minute == alarm.minute and alarm.last ~= key then
            alarm.last = key
            fired[#fired + 1] = L["Alarm: %s"]:format(alarm.name)
        end
    end
    for _, text in ipairs(fired) do
        self:Alert(text)
    end
    if #fired > 0 then
        self:UpdatePanel()
    end
    return fired
end

-- Chronomètre : démarre, arrête (le temps reste), remet à zéro.
function Clock:StopwatchToggle()
    local watch = self.stopwatch
    if watch.started then
        watch.elapsed = watch.elapsed + (now() - watch.started)
        watch.started = nil
    else
        watch.started = now()
    end
    self:UpdatePanel()
end

function Clock:StopwatchReset()
    self.stopwatch = { elapsed = 0 }
    self:UpdatePanel()
end

function Clock:StopwatchTime()
    local watch = self.stopwatch
    return watch.elapsed + (watch.started and (now() - watch.started) or 0)
end

---------------------------------------------------------------------------
-- Alerte
---------------------------------------------------------------------------

function Clock:Alert(text)
    local frame = self.alertFrame
    if not frame then
        frame = CreateFrame("Button", "NextStepClockAlert", UIParent)
        frame:SetSize(360, 50)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        Style.Fill(frame, C.background)
        Style.Border(frame, C.gold)
        frame.text = Style.Text(frame, "GameFontNormalLarge", C.gold, "CENTER")
        frame.text:SetAllPoints()
        frame:SetScript("OnClick", function() frame:Hide() end)
        self.alertFrame = frame
    end
    -- En combat : en petit, pour ne pas gêner.
    local combat = InCombatLockdown and InCombatLockdown()
    frame:SetScale(combat and 0.6 or 1)
    frame.text:SetText(text)
    frame:Show()
    self.lastAlert = text
    if PlaySound then
        PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or ALERT_SOUND)
    end
    ns:Print(text)
    self.alertToken = (self.alertToken or 0) + 1
    local token = self.alertToken
    if C_Timer and C_Timer.After then
        C_Timer.After(ALERT_DURATION, function()
            if self.alertToken == token then
                frame:Hide()
            end
        end)
    end
end

---------------------------------------------------------------------------
-- Panneau
---------------------------------------------------------------------------

local function editBox(parent, width)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(width, 22)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlight")
    box:SetTextInsets(6, 6, 0, 0)
    Style.Fill(box, C.track)
    Style.Border(box, C.goldDim)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return box
end

local function section(parent, text, anchor, y)
    local label = Style.Text(parent, "GameFontNormal", C.gold)
    label:SetPoint("TOPLEFT", anchor, "TOPLEFT", 12, y)
    label:SetText(text)
    return label
end

-- Lignes d'une liste (alarmes ou minuteurs) : texte et bouton de suppression.
local function rows(parent, anchor)
    local list = {}
    for index = 1, MAX_ROWS do
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(300, 18)
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4 - (index - 1) * 20)
        row.text = Style.Text(row, "GameFontHighlight", C.text)
        row.text:SetPoint("LEFT")
        row.remove = Style.Button(row, "×", 18, 18)
        row.remove:SetPoint("RIGHT")
        list[index] = row
    end
    return list
end

function Clock:CreatePanel()
    local frame = Style.Window("NextStepClockFrame", 340, 430, L["Clock"])
    local top = frame.header

    -- Alarmes.
    local alarms = section(frame, L["Alarms"], top, -46)
    frame.alarmRows = rows(frame, alarms)
    local alarmName = editBox(frame, 120)
    alarmName:SetPoint("TOPLEFT", alarms, "BOTTOMLEFT", 0, -4 - MAX_ROWS * 20)
    local alarmTime = editBox(frame, 60)
    alarmTime:SetPoint("LEFT", alarmName, "RIGHT", 6, 0)
    local server = Style.Button(frame, L["Local"], 60, 22)
    server:SetPoint("LEFT", alarmTime, "RIGHT", 6, 0)
    server:SetScript("OnClick", function(button)
        button.server = not button.server
        button:SetLabel(button.server and L["Server"] or L["Local"])
    end)
    local addAlarm = Style.Button(frame, "+", 22, 22, function()
        local hour, minute = Clock.ParseTime(alarmTime:GetText())
        if hour then
            self:AddAlarm(hour, minute, alarmName:GetText(), server.server)
            alarmName:SetText("")
            alarmTime:SetText("")
        else
            ns:Print(L["Time expected: hh:mm"])
        end
    end)
    addAlarm:SetPoint("LEFT", server, "RIGHT", 6, 0)

    -- Minuteurs.
    local timers = section(frame, L["Timers"], top, -210)
    frame.timerRows = rows(frame, timers)
    local timerName = editBox(frame, 160)
    timerName:SetPoint("TOPLEFT", timers, "BOTTOMLEFT", 0, -4 - MAX_ROWS * 20)
    local minutes = editBox(frame, 60)
    minutes:SetPoint("LEFT", timerName, "RIGHT", 6, 0)
    local addTimer = Style.Button(frame, "+", 22, 22, function()
        local value = tonumber(((minutes:GetText() or ""):gsub(",", ".")))
        if value and value > 0 then
            self:AddTimer(value * 60, timerName:GetText())
            timerName:SetText("")
            minutes:SetText("")
        else
            ns:Print(L["Minutes expected"])
        end
    end)
    addTimer:SetPoint("LEFT", minutes, "RIGHT", 6, 0)
    local hint = Style.Text(frame, "GameFontDisableSmall", C.muted)
    hint:SetPoint("TOPLEFT", timerName, "BOTTOMLEFT", 0, -3)
    hint:SetText(L["name, minutes"])

    -- Chronomètre.
    local watch = section(frame, L["Stopwatch"], top, -374)
    frame.watch = Style.Text(frame, "GameFontHighlightLarge", C.text)
    frame.watch:SetPoint("LEFT", watch, "RIGHT", 16, 0)
    frame.watchButton = Style.Button(frame, L["Start"], 70, 22, function() self:StopwatchToggle() end)
    frame.watchButton:SetPoint("TOPLEFT", watch, "BOTTOMLEFT", 0, -6)
    local reset = Style.Button(frame, L["Reset"], 70, 22, function() self:StopwatchReset() end)
    reset:SetPoint("LEFT", frame.watchButton, "RIGHT", 6, 0)

    frame:SetScript("OnShow", function() self:UpdatePanel() end)
    self.panel = frame
    return frame
end

local function fill(rowsList, items, describe, onRemove)
    for index, row in ipairs(rowsList) do
        local item = items[index]
        row.text:SetText(item and describe(item) or "")
        row.remove:SetShown(item ~= nil)
        row.remove:SetScript("OnClick", item and function() onRemove(item) end or nil)
    end
end

function Clock:UpdatePanel()
    local frame = self.panel
    if not (frame and frame:IsShown()) then
        return
    end
    fill(frame.alarmRows, self.char.alarms, function(alarm)
        return ("%02d:%02d  %s%s"):format(alarm.hour, alarm.minute, alarm.name,
            alarm.server and (" (" .. L["server"] .. ")") or "")
    end, function(alarm) self:Remove(self.char.alarms, alarm) end)
    local t = now()
    fill(frame.timerRows, self.char.timers, function(timer)
        return ("%s  %s"):format(Clock.FormatDuration(timer.ends - t), timer.name)
    end, function(timer) self:Remove(self.char.timers, timer) end)
    frame.watch:SetText(Clock.FormatDuration(self:StopwatchTime()))
    frame.watchButton:SetLabel(self.stopwatch.started and L["Pause"] or L["Start"])
end

function Clock:Toggle()
    local frame = self.panel or self:CreatePanel()
    frame:SetShown(not frame:IsShown())
    self:UpdatePanel()
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

-- Clic droit sur l'horloge de la minimap (chargée à la demande) : le panneau.
function Clock:HookMinimapClock()
    local button = TimeManagerClockButton
    if self.clockHooked or not (button and button.HookScript) then
        return
    end
    self.clockHooked = true
    button:HookScript("OnMouseUp", function(_, mouse)
        if self.enabled and mouse == "RightButton" then
            self:Toggle()
        end
    end)
end

function Clock:OnInitialize()
    self.stopwatch = { elapsed = 0 }
    ns.Slash:Add("clock", function()
        self:Toggle()
    end, L["Open the clock: alarms, timers, stopwatch"])
    ns.Slash:Add("timer", function(input)
        local minutes, name = (input or ""):match("^%s*([%d%.,]+)%s*(.-)%s*$")
        minutes = minutes and tonumber((minutes:gsub(",", ".")))
        if minutes and self:AddTimer(minutes * 60, name) then
            ns:Print(L["Timer set: %s in %s."]:format(name ~= "" and name or L["Timer"],
                Clock.FormatDuration(minutes * 60)))
        else
            ns:Print(L["Usage: /ns timer <minutes> [name]"])
        end
    end, L["Start a timer: /ns timer <minutes> [name]"])
    ns.Slash:Add("alarm", function(input)
        local when, name = (input or ""):match("^%s*(%S+)%s*(.-)%s*$")
        local hour, minute = Clock.ParseTime(when)
        if hour then
            self:AddAlarm(hour, minute, name)
            ns:Print(L["Alarm set at %02d:%02d."]:format(hour, minute))
        else
            ns:Print(L["Usage: /ns alarm <hh:mm> [name]"])
        end
    end, L["Set an alarm: /ns alarm <hh:mm> [name]"])
end

function Clock:OnEnable()
    -- Minuteurs terminés pendant l'absence : signalés à la connexion.
    local t = now()
    for index = #self.char.timers, 1, -1 do
        local timer = self.char.timers[index]
        if t >= timer.ends then
            table.remove(self.char.timers, index)
            self:Alert(L["Timer finished while you were away: %s"]:format(timer.name))
        end
    end
    if C_Timer and C_Timer.NewTicker then
        self.ticker = C_Timer.NewTicker(PERIOD, function()
            self:Check()
            self:UpdatePanel()
        end)
    end
    self:HookMinimapClock()
    self:RegisterEvent("ADDON_LOADED", function(_, _, name)
        if name == "Blizzard_TimeManager" then
            self:HookMinimapClock()
        end
    end)
end

function Clock:OnDisable()
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    if self.panel then
        self.panel:Hide()
    end
end

-- Options : ouvrir l'horloge.
function Clock:BuildOptions(panel, anchor)
    local button = ns.Options.AddButton(panel, L["Open the clock"], 200, function()
        self:Toggle()
    end)
    button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
    return button
end
