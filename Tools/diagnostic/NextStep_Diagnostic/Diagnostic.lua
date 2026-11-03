-- NextStep - Diagnostic : vérifie en jeu les points marqués [À vérifier] dans
-- docs/DESIGN.md (phase 1 de la feuille de route). Outil de développement, jamais
-- livré aux joueurs.
--
--   /nsdiag          lance toutes les vérifications hors combat et résume dans le chat
--   /nsdiag combat   arme la capture : attaquer ensuite un monstre (secret values)
--   /nsdiag show     affiche le dernier rapport dans une fenêtre, pour le copier
--
-- Le rapport est écrit dans NextStepDiagDB (sauvegardé au /reload ou à la
-- déconnexion), puis converti par Tools/diagnostic/report.ps1.
--
-- Tout est appelé sous pcall : l'outil ne doit jamais provoquer d'erreur, et il
-- n'effectue aucune action protégée.

local ADDON = ...

local PREFIX = "|cff66ccffNextStep Diagnostic|r "
local STATUS_ORDER = { "ok", "warn", "missing", "info" }

local function print(...)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. table.concat({ ... }, " "))
end

-- Valeur d'un chemin pointé depuis _G : "C_QuestLog.IsOnQuest".
local function resolve(path)
    local value = _G
    for part in path:gmatch("[^%.]+") do
        if type(value) ~= "table" then
            return nil
        end
        value = value[part]
    end
    return value
end

local function isSecret(value)
    local check = _G.issecretvalue
    if not check then
        return false
    end
    local ok, secret = pcall(check, value)
    return ok and secret == true
end

-- Texte sûr pour le rapport, même pour une valeur secrète.
local function describe(value)
    if value == nil then
        return "nil"
    end
    if isSecret(value) then
        return "<secret " .. type(value) .. ">"
    end
    if type(value) == "table" then
        local count = 0
        for _ in pairs(value) do
            count = count + 1
        end
        return ("<table %d>"):format(count)
    end
    local ok, text = pcall(tostring, value)
    return ok and text or "<illisible>"
end

---------------------------------------------------------------------------
-- Rapport
---------------------------------------------------------------------------

local report, current

local function newReport(kind)
    local version, build, date, interface = GetBuildInfo()
    return {
        kind = kind,
        time = time(),
        client = { version = version, build = build, date = date, interface = interface, locale = GetLocale() },
        sections = {},
    }
end

local function section(name)
    current = { name = name, results = {} }
    report.sections[#report.sections + 1] = current
end

local function add(id, status, value, note)
    current.results[#current.results + 1] = {
        id = id,
        status = status,
        value = value ~= nil and describe(value) or nil,
        note = note,
    }
end

-- Existence d'une API (fonction ou table).
local function exists(path, note)
    local value = resolve(path)
    add(path, value ~= nil and "ok" or "missing", value ~= nil and type(value) or nil, note)
end

-- Valeur renvoyée par une sonde : ok si utilisable, warn si nil ou secrète.
local function probe(id, fn, note)
    local ok, a, b = pcall(fn)
    if not ok then
        add(id, "warn", nil, "erreur : " .. describe(a))
    elseif a == nil then
        add(id, "warn", nil, note or "nil")
    elseif isSecret(a) then
        add(id, "warn", a, note)
    else
        local value = b ~= nil and (describe(a) .. " | " .. describe(b)) or a
        add(id, "ok", value, note)
    end
end

local function info(id, value, note)
    add(id, "info", value, note)
end

---------------------------------------------------------------------------
-- Vérifications hors combat
---------------------------------------------------------------------------

local factionAtLoad, raceAtLoad

local API = {
    ["Quêtes"] = {
        "C_QuestLog.GetNumQuestLogEntries", "C_QuestLog.GetInfo", "C_QuestLog.GetLogIndexForQuestID",
        "C_QuestLog.IsOnQuest", "C_QuestLog.IsComplete", "C_QuestLog.IsQuestFlaggedCompleted",
        "C_QuestLog.GetQuestObjectives", "C_QuestLog.GetTitleForQuestID", "C_QuestLog.GetAllCompletedQuestIDs",
        "GetQuestsCompleted", "GetQuestLogTitle",
    },
    ["Cartes et position"] = {
        "C_Map.GetBestMapForUnit", "C_Map.GetPlayerMapPosition", "C_Map.GetMapInfo", "C_Map.GetAreaInfo",
        "C_Map.GetWorldPosFromMapPos", "C_Map.GetMapPosFromWorldPos", "C_Map.SetUserWaypoint",
        "C_Map.CanSetUserWaypointOnMap", "C_SuperTrack", "GetPlayerFacing", "CreateVector2D",
        "UiMapPoint.CreateFromCoordinates", "C_MapExplorationInfo.GetExploredAreaIDsAtPosition",
        "GetZoneText", "GetSubZoneText", "GetRealZoneText", "GetMinimapZoneText", "IsIndoors",
    },
    ["Objets et sacs"] = {
        "C_Item.GetItemNameByID", "C_Item.GetItemCount", "C_Item.GetItemInfo", "C_Item.EquipItemByName",
        "EquipItemByName", "C_Container.GetContainerNumSlots", "C_Container.GetContainerItemInfo",
        "C_Container.SortBags", "C_Container.UseContainerItem", "GetItemStats", "C_TooltipInfo.GetBagItem",
    },
    ["Sorts, métiers, réputation"] = {
        "C_Spell.GetSpellName", "C_Spell.GetSpellInfo", "IsPlayerSpell", "IsSpellKnown", "C_SpellBook",
        "GetNumSkillLines", "GetSkillLineInfo", "C_TradeSkillUI", "C_Reputation.GetFactionDataByID",
        "GetFactionInfoByID", "GetBindLocation", "GetMoney", "UnitXP", "UnitXPMax",
        "C_TaxiMap.GetAllTaxiNodes", "TaxiNodeName", "NumTaxiNodes",
    },
    ["Unités et combat"] = {
        "UnitHealth", "UnitHealthMax", "UnitPower", "UnitPowerMax", "UnitHealthPercent", "UnitPowerPercent",
        "AbbreviateNumbers", "AbbreviateLargeNumbers", "BreakUpLargeNumbers", "issecretvalue", "canaccessvalue",
        "UnitGUID", "UnitName", "UnitRace", "UnitClass", "InCombatLockdown", "C_NamePlate.GetNamePlateForUnit",
        "C_NamePlate.GetNamePlates", "C_TooltipInfo.GetHyperlink", "C_TooltipInfo.GetUnit",
        "CombatLogGetCurrentEventInfo",
    },
    ["Interface et addons"] = {
        "Settings.RegisterCanvasLayoutCategory", "Settings.RegisterAddOnCategory", "Settings.OpenToCategory",
        "C_AddOns.LoadAddOn", "C_AddOns.IsAddOnLoaded", "C_AddOns.GetAddOnMetadata",
        "C_AddOns.GetAddOnMemoryUsage", "UpdateAddOnMemoryUsage", "GetAddOnMemoryUsage", "C_Timer.After",
        "C_CVar.GetCVar", "GetMinimapShape", "HandleModifiedItemClick", "C_AddOns.EnableAddOn",
    },
}

local API_ORDER = {
    "Quêtes", "Cartes et position", "Objets et sacs", "Sorts, métiers, réputation", "Unités et combat",
    "Interface et addons",
}

local function checkClient()
    section("Client")
    local _, _, _, interface = GetBuildInfo()
    add("Interface", interface == 16001 and "ok" or "warn", interface, "attendu : 16001")
    info("WOW_PROJECT_ID", _G.WOW_PROJECT_ID)
    info("WOW_PROJECT_CAMELOT", _G.WOW_PROJECT_CAMELOT)
    info("Langue", GetLocale())
    local ok, raceName, raceFile = pcall(UnitRace, "player")
    info("UnitRace (raceFile)", ok and raceFile, ok and describe(raceName) or nil)
    local okClass, _, classFile = pcall(UnitClass, "player")
    info("UnitClass (classFile)", okClass and classFile)
    probe("UnitFactionGroup", function()
        return UnitFactionGroup("player")
    end)
    info("Faction au chargement", factionAtLoad, "UnitFactionGroup lu à ADDON_LOADED")
    info("raceFile au chargement", raceAtLoad)
end

local function checkAPIs()
    for _, name in ipairs(API_ORDER) do
        section("API : " .. name)
        for _, path in ipairs(API[name]) do
            exists(path)
        end
    end
end

local function firstLogQuest()
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then
        return nil
    end
    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local questInfo = C_QuestLog.GetInfo(index)
        if questInfo and not questInfo.isHeader and questInfo.questID then
            return questInfo.questID
        end
    end
end

local function tooltipName(id)
    local data = C_TooltipInfo.GetHyperlink(("unit:Creature-0-0-0-0-%d-0000000000"):format(id))
    return data and data.lines and data.lines[1] and data.lines[1].leftText
end

local function checkValues()
    section("Valeurs lues hors combat")
    probe("Niveau et expérience", function()
        return UnitLevel("player"), UnitXP("player") .. "/" .. UnitXPMax("player")
    end)
    probe("Argent", GetMoney)
    probe("Quêtes dans le journal", function()
        return C_QuestLog.GetNumQuestLogEntries()
    end)
    local quest = firstLogQuest()
    info("Première quête du journal", quest)
    if quest then
        probe("Titre de cette quête", function()
            return C_QuestLog.GetTitleForQuestID(quest)
        end)
        probe("Objectifs de cette quête", function()
            local objectives = C_QuestLog.GetQuestObjectives(quest)
            local first = objectives and objectives[1]
            return objectives and #objectives, first and (first.text .. " / fini=" .. tostring(first.finished))
        end)
    end
    probe("Quête 783 rendue ? (IsQuestFlaggedCompleted)", function()
        return tostring(C_QuestLog.IsQuestFlaggedCompleted(783))
    end)
    probe("Quêtes rendues (GetAllCompletedQuestIDs)", function()
        return #C_QuestLog.GetAllCompletedQuestIDs()
    end)
    probe("Région 12 (C_Map.GetAreaInfo)", function()
        return C_Map.GetAreaInfo(12)
    end, "Forêt d'Elwynn attendue")
    probe("Carte 1429 (C_Map.GetMapInfo)", function()
        return C_Map.GetMapInfo(1429).name
    end, "Forêt d'Elwynn attendue")
    probe("Sort 6603 (C_Spell.GetSpellName)", function()
        return C_Spell.GetSpellName(6603)
    end, "Attaque attendue")
    probe("Objet 6948 (C_Item.GetItemNameByID)", function()
        return C_Item.GetItemNameByID(6948)
    end, "Pierre de foyer attendue (peut être nil au premier appel)")
    probe("Pierre de foyer dans les sacs (C_Item.GetItemCount)", function()
        return C_Item.GetItemCount(6948)
    end)
    probe("Foyer (GetBindLocation)", GetBindLocation)
    probe("Zone / sous-zone", function()
        return GetZoneText(), GetSubZoneText()
    end)
    probe("Compétences (GetNumSkillLines)", GetNumSkillLines)
    probe("Points de vol connus (C_TaxiMap.GetAllTaxiNodes)", function()
        return #C_TaxiMap.GetAllTaxiNodes(C_Map.GetBestMapForUnit("player"))
    end, "souvent vide hors de la carte des vols")
    probe("Orientation (GetPlayerFacing)", GetPlayerFacing)
    probe("PNJ 197 par infobulle (C_TooltipInfo.GetHyperlink)", function()
        return tooltipName(197)
    end, "Maréchal McBride attendu (si le client le connaît)")
    probe("PNJ 6 par infobulle", function()
        return tooltipName(6)
    end, "Vermine kobold attendue")
    probe("Cible : GUID", function()
        return UnitGUID("target")
    end, "cibler un PNJ avant /nsdiag")
    probe("Cible : nom", function()
        return UnitName("target")
    end, "cibler un PNJ avant /nsdiag")
    probe("Santé du joueur hors combat secrète ?", function()
        return tostring(isSecret(UnitHealth("player")))
    end, "false attendu")
end

local function cvar(name)
    return C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(name)
end

local function template(frameType, name)
    local ok, frame = pcall(CreateFrame, frameType, nil, UIParent, name)
    if ok and frame then
        frame:Hide()
    end
    add("Modèle " .. name, ok and "ok" or "missing", nil, not ok and describe(frame) or nil)
end

local function checkNative()
    section("Interface native")
    probe("CVar statusText", function()
        return cvar("statusText")
    end, "texte de statut des cadres d'unité")
    probe("CVar statusTextDisplay", function()
        return cvar("statusTextDisplay")
    end, "NUMERIC, PERCENT, BOTH")
    probe("CVar combinedBags", function()
        return cvar("combinedBags")
    end, "sacs combinés")
    probe("CVar nameplateShowEnemies", function()
        return cvar("nameplateShowEnemies")
    end)
    probe("Horloge Blizzard (Blizzard_TimeManager)", function()
        return tostring(C_AddOns.IsAddOnLoaded("Blizzard_TimeManager")), tostring(_G.TimeManagerFrame ~= nil)
    end, "chargée | cadre présent")
    probe("Zoom de la carte du monde", function()
        local container = WorldMapFrame and WorldMapFrame.ScrollContainer
        return container and tostring(container.ZoomIn ~= nil or container.SetZoomTarget ~= nil)
    end, "ScrollContainer et fonctions de zoom")
    probe("Niveaux de zoom de la minimap", function()
        return Minimap:GetZoomLevels(), Minimap:GetZoom()
    end)
    probe("Molette sur la minimap", function()
        return tostring(Minimap:IsMouseWheelEnabled())
    end, "false : à activer nous-mêmes")
    template("CheckButton", "UICheckButtonTemplate")
    template("Button", "UIPanelButtonTemplate")
    template("Frame", "BackdropTemplate")
    template("ScrollFrame", "UIPanelScrollFrameTemplate")
    template("Button", "ContainerFrameItemButtonTemplate")
    probe("Sacs combinés : cadre", function()
        return tostring(_G.ContainerFrameCombinedBags ~= nil)
    end)
    probe("Suivi d'objectifs Blizzard", function()
        return tostring((_G.QuestWatchFrame or _G.ObjectiveTrackerFrame or _G.WatchFrame) ~= nil),
            (_G.ObjectiveTrackerFrame and "ObjectiveTrackerFrame") or (_G.QuestWatchFrame and "QuestWatchFrame")
            or (_G.WatchFrame and "WatchFrame")
    end)
end

local function memoryKB(name)
    if UpdateAddOnMemoryUsage then
        UpdateAddOnMemoryUsage()
    end
    local get = (C_AddOns and C_AddOns.GetAddOnMemoryUsage) or GetAddOnMemoryUsage
    return get and get(name)
end

local function checkNextStep()
    section("NextStep")
    local NS = _G.NextStep
    add("NextStep chargé", NS and "ok" or "missing", NS and NS.version)
    for _, name in ipairs({ "NextStep", "NextStep_Alliance", "NextStep_Horde" }) do
        probe("Mémoire " .. name .. " (Ko)", function()
            if not C_AddOns.IsAddOnLoaded(name) then
                return nil
            end
            return math.floor(memoryKB(name))
        end, "nil : non chargé")
    end
    if not NS then
        return
    end
    probe("Faction chargée", function()
        local loaded = {}
        for faction in pairs(NS.Factions.loaded) do
            loaded[#loaded + 1] = faction
        end
        return table.concat(loaded, ", ")
    end)
    probe("Guides disponibles", function()
        local count = 0
        for _ in NS.DB:IterateGuides() do
            count = count + 1
        end
        return count
    end)
    probe("Rendu d'un texte de guide", function()
        return NS.DB:Render("{npc:197} {area:12} {zone:1429} {spell:6603} {item:6948}")
    end, "noms dans la langue du client")
    probe("Noms appris", function()
        local Names = NS.Modules:Get("Names")
        return Names and Names:Count(), Names and tostring(Names.enabled)
    end, "nombre | module actif")
    probe("Panneau d'options", function()
        return NS.Options.category and "enregistré"
    end)
end

local function eraToWorld(frame, x, y)
    return frame.top + (frame.bottom - frame.top) * y / 100, frame.left + (frame.right - frame.left) * x / 100
end

local function checkCoordinates()
    section("Coordonnées")
    local map = C_Map.GetBestMapForUnit("player")
    info("Carte du joueur (uiMapID)", map)
    if not map then
        return
    end
    local position = C_Map.GetPlayerMapPosition(map, "player")
    if not position then
        add("Position du joueur", "warn", nil, "indisponible (instance ?)")
        return
    end
    local x, y = position:GetXY()
    add("Position du joueur", "ok", ("%.2f, %.2f"):format(x * 100, y * 100))
    local continent, world = C_Map.GetWorldPosFromMapPos(map, position)
    if not world then
        add("Position monde", "warn", nil, "C_Map.GetWorldPosFromMapPos sans résultat")
        return
    end
    local worldX, worldY = world:GetXY()
    add("Position monde", "ok", ("continent %s : %.1f, %.1f"):format(tostring(continent), worldX, worldY))
    local NS = _G.NextStep
    local frame = NS and NS.DB.mapFrames.era and NS.DB.mapFrames.era[map]
    if not frame then
        info("Repère era de cette carte", nil, "absent : carte propre à Forever ?")
        return
    end
    local eraX, eraY = eraToWorld(frame, x * 100, y * 100)
    local gap = math.sqrt((eraX - worldX) ^ 2 + (eraY - worldY) ^ 2)
    add("Écart repère era / client (yards)", gap < 5 and "ok" or "warn", ("%.1f"):format(gap),
        gap < 5 and "carte identique au Classic" or "carte modifiée : la conversion en jeu est nécessaire")
end

local function count(results)
    local counts = {}
    for _, status in ipairs(STATUS_ORDER) do
        counts[status] = 0
    end
    for _, s in ipairs(results.sections) do
        for _, r in ipairs(s.results) do
            counts[r.status] = counts[r.status] + 1
        end
    end
    return counts
end

local function store(kind)
    NextStepDiagDB = NextStepDiagDB or {}
    NextStepDiagDB.reports = NextStepDiagDB.reports or {}
    NextStepDiagDB.reports[kind] = report
end

local function runAll()
    if InCombatLockdown() then
        print("à lancer hors combat.")
        return
    end
    report = newReport("general")
    for _, check in ipairs({ checkClient, checkAPIs, checkValues, checkNative, checkNextStep, checkCoordinates }) do
        local ok, err = pcall(check)
        if not ok then
            section("Erreur")
            add("Vérification interrompue", "warn", nil, describe(err))
        end
    end
    store("general")
    local c = count(report)
    print(("%d OK, %d à revoir, %d absents, %d infos."):format(c.ok, c.warn, c.missing, c.info))
    print("Tapez /reload pour enregistrer le rapport. /nsdiag show pour le voir.")
end

---------------------------------------------------------------------------
-- Capture en combat (secret values)
---------------------------------------------------------------------------

local armed = false
local testText, testBar

local function combatChecks(unit)
    section("Combat : " .. unit)
    info("UnitExists secret ?", tostring(isSecret(UnitExists(unit))))
    local values = {
        UnitHealth = UnitHealth(unit),
        UnitHealthMax = UnitHealthMax(unit),
        UnitPower = UnitPower(unit),
        UnitName = UnitName(unit),
        UnitGUID = UnitGUID(unit),
    }
    for _, name in ipairs({ "UnitHealth", "UnitHealthMax", "UnitPower", "UnitName", "UnitGUID" }) do
        add(name .. " secret ?", "info", tostring(isSecret(values[name])))
    end
    local health, maxHealth = values.UnitHealth, values.UnitHealthMax
    local function attempt(id, fn)
        local ok, result = pcall(fn)
        add(id, ok and "ok" or "warn", ok and result or nil, not ok and describe(result) or nil)
    end
    attempt("Arithmétique sur la santé", function()
        return health + 0
    end)
    attempt("Comparaison sur la santé", function()
        return tostring(health > 0)
    end)
    attempt("string.format %d", function()
        return ("%d"):format(health)
    end)
    attempt("FontString:SetText(santé)", function()
        testText:SetText(health)
        return "accepté"
    end)
    attempt("StatusBar:SetMinMaxValues + SetValue", function()
        testBar:SetMinMaxValues(0, maxHealth)
        testBar:SetValue(health)
        return "accepté"
    end)
    if _G.AbbreviateNumbers then
        attempt("AbbreviateNumbers(santé) vers SetText", function()
            testText:SetText(AbbreviateNumbers(health))
            return "accepté"
        end)
    end
    if _G.UnitHealthPercent then
        attempt("UnitHealthPercent", function()
            local percent = UnitHealthPercent(unit)
            testText:SetText(percent)
            return "secret=" .. tostring(isSecret(percent))
        end)
    end
    attempt("SetFormattedText(%d / %d)", function()
        testText:SetFormattedText("%d / %d", health, maxHealth)
        return "accepté"
    end)
end

local function captureCombat()
    report = newReport("combat")
    for _, unit in ipairs({ "player", "target" }) do
        local ok, err = pcall(combatChecks, unit)
        if not ok then
            section("Erreur")
            add("Capture " .. unit .. " interrompue", "warn", nil, describe(err))
        end
    end
    pcall(function()
        section("Combat : nameplates")
        local plates = C_NamePlate.GetNamePlates()
        info("Nameplates visibles", #plates)
        local plate = plates[1]
        local unit = plate and (plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit))
        info("Unité de la première", unit)
        if unit then
            info("GUID secret ?", tostring(isSecret(UnitGUID(unit))))
            info("Santé secrète ?", tostring(isSecret(UnitHealth(unit))))
        end
    end)
    store("combat")
    print("capture en combat enregistrée. Tapez /reload après le combat.")
end

---------------------------------------------------------------------------
-- Fenêtre d'export
---------------------------------------------------------------------------

local exportFrame

local function reportText()
    local lines = {}
    for _, kind in ipairs({ "general", "combat" }) do
        local r = NextStepDiagDB and NextStepDiagDB.reports and NextStepDiagDB.reports[kind]
        if r then
            lines[#lines + 1] = ("== %s (%s, build %s)"):format(kind, tostring(r.client.version),
                tostring(r.client.build))
            for _, s in ipairs(r.sections) do
                lines[#lines + 1] = "-- " .. s.name
                for _, res in ipairs(s.results) do
                    lines[#lines + 1] = ("[%s] %s = %s %s"):format(res.status, res.id, tostring(res.value),
                        res.note and ("(" .. res.note .. ")") or "")
                end
            end
        end
    end
    return table.concat(lines, "\n")
end

local function show()
    if not exportFrame then
        local frame = CreateFrame("Frame", "NextStepDiagnosticFrame", UIParent, "BackdropTemplate")
        frame:SetSize(700, 500)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        frame:SetBackdropColor(0, 0, 0, 0.9)
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -12)
        scroll:SetPoint("BOTTOMRIGHT", -32, 40)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(640)
        edit:SetAutoFocus(false)
        edit:SetScript("OnEscapePressed", function()
            frame:Hide()
        end)
        scroll:SetScrollChild(edit)
        frame.edit = edit

        local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        close:SetSize(100, 22)
        close:SetPoint("BOTTOMRIGHT", -12, 10)
        close:SetText(CLOSE or "Fermer")
        close:SetScript("OnClick", function()
            frame:Hide()
        end)
        exportFrame = frame
    end
    exportFrame.edit:SetText(reportText())
    exportFrame.edit:HighlightText()
    exportFrame:Show()
end

---------------------------------------------------------------------------
-- Événements et commande
---------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        factionAtLoad = describe(UnitFactionGroup("player"))
        local _, raceFile = UnitRace("player")
        raceAtLoad = describe(raceFile)
        testText = UIParent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        testText:Hide()
        testBar = CreateFrame("StatusBar", nil, UIParent)
        testBar:Hide()
    elseif event == "PLAYER_REGEN_DISABLED" and armed then
        armed = false
        -- Laisser la cible et les nameplates se mettre à jour.
        C_Timer.After(1, captureCombat)
    end
end)

SLASH_NEXTSTEPDIAG1 = "/nsdiag"
SlashCmdList.NEXTSTEPDIAG = function(input)
    local command = (input or ""):match("^%s*(%S*)"):lower()
    if command == "combat" then
        armed = true
        print("capture armée : ciblez un monstre et attaquez-le.")
    elseif command == "show" then
        show()
    else
        runAll()
    end
end
