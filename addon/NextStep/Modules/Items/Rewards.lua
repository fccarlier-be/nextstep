-- Récompenses de quête (docs/DESIGN.md, « 7. Items ») : quand le PNJ présente une quête
-- ou sa récompense, NextStep indique quel choix prendre et pourquoi, dans un encart
-- doré à côté de la fenêtre de quête, et encadre l'objet conseillé. Jamais choisi
-- automatiquement : le joueur clique lui-même.
--
--   amélioration : celle qui gagne le plus pour la spécialisation ;
--   sinon       : celle qui se vend le plus cher (prix de vente × quantité).
--
-- Sans souillure : l'encart et le cadre sont des cadres de NextStep, enfants
-- d'UIParent et seulement ancrés à ceux du client ; aucun Show/Hide sur un cadre de
-- Blizzard.
--
-- [À vérifier] sur Forever : noms des boutons de récompense
-- (QuestInfoRewardsFrameQuestInfoItem<n>, choix d'abord) ; GetQuestItemLink.

local _, ns = ...
local L = ns.L
local Score = ns.Score

local Items = ns.Modules:Get("Items")
local Style = ns.Style

local REWARD_BUTTON = "QuestInfoRewardsFrameQuestInfoItem%d"

-- Classe les choix. choices[i] = { link, count } ; -> pick, raison, détail
--   raison "upgrade" : détail = résultat de Score.Compare
--   raison "sell"    : détail = prix de vente total (cuivre)
-- Égalités : le plus gros score, puis le premier choix.
function Items:RankChoices(choices)
    local best, bestDelta, bestScore
    for index, choice in ipairs(choices) do
        local up, delta = Score.IsUpgrade(choice.link, self.db.threshold)
        if up then
            local result = Score.Compare(choice.link)
            if not best or delta > bestDelta or (delta == bestDelta and result.score > bestScore) then
                best, bestDelta, bestScore = index, delta, result.score
            end
        end
    end
    if best then
        return best, "upgrade", Score.Compare(choices[best].link)
    end
    local richest, price = nil, -1
    for index, choice in ipairs(choices) do
        local _, _, _, _, _, sellPrice = Score.Client.ItemInfo(choice.link)
        local total = (tonumber(sellPrice) or 0) * (choice.count or 1)
        if total > price then
            richest, price = index, total
        end
    end
    if richest and price > 0 then
        return richest, "sell", price
    end
end

-- Choix proposés par le PNJ : { link, count, name, icon }.
local function questChoices()
    local list = {}
    if not (GetNumQuestChoices and GetQuestItemLink) then
        return list
    end
    for index = 1, GetNumQuestChoices() or 0 do
        local link = GetQuestItemLink("choice", index)
        local name, icon, count
        if GetQuestItemInfo then
            name, icon, count = GetQuestItemInfo("choice", index)
        end
        if ns.Usable(link) then
            list[#list + 1] = { link = link, count = tonumber(count) or 1, name = name, icon = icon }
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Encart
---------------------------------------------------------------------------

function Items:CreateRewardPanel()
    local panel = CreateFrame("Frame", "NextStepRewardAdvice", UIParent)
    panel:SetSize(230, 74)
    panel:SetFrameStrata("HIGH")
    panel:Hide()
    Style.Fill(panel, Style.COLORS.background)
    Style.Border(panel, Style.COLORS.goldDim)
    local title = Style.Text(panel, "GameFontNormal", Style.COLORS.gold)
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText(L["NextStep: reward"])
    panel.icon = Style.Icon(panel, 28)
    panel.icon:SetPoint("TOPLEFT", 10, -28)
    panel.name = Style.Text(panel, "GameFontHighlight")
    panel.name:SetPoint("TOPLEFT", panel.icon, "TOPRIGHT", 8, 0)
    panel.name:SetPoint("RIGHT", -10, 0)
    panel.reason = Style.Text(panel, "GameFontHighlightSmall", Style.COLORS.muted)
    panel.reason:SetPoint("TOPLEFT", panel.name, "BOTTOMLEFT", 0, -3)
    panel.reason:SetPoint("RIGHT", -10, 0)

    -- Cadre doré posé sur le bouton de la récompense conseillée.
    local mark = CreateFrame("Frame", nil, UIParent)
    mark:SetFrameStrata("HIGH")
    mark:Hide()
    Style.Border(mark, Style.COLORS.gold)
    panel.mark = mark
    self.rewardPanel = panel
    return panel
end

-- Texte de la raison, d'après RankChoices.
function Items:RewardReason(reason, detail)
    if reason == "upgrade" then
        local spec = Items.SpecName((Score.Spec()))
        if detail.empty then
            return L["Upgrade for %s: empty slot"]:format(spec)
        end
        return L["Upgrade for %s: %s"]:format(spec, Items.GainText(detail.pct or 0))
    end
    local money = ns.Modules:Get("Guide") and ns.Modules:Get("Guide").FormatMoney
    return L["No upgrade: sells best (%s)"]:format(money and money(detail) or tostring(detail))
end

function Items:ShowRewardAdvice()
    if not (self.enabled and self.db.rewards) or not (QuestFrame and QuestFrame:IsShown()) then
        self:HideRewardAdvice()
        return
    end
    local choices = questChoices()
    local pick, reason, detail
    if #choices > 0 then
        pick, reason, detail = self:RankChoices(choices)
    end
    if not pick then
        self:HideRewardAdvice()
        return
    end
    local panel = self.rewardPanel or self:CreateRewardPanel()
    local choice = choices[pick]
    panel.icon:SetTexture(choice.icon)
    panel.name:SetText(choice.name or choice.link)
    panel.reason:SetText(self:RewardReason(reason, detail))
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", QuestFrame, "TOPRIGHT", 4, -40)
    panel:Show()
    self.rewardPick, self.rewardReason = pick, reason

    local button = _G[REWARD_BUTTON:format(pick)]
    if button and button.IsShown and button:IsShown() and (button.type == nil or button.type == "choice") then
        panel.mark:ClearAllPoints()
        panel.mark:SetAllPoints(button)
        panel.mark:Show()
    else
        panel.mark:Hide()
    end
end

function Items:HideRewardAdvice()
    if self.rewardPanel then
        self.rewardPanel:Hide()
        self.rewardPanel.mark:Hide()
    end
    self.rewardPick, self.rewardReason = nil, nil
end

function Items:RefreshRewards()
    if self.rewardPanel and self.rewardPanel:IsShown() then
        self:ShowRewardAdvice()
    end
end

-- Le client remplit les boutons pendant l'événement : l'encart suit, un instant après.
local function later(fn)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, fn)
    else
        fn()
    end
end

function Items:EnableRewards()
    for _, event in ipairs({ "QUEST_DETAIL", "QUEST_COMPLETE" }) do
        self:RegisterEvent(event, function()
            later(function()
                ns.SafeCall(self.ShowRewardAdvice, self)
            end)
        end)
    end
    self:RegisterEvent("QUEST_FINISHED", "HideRewardAdvice")
end

function Items:DisableRewards()
    self:HideRewardAdvice()
end
