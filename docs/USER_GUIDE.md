# Guide d'utilisation de NextStep

NextStep regroupe dans un seul addon tout ce qu'il faut pour monter un personnage sur **WoW Forever** : guide de leveling, équipement, métiers et améliorations de l'interface. Chaque module se coupe dans les options, et rien n'est jamais envoyé hors de ton PC.

## Pour commencer

1. Installe NextStep (le dossier `NextStep` et celui de ta faction, `NextStep_Alliance` ou `NextStep_Horde`) dans `_forever_\Interface\AddOns\`, puis connecte-toi.
2. La **fenêtre du guide** s'ouvre : choisis un guide de départ, ou suis les quêtes proposées près de toi.
3. Le **bouton NextStep** de la minimap ouvre le menu : journal, donjons, équipement, métiers, zones, sacs et banque, horloge, radar, options.
4. Tape **`/ns`** pour la liste des commandes.

## Le guide

| Élément | Ce qu'il fait |
|---|---|
| **Fenêtre du guide** | L'étape en cours et ses objectifs. Niveau des quêtes en couleur (gris, vert, jaune, orange, rouge), quêtes **élites**, de groupe, de donjon ou de raid signalées, récompense qui améliore ton équipement (« récompense +12 % »). Survol d'une quête : son texte ; clic : le journal de quêtes. |
| **Modes** | *Strict* (une étape à la fois) ou *Libre* (les objectifs du même endroit, dans n'importe quel ordre ; conseillé en groupe). Bouton en bas de la fenêtre. |
| **Flèche** | En haut de l'écran, vers l'objectif le plus proche, avec la distance. Un clic dans le journal la tourne vers un donneur de quête ; **clic droit dessus** (ou la ligne « Flèche : … », ou `/ns arrow`) pour la rendre au guide. |
| **Carte et minimap** | Tous les points de l'étape ; la cible en doré. |
| **Ici aussi** | Près d'un PNJ, les quêtes que le guide prévoit plus loin chez lui et que tu peux faire tout de suite. |
| **Ignorer** | Clic droit sur une ligne : ignorer cet objectif, ignorer toute la quête (dans tous les guides), ou la marquer faite. « N quêtes ignorées » en bas de la fenêtre pour les reprendre. **Passer l'étape** laisse de côté toute l'étape ; **Étape faite** coche ce que le guide ne voit pas (parler à, visiter) et passe à la suite. |
| **Détours** | Tu peux faire les quêtes dans un autre ordre : le guide se recale tout seul. Une quête abandonnée est signalée (clic pour la reprendre). |
| **Guides annexes** | Quêtes de classe, guides de métier, de réputation ou de collection : ton guide de leveling est gardé, « Reprendre : … » y revient d'un clic. |
| **Sorts à apprendre** | Les sorts de ton maître de classe et leur coût ; en ville, près de ton maître, un clic t'y mène. La liste lue chez le maître est retenue. |
| **Célébration** | À chaque niveau : nouveaux sorts, quête de classe qui s'ouvre, suite conseillée. |
| **Sans guide suivi** | Les 5 quêtes à prendre les plus proches, pour ta faction, ta race, ta classe et ton niveau. |

## Le journal (`/ns journal`)

| Onglet | Contenu |
|---|---|
| **Routes** | Tous les guides de ton personnage par catégorie, « Choisis ton chemin » en tête, avancement, détail, bouton pour suivre. |
| **Sorts de classe** | Ce que ton maître a maintenant et à chaque niveau à venir, avec le prix. |
| **Zones** | Les zones de ton niveau en tête, avec leurs quêtes à prendre (clic : flèche vers le donneur), leurs guides et leurs donjons. |
| **Donjons** (`/ns dungeons`) | Pour chaque donjon : les quêtes à prendre avant d'y aller, les étapes de leur suite de quêtes avec le donneur et sa zone, le butin des boss avec le gain pour ta spécialisation. |
| **Équipement** | Prochains jalons (sorts, quêtes de classe, sacs, monture) et équipement à ne pas rater d'ici cinq niveaux, avec sa provenance. |
| **Métiers** | Tes métiers et leur rang, la maîtrise suivante, les routes de métier à suivre, et un conseiller de paires de métiers (objectif leveling, or ou fin de jeu). |

## Équipement

- **Infobulles** : « NextStep (Armes) : +12 % » face à ce que tu portes, ou la raison si l'objet ne te convient pas.
- **Récompenses de quête** : la récompense conseillée est encadrée, avec la raison (amélioration, sinon celle qui se vend le mieux). Jamais choisie à ta place.
- **Alerte** : quand une amélioration arrive dans tes sacs, un encart s'affiche (jamais en combat) ; clic pour l'équiper, clic droit pour fermer.
- **Spécialisation** : déduite de tes talents, ou choisie dans les options. `/ns gear` la montre, `/ns gear <lien>` compare un objet.

## Interface

| Module | Ce qu'il fait |
|---|---|
| **Minimap** | Carrée, zoom à la molette, icône jour / nuit dans le coin. |
| **Bouton NextStep** | Un seul bouton pour tout NextStep et les paramètres de chaque addon ; les boutons des autres addons sont masqués. Clic droit : options ; clic milieu : radar. |
| **Radar de récolte** | La minimap en grand et en transparence autour de toi (`/ns radar`, Échap ou la croix pour fermer). |
| **Points de récolte** | Chaque herbe, filon et coffre récoltés sont retenus et affichés sur la minimap et la carte. |
| **Carte sans brouillard** | Les zones inexplorées de la carte du monde, plus sombres. |
| **Niveau des zones** | La tranche de niveaux des zones sur la carte du monde. |
| **Valeurs de vie** | Vie et ressources en chiffres sur les cadres d'unité, vie sous les barres de nom. |
| **Sacs et banque** | Améliorations et camelote marquées dans les sacs, places libres ; sacs et banque de tous tes personnages dans les infobulles et consultables de partout (`/ns bank`). |
| **Camelote** | Les objets gris sont vendus à l'ouverture d'un marchand (Maj pour ne rien vendre ; `/ns keep <objet>` pour une exception). |
| **Objets de quête** | Marqués dans les sacs, avec la quête dans leur infobulle. |
| **Fenêtres déplaçables** | Les fenêtres de Blizzard se déplacent en les faisant glisser ; Alt + clic droit les remet en place. |
| **Horloge** | Clic droit sur l'horloge de la minimap (ou `/ns clock`) : alarmes, minuteurs, chronomètre. |

## Commandes

| Commande | Effet |
|---|---|
| `/ns` | Liste des commandes |
| `/ns guide` | Affiche ou cache le guide ; `list`, `start`, `stop`, `reset`, `skip`, `done`, `mode` |
| `/ns journal`, `/ns spells`, `/ns dungeons` | Journal, sorts de classe, donjons |
| `/ns arrow` | Affiche ou cache la flèche (ou la rend au guide) |
| `/ns gear [lien]` | Spécialisation et poids utilisés, ou comparaison d'un objet |
| `/ns bank` | Sacs et banque de tous tes personnages |
| `/ns clock`, `/ns timer <minutes> [nom]`, `/ns alarm <hh:mm> [nom]` | Horloge, minuteur, alarme |
| `/ns radar` | Radar de récolte |
| `/ns keep <objet>` | Objet gris à ne jamais vendre |
| `/ns options`, `/ns modules`, `/ns enable <module>`, `/ns disable <module>` | Options et modules |
| `/ns debug` | Informations pour signaler un problème |

## Signaler un problème

Tape `/ns debug` à l'endroit du problème et envoie le résultat (avec une capture d'écran si possible) dans un ticket sur [GitHub](https://github.com/fccarlier-be/nextstep/issues) ou en commentaire sur CurseForge.
