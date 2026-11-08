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
L["Skip"] = "Passer l'étape"
L["Done"] = "Étape faite"
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
L["Show or hide the arrow (or point it back to the guide)"] =
    "Affiche ou cache la flèche (ou la rend au guide)"
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

-- Modules/Items
L["Gear upgrades"] = "Améliorations d'équipement"
L["Scores gear for your class and spec: gain or loss in item tooltips, the quest reward "
    .. "to take, and an alert when an upgrade lands in your bags."] =
    "Évalue l'équipement pour votre classe et votre spécialisation : gain ou perte dans l'infobulle des "
    .. "objets, récompense de quête à prendre, et alerte quand une amélioration arrive dans vos sacs."
L["Arms"] = "Armes"
L["Fury"] = "Fureur"
L["Protection"] = "Protection"
L["Holy"] = "Sacré"
L["Retribution"] = "Vindicte"
L["Beast Mastery"] = "Maîtrise des bêtes"
L["Marksmanship"] = "Précision"
L["Survival"] = "Survie"
L["Assassination"] = "Assassinat"
L["Combat"] = "Combat"
L["Subtlety"] = "Finesse"
L["Discipline"] = "Discipline"
L["Shadow"] = "Ombre"
L["Elemental"] = "Élémentaire"
L["Enhancement"] = "Amélioration"
L["Restoration"] = "Restauration"
L["Arcane"] = "Arcanes"
L["Fire"] = "Feu"
L["Frost"] = "Givre"
L["Affliction"] = "Affliction"
L["Demonology"] = "Démonologie"
L["Destruction"] = "Destruction"
L["Balance"] = "Équilibre"
L["Feral"] = "Combat farouche"
L["your class cannot wear it"] = "votre classe ne peut pas le porter"
L["your class cannot use this weapon"] = "votre classe ne peut pas manier cette arme"
L["weapon skill not learned"] = "compétence d'arme pas encore apprise"
L["dual wield not learned"] = "ambidextrie pas encore apprise"
L["not usable"] = "inutilisable"
L["big upgrade"] = "grosse amélioration"
L["no weights for your class"] = "pas de poids pour votre classe"
L["chosen"] = "choisie"
L["talents"] = "talents"
L["default"] = "par défaut"
L["Spec: automatic (%s)"] = "Spécialisation : automatique (%s)"
L["Spec: %s"] = "Spécialisation : %s"
L["NextStep: %s"] = "NextStep : %s"
L["NextStep (%s): equipped"] = "NextStep (%s) : porté"
L["NextStep (%s): empty slot"] = "NextStep (%s) : emplacement vide"
L["NextStep (%s): %s"] = "NextStep (%s) : %s"
L["(level %d)"] = "(niveau %d)"
L["Gear weights: %s"] = "Poids d'équipement : %s"
L["up to level %d, %s"] = "jusqu'au niveau %d, %s"
L["Not gear, or its stats are not known yet."] =
    "Pas un équipement, ou ses caractéristiques ne sont pas encore connues."
L["Gear: spec and weights in use, or compare an item link"] =
    "Équipement : spécialisation et poids utilisés, ou comparer un lien d'objet"
L["Gain or loss in item tooltips"] = "Gain ou perte dans l'infobulle des objets"
L["Advise the quest reward to take"] = "Conseiller la récompense de quête à prendre"
L["Alert when an upgrade lands in your bags"] = "Alerte quand une amélioration arrive dans les sacs"
L["Minimum gain for an upgrade: %d%%"] = "Gain minimal d'une amélioration : %d %%"
L["The alert stays until closed"] = "L'alerte reste jusqu'à sa fermeture"
L["The alert closes after %d seconds"] = "L'alerte se ferme après %d secondes"
L["NextStep: reward"] = "NextStep : récompense"
L["Upgrade for %s: empty slot"] = "Amélioration (%s) : emplacement vide"
L["Upgrade for %s: %s"] = "Amélioration (%s) : %s"
L["No upgrade: sells best (%s)"] = "Aucune amélioration : se vend le mieux (%s)"
L["right-click: close"] = "clic droit : fermer"
L["Click: equip"] = "Clic : équiper"
L["Upgrades in your bags"] = "Améliorations dans vos sacs"
L["Upgrade in your bags"] = "Amélioration dans vos sacs"
L["new"] = "nouveau"

-- Modules/Items : donjons, équipement à venir, jalons
L["reserved for other classes"] = "réservé à d'autres classes"
L["Dungeons"] = "Donjons"
L["Gear"] = "Équipement"
L["Dungeons: quests to take before going in, and boss loot"] =
    "Donjons : quêtes à prendre avant d'y aller, et butin des boss"
L["unknown"] = "inconnu"
L["the item %s"] = "l'objet %s"
L["Item %d"] = "Objet %d"
L["not for you"] = "pas pour vous"
L["equipped"] = "porté"
L["%d quests"] = "%d quêtes"
L["For your level"] = "À votre niveau"
L["All dungeons"] = "Tous les donjons"
L["done"] = "faite"
L["in your log"] = "dans le journal"
L["to take"] = "à prendre"
L["earlier step"] = "étape avant"
L["level %d"] = "niveau %d"
L["The arrow points to %s. Right-click it to go back to the guide."] =
    "La flèche pointe vers %s. Clic droit dessus pour revenir au guide."
L["Right-click: back to the guide"] = "Clic droit : revenir au guide"
L["The arrow follows the guide again."] = "La flèche suit de nouveau le guide."
L["Arrow: %s (click to go back to the guide)"] = "Flèche : %s (clic pour revenir au guide)"
L["Levels %d-%d"] = "Niveaux %d-%d"
L["Entrance: %s"] = "Entrée : %s"
L["Quests to take before going in"] = "Quêtes à prendre avant d'y aller"
L["No quest left for this dungeon."] = "Plus aucune quête pour ce donjon."
L["Given by %s"] = "Donnée par %s"
L["Turned in to %s"] = "À rendre à %s"
L["Click: point the arrow to the giver"] = "Clic : la flèche pointe vers le donneur"
L["Quest chain: %d steps left"] = "Suite de quêtes : encore %d étapes"
L["Boss loot"] = "Butin des boss"
L["Seen in game"] = "Vu en jeu"
L["No loot known yet: loot seen in game will be listed here."] =
    "Aucun butin connu pour l'instant : le butin vu en jeu s'affichera ici."
L["Pick a dungeon in the list."] = "Choisissez un donjon dans la liste."
L["Alchemy"] = "Alchimie"
L["Blacksmithing"] = "Forge"
L["Enchanting"] = "Enchantement"
L["Engineering"] = "Ingénierie"
L["Leatherworking"] = "Travail du cuir"
L["Tailoring"] = "Couture"
L["Jewelcrafting"] = "Joaillerie"
L["Mining"] = "Minage"
L["Herbalism"] = "Herboristerie"
L["Skinning"] = "Dépeçage"
L["Cooking"] = "Cuisine"
L["First Aid"] = "Secourisme"
L["Fishing"] = "Pêche"
L["reward: new slot"] = "récompense : nouvel emplacement"
L["reward %s"] = "récompense %s"
L["Quest: %s, %s"] = "Quête : %s, %s"
L["Quest: %s"] = "Quête : %s"
L["Drop: %s, %s (%d %%)"] = "Butin : %s, %s (%d %%)"
L["Crafted: %s (%d)"] = "Artisanat : %s (%d)"
L["Spells to learn now: %d"] = "Sorts à apprendre maintenant : %d"
L["Bags: %d bag slots are empty"] = "Sacs : %d emplacements de sac vides"
L["Bags: %d bags have fewer than %d slots"] = "Sacs : %d sacs ont moins de %d places"
L["Level %d: riding and a first mount, about %s"] = "Niveau %d : monte et première monture, environ %s"
L["saved: %d %%"] = "économisé : %d %%"
L["up to level %d"] = "jusqu'au niveau %d"
L["Next milestones"] = "Prochains jalons"
L["Nothing to plan for now."] = "Rien à prévoir pour l'instant."
L["Gear not to miss (%s)"] = "Équipement à ne pas rater (%s)"
L["No known upgrade for the next levels."] = "Aucune amélioration connue pour les prochains niveaux."
L["Leave this guide and resume your leveling guide where you left it."] =
    "Quitter ce guide et reprendre votre guide de leveling là où vous l'avez laissé."

-- Modules/Guide/Celebration.lua
L["New spells at your trainer: %d (%s)"] = "Nouveaux sorts chez votre maître : %d (%s)"
L["Class quest available: %s"] = "Quête de classe disponible : %s"
L["Suggested next: %s"] = "Ensuite, conseillé : %s"
L["Level %d!"] = "Niveau %d !"
L["Celebrate each level"] = "Célébrer chaque niveau gagné"
L["Play a sound for the celebration"] = "Jouer un son pour la célébration"

-- Modules/UI/ZoneLevels.lua
L["Zone levels"] = "Niveau des zones"
L["Shows each zone's level range on the world map."] =
    "Affiche la tranche de niveaux de chaque zone sur la carte du monde."

-- Sorts : maître de classe tout près
L["your class trainer"] = "votre maître de classe"
L["Class trainer nearby (%s, %d yd): %s"] = "Maître de classe tout près (%s, %d m) : %s"

-- Modules/UI/Clock.lua
L["Clock"] = "Horloge"
L["Alarms, timers and a stopwatch, opened by right-clicking the minimap clock."] =
    "Alarmes, minuteurs et chronomètre, ouverts d'un clic droit sur l'horloge de la minimap."
L["Timer"] = "Minuteur"
L["Alarm"] = "Alarme"
L["Timer finished: %s"] = "Minuteur terminé : %s"
L["Alarm: %s"] = "Alarme : %s"
L["Alarms"] = "Alarmes"
L["Local"] = "Locale"
L["Server"] = "Serveur"
L["server"] = "serveur"
L["Time expected: hh:mm"] = "Heure attendue : hh:mm"
L["Timers"] = "Minuteurs"
L["Minutes expected"] = "Nombre de minutes attendu"
L["name, minutes"] = "nom, minutes"
L["Stopwatch"] = "Chronomètre"
L["Start"] = "Démarrer"
L["Reset"] = "Remettre à zéro"
L["Pause"] = "Pause"
L["Open the clock: alarms, timers, stopwatch"] = "Ouvre l'horloge : alarmes, minuteurs, chronomètre"
L["Timer set: %s in %s."] = "Minuteur réglé : %s dans %s."
L["Usage: /ns timer <minutes> [name]"] = "Usage : /ns timer <minutes> [nom]"
L["Start a timer: /ns timer <minutes> [name]"] = "Lance un minuteur : /ns timer <minutes> [nom]"
L["Alarm set at %02d:%02d."] = "Alarme réglée à %02d:%02d."
L["Usage: /ns alarm <hh:mm> [name]"] = "Usage : /ns alarm <hh:mm> [nom]"
L["Set an alarm: /ns alarm <hh:mm> [name]"] = "Règle une alarme : /ns alarm <hh:mm> [nom]"
L["Timer finished while you were away: %s"] = "Minuteur terminé pendant votre absence : %s"

-- Modules/UI/UnitText.lua
L["Health and power values"] = "Valeurs de vie et de ressources"
L["Health and power values on unit frames (Blizzard's status text) and health on nameplates."] =
    "Valeurs de vie et de ressources sur les cadres d'unité (texte de statut de Blizzard) et vie sur les barres de nom."
L["value and percent"] = "valeur et pourcentage"
L["value"] = "valeur"
L["percent"] = "pourcentage"
L["short (4.5k)"] = "court (4,5k)"
L["full (4,523 / 6,000)"] = "complet (4 523 / 6 000)"
L["Show values on unit frames (Blizzard's status text)"] =
    "Valeurs sur les cadres d'unité (texte de statut de Blizzard)"
L["Unit frames: %s"] = "Cadres d'unité : %s"
L["Show health on nameplates"] = "Vie sur les barres de nom"
L["Nameplates: %s"] = "Barres de nom : %s"

-- Modules/UI/Inventory.lua
L["Bags and bank"] = "Sacs et banque"
L["Marks upgrades and junk in your bags, remembers the bags and bank of all your "
    .. "characters, counts items in tooltips, and shows any bank from anywhere."] =
    "Marque les améliorations et la camelote dans vos sacs, retient les sacs et la banque de tous vos "
    .. "personnages, les compte dans les infobulles et montre n'importe quelle banque, de n'importe où."
L["bags %d"] = "sacs %d"
L["bank %d"] = "banque %d"
L["Total: %d"] = "Total : %d"
L["Free slots: %d"] = "Places libres : %d"
L["Nothing here."] = "Rien ici."
L["Bags"] = "Sacs"
L["Bank"] = "Banque"
L["seen %s"] = "vue le %s"
L["never visited"] = "jamais visitée"
L["No character yet"] = "Aucun personnage pour l'instant"
L["Bags and bank of all your characters, from anywhere"] =
    "Sacs et banque de tous vos personnages, de n'importe où"
L["Mark upgrades in your bags"] = "Marquer les améliorations dans les sacs"
L["Mark junk in your bags"] = "Marquer la camelote dans les sacs"
L["Show the item level of gear in your bags"] = "Niveau d'objet de l'équipement dans les sacs"
L["Count items of all your characters in tooltips"] = "Compter les objets de tous vos personnages dans les infobulles"

-- Modules/UI/Gathering.lua
L["Gathering nodes"] = "Points de récolte"
L["Remembers every herb, ore vein and chest you gather, and shows them on the minimap "
    .. "and the world map."] =
    "Retient chaque herbe, filon et coffre récoltés, et les affiche sur la minimap et la carte du monde."
L["Gathered %d times"] = "Récolté %d fois"
L["Show gathering nodes on the minimap"] = "Points de récolte sur la minimap"
L["Show gathering nodes on the world map"] = "Points de récolte sur la carte du monde"
L["Herbs"] = "Herbes"
L["Ore veins"] = "Filons"
L["Chests"] = "Coffres"

-- Modules/Professions/Professions.lua
L["Tracks your professions, advises which ones to take, and reminds you to see the trainer."] =
    "Suit vos métiers, conseille lesquels prendre, et rappelle d'aller voir le maître."
L["Apprentice"] = "Apprenti"
L["Journeyman"] = "Compagnon"
L["Expert"] = "Expert"
L["Artisan"] = "Artisan"
L["leveling"] = "leveling"
L["gold"] = "or"
L["end game"] = "fin de jeu"
L["racial bonus"] = "bonus racial"
L["suits your class"] = "convient à votre classe"
L["good for %s"] = "bon pour : %s"
L["one gathers what the other crafts"] = "l'un récolte ce que l'autre fabrique"
L["two gathering professions: gold while leveling"] = "deux métiers de récolte : de l'or en montant de niveau"
L["Your professions"] = "Vos métiers"
L["No profession learned yet."] = "Aucun métier appris pour l'instant."
L["Next: %s at skill %d and level %d"] = "Ensuite : %s à %d de compétence et au niveau %d"
L["Route: %s"] = "Route : %s"
L["Advice (goal: %s)"] = "Conseils (objectif : %s)"
L["Goal: %s (click to change)"] = "Objectif : %s (clic pour changer)"
L["score %d"] = "score %d"
L["Also useful: First Aid, Cooking and Fishing."] = "Utiles aussi : Secourisme, Cuisine et Pêche."
L["%s %d/%d: learn %s at the trainer"] = "%s %d/%d : apprenez %s chez le maître"

-- Modules/Guide/Advice.lua, Zones.lua (mode conseil)
L["Quests to take nearby:"] = "Quêtes à prendre près de vous :"
L["Zones"] = "Zones"
L["Other zones"] = "Autres zones"
L["Pick a zone in the list."] = "Choisissez une zone dans la liste."
L["Guide: %s"] = "Guide : %s"
L["Dungeon: %s (%d-%d)"] = "Donjon : %s (%d-%d)"
L["Quests you can take"] = "Quêtes que vous pouvez prendre"
L["No quest to take here for now."] = "Aucune quête à prendre ici pour l'instant."

-- Options complètes (phase 11)
L["Advice goal: %s"] = "Objectif du conseiller : %s"
L["Open the clock"] = "Ouvrir l'horloge"
L["Clear the exceptions (%d)"] = "Vider les exceptions (%d)"
L["Every grey item will be sold again."] = "Tous les objets gris seront de nouveau vendus."

-- Guide : ignorer une quête ou un objectif
L["Right-click: ignore it, or mark it done"] = "Clic droit : l'ignorer, ou la marquer faite"
L["Ignore this objective"] = "Ignorer cet objectif"
L["Ignore the quest \"%s\" (all its lines)"] = "Ignorer la quête « %s » (toutes ses lignes)"
L["Mark this objective done"] = "Marquer cet objectif comme fait"
L["Open in the quest log"] = "Ouvrir dans le journal de quêtes"
L["This objective"] = "Cet objectif"
L["Ignored quests"] = "Quêtes ignorées"
L["Take back: %s"] = "Reprendre : %s"
L["%d ignored quests (click to take them back)"] = "%d quêtes ignorées (clic pour les reprendre)"
L["Moves on without doing this step: all its quests are left aside. "
    .. "To leave out just one quest, right-click its line."] =
    "Passe à la suite sans faire cette étape : toutes ses quêtes sont laissées de côté. "
    .. "Pour n'écarter qu'une quête, clic droit sur sa ligne."
L["You did this step yourself: ticks what the guide cannot see (talk to, "
    .. "visit...), and moves on."] =
    "Vous avez fait cette étape : coche ce que le guide ne peut pas voir (parler à, "
    .. "visiter...), et passe à la suite."

-- Métiers : où farmer
L["Skin beasts up to level %d"] = "Dépecez les bêtes jusqu'au niveau %d"
L["Farm %s in %s"] = "Récoltez %s : %s"
L["To gather: %s"] = "À récolter : %s"
L["Here, to gather: %s"] = "Ici, à récolter : %s"

-- Minimap et menu : réglages complétés
L["Minimap size: %d%%"] = "Taille de la minimap : %d %%"
L["The zoom stays where you leave it"] = "Le zoom reste là où vous le laissez"
L["Back to the widest zoom after %d seconds"] = "Retour au zoom le plus large après %d secondes"
L["Keep visible on the minimap"] = "Garder visibles sur la minimap"
L["%s already groups minimap buttons: NextStep leaves them alone."] =
    "%s regroupe déjà les boutons de la minimap : NextStep n'y touche pas."
L["Hide Blizzard's add-on compartment"] = "Masquer le compartiment d'addons de Blizzard"
L["Hide the NextStep button (menu: /ns addons)"] = "Cacher le bouton NextStep (menu : /ns addons)"
