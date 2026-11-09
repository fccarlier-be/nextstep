-- Munitions du chasseur (docs/DESIGN.md, « Munitions ») : quand les flèches ou les balles
-- de l'arme à distance passent sous un seuil, un encart s'affiche au milieu de l'écran
-- avec le vendeur le plus proche ; un clic y pointe la flèche du guide.
--
--   arc et arbalète : flèches ; fusil : balles (autres armes : rien) ;
--   une alerte quand le stock passe sous le seuil, une autre quand il est vide ; elle
--   revient après que le stock est repassé au-dessus du seuil ;
--   jamais en combat : l'alerte attend la fin du combat ;
--   vendeurs : ceux de Data/Imported/Polestar/AmmoVendors.lua, présumés sur leur titre,
--   corrigés par ce que l'addon apprend à chaque ouverture d'un marchand (db.vendors,
--   commun aux personnages).

local _, ns = ...
local L = ns.L
local Style = ns.Style
local Navigation = ns.Navigation

local Ammo = ns.Modules:New("Ammo", {
    title = L["Hunter ammunition"],
    description = L["Alerts you in the middle of the screen when your arrows or bullets run low, "
        .. "with the nearest vendor that sells them."],
    defaults = {
        threshold = 200,      -- alerte sous ce nombre de munitions
        alertDuration = 30,   -- secondes avant la fermeture de l'alerte (0 : jamais)
        vendors = {},         -- [PNJ] = vendeur vu en jeu (voir Ammo:Learn)
    },
})

local ALERT_SOUND = 8959   -- SOUNDKIT.RAID_WARNING
local RANGED_SLOT = 18
local PROJECTILE = 6       -- classe d'objet des munitions
local WEAPON = 2
-- Sous-classe d'arme -> munitions ; munitions -> sous-classe de projectile.
local WEAPON_AMMO = { [2] = "a", [18] = "a", [3] = "b" }
local PROJECTILE_KIND = { [2] = "a", [3] = "b" }

-- Munitions vendues, de la meilleure à la plus simple : niveau requis, flèche, balle.
local TIERS = {
    { 40, 11285, 11284 },
    { 25, 3030, 3033 },
    { 10, 2515, 2519 },
    { 1, 2512, 2516 },
}
-- Noms de secours, si le client n'a pas encore l'objet en mémoire.
local TIER_NAMES = {
    [11285] = L["Jagged Arrow"], [11284] = L["Accurate Slugs"],
    [3030] = L["Razor Arrow"], [3033] = L["Solid Shot"],
    [2515] = L["Sharp Arrow"], [2519] = L["Heavy Shot"],
    [2512] = L["Rough Arrow"], [2516] = L["Light Shot"],
}
local ICONS = {
    a = "Interface\\Icons\\INV_Ammo_Arrow_02",
    b = "Interface\\Icons\\INV_Ammo_Bullet_02",
}

local FACTION_CODE = { Alliance = "A", Horde = "H" }

---------------------------------------------------------------------------
-- Arme et stock
---------------------------------------------------------------------------

local function itemClass(item)
    local info = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not (item and info) then
        return nil
    end
    local _, _, _, _, _, classID, subclassID = info(item)
    return classID, subclassID
end
Ammo.ItemClass = itemClass

-- Munitions de l'arme à distance portée : "a" (flèches), "b" (balles) ou nil.
function Ammo.Kind()
    local item = GetInventoryItemID and GetInventoryItemID("player", RANGED_SLOT)
    if not ns.Usable(item) then
        return nil
    end
    local classID, subclassID = itemClass(item)
    if classID == WEAPON then
        return WEAPON_AMMO[subclassID]
    end
end

-- Nombre de munitions d'un type dans les sacs (carquois compris), et l'une d'elles.
function Ammo.Count(kind)
    local total, sample = 0, nil
    if not (kind and C_Container and C_Container.GetContainerNumSlots) then
        return 0
    end
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local classID, subclassID = itemClass(info.itemID)
                if classID == PROJECTILE and PROJECTILE_KIND[subclassID] == kind then
                    total = total + (info.stackCount or 1)
                    sample = sample or info.itemID
                end
            end
        end
    end
    return total, sample
end

local function itemName(item)
    local name = GetItemInfo and GetItemInfo(item)
    if ns.Usable(name) and name ~= "" then
        return name
    end
    return TIER_NAMES[item] or ("item:" .. item)
end

-- Meilleure munition vendue utilisable à ce niveau : objet, nom.
function Ammo.Recommended(kind, level)
    for _, tier in ipairs(TIERS) do
        if (level or 1) >= tier[1] then
            local item = kind == "b" and tier[3] or tier[2]
            return item, itemName(item)
        end
    end
end

---------------------------------------------------------------------------
-- Vendeurs
---------------------------------------------------------------------------

-- Vendeurs importés : [PNJ] = { kinds, faction, instance, north, west, map, x, y, name }.
local imported
function Ammo.Imported()
    if imported then
        return imported
    end
    imported = {}
    for npc, line in pairs(ns.DB.ammoVendors or {}) do
        local data, name = line:match("^([^|]*)|?(.*)$")
        local kinds, faction, instance, north, west, map, x, y =
            data:match("^(%a+) (%a) (%-?%d+) (%S+) (%S+) (%d+) (%S+) (%S+)$")
        if kinds then
            imported[npc] = {
                npc = npc, kinds = kinds, faction = faction, instance = tonumber(instance),
                north = tonumber(north), west = tonumber(west), map = tonumber(map),
                x = tonumber(x), y = tonumber(y), name = name ~= "" and name or nil,
            }
        end
    end
    return imported
end

local function sells(kinds, kind)
    return kinds ~= nil and kinds:find(kind, 1, true) ~= nil
end

-- Nom d'un vendeur : traduit si connu, sinon celui vu en jeu ou le nom anglais.
local function vendorName(vendor)
    local translated = ns.DB.GetName and ns.DB:GetName("npc", vendor.npc)
    if translated and translated ~= "" then
        return translated
    end
    return vendor.name or ("#" .. vendor.npc)
end
Ammo.VendorName = vendorName

-- Vendeurs qui vendent (ou vendraient) ce type de munitions à ce personnage :
-- { npc, name, instance, north, west, map, x, y, confirmed }.
function Ammo:Vendors(kind)
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    local code = FACTION_CODE[faction]
    local learned = self.db.vendors
    local list = {}
    for npc, vendor in pairs(Ammo.Imported()) do
        local seen = learned[npc]
        local ok
        if seen then
            ok = seen[kind] == true
        else
            ok = sells(vendor.kinds, kind) and (vendor.faction == "N" or vendor.faction == code)
        end
        if ok and (not seen or not seen.faction or seen.faction == faction) then
            list[#list + 1] = {
                npc = npc, name = vendor.name, instance = vendor.instance, north = vendor.north,
                west = vendor.west, map = vendor.map, x = vendor.x, y = vendor.y, confirmed = seen ~= nil,
            }
        end
    end
    -- Vendeurs vus en jeu que l'import ne connaît pas.
    for npc, seen in pairs(learned) do
        if not imported[npc] and seen[kind] and (not seen.faction or seen.faction == faction) then
            list[#list + 1] = {
                npc = npc, name = seen.name, instance = seen.instance, north = seen.north, west = seen.west,
                map = seen.map, x = seen.x, y = seen.y, confirmed = true,
            }
        end
    end
    return list
end

-- Vendeur le plus proche sur le continent du joueur, et sa distance en yards.
function Ammo:Nearest(kind)
    local instance, north, west = Navigation.PlayerPosition()
    if not instance then
        return nil
    end
    local best, bestDistance
    for _, vendor in ipairs(self:Vendors(kind)) do
        if vendor.instance == instance and vendor.north and vendor.west then
            local dn, dw = vendor.north - north, vendor.west - west
            local distance = math.sqrt(dn * dn + dw * dw)
            if not bestDistance or distance < bestDistance then
                best, bestDistance = vendor, distance
            end
        end
    end
    return best, bestDistance
end

-- Marchand ouvert : retient s'il vend des flèches, des balles, et où il se trouve.
function Ammo:Learn()
    local guid = UnitGUID and UnitGUID("npc")
    if not ns.Usable(guid) then
        return
    end
    local npc = tonumber(tostring(guid):match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    if not npc then
        return
    end
    local found = {}
    for i = 1, (GetMerchantNumItems and GetMerchantNumItems()) or 0 do
        local item = GetMerchantItemID and GetMerchantItemID(i)
        if not ns.Usable(item) then
            local link = GetMerchantItemLink and GetMerchantItemLink(i)
            item = ns.Usable(link) and tonumber(tostring(link):match("item:(%d+)")) or nil
        end
        if item then
            local classID, subclassID = itemClass(item)
            local kind = classID == PROJECTILE and PROJECTILE_KIND[subclassID]
            if kind then
                found[kind] = true
            end
        end
    end
    -- Un marchand sans munitions n'est retenu que s'il était présumé en vendre.
    if not (found.a or found.b or Ammo.Imported()[npc]) then
        return
    end
    local entry = { a = found.a == true, b = found.b == true }
    entry.faction = UnitFactionGroup and UnitFactionGroup("player")
    local name = UnitName and UnitName("npc")
    entry.name = ns.Usable(name) and name or nil
    local instance, north, west = Navigation.PlayerPosition()
    if instance then
        entry.instance, entry.north, entry.west = instance, north, west
    end
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        local map = C_Map.GetBestMapForUnit("player")
        local position = ns.Usable(map) and C_Map.GetPlayerMapPosition(map, "player")
        if position then
            local x, y = position:GetXY()
            if ns.Usable(x) and ns.Usable(y) then
                entry.map, entry.x, entry.y = map, math.floor(x * 1000 + 0.5) / 10, math.floor(y * 1000 + 0.5) / 10
            end
        end
    end
    self.db.vendors[npc] = entry
    -- Le chasseur est chez un vendeur de ses munitions : l'alerte a fait son office.
    local kind = Ammo.Kind()
    if kind and entry[kind] then
        self:HideAlert()
    end
end

---------------------------------------------------------------------------
-- Surveillance
---------------------------------------------------------------------------

local function isHunter()
    local _, class = UnitClass("player")
    return class == "HUNTER"
end

-- Niveau d'alerte : 0 assez, 1 bas, 2 vide.
function Ammo:Stage(count)
    if count <= 0 then
        return 2
    elseif count < self.db.threshold then
        return 1
    end
    return 0
end

function Ammo:Check()
    if not (self.enabled and isHunter()) then
        return
    end
    local kind = Ammo.Kind()
    if not kind then
        return
    end
    local count = Ammo.Count(kind)
    local stage = self:Stage(count)
    if stage == 0 then
        self.warned = 0
        self:HideAlert()
        return
    end
    if stage <= (self.warned or 0) then
        return
    end
    -- En combat : on attend sa fin.
    if InCombatLockdown and InCombatLockdown() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "Check")
        return
    end
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self.warned = stage
    self:ShowAlert(kind, count)
end

-- Textes de l'alerte : titre, vendeur, conseil d'achat ; et le vendeur pointable.
function Ammo:AlertTexts(kind, count)
    local what = kind == "b" and L["bullets"] or L["arrows"]
    local title
    if count <= 0 then
        title = kind == "b" and L["Out of bullets!"] or L["Out of arrows!"]
    else
        title = L["Low on ammunition: %d %s left"]:format(count, what)
    end
    local vendor, distance = self:Nearest(kind)
    local where
    if vendor then
        local zone = vendor.map and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(vendor.map)
        local zoneName = zone and ns.Usable(zone.name) and zone.name or nil
        local yards = L["%d yd"]:format(distance)
        local place = zoneName and ("%s, %s"):format(zoneName, yards) or yards
        where = L["Nearest vendor: %s (%s)"]:format(vendorName(vendor), place)
        if not vendor.confirmed then
            where = where .. " " .. L["(not checked yet)"]
        end
    else
        where = L["No known ammunition vendor nearby."]
    end
    local _, name = Ammo.Recommended(kind, UnitLevel and UnitLevel("player"))
    local buy = name and L["Buy: %s"]:format(name) or nil
    return title, where, buy, vendor
end

---------------------------------------------------------------------------
-- Encart
---------------------------------------------------------------------------

function Ammo:CreateAlert()
    local frame = CreateFrame("Button", "NextStepAmmoAlert", UIParent)
    frame:SetSize(440, 92)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    Style.Frame(frame, Style.COLORS.orange or Style.COLORS.gold)
    frame.icon = Style.Icon(frame, 40)
    frame.icon:SetPoint("LEFT", 14, 0)
    frame.title = Style.Text(frame, "GameFontNormalLarge", Style.COLORS.gold)
    frame.title:SetPoint("TOPLEFT", 64, -12)
    frame.title:SetPoint("RIGHT", -12, 0)
    frame.vendor = Style.Text(frame, "GameFontHighlight", Style.COLORS.text)
    frame.vendor:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -6)
    frame.vendor:SetPoint("RIGHT", -12, 0)
    frame.buy = Style.Text(frame, "GameFontHighlightSmall", Style.COLORS.muted)
    frame.buy:SetPoint("TOPLEFT", frame.vendor, "BOTTOMLEFT", 0, -4)
    frame.buy:SetPoint("RIGHT", -12, 0)
    frame.hint = Style.Text(frame, "GameFontDisableSmall", Style.COLORS.muted, "RIGHT")
    frame.hint:SetPoint("BOTTOMRIGHT", -10, 8)
    frame:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            self:PointToVendor()
        end
        self:HideAlert()
    end)
    frame:Hide()
    self.alert = frame
    return frame
end

function Ammo:ShowAlert(kind, count)
    local frame = self.alert or self:CreateAlert()
    local title, where, buy, vendor = self:AlertTexts(kind, count)
    self.alertVendor = vendor
    local _, sample = Ammo.Count(kind)
    local icon = sample and GetItemIcon and GetItemIcon(sample)
    if frame.icon.SetTexture then
        frame.icon:SetTexture(ns.Usable(icon) and icon or ICONS[kind])
    end
    frame.title:SetText(title)
    frame.vendor:SetText(where)
    frame.buy:SetText(buy or "")
    frame.hint:SetText(vendor and L["click: arrow to the vendor - right-click: close"] or L["right-click: close"])
    frame:Show()
    if PlaySound then
        PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or ALERT_SOUND)
    end
    ns:Print(("%s. %s"):format(title, where))
    self.alertToken = (self.alertToken or 0) + 1
    local token = self.alertToken
    if self.db.alertDuration > 0 and C_Timer and C_Timer.After then
        C_Timer.After(self.db.alertDuration, function()
            if self.alertToken == token then
                self:HideAlert()
            end
        end)
    end
end

function Ammo:HideAlert()
    if self.alert then
        self.alert:Hide()
    end
end

-- Pointe la flèche du guide sur le vendeur de l'alerte.
function Ammo:PointToVendor()
    local vendor = self.alertVendor
    if not (vendor and vendor.map and vendor.x and vendor.y) then
        return false
    end
    local guide = ns.Modules:Get("Guide")
    local label = L["Ammunition: %s"]:format(vendorName(vendor))
    if guide and guide.enabled and guide.PointTo then
        guide:PointTo({ map = vendor.map, x = vendor.x, y = vendor.y }, label)
    else
        ns:Print(("%s (%.1f, %.1f)"):format(label, vendor.x, vendor.y))
    end
    return true
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function Ammo:OnEnable()
    self.warned = 0
    self:RegisterEvent("BAG_UPDATE_DELAYED", "Check")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "Check")
    self:RegisterEvent("MERCHANT_SHOW", "Learn")
    -- À la connexion, le temps que les sacs soient lus.
    if C_Timer and C_Timer.After then
        C_Timer.After(5, function()
            self:Check()
        end)
    end
end

function Ammo:OnDisable()
    self:HideAlert()
end

-- /ns ammo : état des munitions et vendeur le plus proche, alerte affichée.
function Ammo:Report()
    if not isHunter() then
        ns:Print(L["Ammunition alerts are for hunters."])
        return
    end
    local kind = Ammo.Kind()
    if not kind then
        ns:Print(L["No bow, crossbow or gun equipped."])
        return
    end
    self:ShowAlert(kind, (Ammo.Count(kind)))
end

function Ammo:OnInitialize()
    ns.Slash:Add("ammo", function()
        self:Report()
    end, L["Ammunition left and nearest vendor"])
end

function Ammo:BuildOptions(panel, anchor)
    local Options = ns.Options
    local below = Options.AddSlider(panel, anchor, 50, 1000, 50,
        function(value) return L["Alert below %d arrows or bullets"]:format(value) end,
        function() return self.db.threshold end,
        function(value)
            self.db.threshold = value
            self.warned = 0
            self:Check()
        end)
    below = Options.AddSlider(panel, below, 0, 60, 5,
        function(value)
            return value == 0 and L["The alert stays until closed"]
                or L["The alert closes after %d seconds"]:format(value)
        end,
        function() return self.db.alertDuration end,
        function(value) self.db.alertDuration = value end)
    local button = Options.AddButton(panel, L["Test the alert"], 160, function()
        Ammo:Report()
    end)
    button:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -12)
    return button
end
