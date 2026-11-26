# Crédits

NextStep s'appuie sur le travail de plusieurs projets libres. Merci à leurs auteurs.

## Données intégrées

| Projet | Utilisation dans NextStep | Licence |
|---|---|---|
| [Polestar](https://github.com/fitzforge/polestar), Copyright (c) 2026 The Polestar authors | Guides de leveling, de classe et de métiers ; noms et textes traduits ; poids de stats et calcul du score d'équipement (adapté) | GPL-3.0-only |
| [wowsims](https://github.com/wowsims), Copyright (c) 2024 wowsims team (via Polestar) | Poids de stats par spécialisation au-delà des premiers niveaux | MIT |
| [forever-db](https://github.com/fitzforge/polestar/tree/next/forever-db) (Polestar), et ses sources : EG Link (CC BY 4.0), CMaNGOS classic-db, VMaNGOS et Factoruide, ForeverTDB, QuestieDB, pfQuest, tables du client | Quêtes des donjons et leurs suites, quêtes élites et de groupe, quêtes du mode conseil : prérequis, donneurs, positions, récompenses | GPL-3.0 |
| ForeverLevelingBiS, Copyright (c) 2026 Thunder (via Polestar) | Traits raciaux d'équipement, butin choisi des boss, provenance des objets de leveling | MIT |
| [pfQuest](https://github.com/shagu/pfQuest), Copyright (c) 2017-2021 Eric Mauser (Shagu) (via Polestar) | Faits de quêtes, PNJ, objets et items repris dans les guides ; noms français | MIT |
| [Ding!](https://github.com/moust4ki/DingGuideWoWForever) et sa base DingDB, Copyright Yendi ([@moust4ki](https://github.com/moust4ki)) (via Polestar, v1.8.1, commit `fb0a06a`) | Noms français de quêtes, PNJ, objets et items | GPL-3.0 |
| [CMaNGOS classic-db](https://github.com/cmangos/classic-db) (via Polestar) | Hauteurs d'apparition et déplacements des PNJ, nombre d'objectifs des quêtes | GPL-3.0 |
| [What's Training](https://github.com/fusionpit/WhatsTraining), Copyright (c) 2019 What's Training (Fusionpit) | Sorts de chaque classe chez le maître (niveau, rang, coût, prérequis) | MIT |
| [Shortest Path Forever](https://github.com/cjber/shortest-path-forever), Copyright (C) 2026 Cillian Berragan, via le calculateur de [Polestar](https://github.com/fitzforge/polestar) (Polestar_Nav), et les cartes de navigation de Leffe | Chemins à pied : la flèche et le tracé sur les cartes suivent les vrais chemins (`NextStep_Nav`, `NextStep_Nav_EK`, `NextStep_Nav_Kalimdor`, copiés par `Tools/import/nav.py` en ne changeant que les noms globaux) ; voyages : tables de vols, bateaux, zeppelins et portails de Polestar (`NextStep_Nav/Travel.lua`, `FlightTracks.lua`) | GPL-3.0-or-later |
| DungeonJournal (ForeverDungeonJournal), par Exehn | Cartes des donjons : positions des boss, boss rares, entrées, passages d'étage et PNJ de quêtes (`Data/Imported/DungeonJournal/Maps.lua`, `Tools/import/dungeonmaps.lua`) ; ses images des donjons de Forever, lues dans son dossier quand il est installé (non copiées) | Positions reprises comme faits publics ; addon « All Rights Reserved » |
| Santiago Reyes ([sreyesmaps.com](https://sreyesmaps.com)) | Cartographie de Blackmaw Hold (six étages) et d'Atal'Byzal (Cité engloutie), via DungeonJournal | Images de l'auteur, non redistribuées par NextStep |
| [NauticusClassic](https://github.com/psynct/NauticusClassic), Copyright (c) 2020 psynct, et sa suite pour Forever [NauticusClassicResurrected](https://github.com/sam-k-taylor/NauticusClassicResurrected) | Tour de chaque bateau, zeppelin et du tram : durée, escales, heures d'arrivée et de départ à chaque quai ; position des quais | MIT |

Les mentions et licences complètes de ces sources, et des autres sources de Polestar, sont livrées avec l'addon, à côté des données : un fichier `LICENSE-DATA.txt` dans `NextStep/Data/Imported/Polestar/`, `NextStep_Alliance/Data/` et `NextStep_Horde/Data/`. Ce fichier reproduit sans modification les notices de Polestar (dont la licence MIT de pfQuest et les crédits de DingDB). Les notices MIT de wowsims et de ForeverLevelingBiS sont dans `NextStep/Data/Imported/Polestar/Gear-LICENSE-DATA.txt` et `ItemDB-LICENSE-DATA.txt` ; les crédits de forever-db dans `ForeverDB-NOTICE.md`. La notice MIT de What's Training est dans `NextStep/Data/Imported/WhatsTraining/LICENSE-DATA.txt`. Celle de NauticusClassic et NauticusClassicResurrected est dans `NextStep/Modules/UI/Transports-LICENSE-DATA.txt`. Le calculateur de chemins garde ses notices : `LICENSE`, `CREDITS.md` (crédits de Polestar Nav, dont la permission de Cillian Berragan) et `NOTICE.md` dans chacun des dossiers `NextStep_Nav*`. Le texte de la GPL est dans `NextStep/LICENSE.txt`.

## Inspirations

Ces projets ont inspiré des fonctions de NextStep, sans que leur code ni leurs données soient repris : NextStep a son propre code.

| Projet | Idée reprise | Licence |
|---|---|---|
| [GatherMate2](https://github.com/Nevcairiel/GatherMate2), par kagaro, Xinhuan et Nevcairiel | Détecter une récolte par le sort lancé et le nom de l'objet ciblé | GPL-2.0-or-later |
| BlizzMove, Leatrix Maps, DungeonJournal, Pawn | Fenêtres déplaçables, carte sans brouillard, journal des donjons (hors cartes des donjons, voir plus haut), score d'équipement | Code non réutilisable (« All Rights Reserved ») ou non repris |

## Logo

Le logo (une arche de pierre, une étoile dorée et des marches vers la lumière : « la prochaine étape ») a été généré avec **FLUX.2 [klein] 4B** (Black Forest Labs, licence Apache 2.0 annoncée) via ComfyUI, à partir d'une piste visuelle du porteur du projet, puis détouré avec **BiRefNet** (rembg). Graine, prompt et réglages : [`img/logo/nextstep-generation.json`](img/logo/nextstep-generation.json).

## Sources des données

Les données de Polestar sont elles-mêmes issues de nombreuses sources, listées dans son [THIRD_PARTY.md](https://github.com/fitzforge/polestar/blob/next/THIRD_PARTY.md).

Cette liste est complétée à chaque nouvelle source ou bibliothèque intégrée. La version exacte de chaque donnée importée est consignée par le script d'import.

*World of Warcraft* et *WoW Forever* sont des marques de Blizzard Entertainment. NextStep est un projet de fans, sans lien avec Blizzard.
