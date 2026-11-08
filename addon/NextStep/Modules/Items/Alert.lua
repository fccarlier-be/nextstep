-- Alerte d'amélioration (docs/DESIGN.md, « 7. Items ») : quand un objet qui améliore
-- l'équipement arrive dans les sacs (butin, récompense, achat) ou devient portable
-- (montée de niveau), un encart doré s'affiche un peu au-dessus du centre de l'écran.
--
--   jamais en combat : les objets attendent la fin du combat ;
--   groupée : plusieurs objets dans le même encart (cinq au plus) ;
--   seuil : gain minimal réglable (db.threshold) ;
--   clic gauche sur un objet : l'équipe (hors combat) ; clic droit : ferme ;
--   fermeture automatique après db.alertDuration secondes (0 : jamais) ;
--   déplaçable, position retenue.
--
-- Un objet n'est signalé qu'une fois par personnage (char.alerted, par lien).

local _, ns = ...
local L = ns.L
local Score = ns.Score

local Items = ns.Modules:Get("Items")
local Style = ns.Style

local MAX_ROWS = 5
local ROW_HEIGHT = 30
local ALERTED_CAP = 300

---------------------------------------------------------------------------
-- Détection
---------------------------------------------------------------------------

-- Améliorations des sacs pas encore signalées : { link, delta, pct, empty, slot }.
function Items:NewUpgrades()
    local found = {}
    local alerted = self.char.alerted
    for bag = 0, 4 do
        for slot = 1, Score.Client.BagSlots(bag) do
            local link = Score.Client.BagLink(bag, slot)
            if link and not alerted[link] then
                local up, delta, pct = Score.IsUpgrade(link, self.db.threshold)
                if up then
                    local result = Score.Compare(link)
                    found[#found + 1] = { link = link, delta = delta, pct = pct, empty = result.empty,
                        info = result.info }
                end
            end
        end
    end
    table.sort(found, function(a, b)
        return a.delta > b.delta
    end)
    return found
end

function Items:ScanBags()
    if not (self.enabled and self.db.alert) then
        return
    end
    local found = self:NewUpgrades()
    if #found == 0 then
        return
    end
    local count = 0
    for _ in pairs(self.char.alerted) do
        count = count + 1
    end
    if count + #found > ALERTED_CAP then
        self.char.alerted = {}
    end
    self.pending = self.pending or {}
    for _, item in ipairs(found) do
        self.char.alerted[item.link] = true
        self.pending[#self.pending + 1] = item
    end
    self:FlushAlert()
end

-- Affiche ce qui attend, hors combat.
function Items:FlushAlert()
    if not (self.pending and #self.pending > 0) then
        return
    end
    -- En combat : on attend sa fin (l'événement n'est écouté que le temps d'attendre).
    if InCombatLockdown and InCombatLockdown() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "FlushAlert")
        return
    end
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if not (self.enabled and self.db.alert) then
        self.pending = nil
        return
    end
    local items = {}
    -- Encart déjà ouvert : les nouveaux objets s'ajoutent à ceux qu'il montre.
    for _, item in ipairs(self.alertItems or {}) do
        items[#items + 1] = item
    end
    for _, item in ipairs(self.pending) do
        items[#items + 1] = item
    end
    self.pending = nil
    self:ShowAlert(items)
end

---------------------------------------------------------------------------
-- Encart
---------------------------------------------------------------------------

local function savePosition(frame, db)
    local point, _, relative, x, y = frame:GetPoint(1)
    if point then
        db.alertPoint = { point, relative, x, y }
    end
end

function Items:PlaceAlert()
    local frame = self.alert
    frame:ClearAllPoints()
    local saved = self.db.alertPoint
    if saved then
        frame:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
    end
end

function Items:CreateAlert()
    local frame = CreateFrame("Frame", "NextStepUpgradeAlert", UIParent)
    frame:SetSize(280, 40)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        savePosition(frame, self.db)
    end)
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            self:HideAlert()
        end
    end)
    frame:Hide()
    Style.Fill(frame, Style.COLORS.background)
    Style.Border(frame, Style.COLORS.gold)
    local title = Style.Text(frame, "GameFontNormal", Style.COLORS.gold)
    title:SetPoint("TOPLEFT", 10, -8)
    frame.title = title
    local hint = Style.Text(frame, "GameFontDisableSmall", Style.COLORS.muted, "RIGHT")
    hint:SetPoint("TOPRIGHT", -10, -9)
    hint:SetText(L["right-click: close"])

    frame.rows = {}
    for index = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, frame)
        row:SetHeight(ROW_HEIGHT - 2)
        row:SetPoint("TOPLEFT", 8, -26 - (index - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", -8, 0)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row.bg = Style.Fill(row, Style.COLORS.card)
        row.icon = Style.Icon(row, 24)
        row.icon:SetPoint("LEFT", 3, 0)
        row.name = Style.Text(row, "GameFontHighlight")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.name:SetPoint("RIGHT", -60, 0)
        row.gain = Style.Text(row, "GameFontNormal", Style.COLORS.green, "RIGHT")
        row.gain:SetPoint("RIGHT", -6, 0)
        row:SetScript("OnClick", function(button, mouse)
            if mouse == "RightButton" then
                self:HideAlert()
            elseif button.item then
                self:EquipFromAlert(button.item)
            end
        end)
        row:SetScript("OnEnter", function(button)
            button.bg:SetVertexColor(unpack(Style.COLORS.cardHover))
            if button.item and GameTooltip then
                GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(button.item.link)
                GameTooltip:AddLine(L["Click: equip"], 1, 0.82, 0)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function(button)
            button.bg:SetVertexColor(unpack(Style.COLORS.card))
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)
        frame.rows[index] = row
    end
    self.alert = frame
    self:PlaceAlert()
    return frame
end

function Items:ShowAlert(items)
    local frame = self.alert or self:CreateAlert()
    self.alertItems = items
    local shown = math.min(#items, MAX_ROWS)
    frame.title:SetText(shown > 1 and L["Upgrades in your bags"] or L["Upgrade in your bags"])
    for index, row in ipairs(frame.rows) do
        local item = items[index]
        row.item = item
        if item then
            local info = item.info or {}
            row.icon:SetTexture(info.icon)
            row.name:SetText(info.name or item.link)
            row.gain:SetText(item.empty and L["new"] or Items.GainText(item.pct or 0))
            row:Show()
        else
            row:Hide()
        end
    end
    frame:SetHeight(32 + shown * ROW_HEIGHT)
    frame:Show()
    self.alertShownAt = (self.alertShownAt or 0) + 1
    local token = self.alertShownAt
    local duration = tonumber(self.db.alertDuration) or 0
    if duration > 0 and C_Timer and C_Timer.After then
        C_Timer.After(duration, function()
            if self.alertShownAt == token then
                self:HideAlert()
            end
        end)
    end
end

function Items:HideAlert()
    if self.alert then
        self.alert:Hide()
    end
    self.alertItems = nil
end

-- Équipe l'objet (hors combat) et le retire de l'encart.
function Items:EquipFromAlert(item)
    if InCombatLockdown and InCombatLockdown() then
        ns:Print(L["Not in combat."])
        return
    end
    local equip = C_Item and C_Item.EquipItemByName or EquipItemByName
    if equip then
        equip(item.link)
    end
    local rest = {}
    for _, other in ipairs(self.alertItems or {}) do
        if other ~= item then
            rest[#rest + 1] = other
        end
    end
    if #rest > 0 then
        self:ShowAlert(rest)
    else
        self:HideAlert()
    end
end
