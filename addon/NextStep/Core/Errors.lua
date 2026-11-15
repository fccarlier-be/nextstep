-- Relevé des erreurs Lua de NextStep (docs/DESIGN.md, « Relevé des erreurs ») : le jeu
-- affiche les erreurs sans les garder. Chaque erreur venue d'un fichier de NextStep
-- (ou des addons de faction) est notée dans NextStepDB.errors, avec sa pile d'appels,
-- son nombre d'occurrences, la première et la dernière heure, et la version : /ns errors
-- les liste, et le fichier de sauvegarde permet de les lire hors du jeu.
--
-- Le gestionnaire d'erreurs du jeu est enveloppé (seterrorhandler), comme le fait
-- BugGrabber : le gestionnaire précédent reçoit toujours l'erreur, l'affichage du jeu
-- ne change pas. Les actions bloquées (ADDON_ACTION_BLOCKED, « Interface action
-- failed because of an AddOn ») sont notées aussi. Chargé juste après Core\Init.lua :
-- les erreurs de chargement des fichiers suivants sont gardées en mémoire jusqu'à ce
-- que les sauvegardes soient lues.

local _, ns = ...

local Errors = {}
ns.Errors = Errors

local MAX_ENTRIES = 50   -- erreurs différentes gardées (les plus récentes)
local MAX_STACK = 12     -- lignes de pile gardées par erreur

local pending = {}       -- erreurs survenues avant la lecture des sauvegardes
local saved              -- NextStepDB, une fois lue
local recording = false  -- garde contre une erreur dans le relevé lui-même

-- Une erreur vient-elle de NextStep ? Son texte ou sa pile cite un fichier de l'addon
-- ou de ses addons de faction (Interface/AddOns/NextStep/, NextStep_Alliance/...).
local function fromNextStep(text)
    return type(text) == "string" and text:find("AddOns[/\\]NextStep") ~= nil
end
Errors.FromNextStep = fromNextStep

local function now()
    return (time or os.time)()
end

local function trimStack(stack)
    if type(stack) ~= "string" then
        return nil
    end
    local lines = {}
    for line in stack:gmatch("[^\n]+") do
        lines[#lines + 1] = line
        if #lines >= MAX_STACK then
            break
        end
    end
    return table.concat(lines, "\n")
end

-- Liste des erreurs : celle des sauvegardes, ou la liste en attente avant leur lecture.
local function list()
    return saved and saved.errors or pending
end

-- Note une erreur (message, pile) : une erreur déjà vue gagne une occurrence.
function Errors.Record(message, stack, kind)
    message = tostring(message)
    local entries = list()
    local t = now()
    for index, entry in ipairs(entries) do
        if entry.message == message then
            entry.count = entry.count + 1
            entry.last = t
            entry.version = ns.version
            -- La plus récente en tête.
            table.remove(entries, index)
            table.insert(entries, 1, entry)
            return entry
        end
    end
    local entry = { message = message, stack = trimStack(stack), kind = kind, count = 1, first = t, last = t,
        version = ns.version }
    table.insert(entries, 1, entry)
    while #entries > MAX_ENTRIES do
        table.remove(entries)
    end
    return entry
end

-- Enveloppe du gestionnaire d'erreurs du jeu.
local previous
local function handler(message, ...)
    if not recording then
        recording = true
        pcall(function()
            local stack = debugstack and debugstack(3)
            if fromNextStep(message) or fromNextStep(stack) then
                Errors.Record(message, stack, "error")
            end
        end)
        recording = false
    end
    if previous then
        return previous(message, ...)
    end
end
Errors.Handler = handler

-- Installe l'enveloppe (sans effet si elle est déjà en place). Un addon chargé après
-- NextStep peut remplacer le gestionnaire : on se réinstalle à la connexion.
function Errors.Install()
    if not (seterrorhandler and geterrorhandler) then
        return false
    end
    local current = geterrorhandler()
    if current == handler then
        return true
    end
    previous = current
    seterrorhandler(handler)
    return true
end

-- Sauvegardes lues : les erreurs du chargement les rejoignent.
function Errors.Attach(db)
    db.errors = type(db.errors) == "table" and db.errors or {}
    saved = db
    local early = pending
    pending = {}
    for index = #early, 1, -1 do
        Errors.Record(early[index].message, early[index].stack, early[index].kind)
    end
end

function Errors.List()
    return list()
end

function Errors.Clear()
    if saved then
        saved.errors = {}
    end
    pending = {}
end

-- Action protégée refusée à NextStep (ADDON_ACTION_BLOCKED / FORBIDDEN).
function Errors.Blocked(event, addon, action)
    if type(addon) == "string" and addon:find("^NextStep") then
        Errors.Record(("%s: %s (%s)"):format(event, tostring(action), addon),
            debugstack and debugstack(2), "blocked")
    end
end

Errors.Install()

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("ADDON_ACTION_BLOCKED")
    frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_LOGIN" then
            Errors.Install()
        else
            Errors.Blocked(event, ...)
        end
    end)
end
