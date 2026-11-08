-- Fenêtres déplaçables (docs/DESIGN.md, « Fenêtres déplaçables ») : les fenêtres de
-- Blizzard (personnage, grimoire, journal de quêtes, marchands, maîtres...) se
-- déplacent en les faisant glisser ; leur position est retenue et rendue à chaque
-- ouverture ; Alt + clic droit remet une fenêtre à sa place d'origine. Code propre à
-- NextStep (BlizzMove est « All Rights Reserved »).
--
-- Sans souillure : seulement des fonctions du client (SetMovable, RegisterForDrag,
-- StartMoving, SetPoint), jamais Show ni Hide, jamais la table UIPanelWindows ni
-- d'attribut sécurisé ; les cadres protégés ne bougent pas en combat. Un clic sur une
-- fenêtre la passe au premier plan (Raise). Plusieurs fenêtres de Blizzard ouvertes
-- ensemble demanderaient de retirer les fenêtres de la table UIPanelWindows, ce qui
-- souille l'interface (erreurs « action bloquée ») : écarté.
--
-- [À vérifier] sur Forever : position rendue après le placement par UIParent
-- (UpdateUIPanelPositions) ; fenêtres chargées à la demande.

local _, ns = ...
local L = ns.L

local Windows = ns.Modules:New("Windows", {
    title = L["Movable windows"],
    description = L["Drag Blizzard windows (character, spellbook, quest log, merchants, trainers...) to "
        .. "move them; their position is remembered. Alt + right-click puts one back in its place."],
    defaults = { points = {} },   -- [nom du cadre] = { point, point relatif, x, y }
})

-- Fenêtres prises en charge : toujours chargées, puis chargées à la demande
-- ([addon de Blizzard] = { cadres }).
local FRAMES = {
    "CharacterFrame", "SpellBookFrame", "FriendsFrame", "GossipFrame", "QuestFrame", "QuestLogFrame",
    "MerchantFrame", "MailFrame", "BankFrame", "DressUpFrame", "TaxiFrame", "PetStableFrame",
    "TabardFrame", "GuildRegistrarFrame", "ItemTextFrame", "LootFrame", "TradeFrame",
}
local ON_DEMAND = {
    Blizzard_TalentUI = { "PlayerTalentFrame", "TalentFrame" },
    Blizzard_PlayerSpells = { "PlayerSpellsFrame" },
    Blizzard_TrainerUI = { "ClassTrainerFrame" },
    Blizzard_TradeSkillUI = { "TradeSkillFrame" },
    Blizzard_Professions = { "ProfessionsFrame" },
    Blizzard_AuctionHouseUI = { "AuctionHouseFrame" },
    Blizzard_AuctionUI = { "AuctionFrame" },
    Blizzard_InspectUI = { "InspectFrame" },
    Blizzard_MacroUI = { "MacroFrame" },
    Blizzard_EncounterJournal = { "EncounterJournal" },
    Blizzard_Collections = { "CollectionsJournal" },
    Blizzard_AchievementUI = { "AchievementFrame" },
}

local function blocked(frame)
    return InCombatLockdown and InCombatLockdown() and frame:IsProtected()
end

function Windows:OnInitialize()
    self.managed = {}   -- [cadre] = nom
end

-- Remet la fenêtre à la position retenue (après le placement par Blizzard).
function Windows:Restore(frame)
    local name = self.managed[frame]
    local point = name and self.db.points[name]
    if not (self.enabled and point) or blocked(frame) then
        return
    end
    frame:ClearAllPoints()
    frame:SetPoint(point[1], UIParent, point[2], point[3], point[4])
end

function Windows:Save(frame)
    local name = self.managed[frame]
    local point, _, relative, x, y = frame:GetPoint(1)
    if name and point then
        self.db.points[name] = { point, relative, math.floor(x + 0.5), math.floor(y + 0.5) }
    end
end

-- Rend une fenêtre déplaçable (une seule fois : les accroches ne se retirent pas,
-- elles ne font rien quand le module est désactivé).
function Windows:Manage(name)
    local frame = _G[name]
    if not (frame and frame.SetMovable and frame.HookScript) or self.managed[frame] then
        return
    end
    if blocked(frame) then
        return
    end
    self.managed[frame] = name
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    if frame.RegisterForDrag then
        frame:RegisterForDrag("LeftButton")
    end
    frame:HookScript("OnDragStart", function(window)
        if self.enabled and not blocked(window) then
            window:StartMoving()
        end
    end)
    frame:HookScript("OnDragStop", function(window)
        if self.enabled then
            window:StopMovingOrSizing()
            self:Save(window)
        end
    end)
    -- Clic : la fenêtre passe devant les autres de sa strate.
    frame:HookScript("OnMouseDown", function(window)
        if self.enabled and window.Raise and not blocked(window) then
            window:Raise()
        end
    end)
    frame:HookScript("OnMouseUp", function(window, button)
        if self.enabled and button == "RightButton" and IsAltKeyDown and IsAltKeyDown() then
            self.db.points[self.managed[window]] = nil
            ns:Print(L["%s will open in its usual place."]:format(self.managed[window]))
        end
    end)
    frame:HookScript("OnShow", function(window)
        self:Restore(window)
    end)
    if frame:IsShown() then
        self:Restore(frame)
    end
end

function Windows:ManageAll()
    for _, name in ipairs(FRAMES) do
        self:Manage(name)
    end
    for addon, names in pairs(ON_DEMAND) do
        if C_AddOns.IsAddOnLoaded(addon) then
            for _, name in ipairs(names) do
                self:Manage(name)
            end
        end
    end
end

function Windows:OnEnable()
    self:ManageAll()
    self:RegisterEvent("ADDON_LOADED", function(_, _, addon)
        for _, name in ipairs(ON_DEMAND[addon] or {}) do
            self:Manage(name)
        end
    end)
    -- Blizzard replace ses fenêtres à chaque ouverture ou fermeture d'une autre :
    -- la position retenue est rendue juste après.
    if not self.panelsHooked and UpdateUIPanelPositions then
        self.panelsHooked = true
        hooksecurefunc("UpdateUIPanelPositions", function()
            if self.enabled then
                for frame in pairs(self.managed) do
                    if frame:IsShown() then
                        self:Restore(frame)
                    end
                end
            end
        end)
    end
end

function Windows:Reset()
    self.db.points = {}
    ns:Print(L["Windows will open in their usual place."])
end

function Windows:BuildOptions(panel, anchor)
    local reset = ns.Options.AddButton(panel, L["Reset window positions"], 220, function()
        self:Reset()
    end)
    reset:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
    return reset
end
