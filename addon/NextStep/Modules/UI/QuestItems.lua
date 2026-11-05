-- Objets de quête dans les sacs (docs/DESIGN.md, « Sacs et banque », marques) :
-- chaque objet utile à une quête du journal porte une marque dorée dans les sacs,
-- et son infobulle nomme la quête.
--
-- Un objet est « de quête » quand le client le dit (C_Container.GetContainerItemQuestInfo,
-- pour une quête du journal) ou quand le guide suivi le demande pour une quête du
-- journal (objectifs « ramasser »). La liste est refaite à chaque mise à jour du
-- journal et du guide.
--
-- [À vérifier] sur Forever : boutons des sacs (ContainerFrameCombinedBags et
-- ContainerFrameN, UpdateItems, EnumerateValidItems, GetBagID) ; GetContainerItemQuestInfo ;
-- TooltipDataProcessor.

local _, ns = ...
local L = ns.L

local QuestItems = ns.Modules:New("QuestItems", {
    title = L["Quest items"],
    description = L["Marks the items in your bags that a quest in your log needs, and names the quest "
        .. "in their tooltip."],
    defaults = {},
})

local MARK_TEXTURE = "Interface\\AddOns\\NextStep\\Media\\Pin"
local MARK_SIZE = 12
local MARK_COLOR = { 1, 0.82, 0 }
local MAX_BAG_FRAMES = 13

local marks = setmetatable({}, { __mode = "k" })   -- [bouton d'objet] = texture de la marque

---------------------------------------------------------------------------
-- Objets demandés par les quêtes du journal
---------------------------------------------------------------------------

local function questName(q)
    local name = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(q)
    return name or ns.DB:GetName("quest", q) or ("#" .. q)
end

-- [objet] = quête, d'après le guide suivi : objectifs « ramasser » des quêtes du journal.
function QuestItems:GuideItems()
    local items = {}
    local guideModule = ns.Modules:Get("Guide")
    local guide = guideModule and guideModule.enabled and guideModule:ActiveGuide()
    local state = guideModule and guideModule.state
    if not (guide and state) then
        return items
    end
    for _, step in ipairs(guide.steps or {}) do
        for _, goal in ipairs(step.goals or {}) do
            if goal.t == "collect" and goal.item and goal.quest and not items[goal.item]
                and state:InLog(goal.quest) then
                items[goal.item] = goal.quest
            end
        end
    end
    return items
end

function QuestItems:Rebuild()
    self.items = self:GuideItems()
    self:RefreshBags()
end

-- Vrai pour un vrai emplacement de sac : d'autres boutons d'objets (rachat chez le
-- marchand, banque...) ressemblent aux boutons des sacs sans en avoir le numéro.
local function bagSlot(bag, slot)
    return type(bag) == "number" and type(slot) == "number" and slot >= 1
end
QuestItems.IsBagSlot = bagSlot

-- Quête qui demande l'objet de cet emplacement (nil sinon).
function QuestItems:QuestFor(bag, slot, itemID)
    if not bagSlot(bag, slot) then
        return nil
    end
    if C_Container.GetContainerItemQuestInfo then
        local info = C_Container.GetContainerItemQuestInfo(bag, slot)
        if info and info.isQuestItem then
            local q = info.questID
            if not q or C_QuestLog.GetLogIndexForQuestID == nil or C_QuestLog.GetLogIndexForQuestID(q) then
                return q or true
            end
        end
    end
    return itemID and (self.items or {})[itemID] or nil
end

---------------------------------------------------------------------------
-- Boutons des sacs
---------------------------------------------------------------------------

local function markOf(button)
    local mark = marks[button]
    if not mark then
        mark = button:CreateTexture(nil, "OVERLAY", nil, 7)
        mark:SetTexture(MARK_TEXTURE)
        mark:SetSize(MARK_SIZE, MARK_SIZE)
        mark:SetPoint("TOPLEFT", 2, -2)
        mark:SetVertexColor(MARK_COLOR[1], MARK_COLOR[2], MARK_COLOR[3])
        marks[button] = mark
    end
    return mark
end

function QuestItems:UpdateButton(button)
    if not (button and button.GetID) then
        return
    end
    local bag = button.GetBagID and button:GetBagID() or (button:GetParent() and button:GetParent():GetID())
    local slot = button:GetID()
    local quest
    if self.enabled and bagSlot(bag, slot) then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then
            quest = self:QuestFor(bag, slot, info.itemID)
        end
    end
    if quest then
        markOf(button):Show()
    elseif marks[button] then
        marks[button]:Hide()
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

function QuestItems:HookBags()
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
    -- Sacs à l'ancienne (un cadre par sac, mis à jour par ContainerFrame_Update).
    if not self.hookedLegacy and _G.ContainerFrame_Update then
        self.hookedLegacy = true
        hooksecurefunc("ContainerFrame_Update", function(frame)
            if self.enabled then
                ns.SafeCall(updateFrame, self, frame)
            end
        end)
    end
end

function QuestItems:RefreshBags()
    for _, frame in pairs(bagFrames()) do
        if frame and frame.IsShown and frame:IsShown() then
            updateFrame(self, frame)
        end
    end
end

---------------------------------------------------------------------------
-- Infobulle
---------------------------------------------------------------------------

-- Ligne ajoutée à l'infobulle d'un objet de quête porté (objet et emplacement connus).
function QuestItems:TooltipLine(bag, slot, itemID)
    local quest = self:QuestFor(bag, slot, itemID)
    if not quest then
        return nil
    end
    if quest == true then
        return L["Quest item"]
    end
    return L["Quest item: %s"]:format(questName(quest))
end

function QuestItems:HookTooltip()
    if self.tooltipHooked or not (TooltipDataProcessor and Enum and Enum.TooltipDataType) then
        return
    end
    self.tooltipHooked = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if not self.enabled or not (data and data.id) then
            return
        end
        -- Seulement pour les objets des sacs : le bouton survolé donne l'emplacement.
        local owner = tooltip.GetOwner and tooltip:GetOwner()
        if not (owner and owner.GetID and owner.GetBagID) then
            return
        end
        local line = self:TooltipLine(owner:GetBagID(), owner:GetID(), data.id)
        if line then
            tooltip:AddLine(line, MARK_COLOR[1], MARK_COLOR[2], MARK_COLOR[3])
        end
    end)
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function QuestItems:OnEnable()
    self:HookBags()
    self:HookTooltip()
    self:RegisterEvent("QUEST_LOG_UPDATE", "Rebuild")
    self:RegisterEvent("BAG_UPDATE_DELAYED", "RefreshBags")
    self:RegisterEvent("ADDON_LOADED", function()
        self:HookBags()
    end)
    self:RegisterMessage("NEXTSTEP_GUIDE_UPDATED", "Rebuild")
    self:Rebuild()
end

function QuestItems:OnDisable()
    for _, mark in pairs(marks) do
        mark:Hide()
    end
end
