-- Bouton NextStep et menu des addons (docs/DESIGN.md, « Bouton NextStep et menu des
-- addons ») : un seul bouton sur la minimap donne accès au radar, aux options de
-- NextStep et aux paramètres de chaque addon chargé ; les boutons LibDBIcon des
-- autres addons sont masqués (réversible).
--
--   clic gauche : menu ; clic droit : options de NextStep ; clic milieu : radar ;
--   glisser : déplace le bouton autour de la minimap (position mémorisée).
--
-- Un addon du menu ouvre, dans l'ordre : son propre bouton de minimap (LibDBIcon),
-- son entrée du compartiment d'addons (## AddonCompartmentFunc), sa page dans les
-- options du jeu (retrouvée par son titre) ; sinon la ligne est grisée.
--
-- [À vérifier] sur Forever : MenuUtil (titres, séparateurs, lignes désactivées) ;
-- catégories des autres addons dans SettingsPanel ; boutons LibDBIcon.

local addonName, ns = ...
local L = ns.L

local Menu = ns.Modules:New("AddonsMenu", {
    title = L["NextStep button"],
    description = L["A single minimap button for the farming radar, NextStep's options and the settings "
        .. "of every add-on; other add-ons' minimap buttons are hidden."],
    defaults = {
        angle = 225,
        hideButtons = true,
        keepButtons = {},       -- [nom du bouton LibDBIcon] = true : laissé visible
        hideOwnButton = false,  -- bouton NextStep caché (menu par /ns addons)
        hideCompartment = true, -- compartiment d'addons de Blizzard masqué
    },
})

local ICON = "Interface\\AddOns\\NextStep\\Media\\IconSmall"
local BORDER = "Interface\\Minimap\\MiniMap-TrackingBorder"
local SIZE = 31
local RESCAN_DELAY = 5   -- secondes : boutons créés tardivement par les autres addons
local GROUP_SIZE = 15    -- au-delà, les addons sont rangés par lettre
-- Addons qui regroupent déjà les boutons de la minimap : NextStep ne masque rien.
local BUTTON_BAGS = { "MinimapButtonButton", "Bazooka", "ButtonBin", "MBB" }

-- Retire les codes de couleur et de texture d'un titre d'addon.
local function plain(text)
    text = tostring(text or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end
Menu.Plain = plain

---------------------------------------------------------------------------
-- Addons et leur action
---------------------------------------------------------------------------

-- Page des options du jeu dont le nom est l'un de names.
local function settingsCategory(names)
    if not (SettingsPanel and SettingsPanel.GetAllCategories) then
        return nil
    end
    for _, category in ipairs(SettingsPanel:GetAllCategories() or {}) do
        local name = plain(category:GetName())
        if names[name] then
            return category
        end
    end
end

-- Action d'un addon (fonction sans argument), ou nil s'il n'a pas de paramètres.
function Menu.ActionOf(name, title)
    local button = _G["LibDBIcon10_" .. name]
    local onClick = button and button.GetScript and button:GetScript("OnClick")
    if onClick then
        return function()
            onClick(button, "LeftButton")
        end
    end
    local compartment = C_AddOns.GetAddOnMetadata(name, "AddonCompartmentFunc")
    if compartment and type(_G[compartment]) == "function" then
        return function()
            _G[compartment](name, "LeftButton")
        end
    end
    local category = settingsCategory({ [name] = true, [plain(title)] = true })
    if category and Settings and Settings.OpenToCategory then
        return function()
            Settings.OpenToCategory(category:GetID())
        end
    end
end

-- Addons chargés, hors NextStep et ses addons de données, triés par titre :
-- { name, title, icon, action }.
function Menu.Addons()
    local list = {}
    if not (C_AddOns and C_AddOns.GetNumAddOns) then
        return list
    end
    for index = 1, C_AddOns.GetNumAddOns() do
        local name, title = C_AddOns.GetAddOnInfo(index)
        if name and C_AddOns.IsAddOnLoaded(name) and not name:find("^" .. addonName) then
            list[#list + 1] = {
                name = name,
                title = plain(title ~= nil and title ~= "" and title or name),
                icon = C_AddOns.GetAddOnMetadata(name, "IconTexture"),
                action = Menu.ActionOf(name, title),
            }
        end
    end
    table.sort(list, function(a, b)
        return a.title:lower() < b.title:lower()
    end)
    return list
end

---------------------------------------------------------------------------
-- Menu
---------------------------------------------------------------------------

local function toggleRadar()
    local radar = ns.Modules:Get("Radar")
    if radar and radar.enabled then
        radar:Toggle()
    else
        ns:Print(L["%s is disabled: enable it in the options."]:format(radar and radar.title or "Radar"))
    end
end

local function withIcon(icon, text)
    return icon and ("|T%s:16:16|t %s"):format(icon, text) or text
end

-- Remplit le menu (root : description de MenuUtil).
function Menu:Fill(root)
    root:CreateTitle("NextStep")
    root:CreateButton(L["Farming radar"], toggleRadar)
    root:CreateButton(L["Guide journal"], function()
        local guide = ns.Modules:Get("Guide")
        if guide then
            guide:ToggleJournal("routes")
        end
    end)
    root:CreateButton(L["Class spells"], function()
        local guide = ns.Modules:Get("Guide")
        if guide then
            guide:ToggleJournal("spells")
        end
    end)
    root:CreateButton(L["Zones"], function()
        local guide = ns.Modules:Get("Guide")
        if guide then
            guide:ToggleJournal("zones")
        end
    end)
    root:CreateButton(L["Dungeons"], function()
        local guide = ns.Modules:Get("Guide")
        if guide then
            guide:ToggleJournal("dungeons")
        end
    end)
    root:CreateButton(L["Professions"], function()
        local guide = ns.Modules:Get("Guide")
        if guide then
            guide:ToggleJournal("professions")
        end
    end)
    root:CreateButton(L["Gear"], function()
        local guide = ns.Modules:Get("Guide")
        if guide then
            guide:ToggleJournal("gear")
        end
    end)
    root:CreateButton(L["Bags and bank"], function()
        local inventory = ns.Modules:Get("Inventory")
        if inventory and inventory.enabled then
            inventory:Toggle()
        end
    end)
    root:CreateButton(L["Clock"], function()
        local clock = ns.Modules:Get("Clock")
        if clock and clock.enabled then
            clock:Toggle()
        end
    end)
    root:CreateButton(L["NextStep options"], function()
        ns.Options:Open()
    end)
    root:CreateDivider()
    root:CreateTitle(L["Add-ons"])
    local addons = Menu.Addons()
    if #addons == 0 then
        local none = root:CreateButton(L["No other add-on loaded."], function() end)
        none:SetEnabled(false)
    end
    local function addLine(parent, addon)
        local line = parent:CreateButton(withIcon(addon.icon, addon.title), addon.action or function() end)
        if not addon.action then
            line:SetEnabled(false)
            if line.SetTooltip then
                line:SetTooltip(function(tooltip)
                    tooltip:SetText(L["No settings"])
                end)
            end
        end
    end
    if #addons <= GROUP_SIZE then
        for _, addon in ipairs(addons) do
            addLine(root, addon)
        end
    else
        -- Beaucoup d'addons : un sous-menu par groupe de lettres.
        for _, group in ipairs(Menu.Groups(addons)) do
            local sub = root:CreateButton(group.label)
            for _, addon in ipairs(group.addons) do
                addLine(sub, addon)
            end
        end
    end
    -- Boutons de la minimap à garder visibles.
    local hidden = self:HiddenButtonNames()
    if #hidden > 0 and root.CreateCheckbox then
        root:CreateDivider()
        local sub = root:CreateButton(L["Keep visible on the minimap"])
        for _, name in ipairs(hidden) do
            sub:CreateCheckbox(name:gsub("^LibDBIcon10_", ""), function()
                return self.db.keepButtons[name] == true
            end, function()
                self.db.keepButtons[name] = not self.db.keepButtons[name] or nil
                self:HideButtons()
            end)
        end
    end
end

-- Groupes de lettres : { label = "A - F", addons }, au plus GROUP_SIZE addons chacun.
function Menu.Groups(addons)
    local groups, current = {}, nil
    for _, addon in ipairs(addons) do
        local letter = addon.title:sub(1, 1):upper()
        if not current or #current.addons >= GROUP_SIZE and letter ~= current.last then
            current = { first = letter, last = letter, addons = {} }
            groups[#groups + 1] = current
        end
        current.last = letter
        table.insert(current.addons, addon)
    end
    for _, group in ipairs(groups) do
        group.label = group.first == group.last and group.first or (group.first .. " - " .. group.last)
    end
    return groups
end

function Menu:HiddenButtonNames()
    local list = {}
    for child in pairs(self.hiddenButtons or {}) do
        local name = child.GetName and child:GetName()
        if name then
            list[#list + 1] = name
        end
    end
    table.sort(list)
    return list
end

-- Un addon qui regroupe déjà les boutons est chargé : nom, ou nil.
function Menu.ButtonBag()
    for _, name in ipairs(BUTTON_BAGS) do
        if C_AddOns.IsAddOnLoaded(name) then
            return name
        end
    end
end

function Menu:Open(owner)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner or self.button or UIParent, function(_, root)
            self:Fill(root)
        end)
        return
    end
    -- Sans menu du client : la liste dans le chat.
    ns:Print(L["Add-ons"])
    for _, addon in ipairs(Menu.Addons()) do
        DEFAULT_CHAT_FRAME:AddMessage("  " .. addon.title)
    end
end

---------------------------------------------------------------------------
-- Bouton de la minimap
---------------------------------------------------------------------------

local function square()
    return GetMinimapShape ~= nil and GetMinimapShape() == "SQUARE"
end

-- Position du bouton (depuis le centre de la minimap) pour un angle en degrés :
-- sur le cercle, ou sur le bord du carré.
function Menu.ButtonOffset(angle, half, isSquare)
    local radians = math.rad(angle)
    local x, y = math.cos(radians), math.sin(radians)
    local radius = half + 10
    if isSquare then
        -- Projection sur le carré : la plus grande composante touche le bord.
        local reach = math.max(math.abs(x), math.abs(y))
        return x / reach * radius, y / reach * radius
    end
    return x * radius, y * radius
end

function Menu:PlaceButton()
    local button = self.button
    if not button then
        return
    end
    local x, y = Menu.ButtonOffset(self.db.angle, (Minimap:GetWidth() or 140) / 2, square())
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Angle du curseur autour du centre de la minimap, en degrés.
local function cursorAngle()
    local x, y = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = Minimap:GetCenter()
    return math.deg(math.atan2(y / scale - cy, x / scale - cx)) % 360
end

local function showTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("NextStep")
    GameTooltip:AddLine(L["Left-click: add-ons menu"], 1, 1, 1)
    GameTooltip:AddLine(L["Right-click: NextStep options"], 1, 1, 1)
    GameTooltip:AddLine(L["Middle-click: farming radar"], 1, 1, 1)
    GameTooltip:AddLine(L["Drag: move the button"], 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

function Menu:CreateButton()
    local button = CreateFrame("Button", "NextStepMinimapButton", Minimap)
    button:SetSize(SIZE, SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture(ICON)
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -5)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture(BORDER)
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", function(frame, mouse)
        if mouse == "RightButton" then
            ns.Options:Open()
        elseif mouse == "MiddleButton" then
            toggleRadar()
        else
            self:Open(frame)
        end
    end)
    button:SetScript("OnEnter", showTooltip)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStart", function(frame)
        GameTooltip:Hide()
        frame:SetScript("OnUpdate", function()
            self.db.angle = cursorAngle()
            self:PlaceButton()
        end)
    end)
    button:SetScript("OnDragStop", function(frame)
        frame:SetScript("OnUpdate", nil)
    end)
    self.button = button
end

---------------------------------------------------------------------------
-- Boutons des autres addons
---------------------------------------------------------------------------

-- Cache les boutons LibDBIcon (enfants de la minimap et de son cadre) ; ils restent
-- cachés tant que l'option est active, et réapparaissent sinon.
function Menu:HideButtons()
    self.hiddenButtons = self.hiddenButtons or {}
    for _, parent in ipairs({ Minimap, MinimapCluster }) do
        if parent and parent.GetChildren then
            for _, child in ipairs({ parent:GetChildren() }) do
                local name = child.GetName and child:GetName()
                if name and name:find("^LibDBIcon10_") and not self.hiddenButtons[child] then
                    self.hiddenButtons[child] = true
                    child:HookScript("OnShow", function(frame)
                        local shown = frame.GetName and frame:GetName()
                        if self.enabled and self.db.hideButtons and self.hiddenButtons[frame]
                            and not self.db.keepButtons[shown] and not Menu.ButtonBag() then
                            frame:Hide()
                        end
                    end)
                end
            end
        end
    end
    local hide = self.enabled and self.db.hideButtons and not Menu.ButtonBag()
    for child in pairs(self.hiddenButtons) do
        local name = child.GetName and child:GetName()
        child:SetShown(not (hide and not self.db.keepButtons[name]))
    end
end

-- Compartiment d'addons de Blizzard : masqué sans Hide (transparent, sans souris).
function Menu:ApplyCompartment()
    local frame = _G.AddonCompartmentFrame
    if not (frame and frame.SetAlpha) then
        return
    end
    local hide = self.enabled and self.db.hideCompartment
    frame:SetAlpha(hide and 0 or 1)
    if frame.EnableMouse then
        frame:EnableMouse(not hide)
    end
end

function Menu:ShowButtons()
    for child in pairs(self.hiddenButtons or {}) do
        child:Show()
    end
end

function Menu:SetHideButtons(hide)
    self.db.hideButtons = hide
    if hide then
        self:HideButtons()
    else
        self:ShowButtons()
    end
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function Menu:OnInitialize()
    ns.Slash:Add("addons", function()
        if self.enabled then
            self:Open()
        else
            ns:Print(L["%s is disabled: enable it in the options."]:format(self.title))
        end
    end, L["Open the add-ons menu"])
end

function Menu:OnEnable()
    if not Minimap then
        return
    end
    if not self.button then
        self:CreateButton()
    end
    self:PlaceButton()
    self.button:SetShown(not self.db.hideOwnButton)
    self:HideButtons()
    self:ApplyCompartment()
    local bag = Menu.ButtonBag()
    if bag and self.db.hideButtons then
        ns:Print(L["%s already groups minimap buttons: NextStep leaves them alone."]:format(bag))
    end
    self:RegisterEvent("ADDON_LOADED", function()
        self:HideButtons()
    end)
    if C_Timer and C_Timer.After then
        C_Timer.After(RESCAN_DELAY, function()
            if self.enabled then
                self:HideButtons()
            end
        end)
    end
end

function Menu:OnDisable()
    if self.button then
        self.button:Hide()
    end
    self:ShowButtons()
    self:ApplyCompartment()
end

function Menu:BuildOptions(panel, anchor)
    local Options = ns.Options
    local below = Options.AddCheck(panel, anchor, L["Hide other add-ons' minimap buttons"],
        function() return self.db.hideButtons end,
        function(value) self:SetHideButtons(value) end)
    below = Options.AddCheck(panel, below, L["Hide Blizzard's add-on compartment"],
        function() return self.db.hideCompartment end,
        function(value)
            self.db.hideCompartment = value
            self:ApplyCompartment()
        end)
    return Options.AddCheck(panel, below, L["Hide the NextStep button (menu: /ns addons)"],
        function() return self.db.hideOwnButton end,
        function(value)
            self.db.hideOwnButton = value
            if self.button then
                self.button:SetShown(self.enabled and not value)
            end
        end)
end
