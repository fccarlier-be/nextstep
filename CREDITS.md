# Crédits

NextStep s'appuie sur le travail de plusieurs projets libres. Merci à leurs auteurs.

## Données intégrées

| Projet | Utilisation dans NextStep | Licence |
|---|---|---|
| [Polestar](https://github.com/fitzforge/polestar), Copyright (c) 2026 The Polestar authors | Guides de leveling, de classe et de métiers ; noms et textes traduits | GPL-3.0-only |
| [pfQuest](https://github.com/shagu/pfQuest), Copyright (c) 2017-2021 Eric Mauser (Shagu) (via Polestar) | Faits de quêtes, PNJ, objets et items repris dans les guides ; noms français | MIT |
| [Ding!](https://github.com/moust4ki/DingGuideWoWForever) et sa base DingDB, Copyright Yendi ([@moust4ki](https://github.com/moust4ki)) (via Polestar, v1.8.1, commit `fb0a06a`) | Noms français de quêtes, PNJ, objets et items | GPL-3.0 |
| [CMaNGOS classic-db](https://github.com/cmangos/classic-db) (via Polestar) | Hauteurs d'apparition et déplacements des PNJ, nombre d'objectifs des quêtes | GPL-3.0 |

Les mentions et licences complètes de ces sources, et des autres sources de Polestar, sont livrées avec l'addon, à côté des données : un fichier `LICENSE-DATA.txt` dans `NextStep/Data/Imported/Polestar/`, `NextStep_Alliance/Data/` et `NextStep_Horde/Data/`. Ce fichier reproduit sans modification les notices de Polestar (dont la licence MIT de pfQuest et les crédits de DingDB). Le texte de la GPL est dans `NextStep/LICENSE.txt`.

## Prévus

Ces projets seront utilisés dans les prochaines phases (voir la [feuille de route](docs/ROADMAP.md)). Leurs licences et mentions seront jointes au moment de leur intégration.

| Projet | Utilisation prévue | Licence |
|---|---|---|
| [forever-db](https://github.com/fitzforge/polestar/tree/next/forever-db) (Polestar) | Faits du jeu : quêtes, PNJ, objets, cartes | GPL-3.0 ; couche « mécaniques et étapes » sous CC BY 4.0 |
| ForeverLevelingBiS, par Thunder (via Polestar) | Statistiques et provenance des items de leveling | MIT |
| [wowsims](https://github.com/wowsims) (via Polestar) | Poids de stats par spécialisation | MIT |
| [HereBeDragons](https://github.com/Nevcairiel/HereBeDragons), par Nevcairiel | Points sur la carte et la minimap, coordonnées | BSD |

## Logo

Le logo (une arche de pierre, une étoile dorée et des marches vers la lumière : « la prochaine étape ») a été généré avec **FLUX.2 [klein] 4B** (Black Forest Labs, licence Apache 2.0 annoncée) via ComfyUI, à partir d'une piste visuelle du porteur du projet, puis détouré avec **BiRefNet** (rembg). Graine, prompt et réglages : [`img/logo/nextstep-generation.json`](img/logo/nextstep-generation.json).

## Sources des données

Les données de Polestar sont elles-mêmes issues de nombreuses sources, listées dans son [THIRD_PARTY.md](https://github.com/fitzforge/polestar/blob/next/THIRD_PARTY.md).

Cette liste est complétée à chaque nouvelle source ou bibliothèque intégrée. La version exacte de chaque donnée importée est consignée par le script d'import.

*World of Warcraft* et *WoW Forever* sont des marques de Blizzard Entertainment. NextStep est un projet de fans, sans lien avec Blizzard.
