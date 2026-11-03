# Changelog

Toutes les modifications notables de NextStep sont consignées ici.

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/), et le projet respecte le [versionnage sémantique](https://semver.org/lang/fr/).

## [Non publié]

### Ajouté
- Conception des **fenêtres ouvertes ensemble** (phase 5) : les fenêtres Blizzard non protégées sortent du gestionnaire de Blizzard pour rester ouvertes côte à côte ; clic pour passer au premier plan, Échap qui ferme la fenêtre au premier plan, ouverture en cascade ([docs/DESIGN.md](docs/DESIGN.md#fenêtres-déplaçables)). L'addon de diagnostic relève la strate, le premier plan et la fermeture par Échap de chaque fenêtre.
- Module **Radar de récolte** (`Radar`) : la minimap, en grand et en transparence, au centre de l'écran autour du personnage, pour repérer herbes, filons et poissons ; s'ouvre avec `/ns radar` ou un raccourci clavier. Terrain caché par défaut, rotation avec la caméra et points cardinaux, taille et opacité réglables ; la minimap est rendue exactement dans son état d'origine. Actif par défaut, désactivable, mis de côté si FarmHud est chargé. Textures générées par `Tools/radar/textures.py`. À vérifier en jeu.
- Module **Carte sans brouillard** (`MapReveal`) : les zones inexplorées de la carte du monde sont affichées, plus sombres (luminosité réglable dans les options, 60 % par défaut) ; actif par défaut, désactivable, mis de côté si Leatrix Maps ou Mapster est chargé. À vérifier en jeu.
- **Données de la carte sans brouillard** : superpositions de la carte du monde, explorées ou non, extraites des tables du client Forever (`WorldMapOverlay`, `WorldMapOverlayTile`) dans `Data/Imported/Client/MapOverlays.lua` ; accès par `DB.mapOverlays[mapArtID]`. Script d'extraction reproductible et vérifié (`Tools/worldmap/`, TACTSharp et DBCD, versions figées), rapport `Tools/worldmap/last-import.md`.
- **Nouvelles fonctionnalités prévues**, inspirées d'addons existants, avec reprise des sources libres (What's Training, MIT ; GatherMate2, GPL-2.0-or-later) et licences des autres vérifiées ([docs/DATA_SOURCES.md](docs/DATA_SOURCES.md)) : sorts à apprendre et célébration de niveau (phase 4), niveau des zones sur la carte (phase 4), fenêtres déplaçables et carte sans brouillard (phase 5), points de récolte (phase 9), butin des donjons (phase 10) ; prix de l'hôtel des ventes à l'étude après la v1.0. Idées écartées consignées ([docs/DESIGN.md](docs/DESIGN.md#10-idées-à-létude)).
- Addon de diagnostic : vérifications de l'exploration de la carte, des fenêtres Blizzard et du journal des donjons ; captures automatiques de la liste d'un maître et des derniers butins et récoltes, avec leur source.
- **Licences livrées avec l'addon** : texte de la GPL dans `NextStep/LICENSE.txt` ; à côté des données importées, un `LICENSE-DATA.txt` qui reproduit les notices de Polestar (dont la licence MIT de pfQuest et les crédits de DingDB) ; copyright de Polestar en tête de chaque fichier généré. L'import s'arrête si un pack de Polestar change de licence. Crédits de pfQuest, Ding/DingDB et CMaNGOS classic-db ajoutés ; licence précisée : GPL-3.0-only.
- Texte de la page CurseForge, en anglais et en français, et règles de modération de CurseForge appliquées à NextStep ([docs/CURSEFORGE.md](docs/CURSEFORGE.md)).
- **Logo** : une arche de pierre, une étoile dorée et des marches vers la lumière. Icônes en jeu (`Media/Icon.tga`, `Media/IconSmall.tga`, `## IconTexture` dans le TOC), icône CurseForge, script de préparation `Tools/logo/prepare.py`.
- Addon de développement **NextStep - Diagnostic** (`Tools/diagnostic/`, commande `/nsdiag`) : vérifie en jeu les API, les valeurs, les options natives, la conversion des coordonnées et le comportement des *secret values* en combat ; `Tools/diagnostic/report.ps1` convertit le résultat en rapport Markdown dans `docs/reports/`. Jamais livré aux joueurs.
- **Moteur du guide** (`Modules/Guide/`) : conditions (`only`, `when`), état des 26 types d'objectifs, étape courante calculée, étapes dépassées mémorisées par clé stable, sauts (`skipto`), objectifs en chemin (`along`), quêtes de groupe, modes strict et libre, détours, quêtes abandonnées signalées, conseils (personnage en avance, quêtes grises), guides suivants.
- **Module Guide** : guide actif et progression par personnage, ignorer et réactiver une étape, validations manuelles, réponses aux quêtes de groupe, suggestion du guide de départ selon la race, la classe et le niveau.
- Joueur simulé et joueur automatique pour les tests : chaque guide importé est parcouru jusqu'au bout.
- Module **Noms appris** : retient le nom des PNJ croisés dans la langue du client (cible, survol, nameplates, dialogue) et interroge l'infobulle du client pour les autres, afin de traduire les guides là où Polestar n'a pas de traduction. Actif par défaut sur les clients non anglais, jamais en combat, rien n'est envoyé ; désactivable, avec un bouton pour oublier les noms appris.
- Panneau d'options : une case à cocher par module, avec sa description et ses réglages.
- Import des guides de Polestar 0.3.0 : 256 guides (leveling des deux factions et de chaque race, classes, métiers, réputations, collection), noms anglais et français, traductions françaises des textes ; script d'import isolé, vérifié et reproductible (`Tools/import/`), rapport `Tools/import/last-import.md`.
- Couche d'accès aux données `ns.DB` : guides, noms dans la langue du client (traduction importée, puis noms fournis par le client, puis anglais), rendu des textes de guide.
- Documentation du format de données ([docs/DATA_FORMAT.md](docs/DATA_FORMAT.md)).
- Cœur de l'addon : espace de noms, répartition des événements et messages internes, sauvegardes avec schéma et migrations, registre de modules activables avec détection des addons concurrents, traductions (anglais par défaut, français), panneau d'options, commandes `/ns` et `/nextstep`.
- Addons de données `NextStep_Alliance` et `NextStep_Horde`, chargés à la demande selon la faction du personnage.
- Tests hors jeu avec simulation de l'API du jeu (92 tests), configuration luacheck et intégration continue GitHub.
- Scripts de développement : installation des outils (`Tools/setup.ps1`), vérifications (`Tools/check.ps1`), liaison au dossier AddOns du jeu (`Tools/deploy.ps1`).
- Documentation de conception : architecture, moteur du guide, modules Items, Métiers et UI ([docs/DESIGN.md](docs/DESIGN.md)).
- Feuille de route en 12 phases jusqu'à la v1.0 ([docs/ROADMAP.md](docs/ROADMAP.md)).
- Recensement des sources de données et de leurs licences ([docs/DATA_SOURCES.md](docs/DATA_SOURCES.md)).
- README, licence GPL-3.0, crédits, guide de contribution.
- Configuration du dépôt : modèles de tickets et de pull request, fichiers `.gitignore`, `.gitattributes` et `.editorconfig`.

[Non publié]: https://github.com/fccarlier-be/nextstep/commits/main
