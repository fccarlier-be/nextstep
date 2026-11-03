-- Point d'entrée : crée l'espace de noms partagé par tous les fichiers de l'addon.

local addonName, ns = ...

ns.name = addonName
ns.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "dev"

-- Seule variable globale de l'addon : utile aux addons de faction et au débogage (/dump NextStep).
_G.NextStep = ns

local PREFIX = "|cffffd100NextStep|r "

function ns:Print(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring((select(i, ...)))
    end
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. table.concat(parts, " "))
end

-- Appelle fn en confiant toute erreur au gestionnaire d'erreurs du jeu,
-- pour qu'un module défaillant n'empêche pas les autres de fonctionner.
-- Lua 5.1 : xpcall ne transmet pas d'arguments, d'où la fermeture.
function ns.SafeCall(fn, ...)
    local count, args = select("#", ...), { ... }
    return xpcall(function()
        return fn(unpack(args, 1, count))
    end, geterrorhandler())
end
