# Sources de données

NextStep **importe** ses données au lieu de dépendre d'autres addons à l'exécution : un seul addon à installer, et un format interne stable. Un script d'import (hors addon, non distribué) convertit les données sources vers le format NextStep.

## Sources retenues

| Source | Contenu utilisé | Licence | Remarques |
|---|---|---|---|
| [Polestar](https://github.com/fitzforge/polestar) — guides compilés (`addon/Polestar_Guides*/Guides.lua`) | Routes de leveling, de classe et de métiers | GPL-3.0-only | Format compilé versionné (`format = 8` au 2026-11-03) ; l'import refuse un format inconnu |
| Polestar — `forever-db` | Quêtes, PNJ, objets, points d'apparition, cartes | GPL-3.0 (base), CC BY 4.0 (couche « étapes ») | JSON Lines avec schémas ; versions `data-vAAAA.MM.N` |
| Polestar — `Polestar_ItemDB` | Statistiques et provenance des items | Données issues de *ForeverLevelingBiS* (MIT) | ~10 000 items ajustés pour Forever |
| Polestar — poids de stats | Poids par classe, spécialisation et niveau | Données issues de *wowsims* (MIT) | |
| Polestar — `Polestar_frFR` | Noms traduits (quêtes, PNJ, objets, zones) et textes des guides en français | Voir `LICENSE-DATA.txt` du pack | Noms extraits des tables du client |
| [HereBeDragons](https://github.com/Nevcairiel/HereBeDragons) | Bibliothèque : points sur la carte et la minimap, conversion de coordonnées | BSD (déclarée dans le TOC) | Prend en charge Forever (`WOW_PROJECT_CAMELOT`) |
| Le client du jeu | Noms localisés, état du journal de quêtes, recettes connues | — | Lu en jeu, jamais redistribué |

## Sources écartées

| Source | Raison |
|---|---|
| QuestieDB | Aucune licence déclarée pour les données ; réutilisation impossible sans accord des mainteneurs |
| Sources `.guide` de Polestar | Elles-mêmes générées par l'outil de Polestar ; certaines instructions ne sont résolues qu'à la compilation, avec des données non publiées |
| `Polestar_Nav`, `Legs.lua` | Chemins de marche précalculés, trop volumineux (~38 Mo) et liés au système de navigation de Polestar |
| `Polestar_Recorder` et service de collecte | NextStep n'enregistre ni n'envoie aucune donnée |
| Guides gratuits sans licence (ForeverWisp, PexGuide, Follow The Arrow…) | Gratuit ne signifie pas réutilisable |
| Guides payants (RestedXP, Zygor…) | Propriétaires |
| Wowhead | Conditions d'utilisation : pas d'aspiration ; vérification manuelle uniquement |

## Corrections propres à NextStep

Les corrections et ajouts écrits à la main vivent dans `Data/Overrides/`, au format Lua de NextStep. Ils sont appliqués **après** les données importées et survivent aux réimports.

## Obligations

- NextStep est distribué sous GPL-3.0.
- Polestar, forever-db (dont la mention CC BY 4.0), ForeverLevelingBiS, wowsims et HereBeDragons sont crédités dans [CREDITS.md](../CREDITS.md).
- Chaque import consigne la version exacte de la source utilisée.

## Limites connues des données

- **Contenu au-delà du niveau 30** : selon Polestar, certaines données (notamment l'emplacement des nodes de récolte) sont supposées identiques au Classic, faute de confirmation par la bêta.
- **Métiers** : `forever-db` ne documente ni maîtres de métier, ni recettes, ni nodes ; ces informations viennent des guides de métiers de Polestar et d'une table maintenue à la main.
