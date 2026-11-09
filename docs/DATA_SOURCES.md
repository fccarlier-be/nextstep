# Sources de données

NextStep **importe** ses données au lieu de dépendre d'autres addons à l'exécution : un seul addon à installer, et un format interne stable. Un script d'import (hors addon, non distribué) convertit les données sources vers le format NextStep.

## Sources retenues

| Source | Contenu utilisé | Licence | Remarques |
|---|---|---|---|
| [Polestar](https://github.com/fitzforge/polestar) — guides compilés (`addon/Polestar_Guides*/Guides.lua`) | Routes de leveling, de classe et de métiers | GPL-3.0-only ; faits repris de pfQuest (MIT) et de CMaNGOS classic-db (GPL-3.0), entre autres : voir le `LICENSE-DATA.txt` du pack | Format compilé versionné (`format = 8` au 2026-11-03) ; l'import refuse un format inconnu, ou une licence autre que GPL-3.0-only |
| Polestar — `forever-db` | Quêtes des donjons et toute leur chaîne : titres, niveaux, factions, races et classes, prérequis, donneurs et destinataires avec leur position, récompenses ; **intégré** (`Data/Imported/Polestar/Dungeons.lua`, `Tools/import/dungeons.py`) ; vendeurs de munitions présumés sur leur titre (`AmmoVendors.lua`, `Tools/import/ammo.py`) ; le reste prévu en phase 10 | GPL-3.0 (base), CC BY 4.0 (couche « étapes », non reprise) ; sources créditées dans `ForeverDB-NOTICE.md`, recopié à côté des données | JSON Lines avec schémas ; versions `data-vAAAA.MM.N`. Aucun point d'apparition dans les donjons |
| Polestar — `Polestar_ItemDB` | Butin choisi des boss (avec le taux), provenance des items de leveling, caractéristiques des objets retenus (~2 500) ; **intégré** (`Dungeons.lua`) | GPL-3.0-only (tables du client) ; faits de *ForeverLevelingBiS* (MIT) : notice dans `ItemDB-LICENSE-DATA.txt` | ~10 000 items ajustés pour Forever. Les caractéristiques importées ne servent que si le client n'a pas l'objet en cache : il donne les chiffres de Forever (`C_Item.GetItemStats`) |
| Polestar — poids de stats (`Gear/Weights.lua`, `Gear/SpecData.lua`) | Poids par classe, spécialisation et tranche de niveaux, aptitudes d'équipement, traits raciaux ; **intégré** (`Data/Imported/Polestar/Gear.lua`, `Tools/import/gear.lua`) | GPL-3.0-only ; poids mêlés aux simulations de *wowsims* (MIT), traits raciaux de *ForeverLevelingBiS* (MIT) : notice dans `Data/Imported/Polestar/Gear-LICENSE-DATA.txt` | Tranches de niveau générées par l'outil de Polestar |
| Polestar — `Polestar_frFR` | Noms traduits (quêtes, PNJ, objets, zones) et textes des guides en français | GPL-3.0-only ; noms repris notamment de DingDB (GPL-3.0, Yendi) et de pfQuest (MIT) : voir le `LICENSE-DATA.txt` du pack | Noms extraits des tables du client |
| [HereBeDragons](https://github.com/Nevcairiel/HereBeDragons) | Bibliothèque : points sur la carte et la minimap, conversion de coordonnées | BSD (déclarée dans le TOC) | Prend en charge Forever (`WOW_PROJECT_CAMELOT`). **Non utilisée** : les repères de la carte et de la minimap sont du code propre (v0.1.0) |
| [What's Training](https://github.com/fusionpit/WhatsTraining) | Sorts de chaque classe chez le maître : niveau, rang, coût, prérequis, race, faction, talent et compétence requis ; **intégré** (tables `Classes/Camelot`, celles de Forever, importées par `Tools/trainer/`, notice MIT dans `Data/Imported/WhatsTraining/LICENSE-DATA.txt`) | MIT | Prend en charge Forever ; tables `Classes/Vanilla/*.lua` à importer, notice MIT à conserver |
| [GatherMate2](https://github.com/Nevcairiel/GatherMate2) | Idée de la détection des récoltes (sort lancé et objet ciblé) | GPL-2.0-or-later | Ni code ni données repris : le module Points de récolte (phase 9) est du code propre à NextStep |
| Tables du client Forever (`WorldMapOverlay`, `WorldMapOverlayTile`) | Textures des zones inexplorées de la carte (module prévu en phase 5) ; données extraites : `Data/Imported/Client/MapOverlays.lua` | — | Extraites de l'installation locale (produit `wowf`) par TACTSharp et DBCD (MIT), avec les définitions de WoWDBDefs ; outils de développement, non livrés (`Tools/worldmap/`). Voir [DESIGN.md](DESIGN.md#carte-sans-brouillard) |
| Le client du jeu | Noms localisés (dont les noms de PNJ appris), état du journal de quêtes, recettes connues | — | Lu en jeu, conservé dans les sauvegardes locales, jamais redistribué |

## Sources écartées

| Source | Raison |
|---|---|
| QuestieDB | Aucune licence déclarée pour les données ; réutilisation impossible sans accord des mainteneurs. forever-db la cite parmi ses sources, mais ne publie que les valeurs qu'au moins une source libre confirme (une valeur connue d'une seule source fermée est laissée de côté, selon son README) : ce sont ces valeurs que NextStep importe |
| Sources `.guide` de Polestar | Elles-mêmes générées par l'outil de Polestar ; certaines instructions ne sont résolues qu'à la compilation, avec des données non publiées |
| `Polestar_Nav`, `Legs.lua` | Chemins de marche précalculés, trop volumineux (~38 Mo) et liés au système de navigation de Polestar |
| `Polestar_Recorder` et service de collecte | NextStep n'enregistre ni n'envoie aucune donnée |
| Guides gratuits sans licence (ForeverWisp, PexGuide, Follow The Arrow…) | Gratuit ne signifie pas réutilisable |
| Guides payants (RestedXP, Zygor…) | Propriétaires |
| Wowhead | Conditions d'utilisation : pas d'aspiration ; vérification manuelle uniquement |
| BlizzMove, Leatrix Maps, Mapster (dont la table `FogClearDataForever.lua`), DungeonJournal, Auctionator | « All Rights Reserved » : ni code ni données repris ; NextStep écrit ses propres équivalents |
| GatherMate2_Data | Extraction de Wowhead, sans licence ; données du jeu moderne, pas de Forever |
| AtlasLootClassic | GPL-2.0 sans la mention « ou ultérieure », incompatible avec GPL-3.0-only ; pas de prise en charge de Forever |
| Skyrim Level-Up (RGX) | Code sous MIT, mais le son vient de Skyrim (droits de Bethesda) |

## Version importée

La version de Polestar importée est fixée dans [`Tools/import/polestar.lock`](../Tools/import/polestar.lock), et le résultat du dernier import est décrit dans [`Tools/import/last-import.md`](../Tools/import/last-import.md). Procédure : [DATA_FORMAT.md](DATA_FORMAT.md#import).

## Corrections propres à NextStep

Les corrections et ajouts écrits à la main vivent dans `Data/Overrides/`, au format Lua de NextStep. Ils sont appliqués **après** les données importées et survivent aux réimports.

- `Data/Overrides/Guides.lua` : `DB:AddGuideFix(function(guide) ... end)`, appliquée à chaque guide chargé (`DB.AddGuide`), y compris ceux de faction chargés plus tard.
- Corrections en place : achat du tube en bronze (4371) déplacé de Herble Baubbletump (Sombre-Comté, qui n'en vend pas sur Forever) à Neal Allen (Port de Menethil) ; acceptation des « Lingots de sancteforge » (526) retirée, Glorin Steelbrow ne la propose pas sur Forever (les mêmes lingots viennent par « Les lingots perdus », 324).
- Une erreur de guide trouvée en jeu se corrige ici, et se signale aussi à Polestar.

## Obligations

- NextStep est distribué sous GPL-3.0-only, la licence des données de Polestar qu'il contient. Le texte de la licence est livré dans l'addon (`addon/NextStep/LICENSE.txt`, copie de `LICENSE`, vérifiée par les tests).
- Polestar, pfQuest, Ding/DingDB, CMaNGOS classic-db, ForeverLevelingBiS, wowsims et forever-db (données intégrées), sont crédités dans [CREDITS.md](../CREDITS.md).
- Mentions conservées (GPL-3.0, section 4 ; licence MIT de pfQuest) : chaque fichier généré rappelle le copyright de Polestar et sa licence, et l'import recopie sans modification les notices de Polestar (`LICENSE-DATA.txt` des packs, `CREDITS.md` de DingDB) dans un `LICENSE-DATA.txt` à côté des données.
- Si un pack de Polestar change de licence (`## X-License` de son TOC), l'import s'arrête jusqu'à ce que ces crédits soient revus.
- Chaque import consigne la version exacte de la source utilisée.
- Une bibliothèque intégrée, s'il y en a un jour, garde son fichier de licence dans son dossier.

## Limites connues des données

- **Contenu au-delà du niveau 30** : selon Polestar, certaines données (notamment l'emplacement des nodes de récolte) sont supposées identiques au Classic, faute de confirmation par la bêta.
- **Noms français** : au premier import, Polestar ne fournit un nom français que pour environ la moitié des PNJ cités ; les autres s'affichent en anglais jusqu'à ce que le module Noms appris les rencontre en jeu. Régions, zones, sorts et compétences sont traduits par le client en jeu.
- **Quêtes des donjons** : rattachées par la zone, les boss ou le titre (voir [DATA_FORMAT.md](DATA_FORMAT.md#donjons)) ; une quête de donjon rangée ailleurs par forever-db et absente de la liste écrite à la main peut manquer.
- **Butin des donjons** : `Polestar_ItemDB` n'a qu'une sélection d'objets par boss (19 donjons) et forever-db aucun équipement de boss ; complété en jeu par le butin appris (voir [DESIGN.md](DESIGN.md#7-items)).
- **Métiers** : `forever-db` ne documente ni maîtres de métier, ni recettes, ni nodes ; ces informations viennent des guides de métiers de Polestar et d'une table maintenue à la main.
