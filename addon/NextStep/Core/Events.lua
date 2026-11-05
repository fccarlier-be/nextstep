-- Répartition des événements du jeu et des messages internes.
-- Un seul cadre écoute le jeu ; chaque abonné est identifié par un « propriétaire »
-- (un module, en général), qui reçoit callback(owner, event, ...).

local _, ns = ...

local Events = {}
ns.Events = Events

local frame = CreateFrame("Frame")
local eventHandlers = {}    -- [event] = { [owner] = callback }
local messageHandlers = {}  -- [message] = { [owner] = callback }

local function dispatch(handlers, name, ...)
    local list = handlers[name]
    if not list then
        return
    end
    -- Copie : un abonné peut s'inscrire ou se désinscrire pendant l'envoi.
    local snapshot = {}
    for owner, callback in pairs(list) do
        snapshot[owner] = callback
    end
    for owner, callback in pairs(snapshot) do
        ns.SafeCall(callback, owner, name, ...)
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    dispatch(eventHandlers, event, ...)
end)

-- Vrai si le client connaît l'événement : les noms changent d'une version du jeu à
-- l'autre, et RegisterEvent lève une erreur sur un nom inconnu.
local function isValid(event)
    if C_EventUtils and C_EventUtils.IsEventValid then
        return C_EventUtils.IsEventValid(event)
    end
    return true
end

-- Événements refusés par le client, pour /ns debug : [event] = true.
Events.refused = {}

-- Renvoie false, sans erreur, si le client ne connaît pas l'événement.
function Events:Register(event, owner, callback)
    local list = eventHandlers[event]
    if not list then
        if not isValid(event) or not pcall(frame.RegisterEvent, frame, event) then
            self.refused[event] = true
            return false
        end
        list = {}
        eventHandlers[event] = list
    end
    list[owner] = callback
    return true
end

-- Vrai si le client envoie bien l'événement à NextStep.
function Events:IsListening(event)
    return frame:IsEventRegistered(event) == true
end

function Events:Unregister(event, owner)
    local list = eventHandlers[event]
    if not list then
        return
    end
    list[owner] = nil
    if next(list) == nil then
        eventHandlers[event] = nil
        frame:UnregisterEvent(event)
    end
end

function Events:RegisterMessage(message, owner, callback)
    messageHandlers[message] = messageHandlers[message] or {}
    messageHandlers[message][owner] = callback
end

function Events:UnregisterMessage(message, owner)
    local list = messageHandlers[message]
    if list then
        list[owner] = nil
    end
end

function Events:SendMessage(message, ...)
    dispatch(messageHandlers, message, ...)
end

function Events:UnregisterAll(owner)
    for event in pairs(eventHandlers) do
        self:Unregister(event, owner)
    end
    for message in pairs(messageHandlers) do
        self:UnregisterMessage(message, owner)
    end
end
