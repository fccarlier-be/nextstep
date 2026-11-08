-- Sacs et banque (docs/DESIGN.md, « Sacs et banque ») : les sacs natifs de Blizzard
-- (combinés ou non) sont enrichis plutôt que remplacés, ce qui évite les boutons
-- d'objets sécurisés.
--
--   marques   : amélioration (flèche verte, module Items), camelote (pièce grise, module
--               Junk), niveau d'objet en option ; places libres sous les sacs ;
--   mémoire   : sacs, banque et argent de chaque personnage du compte, retenus à chaque
--               changement (la banque à chaque visite, avec la date) ;
--   infobulle : combien chaque personnage en a, dans ses sacs et dans sa banque ;
--   fenêtre   : sacs et banque de n'importe quel personnage, consultables à distance en
--               lecture seule, avec une recherche (/ns bank, menu du bouton NextStep).
--
-- Sans souillure : hooksecurefunc sur la mise à jour des cadres de sacs, textures et
-- textes de NextStep sur les boutons, aucun Show/Hide de cadre de Blizzard.
--
-- [À vérifier] sur Forever : numéros des sacs de banque (Enum.BagIndex), BANKFRAME_OPENED,
-- boutons des sacs combinés (EnumerateValidItems).

local _, ns = ...
local L = ns.L

local Inventory = ns.Modules:New("Inventory", {
    title = L["Bags and bank"],
    description = L["Marks upgrades and junk in your bags, remembers the bags and bank of all your "
        .. "characters, counts items in tooltips, and shows any bank from anywhere."],
    defaults = {
        upgrades = true,
        junk = true,
        itemLevel = false,
        tooltip = true,
        characters = {},   -- [« Nom - Royaume »] = { name, class, faction, money, updated, bags, bank, bankTime }
    },
})

local Style = ns.Style
local C = Style.COLORS

local MAX_BAG_FRAMES = 13
local UPGRADE_TEXTURE = "Interface\\Buttons\\UI-MicroStream-Green"
local JUNK_TEXTURE = "Interface\\Buttons\\UI-GroupLoot-Coin-Up"
local POOR = 0

local marks = setmetatable({}, { __mode = "k" })   -- [bouton] = { upgrade, junk, level }

---------------------------------------------------------------------------
-- Conteneurs
---------------------------------------------------------------------------

local function bagIndex(name, fallback)
    return Enum and Enum.BagIndex and Enum.BagIndex[name] or fallback
end

-- Sacs portés : 0 à 4. Banque : la banque elle-même, puis ses sacs (5 à 10).
function Inventory.BagIDs()
    return { 0, 1, 2, 3, 4 }
end

function Inventory.BankIDs()
    local list = { bagIndex("Bank", -1) }
    for bag = 5, 11 do
        list[#list + 1] = bag
    end
    return list
end

-- Contenu de conteneurs : [objet] = nombre ; et places libres.
function Inventory.Count(bags)
    local counts, free = {}, 0
    if not (C_Container and C_Container.GetContainerNumSlots) then
        return counts, 0
    end
    for _, bag in ipairs(bags) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1)
            else
                free = free + 1
            end
        end
    end
    return counts, free
end

---------------------------------------------------------------------------
-- Mémoire des personnages
---------------------------------------------------------------------------

function Inventory:Key()
    local name = UnitName("player")
    local realm = GetRealmName and GetRealmName() or ""
    if not ns.Usable(name) then
        return nil
    end
    return realm ~= "" and ("%s - %s"):format(name, realm) or name
end

function Inventory:Me()
    local key = self:Key()
    if not key then
        return nil
    end
    local me = self.db.characters[key]
    if not me then
        local _, class = UnitClass("player")
        me = { name = UnitName("player"), class = class, faction = UnitFactionGroup and UnitFactionGroup("player"),
            bags = {}, bank = {} }
        self.db.characters[key] = me
    end
    return me
end

local function now()
    return (time or os.time)()
end

function Inventory:ScanBags()
    local me = self:Me()
    if not me then
        return
    end
    local counts, free = Inventory.Count(Inventory.BagIDs())
    me.bags, me.freeSlots = counts, free
    me.money = GetMoney and GetMoney() or me.money
    me.updated = now()
    self:UpdateFreeSlots(free)
end

function Inventory:ScanBank()
    local me = self:Me()
    if not (me and self.bankOpen) then
        return
    end
    me.bank = Inventory.Count(Inventory.BankIDs())
    me.bankTime = now()
end

-- Combien de cet objet chaque personnage possède : { { key, name, bags, bank } }.
function Inventory:Owners(itemID)
    local list = {}
    for key, character in pairs(self.db.characters) do
        local bags, bank = (character.bags or {})[itemID] or 0, (character.bank or {})[itemID] or 0
        if bags + bank > 0 then
            list[#list + 1] = { key = key, name = character.name or key, bags = bags, bank = bank }
        end
    end
    table.sort(list, function(a, b) return a.key < b.key end)
    return list
end

---------------------------------------------------------------------------
-- Infobulle : compteurs
---------------------------------------------------------------------------

function Inventory:TooltipLines(itemID)
    local lines = {}
    local owners = self:Owners(itemID)
    local total = 0
    for _, owner in ipairs(owners) do
        local parts = {}
        if owner.bags > 0 then
            parts[#parts + 1] = L["bags %d"]:format(owner.bags)
        end
        if owner.bank > 0 then
            parts[#parts + 1] = L["bank %d"]:format(owner.bank)
        end
        lines[#lines + 1] = ("%s : %d (%s)"):format(owner.name, owner.bags + owner.bank, table.concat(parts, ", "))
        total = total + owner.bags + owner.bank
    end
    if #owners > 1 then
        lines[#lines + 1] = L["Total: %d"]:format(total)
    end
    return lines
end

function Inventory:HookTooltip()
    if self.tooltipHooked or not (TooltipDataProcessor and Enum and Enum.TooltipDataType) then
        return
    end
    self.tooltipHooked = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if not (self.enabled and self.db.tooltip and data and ns.Usable(data.id) and data.id) then
            return
        end
        for _, line in ipairs(self:TooltipLines(data.id)) do
            tooltip:AddLine(line, 0.6, 0.8, 1)
        end
    end)
end

---------------------------------------------------------------------------
-- Marques sur les boutons des sacs
---------------------------------------------------------------------------

local function markOf(button)
    local mark = marks[button]
    if not mark then
        mark = {}
        mark.upgrade = button:CreateTexture(nil, "OVERLAY", nil, 7)
        mark.upgrade:SetTexture(UPGRADE_TEXTURE)
        mark.upgrade:SetSize(14, 14)
        mark.upgrade:SetPoint("TOPRIGHT", -1, -1)
        mark.junk = button:CreateTexture(nil, "OVERLAY", nil, 7)
        mark.junk:SetTexture(JUNK_TEXTURE)
        mark.junk:SetSize(12, 12)
        mark.junk:SetPoint("BOTTOMLEFT", 2, 2)
        mark.level = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        mark.level:SetPoint("BOTTOMRIGHT", -2, 2)
        marks[button] = mark
    end
    return mark
end

-- Marques d'un emplacement : amélioration, camelote, niveau d'objet (texte ou nil).
function Inventory:MarksFor(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info then
        return false, false, nil
    end
    local link = info.hyperlink
    local upgrade, junk, level = false, false, nil
    local items = ns.Modules:Get("Items")
    if self.db.upgrades and items and items.enabled and link and ns.Score then
        upgrade = ns.Score.IsUpgrade(link, items.db.threshold) and true or false
    end
    local seller = ns.Modules:Get("Junk")
    if self.db.junk and seller and seller.enabled and info.quality == POOR and not info.hasNoValue then
        junk = not seller.db.keep[info.itemID]
    end
    if self.db.itemLevel and link and C_Item and C_Item.GetDetailedItemLevelInfo then
        local scored = ns.Score and ns.Score.Info(link)
        if scored then
            level = C_Item.GetDetailedItemLevelInfo(link)
        end
    end
    return upgrade, junk, level
end

function Inventory:UpdateButton(button)
    if not (button and button.GetID) then
        return
    end
    local bag = button.GetBagID and button:GetBagID() or (button:GetParent() and button:GetParent():GetID())
    local slot = button:GetID()
    local upgrade, junk, level = false, false, nil
    if self.enabled and type(bag) == "number" and type(slot) == "number" and slot >= 1 then
        upgrade, junk, level = self:MarksFor(bag, slot)
    end
    if upgrade or junk or level or marks[button] then
        local mark = markOf(button)
        mark.upgrade:SetShown(upgrade)
        mark.junk:SetShown(junk)
        mark.level:SetText(level and tostring(level) or "")
    end
end

local function updateFrame(self, frame)
    if frame.EnumerateValidItems then
        for _, button in frame:EnumerateValidItems() do
            self:UpdateButton(button)
        end
    else
        local name = frame.GetName and frame:GetName()
        for index = 1, frame.size or 0 do
            self:UpdateButton(name and _G[name .. "Item" .. index])
        end
    end
end

local function bagFrames()
    local list = { _G.ContainerFrameCombinedBags }
    for index = 1, MAX_BAG_FRAMES do
        list[#list + 1] = _G["ContainerFrame" .. index]
    end
    return list
end

function Inventory:HookBags()
    self.hookedFrames = self.hookedFrames or {}
    for _, frame in pairs(bagFrames()) do
        if frame and frame.UpdateItems and not self.hookedFrames[frame] then
            self.hookedFrames[frame] = true
            hooksecurefunc(frame, "UpdateItems", function(bagFrame)
                if self.enabled then
                    ns.SafeCall(updateFrame, self, bagFrame)
                end
            end)
        end
    end
    if not self.hookedLegacy and _G.ContainerFrame_Update then
        self.hookedLegacy = true
        hooksecurefunc("ContainerFrame_Update", function(frame)
            if self.enabled then
                ns.SafeCall(updateFrame, self, frame)
            end
        end)
    end
end

function Inventory:RefreshBags()
    for _, frame in pairs(bagFrames()) do
        if frame and frame.IsShown and frame:IsShown() then
            updateFrame(self, frame)
        end
    end
end

-- Places libres, sous les sacs combinés.
function Inventory:UpdateFreeSlots(free)
    local frame = _G.ContainerFrameCombinedBags
    if not (frame and frame.CreateFontString) then
        return
    end
    if not self.freeText then
        self.freeHolder = CreateFrame("Frame", nil, frame)
        self.freeHolder:SetAllPoints()
        self.freeText = self.freeHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.freeText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 10)
    end
    self.freeText:SetText(self.enabled and L["Free slots: %d"]:format(free) or "")
end

---------------------------------------------------------------------------
-- Fenêtre : sacs et banque de n'importe quel personnage
---------------------------------------------------------------------------

function Inventory:Characters()
    local list = {}
    for key in pairs(self.db.characters) do
        list[#list + 1] = key
    end
    table.sort(list)
    return list
end

local function itemDisplay(id)
    local name, icon, quality
    if C_Item and C_Item.GetItemInfo then
        local ok, n, _, q, _, _, _, _, _, _, i = pcall(C_Item.GetItemInfo, id)
        if ok then
            name, quality, icon = n, q, i
        end
    end
    if not name and C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, id)
    end
    return name or L["Item %d"]:format(id), icon or "Interface\\Icons\\INV_Misc_QuestionMark", quality
end

local QUALITY = {
    [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 },
}

-- Lignes de la fenêtre pour un personnage : sacs puis banque, filtrées par la recherche.
function Inventory:ViewRows(key, search)
    local character = self.db.characters[key]
    local rows = {}
    if not character then
        return rows
    end
    search = search and search ~= "" and search:lower() or nil
    local function section(title, counts, right)
        local ids = {}
        for id in pairs(counts or {}) do
            ids[#ids + 1] = id
        end
        local entries = {}
        for _, id in ipairs(ids) do
            local name, icon, quality = itemDisplay(id)
            if not search or name:lower():find(search, 1, true) then
                entries[#entries + 1] = { id = id, name = name, icon = icon, quality = quality }
            end
        end
        table.sort(entries, function(a, b) return a.name < b.name end)
        rows[#rows + 1] = { header = true, text = title, right = right }
        if #entries == 0 then
            rows[#rows + 1] = { text = L["Nothing here."], color = C.muted }
        end
        for _, entry in ipairs(entries) do
            rows[#rows + 1] = { text = entry.name, icon = entry.icon, right = "x" .. counts[entry.id],
                color = QUALITY[entry.quality or 1] or QUALITY[1], tooltip = "item:" .. entry.id }
        end
    end
    local money = character.money and ns.Modules:Get("Guide") and ns.Modules:Get("Guide").FormatMoney
    section(L["Bags"], character.bags, money and money(character.money) or nil)
    section(L["Bank"], character.bank, character.bankTime and L["seen %s"]:format(date and date("%d/%m %H:%M",
        character.bankTime) or "") or L["never visited"])
    return rows
end

function Inventory:CreateWindow()
    local frame = Style.Window("NextStepInventoryFrame", 420, 520, L["Bags and bank"])
    local character = Style.Button(frame, "", 240, 24, function()
        local list = self:Characters()
        local index = 1
        for i, key in ipairs(list) do
            if key == self.viewing then
                index = i % #list + 1
            end
        end
        self.viewing = list[index]
        self:UpdateWindow()
    end)
    character:SetPoint("TOPLEFT", 12, -46)
    frame.character = character
    local search = CreateFrame("EditBox", nil, frame)
    search:SetSize(140, 22)
    search:SetPoint("LEFT", character, "RIGHT", 8, 0)
    search:SetAutoFocus(false)
    search:SetFontObject("GameFontHighlight")
    search:SetTextInsets(6, 6, 0, 0)
    Style.Fill(search, C.track)
    Style.Border(search, C.goldDim)
    search:SetScript("OnTextChanged", function() self:UpdateWindow() end)
    search:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    frame.search = search
    local Guide = ns.Modules:Get("Guide")
    frame.list = Guide.RowList(frame, 396, 430)
    frame.list:SetPoint("TOPLEFT", 12, -78)
    frame:SetScript("OnShow", function() self:UpdateWindow() end)
    self.window = frame
    return frame
end

function Inventory:UpdateWindow()
    local frame = self.window
    if not (frame and frame:IsShown()) then
        return
    end
    self.viewing = self.viewing or self:Key() or self:Characters()[1]
    local character = self.viewing and self.db.characters[self.viewing]
    frame.character:SetLabel(character and (character.name or self.viewing) or L["No character yet"])
    frame.list:SetRows(self:ViewRows(self.viewing, frame.search:GetText()))
end

function Inventory:Toggle()
    local frame = self.window or self:CreateWindow()
    frame:SetShown(not frame:IsShown())
    self:UpdateWindow()
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function Inventory:OnInitialize()
    ns.Slash:Add("bank", function()
        if self.enabled then
            self:Toggle()
        else
            ns:Print(L["%s is disabled: enable it in the options."]:format(self.title))
        end
    end, L["Bags and bank of all your characters, from anywhere"])
end

function Inventory:OnEnable()
    self:HookBags()
    self:HookTooltip()
    self:RegisterEvent("ADDON_LOADED", function() self:HookBags() end)
    self:RegisterEvent("BAG_UPDATE_DELAYED", function()
        self:ScanBags()
        self:ScanBank()
        self:RefreshBags()
    end)
    self:RegisterEvent("PLAYER_MONEY", function()
        local me = self:Me()
        if me then
            me.money = GetMoney()
        end
    end)
    self:RegisterEvent("BANKFRAME_OPENED", function()
        self.bankOpen = true
        self:ScanBank()
    end)
    self:RegisterEvent("BANKFRAME_CLOSED", function()
        self:ScanBank()
        self.bankOpen = false
    end)
    self:RegisterEvent("PLAYERBANKSLOTS_CHANGED", function() self:ScanBank() end)
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function() self:RefreshBags() end)
    self:ScanBags()
end

function Inventory:OnDisable()
    self:RefreshBags()
    if self.freeText then
        self.freeText:SetText("")
    end
    if self.window then
        self.window:Hide()
    end
end

function Inventory:BuildOptions(panel, anchor)
    local Options = ns.Options
    local below = Options.AddCheck(panel, anchor, L["Mark upgrades in your bags"],
        function() return self.db.upgrades end,
        function(value) self.db.upgrades = value; self:RefreshBags() end)
    below = Options.AddCheck(panel, below, L["Mark junk in your bags"],
        function() return self.db.junk end,
        function(value) self.db.junk = value; self:RefreshBags() end)
    below = Options.AddCheck(panel, below, L["Show the item level of gear in your bags"],
        function() return self.db.itemLevel end,
        function(value) self.db.itemLevel = value; self:RefreshBags() end)
    return Options.AddCheck(panel, below, L["Count items of all your characters in tooltips"],
        function() return self.db.tooltip end,
        function(value) self.db.tooltip = value end)
end
