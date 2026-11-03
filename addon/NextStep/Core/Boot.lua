-- Démarrage, dernier fichier chargé :
--   ADDON_LOADED : sauvegardes disponibles → initialisation des modules et des options ;
--   PLAYER_LOGIN : personnage connu → données de faction, puis activation des modules.

local addonName, ns = ...

local Boot = {}

ns.Events:Register("ADDON_LOADED", Boot, function(_, _, loadedName)
    if loadedName ~= addonName then
        return
    end
    ns.Events:Unregister("ADDON_LOADED", Boot)
    ns.Storage:Init()
    ns.Modules:InitializeAll()
    ns.Options:Init()
end)

ns.Events:Register("PLAYER_LOGIN", Boot, function()
    ns.Events:Unregister("PLAYER_LOGIN", Boot)
    ns.Factions:Load()
    ns.Modules:EnableAll()
end)
