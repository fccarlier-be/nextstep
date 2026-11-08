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
L["on: %s"] = "sur : %s"
L["in: %s"] = "dans : %s"
L["%s, for: %s"] = "%s, pour : %s"
L["Accept %s from %s"] = "Accepter %s auprès de %s"
L["Accept %s (object: %s)"] = "Accepter %s (objet : %s)"
L["Accept %s (item: %s)"] = "Accepter %s (objet du sac : %s)"
L["Turn in %s to %s"] = "Rendre %s à %s"
L["Turn in %s (object: %s)"] = "Rendre %s (objet : %s)"
L["Turn in %s (item: %s)"] = "Rendre %s (objet du sac : %s)"
L["elite"] = "élite"
L["group of %d"] = "groupe de %d"
L["group"] = "groupe"
L["dungeon: %s"] = "donjon : %s"
L["dungeon"] = "donjon"
L["raid"] = "raid"
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
L["Show debugging information"] = "Affiche des informations de débogage"
L["Mark the current step as done"] = "Valide l'étape en cours"
L["Guides for your character:"] = "Guides pour votre personnage :"
L["Unknown guide: %s"] = "Guide inconnu : %s"
L["Progress of the guide reset."] = "Progression du guide remise à zéro."
L["Usage: /ns guide [list | start <number or id> | stop | reset | skip | done | mode]"] =
    "Utilisation : /ns guide [list | start <numéro ou identifiant> | stop | reset | skip | done | mode]"
L["Show or hide the guide; /ns guide list, start, stop, reset, skip, done, mode"] =
    "Affiche ou cache le guide ; /ns guide list, start, stop, reset, skip, done, mode"
L["Show the arrow"] = "Afficher la flèche"
L["Class quest: %s"] = "Quête de classe : %s"
L["Here too (planned later in the guide):"] = "Ici aussi (prévu plus loin dans le guide) :"
L["Bags almost full: %d free slots."] = "Sacs presque pleins : %d places libres."
L["Sell your grey items, or hand in finished quests nearby, before picking up more."] =
    "Vendez vos objets gris, ou rendez les quêtes terminées tout près, avant d'en ramasser d'autres."
L["In a group? Free mode follows the quests you do together."] =
    "En groupe ? Le mode Libre suit les quêtes que vous faites ensemble."
L["Free mode shows the open objectives around you, in any order, instead of one step at a time."] =
    "Le mode Libre montre les objectifs ouverts autour de vous, dans n'importe quel ordre, "
    .. "au lieu d'une étape à la fois."
L["Back to: %s"] = "Reprendre : %s"
L["Show the step's points on the minimap"] = "Afficher les points de l'étape sur la minimap"
L["Show the step's points on the world map"] = "Afficher les points de l'étape sur la carte du monde"
L["Hide the Blizzard quest tracker while following a guide"] =
    "Masquer le suivi de quêtes de Blizzard pendant un guide"
L["Lock the guide window"] = "Verrouiller la fenêtre du guide"

-- Modules/UI/Minimap.lua
L["Minimap"] = "Minimap"
L["Square minimap (round as an option) and zoom with the mouse wheel."] =
    "Minimap carrée (ronde en option) et zoom à la molette."
L["Square minimap"] = "Minimap carrée"
L["Zoom with the mouse wheel"] = "Zoom à la molette"

-- Modules/UI/AddonsMenu.lua
L["NextStep button"] = "Bouton NextStep"
L["A single minimap button for the farming radar, NextStep's options and the settings "
    .. "of every add-on; other add-ons' minimap buttons are hidden."] =
    "Un seul bouton sur la minimap pour le radar de récolte, les options de NextStep et les "
    .. "paramètres de chaque addon ; les boutons des autres addons sont masqués."
L["NextStep options"] = "Options de NextStep"
L["Add-ons"] = "Addons"
L["No other add-on loaded."] = "Aucun autre addon chargé."
L["No settings"] = "Pas de paramètres"
L["Left-click: add-ons menu"] = "Clic gauche : menu des addons"
L["Right-click: NextStep options"] = "Clic droit : options de NextStep"
L["Middle-click: farming radar"] = "Clic milieu : radar de récolte"
L["Drag: move the button"] = "Glisser : déplacer le bouton"
L["Open the add-ons menu"] = "Ouvre le menu des addons"
L["Hide other add-ons' minimap buttons"] = "Masquer les boutons de minimap des autres addons"

-- Modules/UI/QuestItems.lua
L["Quest items"] = "Objets de quête"
L["Marks the items in your bags that a quest in your log needs, and names the quest "
    .. "in their tooltip."] =
    "Marque dans les sacs les objets utiles à une quête du journal, et nomme la quête dans leur infobulle."
L["Quest item"] = "Objet de quête"
L["Quest item: %s"] = "Objet de quête : %s"

-- Modules/Guide/Spells.lua
L["%d g"] = "%d po"
L["%d s"] = "%d pa"
L["%d c"] = "%d pc"
L["%d spells to learn (%s)"] = "%d sorts à apprendre (%s)"
L["Total: %s"] = "Total : %s"
L["Missing: %s"] = "Il manque : %s"
L["Level %d: %d new spells"] = "Niveau %d : %d nouveaux sorts"
L["No trainer data for your class."] = "Pas de données de maître pour ta classe."
L["Nothing to learn at your trainer for now."] = "Rien à apprendre chez ton maître pour l'instant."
L["Show your class spells, now and at the next levels (list: in the chat)"] =
    "Affiche tes sorts de classe, maintenant et aux niveaux suivants (list : dans le chat)"
L["Class spells"] = "Sorts de classe"
L["Now: %d spells"] = "Maintenant : %d sorts"

-- Modules/Guide/Journal.lua
L["Leveling"] = "Leveling"
L["Class"] = "Classe"
L["Professions"] = "Métiers"
L["Reputation"] = "Réputation"
L["Collectibles"] = "Collection"
L["Exploration"] = "Exploration"
L["Miscellaneous"] = "Divers"
L["Legacy content"] = "Ancien contenu"
L["(following)"] = "(suivi)"
L["(done)"] = "(terminé)"
L["Choose your path"] = "Choisis ton chemin"
L["All guides"] = "Tous les guides"
L["Zone: %s"] = "Zone : %s"
L["Reward: %s"] = "Récompense : %s"
L["Then: %s"] = "Ensuite : %s"
L["You are following this guide."] = "Tu suis ce guide."
L["You finished this guide."] = "Tu as terminé ce guide."
L["Progress: %d %%"] = "Avancement : %d %%"
L["NextStep journal"] = "Journal de NextStep"
L["Routes"] = "Routes"
L["Options"] = "Options"
L["Follow this guide"] = "Suivre ce guide"
L["Pick a guide in the list."] = "Choisis un guide dans la liste."
L["Guide journal"] = "Journal du guide"
L["Following"] = "Suivi"
L["Finished"] = "Terminé"
L["Reward"] = "Récompense"
L["Levels %s"] = "Niveaux %s"
L["Trainer cost: %s"] = "Prix chez le maître : %s"
L["Open the guide journal"] = "Ouvre le journal du guide"

-- Modules/Guide/Window.lua (quêtes)
L["Click to open it in the quest log."] = "Clic : l'ouvrir dans le journal de quêtes."
L["Not in your quest log."] = "Pas dans ton journal de quêtes."
L["Not in combat."] = "Pas en combat."

-- Core/Options.lua
L["Open NextStep options"] = "Ouvrir les options de NextStep"
L["Also with /ns options or a right-click on the NextStep minimap button."] =
    "Aussi avec /ns options ou un clic droit sur le bouton NextStep de la minimap."

-- Modules/UI/Junk.lua
L["Junk"] = "Camelote"
L["Sells grey items when you open a merchant (twelve at most, so you can buy them back), "
    .. "with a summary in the chat."] =
    "Vend les objets gris à l'ouverture d'un marchand (douze au plus, pour pouvoir les racheter), "
    .. "avec un résumé dans le chat."
L["Junk sold: %d items for %s."] = "Camelote vendue : %d objets pour %s."
L["%d more grey items: reopen the merchant to sell them."] =
    "Encore %d objets gris : rouvrez le marchand pour les vendre."
L["Never sell this grey item: /ns keep <item link or id>"] =
    "Ne jamais vendre cet objet gris : /ns keep <lien ou identifiant>"
L["Usage: /ns keep <item link or id>"] = "Usage : /ns keep <lien ou identifiant de l'objet>"
L["Item %d will be sold again."] = "L'objet %d sera de nouveau vendu."
L["Item %d will never be sold."] = "L'objet %d ne sera jamais vendu."

-- Modules/UI/Windows.lua
L["Movable windows"] = "Fenêtres déplaçables"
L["Drag Blizzard windows (character, spellbook, quest log, merchants, trainers...) to "
    .. "move them; their position is remembered. Alt + right-click puts one back in its place."] =
    "Faites glisser les fenêtres de Blizzard (personnage, grimoire, journal de quêtes, marchands, maîtres...) "
    .. "pour les déplacer ; leur position est retenue. Alt + clic droit en remet une à sa place."
L["%s will open in its usual place."] = "%s s'ouvrira à sa place habituelle."
L["Windows will open in their usual place."] = "Les fenêtres s'ouvriront à leur place habituelle."
L["Reset window positions"] = "Rétablir la place des fenêtres"
