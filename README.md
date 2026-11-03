# NextStep

> L'addon tout-en-un pour monter ses personnages sur **WoW Forever** : guide de leveling, métiers, équipement et améliorations de l'interface, dans un seul addon.

**Statut : en développement (fondations et import des données terminés, moteur du guide en préparation).** Aucune version jouable n'est encore publiée. Voir la [feuille de route](docs/ROADMAP.md).

[![CI](https://github.com/fccarlier-be/nextstep/actions/workflows/ci.yml/badge.svg)](https://github.com/fccarlier-be/nextstep/actions/workflows/ci.yml)

*English summary below.*

---

## Pourquoi NextStep ?

Pour bien monter un personnage, on finit souvent par installer une quinzaine d'addons : un guide, un suivi de quêtes, une flèche, un comparateur d'équipement, des sacs unifiés, une minimap améliorée… NextStep les regroupe dans un seul addon cohérent, avec une seule fenêtre d'options.

## Fonctionnalités prévues

### Guide de leveling
- Une route étape par étape, adaptée à **ta race, ta classe et ton niveau**.
- **Deux modes** : *strict* (une étape à la fois) et *libre* (tu choisis l'ordre des objectifs d'un même lieu).
- **Les détours sont acceptés** : prends une suite de quêtes hors route, le guide se recale tout seul à ton retour.
- Conseil de **zone suivante**, avec plusieurs chemins au choix.
- Une **flèche** de navigation, des points sur la **carte** et la **minimap**.

### Métiers
- Un **conseiller** qui suggère des métiers selon ta race, ta classe et ton objectif (leveling, or, end game).
- Des **routes de métier** (où farmer, quoi fabriquer, quand voir le maître), intégrées au guide de leveling.

### Équipement
- Les **récompenses de quête** conseillées, mises en évidence (jamais choisies à ta place).
- Le gain ou la perte affiché dans les **infobulles**, et une **alerte** quand tu ramasses une amélioration.
- Les **items à ne pas rater** à chaque tranche de niveaux, et les jalons importants (sacs, monture, quêtes de classe).

### Interface
- **Valeurs de vie et de ressources** sur les cadres d'unité et les nameplates.
- **Sacs et banque unifiés**, banque consultable à distance, vente automatique de la camelote.
- **Minimap** carrée, zoom à la molette, coordonnées, boutons d'addons rangés, horloge avec **alarmes et minuteurs**.

## Principes

- **Un seul addon** à installer.
- **Aucune donnée envoyée** nulle part : NextStep ne communique avec aucun serveur. Tout reste sur ton PC.
- **Améliorer l'interface Blizzard plutôt que la remplacer**, pour limiter les erreurs et les conflits avec d'autres addons.
- **Libre et open source** sous licence GPL-3.0.

## Documentation

| Document | Contenu |
|---|---|
| [docs/ROADMAP.md](docs/ROADMAP.md) | Feuille de route et état d'avancement |
| [docs/DESIGN.md](docs/DESIGN.md) | Conception : architecture, moteur du guide, modules |
| [docs/DATA_SOURCES.md](docs/DATA_SOURCES.md) | Origine des données et licences |
| [docs/DATA_FORMAT.md](docs/DATA_FORMAT.md) | Format des données et procédure d'import |
| [CHANGELOG.md](CHANGELOG.md) | Historique des versions |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Conventions pour contribuer |
| [CREDITS.md](CREDITS.md) | Remerciements et projets réutilisés |

## Compatibilité

- **Jeu** : WoW Forever (client moderne, interface `16001`).
- **Langues** : français et anglais.

## Installation

Pas encore disponible. NextStep sera publié sur CurseForge une fois la première version jouable prête.

## Licence

NextStep est distribué sous la [GNU General Public License v3.0](LICENSE). Il réutilise des données et des bibliothèques d'autres projets libres, crédités dans [CREDITS.md](CREDITS.md).

---

## English summary

**NextStep** is an all-in-one addon for **WoW Forever**: a race/class-aware leveling guide that tolerates detours, profession advice and routes, gear upgrade hints, and light Blizzard UI improvements (unit values, unified bags and bank, square minimap, clock timers). One addon instead of fifteen. It never sends any data anywhere. **Status: design phase**, no playable release yet. Licensed under GPL-3.0.
