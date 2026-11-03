-- Point d'entrée : crée l'espace de noms partagé par tous les fichiers de l'addon.

local addonName, ns = ...

ns.name = addonName
-- Le TOC du dépôt porte @project-version@, remplacé par le numéro du tag à l'empaquetage
-- (voir docs/RELEASE.md) : non remplacé, c'est une version de développement.
local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
if not version or version:find("^@") then
    version = "dev"
end
ns.version = version

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

-- Valeur lisible : ni absente, ni secrète (en combat, certaines valeurs ne
-- supportent ni comparaison ni calcul ; voir docs/DESIGN.md, « Secret values »).
function ns.Usable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

-- Identifiant d'un PNJ d'après son GUID :
-- Creature-0-<serveur>-<instance>-<zone>-<id du PNJ>-<apparition>.
function ns.NpcID(guid)
    if not ns.Usable(guid) or type(guid) ~= "string" then
        return nil
    end
    local unitType, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(id)
    end
end
