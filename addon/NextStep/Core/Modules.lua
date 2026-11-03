-- Registre des modules. Chaque module peut être activé ou désactivé dans les
-- options, et se met de côté si un addon concurrent est chargé.
--
--   local Guide = ns.Modules:New("Guide", {
--       title = L["Guide"],
--       defaults = { ... },        -- réglages du compte (module.db)
--       charDefaults = { ... },    -- données du personnage (module.char)
--       defaultEnabled = true,
--       conflicts = { "Bagnon" },  -- addons qui empêchent l'activation
--   })
--   function Guide:OnInitialize() end  -- après le chargement des sauvegardes
--   function Guide:OnEnable() end      -- à la connexion, ou à l'activation
--   function Guide:OnDisable() end

local _, ns = ...
local L = ns.L

local Modules = {}
ns.Modules = Modules

local registry, order = {}, {}

local Module = {}
Module.__index = Module

function Modules:New(name, options)
    assert(not registry[name], "NextStep: module already registered: " .. name)
    local module = setmetatable(options or {}, Module)
    module.name = name
    module.enabled = false
    registry[name] = module
    order[#order + 1] = name
    return module
end

function Modules:Get(name)
    return registry[name]
end

-- Parcourt les modules dans leur ordre d'enregistrement.
function Modules:Iterate()
    local index = 0
    return function()
        index = index + 1
        local name = order[index]
        if name then
            return name, registry[name]
        end
    end
end

local function conflictingAddOn(module)
    for _, addon in ipairs(module.conflicts or {}) do
        if C_AddOns.IsAddOnLoaded(addon) then
            return addon
        end
    end
end

function Modules:InitializeAll()
    for name, module in self:Iterate() do
        local defaults = { enabled = module.defaultEnabled ~= false }
        ns.Storage.ApplyDefaults(defaults, module.defaults or {})
        module.db = ns.Storage:ModuleSettings(name, defaults)
        module.char = ns.Storage:ModuleCharData(name, module.charDefaults)
        if module.OnInitialize then
            ns.SafeCall(module.OnInitialize, module)
        end
    end
end

function Modules:Enable(module)
    if module.enabled then
        return true
    end
    local conflict = conflictingAddOn(module)
    if conflict then
        module.blockedBy = conflict
        ns:Print(L["%s is disabled because %s is loaded."]:format(module.title or module.name, conflict))
        return false
    end
    module.enabled = true
    if module.OnEnable then
        ns.SafeCall(module.OnEnable, module)
    end
    return true
end

function Modules:Disable(module)
    if not module.enabled then
        return
    end
    module.enabled = false
    if module.OnDisable then
        ns.SafeCall(module.OnDisable, module)
    end
    ns.Events:UnregisterAll(module)
end

function Modules:EnableAll()
    for _, module in self:Iterate() do
        if module.db.enabled then
            self:Enable(module)
        end
    end
end

-- Change l'état d'un module et le mémorise. Renvoie false si le module est inconnu
-- ou n'a pas pu être activé.
function Modules:SetEnabled(name, enabled)
    local module = registry[name]
    if not module then
        return false
    end
    module.db.enabled = enabled
    if enabled then
        return self:Enable(module)
    end
    self:Disable(module)
    return true
end

-- Raccourcis d'abonnement : tout est désinscrit quand le module est désactivé.
-- handler est une fonction ou le nom d'une méthode du module (par défaut, le nom
-- de l'événement) ; il reçoit (module, event, ...).

local function resolve(handler)
    if type(handler) == "function" then
        return handler
    end
    return function(self, ...)
        return self[handler](self, ...)
    end
end

function Module:RegisterEvent(event, handler)
    ns.Events:Register(event, self, resolve(handler or event))
end

function Module:UnregisterEvent(event)
    ns.Events:Unregister(event, self)
end

function Module:RegisterMessage(message, handler)
    ns.Events:RegisterMessage(message, self, resolve(handler or message))
end

function Module:UnregisterMessage(message)
    ns.Events:UnregisterMessage(message, self)
end

function Module:SendMessage(message, ...)
    ns.Events:SendMessage(message, ...)
end
