-- Noms appris : retient le nom des PNJ croisés, dans la langue du client, pour
-- traduire les guides là où les données importées n'ont pas de traduction.
-- Rien n'est envoyé : les noms restent dans les sauvegardes du compte.
--
-- Sources : cible, survol, nameplates, dialogue avec un PNJ ; et, à la demande,
-- l'infobulle d'un PNJ que le client a en mémoire. Jamais en combat : nom et GUID
-- peuvent y être des secret values.

local _, ns = ...
local L = ns.L

local Names = ns.Modules:New("Names", {
    title = L["Learned names"],
    description = L["Remembers the names of the NPCs you meet, in your game's language, to translate the guides. "
        .. "Nothing is sent anywhere."],
    defaults = { learned = {} },   -- [locale][genre][id] = nom
})

-- Événements qui désignent un PNJ, et l'unité à lire.
local UNIT_EVENTS = {
    PLAYER_TARGET_CHANGED = "target",
    UPDATE_MOUSEOVER_UNIT = "mouseover",
    GOSSIP_SHOW = "npc",
    QUEST_DETAIL = "npc",
    QUEST_GREETING = "npc",
    QUEST_PROGRESS = "npc",
    QUEST_COMPLETE = "npc",
    MERCHANT_SHOW = "npc",
    TRAINER_SHOW = "npc",
}

local function usable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

-- GUID d'un PNJ : Creature-0-<serveur>-<instance>-<zone>-<id du PNJ>-<apparition>.
local function npcID(guid)
    local unitType, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(id)
    end
end

local function validName(name)
    return usable(name) and type(name) == "string" and name ~= "" and name ~= UNKNOWNOBJECT
end

function Names:OnInitialize()
    local locale = ns.DB.locale
    self.db.learned[locale] = self.db.learned[locale] or {}
    self.names = self.db.learned[locale]
    self.tried = {}   -- PNJ déjà cherchés dans l'infobulle pendant la session
    -- Les noms appris servent même quand la collecte est désactivée.
    ns.DB:SetLearnedNames(self.names)
    ns.DB:SetResolver("npc", function(id)
        return self:Lookup(id)
    end)
end

function Names:OnEnable()
    -- En anglais, les noms importés sont complets : rien à apprendre.
    if ns.DB.locale == "enUS" then
        return
    end
    for event, unit in pairs(UNIT_EVENTS) do
        self:RegisterEvent(event, function()
            self:Learn(unit)
        end)
    end
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, _, unit)
        self:Learn(unit)
    end)
end

function Names:Remember(kind, id, name)
    local byKind = self.names[kind] or {}
    self.names[kind] = byKind
    byKind[id] = name
end

-- Lit le nom d'une unité et le retient si c'est un PNJ.
function Names:Learn(unit)
    if InCombatLockdown() or not unit then
        return
    end
    local guid = UnitGUID(unit)
    if not usable(guid) or type(guid) ~= "string" then
        return
    end
    local id = npcID(guid)
    if not id then
        return
    end
    local name = UnitName(unit)
    if validName(name) then
        self:Remember("npc", id, name)
    end
end

-- Nom d'un PNJ jamais croisé, si le client l'a en mémoire. [À vérifier] sur Forever.
function Names:Lookup(id)
    if ns.DB.locale == "enUS" or not self.enabled or self.tried[id] or InCombatLockdown() then
        return nil
    end
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then
        return nil
    end
    self.tried[id] = true
    local data = C_TooltipInfo.GetHyperlink(("unit:Creature-0-0-0-0-%d-0000000000"):format(id))
    local line = data and data.lines and data.lines[1]
    local name = line and line.leftText
    if validName(name) then
        self:Remember("npc", id, name)
        return name
    end
end

function Names:Count()
    local count = 0
    for _, byKind in pairs(self.names) do
        for _ in pairs(byKind) do
            count = count + 1
        end
    end
    return count
end

function Names:Clear()
    for kind in pairs(self.names) do
        self.names[kind] = nil
    end
    self.tried = {}
end

function Names:BuildOptions(panel, anchor)
    local count = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    count:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)

    local clear = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clear:SetSize(200, 22)
    clear:SetPoint("LEFT", count, "RIGHT", 12, 0)
    clear:SetText(L["Forget learned names"])

    local function refresh()
        count:SetText(L["Learned names: %d"]:format(self:Count()))
    end
    clear:SetScript("OnClick", function()
        self:Clear()
        refresh()
    end)
    panel:HookScript("OnShow", refresh)
    refresh()

    self.clearButton, self.countText = clear, count
    return count
end
