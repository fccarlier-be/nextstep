-- Camelote (docs/DESIGN.md, « Camelote ») : à l'ouverture d'un marchand, les objets
-- gris des sacs sont vendus, sauf ceux de la liste d'exceptions, avec un résumé dans
-- le chat. Au plus douze par visite : le marchand garde les douze derniers objets
-- vendus en rachat, tout reste donc rachetable. Activé par défaut.
--
-- [À vérifier] sur Forever : C_Container.UseContainerItem vend bien chez un marchand ;
-- prix de vente dans C_Item.GetItemInfo (11e valeur).

local _, ns = ...
local L = ns.L

local Junk = ns.Modules:New("Junk", {
    title = L["Junk"],
    description = L["Sells grey items when you open a merchant (twelve at most, so you can buy them back), "
        .. "with a summary in the chat."],
    defaults = { keep = {} },   -- [identifiant d'objet] = true : jamais vendu
    conflicts = { "Scrap", "Peddler", "AutoVendor" },
})

local POOR = 0                  -- qualité des objets gris
local MAX_PER_VISIT = 12        -- taille de l'onglet Rachat du marchand
local BAG_FIRST, BAG_LAST = 0, 4

local function sellPrice(itemID)
    if not (C_Item and C_Item.GetItemInfo) then
        return 0
    end
    local price = select(11, C_Item.GetItemInfo(itemID))
    return tonumber(price) or 0
end

-- Objets gris à vendre : { bag, slot, itemID, count, price } (prix total de la pile).
function Junk:Items()
    local list = {}
    for bag = BAG_FIRST, BAG_LAST do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == POOR and not info.hasNoValue and info.itemID
                and not self.db.keep[info.itemID] then
                local count = info.stackCount or 1
                list[#list + 1] = {
                    bag = bag, slot = slot, itemID = info.itemID, count = count,
                    price = sellPrice(info.itemID) * count,
                }
            end
        end
    end
    return list
end

function Junk:Sell()
    local items = self:Items()
    local sold, total = 0, 0
    for index = 1, math.min(#items, MAX_PER_VISIT) do
        local item = items[index]
        C_Container.UseContainerItem(item.bag, item.slot)
        sold = sold + 1
        total = total + item.price
    end
    if sold > 0 then
        local money = ns.Modules:Get("Guide") and ns.Modules:Get("Guide").FormatMoney
        local text = money and money(total) or tostring(total)
        ns:Print(L["Junk sold: %d items for %s."]:format(sold, text))
    end
    if #items > MAX_PER_VISIT then
        ns:Print(L["%d more grey items: reopen the merchant to sell them."]:format(#items - MAX_PER_VISIT))
    end
    return sold, total
end

function Junk:OnEnable()
    self:RegisterEvent("MERCHANT_SHOW", function()
        -- Touche Maj enfoncée à l'ouverture : rien n'est vendu cette fois.
        if IsShiftKeyDown and IsShiftKeyDown() then
            return
        end
        self:Sell()
    end)
end

function Junk:OnInitialize()
    ns.Slash:Add("keep", function(input)
        self:ToggleKeep(input)
    end, L["Never sell this grey item: /ns keep <item link or id>"])
end

-- Exception : /ns keep [lien ou identifiant] ajoute ou retire un objet.
function Junk:ToggleKeep(input)
    local itemID = tonumber((input or ""):match("item:(%d+)") or (input or ""):match("^%s*(%d+)%s*$"))
    if not itemID then
        ns:Print(L["Usage: /ns keep <item link or id>"])
        return
    end
    if self.db.keep[itemID] then
        self.db.keep[itemID] = nil
        ns:Print(L["Item %d will be sold again."]:format(itemID))
    else
        self.db.keep[itemID] = true
        ns:Print(L["Item %d will never be sold."]:format(itemID))
    end
end

-- Options : exceptions (objets gris jamais vendus), ajoutées par /ns keep.
function Junk:BuildOptions(panel, anchor)
    local function count()
        local total = 0
        for _ in pairs(self.db.keep) do
            total = total + 1
        end
        return total
    end
    local button = ns.Options.AddButton(panel, L["Clear the exceptions (%d)"]:format(count()), 260, function(frame)
        self.db.keep = {}
        frame:SetLabel(L["Clear the exceptions (%d)"]:format(0))
        ns:Print(L["Every grey item will be sold again."])
    end)
    button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
    panel:HookScript("OnShow", function()
        button:SetLabel(L["Clear the exceptions (%d)"]:format(count()))
    end)
    return button
end
