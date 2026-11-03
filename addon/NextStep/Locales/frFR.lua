local _, ns = ...

if GetLocale() ~= "frFR" then
    return
end

local L = ns.L

-- Core/Factions.lua
L["Could not load %s (%s)."] = "Impossible de charger %s (%s)."

-- Core/Modules.lua
L["%s is disabled because %s is loaded."] = "%s est désactivé car %s est chargé."

-- Core/Options.lua
L["Version %s"] = "Version %s"

-- Core/Slash.lua
L["Commands:"] = "Commandes :"
L["Show this help"] = "Affiche cette aide"
L["Show the version"] = "Affiche la version"
L["List modules"] = "Liste les modules"
L["Enable a module"] = "Active un module"
L["Disable a module"] = "Désactive un module"
L["Open the options"] = "Ouvre les options"
L["Unknown command: %s"] = "Commande inconnue : %s"
L["Usage: /ns %s <module>"] = "Utilisation : /ns %s <module>"
L["Unknown module: %s"] = "Module inconnu : %s"
L["No modules."] = "Aucun module."
L["%s: %s"] = "%s : %s"
L["enabled"] = "activé"
L["disabled"] = "désactivé"
L["blocked by %s"] = "bloqué par %s"
L["Module %s enabled."] = "Module %s activé."
L["Module %s disabled."] = "Module %s désactivé."

-- Modules/Names.lua
L["Learned names"] = "Noms appris"
L["Remembers the names of the NPCs you meet, in your game's language, to translate the guides. "
    .. "Nothing is sent anywhere."] =
    "Retient le nom des PNJ que vous croisez, dans la langue du jeu, pour traduire les guides. "
    .. "Rien n'est envoyé nulle part."
L["Forget learned names"] = "Oublier les noms appris"
L["Learned names: %d"] = "Noms appris : %d"

-- Modules/UI/MapReveal.lua
L["Map without fog"] = "Carte sans brouillard"
L["Shows the unexplored areas of the world map, dimmed."] =
    "Affiche les zones inexplorées de la carte du monde, en plus sombre."
L["Unexplored areas brightness: %d%%"] = "Luminosité des zones inexplorées : %d %%"

-- Modules/UI/Radar.lua
L["Farming radar"] = "Radar de récolte"
L["Shows the minimap, large and see-through, around your character, to spot herbs, "
    .. "ore and fish while gathering. Toggle it with /ns radar or a key (Key Bindings > NextStep)."] =
    "Affiche la minimap, en grand et en transparence, autour de votre personnage, pour repérer herbes, "
    .. "filons et poissons pendant la récolte. S'ouvre avec /ns radar ou une touche (Raccourcis > NextStep)."
L["Show or hide the farming radar"] = "Affiche ou cache le radar de récolte"
L["%s is disabled: enable it in the options."] = "%s est désactivé : activez-le dans les options."
L["The radar will change after combat."] = "Le radar changera après le combat."
L["Radar size: %d%% of the screen height"] = "Taille du radar : %d %% de la hauteur de l'écran"
L["Radar opacity: %d%%"] = "Opacité du radar : %d %%"
L["Show the terrain"] = "Afficher le terrain"
L["Rotate with the camera"] = "Tourner avec la caméra"
L["W"] = "O"

-- Modules/Guide/Guide.lua
L["Leveling guide"] = "Guide de leveling"
L["Step-by-step guide for your race, class and level, which accepts detours."] =
    "Guide pas à pas adapté à votre race, votre classe et votre niveau, qui accepte les détours."

-- Core/Storage.lua
L["Saved data comes from a newer version of NextStep: it was left untouched."] =
    "Les données sauvegardées viennent d'une version plus récente de NextStep : elles n'ont pas été modifiées."
