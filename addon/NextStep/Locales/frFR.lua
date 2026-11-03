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

-- Modules/Guide/Labels.lua
L["Accept %s"] = "Accepter %s"
L["Turn in %s"] = "Rendre %s"
L["Complete %s"] = "Terminer %s"
L["Kill %s"] = "Tuer %s"
L["Collect %s"] = "Ramasser %s"
L["Buy %s"] = "Acheter %s"
L["Use %s"] = "Utiliser %s"
L["Talk to %s"] = "Parler à %s"
L["Visit %s (vendor)"] = "Aller voir %s (marchand)"
L["Visit a vendor"] = "Passer chez un marchand"
L["Go to %s"] = "Aller à %s"
L["Explore %s"] = "Explorer %s"
L["Enter %s"] = "Entrer dans %s"
L["Fly to %s"] = "Voler jusqu'à %s"
L["Hearth to %s"] = "Pierre de foyer vers %s"
L["Make %s your home"] = "Lier votre pierre de foyer à %s"
L["Get the flight path of %s"] = "Prendre le point de vol de %s"
L["Reach level %d"] = "Atteindre le niveau %d"
L["Visit your class trainer"] = "Aller voir votre maître de classe"
L["Train %s"] = "Apprendre %s"
L["Visit the trainer"] = "Aller voir le maître"
L["Learn %s"] = "Apprendre %s"
L["Cast %s"] = "Lancer %s"
L["Craft %s"] = "Fabriquer %s"
L["Reach %d in %s"] = "Atteindre %d en %s"
L["Reach %s with %s"] = "Atteindre %s auprès de %s"
L["Have %d gold"] = "Avoir %d po"
L["Die (shortcut, not used)"] = "Mourir (raccourci, non utilisé)"

-- Modules/Guide/Window.lua
L["Skip"] = "Ignorer"
L["Done"] = "Valider"
L["Strict"] = "Strict"
L["Free"] = "Libre"
L["requires level %d"] = "niveau %d requis"
L["not available yet"] = "pas encore disponible"
L["(optional) %s"] = "(facultatif) %s"
L["Click to mark it as done."] = "Cliquez pour le valider."
L["Along the way:"] = "En chemin :"
L["Abandoned quest: %s. Click to take it again."] = "Quête abandonnée : %s. Cliquez pour la reprendre."
L["Next: %s"] = "Ensuite : %s"
L["Detours: %d quests off the route"] = "Détours : %d quêtes hors route"
L["Quests in your log that this guide does not use."] =
    "Quêtes de votre journal que ce guide n'utilise pas."
L["You are above the level of this guide."] = "Vous avez dépassé le niveau de ce guide."
L["No guide followed."] = "Aucun guide suivi."
L["Reading the quest log..."] = "Lecture du journal de quêtes…"
L["No leveling guide for your level."] = "Aucun guide de leveling pour votre niveau."
L["Start: %s"] = "Commencer : %s"
L["Guide complete!"] = "Guide terminé !"
L["Continue: %s"] = "Continuer : %s"
L["Group quest: %s. Do it?"] = "Quête de groupe : %s. La faire ?"
L["Yes"] = "Oui"
L["No, skip it"] = "Non, la passer"

-- Modules/Guide/Arrow.lua
L["%d yd"] = "%d m"

-- Modules/Guide/Live.lua
L["Show or hide the guide window"] = "Affiche ou cache la fenêtre du guide"
L["Show or hide the arrow"] = "Affiche ou cache la flèche"
L["Mark the current step as done"] = "Valide l'étape en cours"
L["Guides for your character:"] = "Guides pour votre personnage :"
L["Unknown guide: %s"] = "Guide inconnu : %s"
L["Progress of the guide reset."] = "Progression du guide remise à zéro."
L["Usage: /ns guide [list | start <number or id> | stop | reset | skip | done | mode]"] =
    "Utilisation : /ns guide [list | start <numéro ou identifiant> | stop | reset | skip | done | mode]"
L["Show or hide the guide; /ns guide list, start, stop, reset, skip, done, mode"] =
    "Affiche ou cache le guide ; /ns guide list, start, stop, reset, skip, done, mode"
L["Show the arrow"] = "Afficher la flèche"
L["Hide the Blizzard quest tracker while following a guide"] =
    "Masquer le suivi de quêtes de Blizzard pendant un guide"
L["Lock the guide window"] = "Verrouiller la fenêtre du guide"
