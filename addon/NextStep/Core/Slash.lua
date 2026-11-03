-- Commandes /ns et /nextstep. Les modules ajoutent leurs propres commandes
-- avec ns.Slash:Add(name, handler, help) ; handler reçoit le reste de la ligne.

local _, ns = ...
local L = ns.L

local Slash = {}
ns.Slash = Slash

local commands, order = {}, {}

function Slash:Add(name, handler, help)
    if not commands[name] then
        order[#order + 1] = name
    end
    commands[name] = { handler = handler, help = help }
end

function Slash:PrintHelp()
    ns:Print(L["Commands:"])
    for _, name in ipairs(order) do
        DEFAULT_CHAT_FRAME:AddMessage(("  /ns %s - %s"):format(name, commands[name].help))
    end
end

function Slash:Run(input)
    local name, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    name = name:lower()
    if name == "" then
        self:PrintHelp()
        return
    end
    local command = commands[name]
    if not command then
        ns:Print(L["Unknown command: %s"]:format(name))
        self:PrintHelp()
        return
    end
    command.handler(rest)
end

local function moduleState(module)
    if module.blockedBy then
        return L["blocked by %s"]:format(module.blockedBy)
    end
    return module.enabled and L["enabled"] or L["disabled"]
end

local function setModule(commandName, enabled, message)
    return function(moduleName)
        if moduleName == "" then
            ns:Print(L["Usage: /ns %s <module>"]:format(commandName))
            return
        end
        if not ns.Modules:Get(moduleName) then
            ns:Print(L["Unknown module: %s"]:format(moduleName))
            return
        end
        if ns.Modules:SetEnabled(moduleName, enabled) then
            ns:Print(message:format(moduleName))
        end
    end
end

Slash:Add("help", function()
    Slash:PrintHelp()
end, L["Show this help"])

Slash:Add("version", function()
    ns:Print(L["Version %s"]:format(ns.version))
end, L["Show the version"])

Slash:Add("modules", function()
    local any = false
    for name, module in ns.Modules:Iterate() do
        any = true
        DEFAULT_CHAT_FRAME:AddMessage("  " .. L["%s: %s"]:format(name, moduleState(module)))
    end
    if not any then
        ns:Print(L["No modules."])
    end
end, L["List modules"])

Slash:Add("enable", setModule("enable", true, L["Module %s enabled."]), L["Enable a module"])
Slash:Add("disable", setModule("disable", false, L["Module %s disabled."]), L["Disable a module"])

Slash:Add("options", function()
    ns.Options:Open()
end, L["Open the options"])

SLASH_NEXTSTEP1 = "/ns"
SLASH_NEXTSTEP2 = "/nextstep"
SlashCmdList.NEXTSTEP = function(input)
    Slash:Run(input)
end
