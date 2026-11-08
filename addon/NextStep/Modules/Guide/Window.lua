-- Fenêtre du guide (docs/DESIGN.md, « Fenêtre du guide ») : l'étape courante et
-- ses objectifs, le conseil, les objectifs en chemin, les quêtes abandonnées,
-- l'étape suivante et les détours ; boutons Ignorer, Valider et Strict / Libre.
-- Sans guide suivi, elle propose les guides adaptés au personnage ; à la fin d'un
-- guide, les guides suivants.
--
-- Déplaçable par la barre de titre (sauf verrouillée), réductible à cette barre,
-- position et échelle mémorisées. Reconstruite à chaque NEXTSTEP_GUIDE_UPDATED.

local _, ns = ...
local L = ns.L

local Guide = ns.Modules:Get("Guide")
local Labels = ns.GuideLabels

local WIDTH = 330
local PADDING = 10
local HEADER_HEIGHT = 30
local FOOTER_HEIGHT = 36
local LINE_GAP = 3
local INDENT = 14

local ICONS = {
    done = "|TInterface\\Buttons\\UI-CheckBox-Check:16:16|t",
    todo = "|TInterface\\Buttons\\UI-CheckBox-Up:16:16|t",
    manual = "|TInterface\\Buttons\\UI-CheckBox-Up:16:16|t",
    blocked = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14:14|t",
    note = "|TInterface\\FriendsFrame\\InformationIcon:14:14|t",
}

local Style = ns.Style
local COLORS = {
    title = Style.COLORS.gold,
    text = Style.COLORS.text,
    done = { 0.5, 0.5, 0.5 },
    muted = Style.COLORS.muted,
    action = Style.COLORS.blue,
    warning = Style.COLORS.orange,
}

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

local function savePosition(self)
    local point, _, relativePoint, x, y = self.window:GetPoint(1)
    if point then
        self.db.window.point = { point, relativePoint, x, y }
    end
end

local function restorePosition(self)
    local frame = self.window
    frame:ClearAllPoints()
    local saved = self.db.window.point
    if saved then
        frame:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
    else
        frame:SetPoint("RIGHT", UIParent, "RIGHT", -60, 80)
    end
end

-- Bouton plat du style commun (Core/Style.lua), avec SetText comme un bouton du jeu.
local function smallButton(parent, text, width, onClick)
    local button = Style.Button(parent, text, width, 24, onClick)
    button.text:SetFontObject("GameFontNormalSmall")
    button.SetText = button.SetLabel
    return button
end

-- Petit bouton d'icône de la barre de titre (texte doré, éclairé au survol).
local function headerButton(parent, label, onClick)
    local button = Style.Button(parent, label, 22, 22, onClick)
    button.text:SetFontObject("GameFontNormal")
    return button
end

function Guide:CreateWindow()
    local frame = CreateFrame("Frame", "NextStepGuideFrame", UIParent)
    frame:SetSize(WIDTH, HEADER_HEIGHT + FOOTER_HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    -- Style sombre et doré, comme le journal.
    frame.bg = Style.Fill(frame, Style.COLORS.background)
    Style.Border(frame, Style.COLORS.goldDim)

    -- Barre de titre : déplacement, guide suivi, journal, options, réduction.
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(HEADER_HEIGHT)
    Style.Fill(header, Style.COLORS.header)
    local underline = Style.Line(header, Style.COLORS.gold)
    underline:SetPoint("BOTTOMLEFT")
    underline:SetPoint("BOTTOMRIGHT")
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if not self.db.window.locked then
            frame:StartMoving()
        end
    end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        savePosition(self)
    end)

    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\NextStep\\Media\\IconSmall")
    logo:SetSize(20, 20)
    logo:SetPoint("LEFT", 6, 0)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
    title:SetPoint("RIGHT", -80, 0)
    title:SetJustifyH("LEFT")
    if title.SetWordWrap then
        title:SetWordWrap(false)
    end
    frame.title = title

    local collapse = headerButton(header, "-", function()
        self:SetWindowCollapsed(not self.db.window.collapsed)
    end)
    collapse:SetPoint("RIGHT", -4, 0)
    frame.collapse = collapse

    local options = Style.IconButton(header, "Interface\\Buttons\\UI-OptionsButton", 22, function()
        ns.Options:Open()
    end)
    options:SetPoint("RIGHT", collapse, "LEFT", -3, 0)

    local journal = Style.IconButton(header, "Interface\\Icons\\INV_Misc_Book_09", 22, function()
        self:ToggleJournal("routes")
    end)
    journal.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    journal:SetPoint("RIGHT", options, "LEFT", -3, 0)
    frame.journalButton = journal

    -- Corps : lignes réutilisées d'une mise à jour à l'autre.
    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", PADDING, -HEADER_HEIGHT)
    -- Ancré aussi en bas : sans hauteur, le corps mesure 0 × 0 et Forever n'affiche
    -- pas les lignes qu'il contient.
    body:SetPoint("BOTTOMRIGHT", -PADDING, FOOTER_HEIGHT)
    frame.body = body
    frame.lines = {}

    -- Pied : Ignorer, Valider, mode.
    local footer = CreateFrame("Frame", nil, frame)
    footer:SetPoint("BOTTOMLEFT", PADDING, 7)
    footer:SetPoint("BOTTOMRIGHT", -PADDING, 7)
    footer:SetHeight(FOOTER_HEIGHT - 10)
    local separator = Style.Line(frame, Style.COLORS.goldDim)
    separator:SetPoint("BOTTOMLEFT", 1, FOOTER_HEIGHT - 2)
    separator:SetPoint("BOTTOMRIGHT", -1, FOOTER_HEIGHT - 2)
    frame.separator = separator
    frame.skip = smallButton(footer, L["Skip"], 70, function()
        local result = self.result
        if result and result.current then
            self:Skip(result.current)
        end
    end)
    frame.skip:SetPoint("LEFT", 0, 0)
    frame.done = smallButton(footer, L["Done"], 70, function()
        self:ValidateCurrent()
    end)
    frame.done:SetPoint("LEFT", frame.skip, "RIGHT", 4, 0)
    frame.mode = smallButton(footer, L["Strict"], 80, function()
        self:SetMode(self.char.mode == "free" and "strict" or "free")
    end)
    frame.mode:SetPoint("RIGHT", 0, 0)
    frame.footer = footer

    self.window = frame
    frame:SetScale(self.db.window.scale or 1)
    restorePosition(self)
    frame:SetShown(self.db.window.shown)
    return frame
end

---------------------------------------------------------------------------
-- Lignes
---------------------------------------------------------------------------

local function acquireLine(frame, index)
    local line = frame.lines[index]
    if not line then
        line = CreateFrame("Button", nil, frame.body)
        local text = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("TOPLEFT", 0, 0)
        text:SetJustifyH("LEFT")
        text:SetJustifyV("TOP")
        if text.SetWordWrap then
            text:SetWordWrap(true)
        end
        line.text = text
        line:SetScript("OnClick", function(button)
            if button.onClick then
                button.onClick()
            end
        end)
        line:SetScript("OnEnter", function(button)
            if not (button.tooltip and GameTooltip) then
                return
            end
            GameTooltip:SetOwner(button, "ANCHOR_LEFT")
            if type(button.tooltip) == "function" then
                button.tooltip(GameTooltip)
            else
                GameTooltip:SetText(button.tooltip, 1, 1, 1, 1, true)
            end
            GameTooltip:Show()
        end)
        line:SetScript("OnLeave", function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)
        frame.lines[index] = line
    end
    return line
end

-- Ajoute une ligne : texte, couleur, retrait, action au clic, infobulle.
local function addLine(view, text, color, options)
    options = options or {}
    view.count = view.count + 1
    local line = acquireLine(view.frame, view.count)
    local indent = options.indent or 0
    local width = WIDTH - 2 * PADDING - indent
    line.text:SetWidth(width)
    line.text:SetText(text)
    color = color or COLORS.text
    line.text:SetTextColor(color[1], color[2], color[3])
    local height = math.max(line.text:GetStringHeight() or 12, 12)
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", view.frame.body, "TOPLEFT", indent, -view.height)
    line:SetSize(width, height)
    line.onClick = options.onClick
    line.tooltip = options.tooltip
    line:EnableMouse(options.onClick ~= nil or options.tooltip ~= nil)
    line:Show()
    view.height = view.height + height + LINE_GAP
    view.texts[#view.texts + 1] = text
    return line
end

local function addGap(view)
    view.height = view.height + 4
end

---------------------------------------------------------------------------
-- Contenu
---------------------------------------------------------------------------

local function blockedReason(reason)
    if reason and reason.kind == "level" then
        return L["requires level %d"]:format(reason.level)
    end
    return L["not available yet"]
end

-- Une ligne d'objectif : icône, libellé, précision.
local function addGoal(self, view, result, i, j, status)
    local guide = result.guide
    local goal = guide.steps[i].goals[j]
    local text = Labels.Goal(goal, guide, self.state)
    if goal.optional then
        text = L["(optional) %s"]:format(text)
    end
    local level = self.state and self.state:Level()
    local levelTag = Labels.LevelTag(goal, guide, level)
    if levelTag then
        text = levelTag .. " " .. text
    end
    local group = Labels.GroupTag(goal, guide)
    if group then
        text = ("%s |cffff8040(%s)|r"):format(text, group)
    end
    -- Récompense de la quête qui améliore l'équipement (module Items).
    local items = ns.Modules:Get("Items")
    if goal.quest and status ~= "done" and (goal.t == "accept" or goal.t == "turnin")
        and items and items.enabled then
        local reward = items:QuestRewardTag(goal.quest)
        if reward then
            text = ("%s |cff66e666(%s)|r"):format(text, reward)
        end
    end
    local source = status ~= "done" and Labels.CollectSource(goal, guide)
    if source then
        text = ("%s |cffa0a0a0(%s)|r"):format(text, source)
    end
    local note = Labels.GoalNote(goal, guide)
    if note then
        text = ("%s |cffa0a0a0- %s|r"):format(text, note)
    end
    if status == "blocked" then
        local reason = result.steps[i].goals and result.steps[i].goals[j].reason
        text = ("%s |cffff8040(%s)|r"):format(text, blockedReason(reason))
    end
    local options = { indent = INDENT }
    if status == "manual" then
        options.onClick = function()
            self:Tick(i, j)
        end
        options.tooltip = L["Click to mark it as done."]
    end
    -- Objectif de quête : son texte au survol ; un clic l'ouvre dans le journal de
    -- quêtes si elle y est (un objectif « à valider » garde son clic).
    if goal.quest and not options.onClick then
        local quest = goal.quest
        options.tooltip = function(tooltip)
            self:FillQuestTooltip(tooltip, quest, guide)
        end
        if self.state and self.state:InLog(quest) then
            options.onClick = function()
                self:OpenQuestLog(quest)
            end
        end
    end
    -- Maître de classe : les sorts à apprendre et leur coût.
    if goal.t == "train" and goal.class and status ~= "done" then
        local summary = self:SpellsSummary()
        if summary then
            text = ("%s |cffa0a0a0- %s|r"):format(text, summary)
            options.tooltip = self:SpellsTooltip()
        end
    end
    local color = status == "done" and COLORS.done or COLORS.text
    addLine(view, (ICONS[status] or ICONS.todo) .. " " .. text, color, options)
end

local SHOWN_GOALS = { done = true, todo = true, manual = true, blocked = true }

local function addCurrentStep(self, view, result)
    local guide, i = result.guide, result.current
    local step = guide.steps[i]
    addLine(view, Labels.Step(step, guide), COLORS.title)
    if result.mode == "free" then
        for _, entry in ipairs(result.free) do
            addGoal(self, view, result, entry.step, entry.goal, entry.status)
        end
    else
        for j in ipairs(step.goals) do
            local status = result.steps[i].goals and result.steps[i].goals[j].status
            if SHOWN_GOALS[status] then
                addGoal(self, view, result, i, j, status)
            end
        end
    end
    local note = Labels.StepNote(step, guide)
    if note then
        addLine(view, ICONS.note .. " " .. note, COLORS.muted, { indent = INDENT })
    end
end

-- Ici aussi : quêtes à prendre ou à rendre tout de suite auprès d'un PNJ proche,
-- que le guide prévoit plus loin.
local function addNearby(self, view, result)
    local list = self:NearbyActions(result)
    if #list == 0 then
        return
    end
    addGap(view)
    addLine(view, L["Here too (planned later in the guide):"], COLORS.title)
    for _, entry in ipairs(list) do
        addGoal(self, view, result, entry.step, entry.goal, "todo")
    end
end

-- Sacs presque pleins : le guide ramasse beaucoup d'objets en chemin.
local LOW_BAG_SLOTS = 4

local function addBagWarning(view)
    if not (C_Container and C_Container.GetContainerNumFreeSlots) then
        return
    end
    local free = 0
    for bag = 0, 4 do
        free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
    end
    if free <= LOW_BAG_SLOTS then
        addLine(view, L["Bags almost full: %d free slots."]:format(free), COLORS.warning, {
            tooltip = L["Sell your grey items, or hand in finished quests nearby, before picking up more."],
        })
    end
end

local function addAlong(self, view, result)
    if #result.along == 0 then
        return
    end
    addGap(view)
    addLine(view, L["Along the way:"], COLORS.title)
    for _, entry in ipairs(result.along) do
        addGoal(self, view, result, entry.step, entry.goal, entry.status)
    end
end

local function addAbandoned(self, view, result)
    for _, entry in ipairs(result.abandoned) do
        local quest = ns.DB:GetName("quest", entry.quest, result.guide) or "?"
        addLine(view, L["Abandoned quest: %s. Click to take it again."]:format(quest), COLORS.warning, {
            onClick = function()
                self:Reopen(entry.step)
            end,
        })
    end
end

local function nextStepIndex(result)
    for i = result.current + 1, #result.guide.steps do
        if result.steps[i].status == "ahead" then
            return i
        end
    end
end

local function addFooterLines(view, result)
    local nextIndex = nextStepIndex(result)
    if nextIndex then
        addGap(view)
        addLine(view, L["Next: %s"]:format(Labels.Step(result.guide.steps[nextIndex], result.guide)), COLORS.muted)
    end
    if #result.detours > 0 then
        addLine(view, L["Detours: %d quests off the route"]:format(#result.detours), COLORS.muted, {
            tooltip = L["Quests in your log that this guide does not use."],
        })
    end
    if result.advice.overleveled then
        addLine(view, L["You are above the level of this guide."], COLORS.warning)
    end
end

-- En groupe et en mode strict : rappel du mode libre, qui suit les objectifs proches
-- dans l'ordre où le groupe les fait (les guides de deux joueurs de niveaux
-- différents ne tombent jamais pile ensemble). Un clic passe en mode libre.
local function addGroupHint(self, view)
    if self.char.mode == "free" or not (IsInGroup and IsInGroup()) then
        return
    end
    addLine(view, L["In a group? Free mode follows the quests you do together."], COLORS.action, {
        onClick = function()
            self:SetMode("free")
        end,
        tooltip = L["Free mode shows the open objectives around you, in any order, instead of one step at a time."],
    })
end

-- Rappel des sorts à apprendre, sauf si l'étape courante mène déjà au maître.
-- Métier au plafond de sa maîtrise : la suivante est à apprendre chez le maître.
local function addProfessionHint(self, view)
    local professions = ns.Modules:Get("Professions")
    if not (professions and professions.enabled and self.state) then
        return
    end
    for _, due in ipairs(professions:TrainingDue(self.state:Level())) do
        addLine(view, L["%s %d/%d: learn %s at the trainer"]:format(due.profession.name, due.rank, due.max,
            due.tier.name), COLORS.warning)
    end
end

local function addSpellsReminder(self, view, result)
    for _, goal in ipairs(result.guide.steps[result.current].goals) do
        if goal.t == "train" and goal.class then
            return
        end
    end
    local summary, _, total = self:SpellsSummary()
    if summary then
        local short = (self.state:Money() or 0) < total
        -- En ville, près d'un maître de classe : un détour d'un clic.
        local trainer, distance = self:NearbyClassTrainer()
        if trainer and not short then
            local name = ns.DB:GetName("npc", trainer.npc) or L["your class trainer"]
            addLine(view, L["Class trainer nearby (%s, %d yd): %s"]:format(name, math.floor(distance + 0.5), summary),
                COLORS.action, {
                    tooltip = self:SpellsTooltip(),
                    onClick = function()
                        self:PointTo(trainer, name)
                    end,
                })
            return
        end
        addLine(view, summary, short and COLORS.warning or COLORS.muted, { tooltip = self:SpellsTooltip() })
    end
end

-- Quêtes de classe à faire : une ligne cliquable chacune (au plus deux).
local MAX_CLASS_GUIDES = 2

local function addClassGuides(self, view)
    local list = self:ClassGuides()
    for index = 1, math.min(#list, MAX_CLASS_GUIDES) do
        local guide = list[index]
        if index == 1 then
            addGap(view)
        end
        addLine(view, L["Class quest: %s"]:format(Labels.Guide(guide)), COLORS.action, {
            onClick = function()
                self:StartClassGuide(guide.id)
            end,
            tooltip = guide.why and ns.DB:Render(guide.why, guide) or nil,
        })
    end
end

local function addChoices(self, view, list, format)
    for _, guide in ipairs(list) do
        addLine(view, format:format(Labels.Guide(guide)), COLORS.action, {
            indent = INDENT,
            onClick = function()
                self:Start(guide.id)
            end,
        })
    end
end

local MAX_SUGGESTIONS = 3

local function addSuggestions(self, view)
    addLine(view, L["No guide followed."], COLORS.title)
    if not (self.state and self.state:Ready() ~= false) then
        addLine(view, L["Reading the quest log..."], COLORS.muted)
        return
    end
    local list = {}
    for _, guide in ipairs(self:Suggest()) do
        if #list < MAX_SUGGESTIONS then
            list[#list + 1] = guide
        end
    end
    if #list == 0 then
        addLine(view, L["No leveling guide for your level."], COLORS.muted)
        return
    end
    addChoices(self, view, list, L["Start: %s"])
    addClassGuides(self, view)
end

local function addFinished(self, view, result)
    addLine(view, L["Guide complete!"], COLORS.title)
    local back = self.char.returnTo and ns.DB:GetGuide(self.char.returnTo)
    if back then
        addLine(view, L["Back to: %s"]:format(Labels.Guide(back)), COLORS.action, {
            indent = INDENT,
            onClick = function()
                self:Resume()
            end,
        })
    end
    local list = {}
    for _, id in ipairs(result.next or {}) do
        local guide = ns.DB:GetGuide(id)
        if guide then
            list[#list + 1] = guide
        end
    end
    addChoices(self, view, list, L["Continue: %s"])
end

local function addAsk(self, view, result)
    local quest = ns.DB:GetName("quest", result.ask.quest, result.guide) or "?"
    addLine(view, L["Group quest: %s. Do it?"]:format(quest), COLORS.title)
    addLine(view, L["Yes"], COLORS.action, { indent = INDENT, onClick = function()
        self:Answer(result.ask.quest, true)
    end })
    addLine(view, L["No, skip it"], COLORS.action, { indent = INDENT, onClick = function()
        self:Answer(result.ask.quest, false)
    end })
end

---------------------------------------------------------------------------
-- Mise à jour
---------------------------------------------------------------------------

function Guide:UpdateWindow(result)
    local frame = self.window
    if not frame then
        return
    end
    frame.title:SetText(result and Labels.Guide(result.guide) or "NextStep")
    frame.mode:SetText(self.char.mode == "free" and L["Free"] or L["Strict"])

    local view = { frame = frame, count = 0, height = 4, texts = {} }
    if not result then
        addSuggestions(self, view)
    elseif not result.ready then
        addLine(view, L["Reading the quest log..."], COLORS.muted)
    elseif result.finished then
        addFinished(self, view, result)
    elseif result.ask then
        addAsk(self, view, result)
    else
        -- Guide annexe : le guide de leveling interrompu reste à un clic.
        local back = self.char.returnTo and ns.DB:GetGuide(self.char.returnTo)
        if back and result.guide and result.guide.id ~= back.id then
            addLine(view, L["Back to: %s"]:format(Labels.Guide(back)), COLORS.action, {
                onClick = function()
                    self:Resume()
                end,
                tooltip = L["Leave this guide and resume your leveling guide where you left it."],
            })
        end
        -- Flèche tournée vers un lieu choisi dans le journal : un clic la rend au guide.
        if self.pointTarget then
            addLine(view, L["Arrow: %s (click to go back to the guide)"]:format(self.pointTarget.label or "?"),
                COLORS.warning, { onClick = function() self:BackToGuide() end })
        end
        addCurrentStep(self, view, result)
        addNearby(self, view, result)
        addAlong(self, view, result)
        addAbandoned(self, view, result)
        addFooterLines(view, result)
        addSpellsReminder(self, view, result)
        addProfessionHint(self, view)
        addBagWarning(view)
        addGroupHint(self, view)
        addClassGuides(self, view)
    end
    for index = view.count + 1, #frame.lines do
        frame.lines[index]:Hide()
    end
    self.windowTexts = view.texts   -- pour les tests

    local active = result ~= nil and result.current ~= nil and not result.ask
    frame.skip:SetEnabled(active)
    frame.done:SetEnabled(active)

    local collapsed = self.db.window.collapsed
    frame.body:SetShown(not collapsed)
    frame.footer:SetShown(not collapsed)
    frame.collapse:SetLabel(collapsed and "+" or "-")
    frame.separator:SetShown(not collapsed)
    if collapsed then
        frame:SetHeight(HEADER_HEIGHT)
    else
        frame:SetHeight(HEADER_HEIGHT + view.height + FOOTER_HEIGHT)
    end
end

---------------------------------------------------------------------------
-- Quêtes : texte au survol, ouverture dans le journal de quêtes
---------------------------------------------------------------------------

-- Texte d'une quête du journal : description et objectifs, lus en la sélectionnant
-- un instant (la sélection du joueur est rendue aussitôt).
function Guide:QuestText(quest)
    if not (C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(quest)) then
        return nil
    end
    if not (C_QuestLog.SetSelectedQuest and GetQuestLogQuestText) then
        return nil
    end
    local previous = C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
    C_QuestLog.SetSelectedQuest(quest)
    local description, objectives = GetQuestLogQuestText()
    if previous and previous ~= quest then
        C_QuestLog.SetSelectedQuest(previous)
    end
    return description, objectives
end

-- Infobulle d'une quête : titre et niveau, objectifs du client, description.
function Guide:FillQuestTooltip(tooltip, quest, guide)
    local name = ns.DB:GetName("quest", quest, guide) or ("#" .. quest)
    local level = Labels.QuestLevel({ quest = quest }, guide)
    local levelTag = level and Labels.LevelTag({ quest = quest }, guide, self.state and self.state:Level())
    tooltip:SetText((levelTag and (levelTag .. " ") or "") .. name, 1, 0.82, 0, 1, true)
    local inLog = self.state and self.state:InLog(quest)
    for _, objective in ipairs(inLog and self.state:Objectives(quest) or {}) do
        if objective.text and objective.text ~= "" then
            local done = objective.finished
            tooltip:AddLine((done and "|cff808080- " or "- ") .. objective.text .. (done and "|r" or ""), 1, 1, 1, true)
        end
    end
    local description, objectives = self:QuestText(quest)
    if objectives and objectives ~= "" then
        tooltip:AddLine(" ")
        tooltip:AddLine(objectives, 1, 1, 1, true)
    end
    if description and description ~= "" then
        tooltip:AddLine(" ")
        tooltip:AddLine(description, 0.75, 0.75, 0.75, true)
    end
    if inLog then
        tooltip:AddLine(" ")
        tooltip:AddLine(L["Click to open it in the quest log."], 0.4, 0.8, 1, true)
    elseif not description then
        tooltip:AddLine(L["Not in your quest log."], 0.6, 0.6, 0.6, true)
    end
end

-- Ouvre le journal de quêtes du jeu sur la quête : journal intégré à la carte
-- (QuestMapFrame), ou journal classique (QuestLogFrame).
function Guide:OpenQuestLog(quest)
    if InCombatLockdown and InCombatLockdown() then
        ns:Print(L["Not in combat."])
        return
    end
    if QuestMapFrame_OpenToQuestDetails then
        QuestMapFrame_OpenToQuestDetails(quest)
        return
    end
    if C_QuestLog.SetSelectedQuest then
        C_QuestLog.SetSelectedQuest(quest)
    end
    local index = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(quest)
    if index and SelectQuestLogEntry then
        SelectQuestLogEntry(index)
    end
    if QuestLogFrame and ShowUIPanel then
        ShowUIPanel(QuestLogFrame)
        if QuestLog_Update then
            QuestLog_Update()
        end
    elseif ToggleQuestLog then
        ToggleQuestLog()
    end
end

-- Valide à la main les objectifs « à valider » de l'étape courante (bouton Valider).
function Guide:ValidateCurrent()
    local result = self.result
    if not (result and result.current) then
        return
    end
    local i = result.current
    local any = false
    for j in ipairs(result.guide.steps[i].goals) do
        local entry = result.steps[i].goals and result.steps[i].goals[j]
        if entry and entry.status == "manual" then
            local guide = result.guide
            ns.GuideEngine.Tick(self:Progress(guide.id), guide, i, j)
            any = true
        end
    end
    if any then
        self:Refresh()
    else
        -- Rien à valider à la main : l'étape est considérée comme faite.
        self:Skip(i)
    end
end

function Guide:SetWindowShown(shown)
    self.db.window.shown = shown
    if self.window then
        self.window:SetShown(shown and self.enabled)
    end
end

function Guide:ToggleWindow()
    if not self.enabled then
        ns:Print(L["%s is disabled: enable it in the options."]:format(self.title))
        return
    end
    self:SetWindowShown(not self.db.window.shown)
end

function Guide:SetWindowCollapsed(collapsed)
    self.db.window.collapsed = collapsed
    self:UpdateWindow(self.result)
end

function Guide:SetWindowLocked(locked)
    self.db.window.locked = locked
end
