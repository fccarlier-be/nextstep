-- Annonce au groupe (docs/DESIGN.md, « Annonce au groupe ») : quand une quête du
-- journal passe à « prête à rendre » (tous ses objectifs remplis), un message part dans
-- le chat du groupe (ou du raid) : « {étoile} NextStep : [Quête] est prête à rendre ».
-- En option (activée par défaut), chaque objectif rempli d'une quête pas encore prête
-- est annoncé aussi : « {étoile} NextStep : [Quête] - Guerrier tué : 8/8 ». Quand le
-- dernier objectif rend la quête prête, seul « prête à rendre » part.
--
-- Seul le passage d'inachevée à prête est annoncé : rien à la connexion ni au /reload
-- (le premier relevé du journal sert de référence), rien pour une quête déjà prête au
-- moment où on l'accepte. Hors groupe, rien n'est envoyé. Activé par défaut.
--
-- [À vérifier] sur Forever : GetQuestLink(questID) ; « {rt1} » affiché en étoile.

local _, ns = ...
local L = ns.L

local QuestAnnounce = ns.Modules:New("QuestAnnounce", {
    title = L["Group announcements"],
    description = L["Tells your group in the chat when one of your quests is ready to turn in."],
    defaults = { objectives = true },
})

local STAR = "{rt1}"

-- Objectifs d'une quête : { [index] = { finished, text } } (vide si le client n'en dit rien).
local function readObjectives(questID)
    local list = {}
    local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID)
    for index, objective in ipairs(objectives or {}) do
        list[index] = { finished = objective.finished == true, text = objective.text }
    end
    return list
end

-- [quête] = { complete, title, objectives } pour le journal actuel.
local function readLog()
    local log = {}
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID and info.questID > 0 then
            log[info.questID] = {
                complete = C_QuestLog.IsComplete(info.questID) == true,
                title = info.title,
                objectives = readObjectives(info.questID),
            }
        end
    end
    return log
end

local function groupChannel()
    if not (IsInGroup and IsInGroup()) then
        return nil
    end
    return (IsInRaid and IsInRaid()) and "RAID" or "PARTY"
end

local function questLink(questID, title)
    local link = GetQuestLink and GetQuestLink(questID)
    if type(link) == "string" and link ~= "" then
        return link
    end
    return ("[%s]"):format(title or ("#" .. questID))
end

-- Compare le journal au relevé précédent et annonce les quêtes devenues prêtes.
-- Renvoie la liste des quêtes annoncées (tests).
function QuestAnnounce:Scan()
    local log = readLog()
    local previous = self.log
    self.log = log
    local announced = {}
    if not previous then
        return announced
    end
    local channel = groupChannel()
    local function send(text)
        if channel then
            SendChatMessage(("%s %s"):format(STAR, text), channel)
        end
    end
    for questID, entry in pairs(log) do
        local before = previous[questID]
        if before then
            local link = questLink(questID, entry.title)
            if entry.complete and not before.complete then
                send(L["NextStep: %s is ready to turn in"]:format(link))
                announced[#announced + 1] = questID
            elseif not entry.complete and self.db.objectives ~= false then
                for index, objective in ipairs(entry.objectives) do
                    local old = before.objectives[index]
                    if objective.finished and old and not old.finished and objective.text then
                        send(L["NextStep: %s - %s"]:format(link, objective.text))
                        announced[#announced + 1] = questID .. ":" .. index
                    end
                end
            end
        end
    end
    return announced
end

function QuestAnnounce:OnEnable()
    self.log = nil
    self:RegisterEvent("QUEST_LOG_UPDATE", function()
        self:Scan()
    end)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        -- Après un écran de chargement, repartir d'un relevé neuf.
        self.log = nil
        self:Scan()
    end)
end

function QuestAnnounce:OnDisable()
    self.log = nil
end

function QuestAnnounce:BuildOptions(panel, anchor)
    return ns.Options.AddCheck(panel, anchor, L["Also announce each finished objective"],
        function() return self.db.objectives ~= false end,
        function(value) self.db.objectives = value end)
end
