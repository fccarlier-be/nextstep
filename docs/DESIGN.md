# Conception de NextStep

Ce document consigne les décisions de conception prises avant le développement. Il sert de référence : toute modification importante d'une décision doit être reportée ici et dans le [CHANGELOG](../CHANGELOG.md).

Les points marqués **[À vérifier]** dépendent du comportement réel du client et seront tranchés lors de la phase 1 de la [feuille de route](ROADMAP.md).

## Sommaire

1. [Contexte technique](#1-contexte-technique)
2. [Principes](#2-principes)
3. [Architecture](#3-architecture)
4. [Données](#4-données)
5. [Moteur du guide](#5-moteur-du-guide)
6. [Métiers](#6-métiers)
7. [Items](#7-items)
8. [Interface du guide](#8-interface-du-guide)
9. [Module UI](#9-module-ui)
10. [Idées à l'étude](#10-idées-à-létude)

---

## 1. Contexte technique

WoW Forever est un client officiel Blizzard au contenu de style Classic, construit sur le **moteur moderne** (base 12.0).

| Élément | Valeur |
|---|---|
| Numéro d'interface | `16001` (patch 1.60.1) |
| Nom de code / suffixe TOC | `Camelot` → `NextStep_Camelot.toc` (le nom pourrait changer) |
| `WOW_PROJECT_ID` | `WOW_PROJECT_CAMELOT` |
| Lua | 5.1 modifié : pas de `goto`, pas d'opérateurs bit à bit natifs (bibliothèque `bit`), pas de `io`, `os`, `require` |
| API | Espaces de noms modernes (`C_Item`, `C_Spell`, `C_Map`, `C_Container`, `C_QuestLog`, `C_TooltipInfo`…). Beaucoup d'anciennes fonctions globales n'existent plus (`GetItemInfo`, `GetSpellInfo`, `GetItemStats`, `UnitAura`, `GetContainerItemInfo`…) |
| Cartes | `uiMapID` du Classic (ex. forêt d'Elwynn = `1429`) |
| Dossier du jeu | `World of Warcraft\_forever_\` ; addons dans `_forever_\Interface\AddOns\` (créé au premier lancement) |

### Secret values

En combat, certaines valeurs transmises aux addons sont **secrètes** : leur type est normal (`number`, `string`), mais toute comparaison ou opération arithmétique provoque une erreur. Sont concernés notamment `UnitHealth`, certains noms d'unités et certains booléens (`UnitExists`, `UnitCanAttack`). `COMBAT_LOG_EVENT_UNFILTERED` n'est pas utilisable.

Règles pour NextStep :
- ne jamais comparer ni calculer sur une valeur potentiellement secrète ;
- la transmettre telle quelle aux widgets (`StatusBar:SetValue`, textes) ;
- tester avec `issecretvalue` quand la fonction existe.

### Actions protégées et combat

- Vérifier `InCombatLockdown()` avant de montrer, cacher ou déplacer un cadre protégé ; différer à `PLAYER_REGEN_ENABLED`.
- Ne jamais écrire d'attributs sécurisés sur les cadres Blizzard.
- Un appel bloqué peut échouer sans erreur Lua : le client affiche « Interface action failed because of an AddOn ».

---

## 2. Principes

1. **Un seul addon** pour l'utilisateur (éventuellement découpé en sous-dossiers chargés à la demande, livrés ensemble).
2. **Aucune donnée envoyée** : pas d'enregistrement de session, pas d'application compagnon.
3. **Améliorer l'interface Blizzard, ne pas la remplacer** ; activer d'abord les options natives quand elles existent.
4. **Les faits sont séparés des routes** ; le moteur ne connaît pas l'origine des données.
5. **Toute logique de jeu dans les données, pas dans le code** quand elle peut changer (seuils, bonus raciaux, prix…).
6. **Identifiants plutôt que noms** : l'addon fonctionne quelle que soit la langue du client.

---

## 3. Architecture

```
addon/                       -- les dossiers d'addon, seuls livrés aux joueurs
├── NextStep/                -- cœur + données communes, toujours chargé
│   ├── NextStep.toc
│   ├── Core/                -- initialisation, événements, sauvegardes, modules, options, commandes
│   ├── Libs/                -- LibStub, CallbackHandler, HereBeDragons
│   ├── Locales/             -- traductions (les clés sont les textes anglais)
│   ├── Data/
│   │   ├── Imported/        -- généré par le script d'import, jamais modifié à la main
│   │   └── Overrides/       -- corrections et ajouts NextStep, appliqués en dernier
│   └── Modules/
│       ├── Guide/           -- moteur, état du joueur, navigation, fenêtre et flèche du guide
│       ├── Professions/
│       ├── Items/
│       └── UI/
├── NextStep_Alliance/       -- données Alliance, chargées à la demande
└── NextStep_Horde/          -- données Horde, chargées à la demande
Tools/                       -- scripts de développement et d'import (non livrés)
tests/                       -- tests hors jeu et simulation de l'API du jeu
docs/
```

### Fichiers TOC

Un seul fichier `NextStep.toc` par addon, **sans suffixe de version** (`_Camelot`) : NextStep ne vise que Forever, et un suffixe dont le nom pourrait changer avant la sortie serait un risque inutile. Polestar fait le même choix. `## Interface: 16001`.

### Cœur

| Fichier | Rôle |
|---|---|
| `Core/Init.lua` | Espace de noms `ns` (seule globale : `NextStep`), `ns:Print`, `ns.SafeCall` |
| `Core/Locale.lua`, `Locales/*.lua` | Table `ns.L` ; une clé sans traduction s'affiche telle quelle (anglais) |
| `Core/Events.lua` | Un seul cadre écoute le jeu ; abonnés identifiés par un propriétaire ; messages internes ; erreur d'un abonné isolée des autres |
| `Core/Storage.lua` | `NextStepDB` (compte) et `NextStepCharDB` (personnage), numéro de schéma, migrations, valeurs par défaut |
| `Core/DB.lua` | Couche d'accès aux données : guides, noms, traductions, rendu des textes (voir [DATA_FORMAT.md](DATA_FORMAT.md)) |
| `Core/Modules.lua` | Registre des modules : cycle `OnInitialize` → `OnEnable` / `OnDisable`, état mémorisé, détection des addons concurrents |
| `Core/Factions.lua` | Chargement de l'addon de faction ; message `NEXTSTEP_FACTION_LOADED` |
| `Core/Options.lua` | Panneau dans Options > AddOns (API `Settings`) : une case par module, sa description et ses réglages (`module:BuildOptions`) |
| `Core/Slash.lua` | `/ns` et `/nextstep` : `help`, `version`, `modules`, `enable`, `disable`, `options` ; les modules ajoutent leurs commandes (`guide`, `arrow`, `radar`) |
| `Core/Boot.lua` | `ADDON_LOADED` → sauvegardes, modules, options ; `PLAYER_LOGIN` → faction, activation des modules |

### Chargement par faction

Le cœur et les données communes (classes, métiers, réputations, zones, PNJ neutres) sont toujours chargés. À la connexion, le cœur lit la faction du personnage et charge `NextStep_Alliance` ou `NextStep_Horde` (`C_AddOns.LoadAddOn`). L'autre n'est jamais lu.

**[À vérifier]** La race Skyborne existe dans les deux factions : s'assurer que la faction est connue au moment du chargement.

### Couche d'accès aux données

Le moteur n'accède jamais directement aux tables de données ; il passe par `ns.DB` (`DB:GetGuide(id)`, `DB:IterateGuides(filter)`, `DB:GetName(kind, id)`, `DB:Render(text)`…). Changer de source, de format ou de stratégie de chargement ne touche que cette couche.

### Modules

Chaque module (et chaque sous-module UI) s'enregistre auprès du cœur, peut être activé ou désactivé dans les options, et se désactive s'il détecte un addon concurrent (Bagnon, ElvUI…), en le signalant.

---

## 4. Données

Les sources et licences sont détaillées dans [DATA_SOURCES.md](DATA_SOURCES.md).

Le format exact des fichiers, la couche d'accès `ns.DB` et la procédure d'import sont décrits dans [DATA_FORMAT.md](DATA_FORMAT.md). Les principes :

- **Import, pas dépendance** : les guides compilés de Polestar sont convertis par `Tools/import/import.lua`, exécutés dans un environnement isolé. Le numéro de format est vérifié (`format = 8` au 2026-11-03) : un format inconnu est refusé plutôt que de produire des données fausses. L'import est reproductible et consigne la version source.
- **Structure** : guide → étapes → objectifs. Chaque étape regroupe les objectifs à accomplir ensemble au même endroit. Le vocabulaire (types d'objectifs `accept`, `turnin`, `kill`, `collect`, `goto`…, conditions `when`, restrictions `only`, `along`, `label`, `skipto`) est celui de Polestar, pour que l'import reste quasi direct.
- **Races et classes en jetons** (`HUMAN`, `SCOURGE`, `WARRIOR`…), jamais en masques de bits : les ID raciaux de Skyborne (95, 96) dépassent 32 bits, la limite de la bibliothèque `bit` de Lua 5.1.
- **Pas de noms dans les guides** : les textes contiennent des emplacements `{genre:id}`, remplacés à l'affichage par le nom dans la langue du client (traduction importée, puis nom fourni par le client, puis anglais).
- **Coordonnées en pourcentage de carte, dans leur repère d'origine** : les coordonnées marquées `f = "e"` sont dans le repère *era* du Classic et sont **converties en jeu**, car les repères des cartes de Forever ne sont connus que du client. Les repères *era* sont importés (`DB.mapFrames.era`).
- **Seules les données utilisées sont importées** : les guides, les noms qu'ils citent et leurs traductions. Les statistiques d'items (phase 6) et les faits de forever-db pour le mode conseil (phase 10) seront importés avec les modules qui en ont besoin.

### Noms appris

Polestar ne traduit qu'une partie des noms de PNJ. Le module **Noms appris** (`Modules/Names.lua`) complète les traductions avec les noms que le client affiche :

- **Actif par défaut sur tous les clients non anglais**, désactivable dans les options. Sur un client anglais, il ne fait rien (les noms importés sont complets).
- **Sources** : cible, survol, nameplates, dialogue avec un PNJ (dialogue, quête, marchand, maître). L'identifiant du PNJ est lu dans son GUID (`Creature-0-…-<id>-…`), le nom avec `UnitName`.
- **À la demande** : le nom d'un PNJ jamais croisé est demandé au client par son infobulle (`C_TooltipInfo.GetHyperlink("unit:Creature-0-0-0-0-<id>-…")`), une seule fois par session. **[À vérifier]** sur Forever.
- **Jamais en combat**, et toute valeur secrète est ignorée.
- **Priorité** : le nom vu en jeu passe **avant** la traduction importée, car c'est celui que le jeu affiche réellement.
- **Stockage** : sauvegardes du compte (`NextStepDB.modules.Names.learned[locale]`), partagées par tous les personnages. Rien n'est envoyé.
- **Désactiver** arrête la collecte ; les noms déjà appris restent utilisés jusqu'à ce qu'on les efface (bouton « Oublier les noms appris »).

Ce n'est pas un enregistrement d'activité : seule une correspondance identifiant → nom est conservée.

---

## 5. Moteur du guide

Fichiers : `Modules/Guide/Conditions.lua` (à qui s'adresse une étape, dans quel état), `Goals.lua` (état d'un objectif selon son type), `Engine.lua` (parcours du guide), `Guide.lua` (module : guide actif, progression sauvegardée). Le moteur est **pur** : il ne lit jamais le jeu, il interroge un objet « état du joueur ». Dans les tests, c'est une simulation (`tests/player.lua`) ; en jeu, ce sera l'API du client, branchée en phase 4 avec les événements.

### Règles fondamentales

1. **L'étape courante est calculée, jamais stockée.** À chaque recalcul, le moteur parcourt le guide depuis le début et s'arrête à la première étape qui retient le joueur.
2. **Une étape dépassée garde son résultat** (faite, hors sujet, sautée, en chemin), comme dans Polestar : une étape « achète de l'eau » passée parce que les sacs étaient pleins ne revient pas quand l'eau est épuisée. Ces résultats sont mémorisés **par clé stable**, jamais par position : le `label` de l'étape, sinon la signature de ses premiers objectifs (type, quête, PNJ, objet). Ajouter ou déplacer une étape dans une nouvelle version d'un guide ne fausse donc pas la progression.
3. **Les choix du joueur sont sauvegardés** de la même façon : étapes ignorées, validations manuelles, réponses aux quêtes de groupe.
4. **Rien n'est mémorisé tant que le journal de quêtes n'est pas lu** (juste après la connexion), pour ne pas enregistrer des étapes comme hors sujet à tort.

### États d'une étape

| État | Signification |
|---|---|
| `current` | L'étape courante |
| `ahead` | Après l'étape courante ; ses objectifs sont déjà évalués (étape faite en avance) |
| `done` | Ses objectifs non facultatifs sont accomplis |
| `na` | Hors sujet : autre race ou classe, condition `when` fausse au passage, ou tous ses objectifs hors sujet |
| `skipped` | Ignorée par le joueur (réversible) |
| `jumped` | Sautée par un `skipto` du guide (réversible) |
| `along` | Étape « en chemin » : la route ne s'y arrête pas, ses objectifs ouverts sont listés sous l'étape courante, jusqu'à l'étape indiquée ou jusqu'à ce qu'ils soient faits |
| `ask` | La route attend la réponse du joueur pour une quête de groupe (la faire ou la passer) |

### États d'un objectif

| État | Signification | Retient l'étape |
|---|---|---|
| `done` | Accompli (ou implicite : un déplacement est accompli dès qu'un objectif suivant de l'étape l'est) | Non |
| `todo` | À faire | Oui |
| `blocked` | À faire mais impossible pour l'instant ; aujourd'hui, niveau insuffisant pour accepter une quête | Oui (l'étape affiche la raison) |
| `manual` | Invisible pour l'addon (parler à un PNJ, voir un maître, utiliser un objet sans quête) : validé par le joueur ou par un événement du jeu | Oui |
| `na` | Hors sujet ou plus disponible : quête fermée par une quête exclusive, prérequis manquant, quête dont l'acceptation a été ignorée ou sautée | Non |
| `info` | Simple note | Non |

Un objectif `optional` ne retient jamais l'étape.

**Prérequis manquant ou quête fermée : hors sujet plutôt que bloqué.** Un prérequis que la route n'apporte plus ne viendra jamais : bloquer le guide indéfiniment serait pire. Seul le niveau bloque, car il finit toujours par venir.

**Une quête écartée emporte ses objectifs** : si l'acceptation d'une quête est ignorée, sautée ou hors sujet, sa remise et ses objectifs plus loin le sont aussi, sauf si le joueur a quand même la quête dans son journal.

### Quête abandonnée

Le guide **ne recule pas tout seul** : une étape dépassée reste dépassée (règle 2), et un abandon peut être volontaire. Le moteur signale la quête abandonnée (acceptée dans une étape dépassée, absente du journal, et rendue plus loin dans le guide) ; l'interface propose de revenir à l'étape d'acceptation (`Guide:Reopen`).

### Conditions et sauts

Sémantique de Polestar (voir [DATA_FORMAT.md](DATA_FORMAT.md#conditions-when)) :
- `only` (race, classe, faction) est vérifié à chaque recalcul ; `when` est vérifié tant que l'étape n'est pas dépassée, puis son résultat est gardé. Une étape réactivée par le joueur s'applique ensuite quelles que soient ses conditions `when`.
- `skipto` est vérifié **à l'arrivée** sur l'étape, si elle n'est pas déjà faite : le bloc jusqu'à l'étape nommée est sauté, une fois pour toutes. Réactiver l'étape qui a déclenché le saut annule ce saut définitivement.
- `when done <label>` est vrai si l'étape nommée a été réellement faite (ni ignorée, ni sautée, ni hors sujet).
- Quête de groupe sans réponse : la route attend à l'étape et pose la question ; une étape « en chemin » n'attend pas ; une quête déjà rendue ne demande rien.

### Modes

- **Strict** : une seule étape à la fois.
- **Libre** : les objectifs ouverts de l'étape courante et des étapes suivantes au même endroit (même carte), au plus 6 étapes, jusqu'à un trajet en vol ou par la pierre de foyer. L'interface les trie par distance.

Les deux modes utilisent **le même moteur** ; seul l'affichage change.

### Détours et conseils

| Situation | Réaction |
|---|---|
| Quête du journal que le guide ne cite pas | Listée comme « détour », sans contredire le joueur |
| Étape faite en avance | Validée automatiquement en y arrivant |
| Retour après un détour | Reprise à la première étape non faite |
| Personnage plus haut que le guide | Signalé (`advice.overleveled`), avec le nombre de quêtes grises à venir (`advice.greyAhead`, formule du Classic) |
| Niveau insuffisant | Étape bloquée avec le niveau requis |

### Enchaînement

- En fin de guide, le moteur renvoie les guides suivants (`next`) ; l'interface les propose (« Choisis ton chemin »). Dans les données importées, chaque guide a au plus un suivant.
- **Guide de départ** : `Guide:Suggest` propose les guides de leveling de la faction et de la classe du personnage, à son niveau. La race n'exclut aucun guide : on peut commencer dans la zone de départ d'une autre race. Ordre : le guide de la zone où se trouve le joueur (carte actuelle ou l'une de ses parentes), puis ceux de sa race, les guides communs, et ceux des autres races.
- **Quêtes de classe** : `Guide:ClassGuides` retient les guides de la catégorie `Class` de la classe, de la faction et de la race du personnage, de leur niveau minimal jusqu'à 5 niveaux au-delà du maximal, sauf ceux terminés (`char.completed`) ou dont le personnage connaît déjà les sorts appris (`reward`). La fenêtre en propose deux au plus, sous l'étape (ou sous les guides de départ) ; un clic lance la quête de classe et mémorise le guide de leveling (`char.returnTo`), proposé à la fin (« Reprendre : … »). Exemple : « Dresser une bête » du chasseur au niveau 10.
- Un guide actif remplacé dans Polestar (identifiant retiré) est abandonné à la connexion.
- **Mode conseil** (phase 10) : sans route active, les zones et les quêtes adaptées au niveau, à la race et à la classe.

### Recalcul

`Guide:Refresh` évalue le guide actif, mémorise les étapes dépassées et envoie le message `NEXTSTEP_GUIDE_UPDATED` (le résultat complet, ou `nil` sans guide suivi) à l'interface. Il est déclenché par les événements du jeu (`Modules/Guide/Live.lua`) : quêtes (acceptées, rendues, mises à jour), niveau, expérience, zone, sacs, compétences, sorts, réputations, argent. Les rafales d'événements sont regroupées en un seul calcul (0,1 s). Un minuteur d'une seconde ne recalcule le guide que si un objectif ouvert dépend de la position (`goto`, `explore`) ; sinon, il ne fait que mettre à jour la cible la plus proche.

**État du joueur** (`Modules/Guide/State.lua`) : il répond au moteur avec l'API du jeu, comme le joueur simulé des tests. Journal de quêtes, objets, compétences et sorts sont gardés en cache, vidé par catégorie selon l'événement reçu. Le journal n'est considéré comme lu qu'après le premier `QUEST_LOG_UPDATE` : avant, rien n'est mémorisé. Les régions (`InArea`, `BoundAt`) sont comparées par leur nom, celui du client puis celui du guide. Les points de vol connus sont relevés à chaque ouverture de la carte des vols et sauvegardés par personnage. Toute valeur secrète est ignorée.

**[À vérifier]** `C_QuestLog` (`GetInfo`, `GetQuestObjectives`, `IsQuestFlaggedCompleted`), `GetSkillLineInfo` et le nom des lignes de compétence, `C_Reputation`, `GetBindLocation`, `C_TaxiMap.GetAllTaxiNodes`, valeurs secrètes en combat.

### Vérification

En plus des scénarios unitaires (`tests/spec/engine_spec.lua`, `guide_spec.lua`), un **joueur automatique** (`tests/autoplay.lua`) parcourt chaque guide importé, pour chaque faction, en faisant ce que demande l'étape courante : chacun doit aller jusqu'au bout. C'est le garde-fou contre une régression du moteur ou un changement de données après un import.

---

## 6. Métiers

### Conseiller

Un score par métier, calculé à partir de trois tables de données :

```lua
NS.DB.professionAdvice = {
    race  = { GNOME = { ENGINEERING = 3 }, TAUREN = { HERBALISM = 3 } },
    class = { MAGE = { TAILORING = 3, ENCHANTING = 2 } },
    goal  = { LEVELING = { SKINNING = 2, MINING = 2 }, GOLD = { ... }, ENDGAME = { ... } },
}
```

- L'objectif (leveling, or, end game) se choisit dans les options.
- Le conseiller affiche les 2 ou 3 meilleures combinaisons avec leurs raisons ; le joueur choisit.
- Métiers secondaires (secourisme, cuisine, pêche) conseillés à part.
- **[À vérifier]** Les bonus raciaux de Forever peuvent différer du Classic : ils sont dans les données, pas dans le code.

### Intégration à la route

Le moteur **assemble** à l'affichage la route de leveling et la route de métier (aucune route n'est écrite par combinaison de métiers) :

1. étapes de métier insérées (maître au bon niveau, composants quand on passe devant le vendeur), marquées « métier » et ignorables ;
2. choix de la zone suivante favorisant les ressources adaptées à la compétence ;
3. rappels contextuels (« cette zone a du fer, ta compétence te permet de le miner »).

Une session de farm peut basculer temporairement sur la route de métier ; le retour au leveling se fait là où le joueur en était.

### Points de récolte

Code repris de GatherMate2 (GPL-2.0-or-later, donc réutilisable sous GPL-3.0), adapté au format de NextStep ; ses données (extraction de Wowhead) ne sont pas reprises.

- Chaque récolte (herbe, minerai, coffre, banc de poissons…) est enregistrée automatiquement : carte, coordonnées, type de ressource. Les points très proches sont fusionnés.
- Affichage sur la carte et la minimap (HereBeDragons), filtrable par type ; utilisé par les routes de métier pour « où farmer ».
- Données au niveau du compte, partagées entre les personnages du joueur ; rien n'est envoyé.
- **[À vérifier]** Détection fiable d'une récolte (sort lancé, butin, nom de l'objet ciblé).

---

## 7. Items

### Calcul du score

`Modules/Items/Score.lua` est **le seul** endroit où le score est calculé : capacité à porter l'objet (classe), puis somme pondérée des stats selon la spécialisation et la tranche de niveaux. Les stats viennent de la base importée ; la lecture du tooltip (`C_TooltipInfo`) ne sert qu'en secours.

### Spécialisation

Détectée automatiquement (arbre de talents le plus rempli), **modifiable à la main**. Import d'échelles Pawn envisagé plus tard.

### Fonctions

| Fonction | Décision |
|---|---|
| Récompenses de quête | Item conseillé **mis en évidence** avec la raison ; **jamais choisi automatiquement**. Sans amélioration : l'item le plus cher à revendre |
| Infobulles | Gain ou perte par rapport à l'équipement porté |
| Alerte d'amélioration | Au **centre de l'écran, légèrement au-dessus du milieu**, déplaçable ; **jamais en combat** (différée) ; seuil minimal réglable ; améliorations successives regroupées ; fermeture automatique ou clic droit |
| Items à ne pas rater | Par classe, spécialisation et tranche de niveaux, avec leur provenance ; mis en avant dans la route, proposés en détour, ou rattachés aux donjons recommandés |
| Jalons | Sacs, quêtes de classe, monture, sorts à apprendre (voir [Sorts à apprendre](#sorts-à-apprendre)) ; seuils dans les données |
| Butin des donjons | Récompenses de chaque donjon et de chaque boss ; améliorations pour la spécialisation mises en évidence avec le gain. Enrichit le journal des donjons natif s'il existe, sinon onglet du journal NextStep. Inspiré de DungeonJournal (« All Rights Reserved ») : code propre. AtlasLootClassic est incompatible (GPL-2.0 seule). Données : voir ci-dessous |

**[À vérifier]** Possibilité d'équiper un objet depuis l'alerte. Sinon, le clic ouvre les sacs avec l'objet en surbrillance.

**Données du butin des donjons** (vérifiées sur Polestar 0.3.0) :

- `Polestar_ItemDB` (`Forever.lua`, provenance `d<pnj>x<chance>z<zone>`) : 411 butins de 135 boss dans 19 donjons, dont 4 propres à Forever, avec leur taux. Seuls les objets retenus par ForeverLevelingBiS y figurent (environ 3 par boss) : c'est une sélection, pas la table complète. Maraudon, le Temple englouti, les Profondeurs de Rochenoire et Haches-Tripes manquent ; Zul'Farrak n'a qu'un objet.
- forever-db (`item_source.jsonl`) : 38 105 sources, mais pour les boss seulement les objets de quête, tissus et consommables, aucune pièce d'équipement ; aucun point d'apparition en donjon.
- Conséquence : le module part de `Polestar_ItemDB`, l'objectif « améliorations pour ta spécialisation » étant couvert, et complète avec le **butin appris** : objets vus en ouvrant le butin d'un boss (`LOOT_OPENED`, PNJ source par `GetLootSourceInfo`), mémorisés au niveau du compte, comme les noms appris. La liste complète d'un donjon n'est donc pas garantie.

**[À vérifier]** Présence du journal des donjons (`EncounterJournal`) sur Forever ; s'il existe, il fournit la liste complète.

---

## 8. Interface du guide

**Style** : épuré, dans les couleurs de l'interface Blizzard.

### Fenêtre du guide

```
┌─ NextStep ─────────────── Elwynn 1-11 ─ ⚙ ─ ▾ ┐
│ ▶ Le camp des kobolds                          │
│   ☐ Tuer des Vermines kobolds       6/10       │
│   ☑ Ramasser de la viande de loup   8/8        │
│   ☐ (facultatif) Livre grignoté                │
│   ℹ Les kobolds creusent dans les vignes au    │
│     nord-est de l'abbaye.                      │
│ ────────────────────────────────────────────── │
│   Ensuite : Abbaye de Comté-du-Nord            │
│ ────────────────────────────────────────────── │
│ ⤷ Détours : 2 quêtes hors route                │
│ [Ignorer]  [Valider]            Strict ▸ Libre │
└────────────────────────────────────────────────┘
```

Déplaçable, redimensionnable, réductible à une ligne ; verrouillage, échelle, transparence, estompage en combat en option.

**Version v0.1** (`Modules/Guide/Window.lua`) : déplaçable par la barre de titre, réductible à cette barre, verrouillable, position mémorisée. Contenu :

- l'étape courante et ses objectifs (coche, case vide, croix pour un objectif bloqué avec la raison) ; en mode libre, les objectifs ouverts du même endroit ;
- le conseil de l'étape, les objectifs à faire en chemin, les quêtes abandonnées (clic pour reprendre), l'étape suivante, le nombre de détours, l'avertissement « niveau dépassé » ;
- un objectif « à valider » se valide d'un clic ;
- au survol d'un objectif de quête, une infobulle donne son niveau, ses objectifs (texte du client, barrés une fois faits), le résumé et la description du journal de quêtes (lus en sélectionnant la quête un instant, la sélection du joueur est rendue) ; un clic ouvre le journal de quêtes du jeu sur la quête (`QuestMapFrame_OpenToQuestDetails`, sinon `QuestLogFrame`), hors combat. **[À vérifier]** journal de quêtes de Forever ;
- devant chaque objectif de quête, le **niveau de la quête coloré** selon l'écart avec celui du personnage, comme dans le jeu (`Labels.Difficulty`) : gris sous le niveau gris du jeu classique (aucun avant le niveau 6), vert, jaune de 2 niveaux en dessous à 2 au-dessus, orange à 3 ou 4 au-dessus, rouge à 5 ou plus ; le niveau vient du `qlvl` de l'objectif « accepter » de la quête ;
- la mention du contenu de groupe (élite, groupe de N, donjon, raid) ; les quêtes de classe disponibles, avec le retour au guide de leveling à leur fin ;
- **Ignorer** passe l'étape ; **Valider** valide ses objectifs « à valider », ou la passe s'il n'y en a pas ; **Strict / Libre** change de mode ;
- sans guide suivi, les trois premiers guides adaptés au personnage (clic pour commencer) ; à la fin d'un guide, les guides suivants ; pour une quête de groupe, Oui / Non.

**Formules traduites par modèle** (`Locales/GuideTexts_frFR.lua`, `DB:AddTemplates`) : quand un texte de guide n'a pas de traduction de Polestar, ses noms (`{npc:123}`…) deviennent `{1}`, `{2}`…, le modèle est cherché dans une table de formules récurrentes, puis les noms reprennent leur place (l'ordre peut changer). La liste vient des textes non traduits les plus fréquents (environ 7 000 textes de guide sans traduction au 2026-11-05) ; vouvoiement, comme Polestar.

**Libellés** (`Modules/Guide/Labels.lua`) : les objectifs importés n'ont presque jamais de texte. Le libellé est construit à partir du type et des noms (« Accepter … », « Tuer … »). Pour un objectif de quête, le texte du client est préféré : il est traduit et donne la progression (« Vermine kobold tuée : 6/10 »).

Redimensionnement, échelle, transparence et estompage en combat viendront avec les compléments.

### Flèche

- En haut au centre ; **désactivable**.
- Dessin plat et épuré (chevron avec contour sombre), couleur passant du doré Blizzard au vert dans la bonne direction, rouge-orangé à l'opposé ; rotation fluide ; distance et temps estimé ; coche à l'arrivée.
- Pour `kill` / `collect`, vise la zone de mobs la plus proche.
- **[À vérifier]** Position et orientation du joueur indisponibles en instance : flèche masquée en donjon.

**Version v0.1** (`Modules/Guide/Arrow.lua`) : texture de la flèche de la minimap, couleur verte (devant), dorée (de côté), rouge-orangé (derrière), distance, coche à moins de 5 mètres ; pas encore de temps estimé ni de dessin propre.

**Cible** : en mode strict, l'objectif ouvert le plus proche de l'étape courante (les facultatifs seulement s'il ne reste qu'eux, puis les objectifs en chemin) ; en mode libre, le plus proche de tous. Les points possibles d'un objectif sont sa position, les maîtres proposés au personnage (`candidates`, filtrés par classe et faction) et les zones d'apparition des mobs (`spotsPacked`) : le plus proche est choisi, et la cible est revue chaque seconde.

**Calculs** (`Modules/Guide/Navigation.lua`) : distance et direction se calculent en coordonnées monde, celles de `UnitPosition`. Les coordonnées « era » y passent directement par les cadres importés de Polestar (`DB.mapFrames.era`), les autres par `C_Map.GetWorldPosFromMapPos`. La conversion vers la carte du client (`C_Map.GetMapPosFromWorldPos`) ne sert qu'aux points sur la carte (complément v0.1.x).

**[À vérifier]** Axes de `UnitPosition` (nord, ouest) et cadres « era » des cartes que Forever a modifiées ; textures utilisées.

### Carte du monde et minimap

- **Repères de l'étape** (`Modules/Guide/Pins.lua`, code propre à NextStep) : tous les points des objectifs ouverts (position, maîtres proposés, zones d'apparition des mobs), jusqu'à 80 ; la cible de la flèche en doré et plus grande, les lieux en bleu, les zones de mobs en rouge (`Media/Pin.tga`, teinté, généré par `Tools/pins/textures.py`). Deux options, actives par défaut : minimap, carte du monde.
  - **Minimap** : calcul en coordonnées monde, comme la flèche ; échelle par `Minimap:GetViewRadius` (en secours, diamètres du client selon le zoom, dehors et en intérieur) ; rotation selon le regard si `rotateMinimap` est actif ; minimap ronde. Les points hors de la minimap sont cachés, sauf la cible, collée au bord. Mise à jour toutes les 0,05 s.
  - **Carte du monde** : fournisseur de données ajouté à `WorldMapFrame` (`MapCanvasDataProviderMixin`), rafraîchi à chaque changement de carte et de zoom ; boutons sur le canevas, de taille constante à l'écran, avec le libellé de l'objectif en infobulle. Projection par les bornes de la carte affichée, lues une fois par carte avec `C_Map.GetWorldPosFromMapPos`.
  - HereBeDragons n'est pas utilisé : le guide calcule déjà tout en coordonnées monde, et l'addon reste sans bibliothèque. **[À vérifier]** sur Forever : `Minimap:GetViewRadius`, minimap carrée, ajout d'un fournisseur à la carte du monde.
- En mode conseil (plus tard) : les donneurs de quêtes adaptés.
- Waypoint natif (`C_Map.SetUserWaypoint`) en option. Ne pas utiliser `C_SuperTrack.SetSuperTrackedUserWaypoint`.
- **Zoom à la molette** sur la minimap et sur la carte du monde. **[À vérifier]** zoom natif de la carte sur Forever.
- **Niveau des zones** affiché sur la carte du monde (tranche de niveaux, couleur selon le niveau du joueur), en appui du conseil de zone suivante.

### Journal

Grande fenêtre à onglets : **Routes** (dont « Choisis ton chemin »), **Métiers**, **Items**, **Zones**, **Options**.

**Réalisé** (`Modules/Guide/Journal.lua`), ouvert par le menu du bouton NextStep (« Journal du guide », « Sorts de classe »), `/ns journal` ou un raccourci ; déplaçable, Échap ou la croix pour fermer, listes à la molette :

- **Routes** : à gauche les catégories qui ont des guides pour le personnage (Leveling, Classe, Métiers, Réputation, Collection, Exploration, Divers, Ancien contenu), avec leur nombre ; au milieu les guides de la catégorie, rangés par dossier puis par niveau, avec la tranche de niveaux colorée comme le niveau des quêtes (gris en dessous, jaune dedans, orange ou rouge au-dessus) et l'avancement (suivi, terminé, ou pourcentage d'étapes passées) ; à droite le détail du guide choisi (zone, argument, récompense, guide suivant, avancement) et **Suivre ce guide** (une quête de classe garde la route à reprendre). En tête du leveling, **Choisis ton chemin** : les guides suivants du guide suivi, puis les guides conseillés (`Guide:Suggest`). Filtre : faction et classe toujours, race hors leveling, guides retirés jamais.
- **Sorts de classe** : le plan des sorts (voir [Sorts à apprendre](#sorts-à-apprendre)).
- **Options** : bouton vers les options de NextStep.
- Restent : onglets Métiers, Items et Zones (phases suivantes), recherche.

### Style des fenêtres

Sombre et doré, commun aux fenêtres de NextStep (`Core/Style.lua`, choix du 2026-11-05) : fond presque noir, barre de titre avec le logo et un liseré doré, panneaux un peu plus clairs, cartes avec survol et sélection teintés d'or, boutons plats (onglet actif souligné d'or), barres d'avancement dorées, icônes du jeu aux coins rognés. Aucun modèle XML du client : seulement des aplats d'une texture blanche teintée, pour ne dépendre d'aucune texture propre à une version du jeu. Le journal, la fenêtre du guide et la **fenêtre des options** l'utilisent. Options (`Core/Options.lua`) : fenêtre défilante, une section par module (interrupteur doré, description, réglages alignés en retrait, séparateur), cases, curseurs et boutons au même style (`Options.AddCheck`, `AddSlider`, `AddButton`) ; la page NextStep des options du jeu n'a plus qu'un bouton qui ouvre cette fenêtre. Ils (barre de titre avec le logo, boutons Journal, Options et Réduire ; boutons Ignorer, Valider et Strict / Libre plats, estompés quand ils sont désactivés) ; les autres fenêtres y passeront.

### Divers

- Le suivi d'objectifs Blizzard est **masqué quand le guide est actif** (option). **[À vérifier]** Nom du cadre sur Forever (`ObjectiveTrackerFrame` ou `QuestWatchFrame`) et masquage sans souillure.
- **Validations automatiques** des objectifs « à valider » de l'étape courante, des objectifs en chemin et du mode libre : `talk` à l'ouverture d'un dialogue avec le PNJ, `vendor` à l'ouverture d'un marchand, `train` à l'ouverture d'un des maîtres proposés, `getfp` (sans identifiant) à l'ouverture de la carte des vols, `cast` au sort lancé. Elles valent pour la session ; une fois l'étape passée, son résultat est mémorisé.
- Commande `/ns`, raccourcis clavier, bouton minimap (voir [Bouton NextStep et menu des addons](#bouton-nextstep-et-menu-des-addons)).

### Sorts à apprendre

Données reprises de What's Training (MIT, prend en charge Forever), importées comme celles de Polestar.

- Liste des sorts disponibles chez le maître de classe pour le niveau actuel et les suivants, selon la classe et la race, avec leur coût et le total.
- Dans la route : étape « maître de classe » quand des sorts sont disponibles et qu'on passe dans une ville qui en a un ; avertissement si l'or ne suffit pas.
- Données : table par classe (sort, rang, niveau, coût, race éventuelle) dans les données, complétée et corrigée par la liste lue chez le maître à chaque visite (mémorisée au niveau du compte, comme les [noms appris](#noms-appris)).
- **[À vérifier]** Exactitude des tables de What's Training pour Forever ; lecture des services du maître sur Forever.
- **Réalisé** (`Modules/Guide/Spells.lua`, données `Data/Imported/WhatsTraining/Spells.lua`) : `Guide:SpellsToLearn` retient les sorts de la classe jusqu'au niveau du personnage qu'il ne connaît pas (`IsPlayerSpell`), selon sa race, sa faction, ses talents et ses compétences, dont les prérequis sont connus ou appris pendant la même visite ; un sort exigé par un sort connu est tenu pour connu (rang dépassé). Dans la fenêtre : le nombre de sorts et leur coût sur l'objectif « maître de classe », un rappel sous l'étape sinon (orange si l'argent manque), l'infobulle détaille chaque sort, le total, l'argent manquant et le prochain niveau à nouveaux sorts ; fenêtre « Sorts de classe » (`Modules/Guide/SpellsWindow.lua`, menu du bouton NextStep ou `/ns spells`) avec le plan des sorts (`Guide:SpellPlan`) : maintenant, puis chaque niveau à venir jusqu'au 60 qui apporte de nouveaux sorts (en apprenant tout au fur et à mesure, rangs enchaînés ; compétences non vérifiées pour l'avenir), prix de chaque sort et total du niveau, défilement à la molette, Échap pour fermer ; `/ns spells list` dans le chat. L'étape « maître de classe » est faite quand il n'y a rien à apprendre ; sans données pour la classe, la règle des niveaux pairs (dernière visite retenue) reste en secours. Restent : la liste lue chez le maître, l'étape ajoutée à la route quand on passe dans une ville qui a un maître.

### Célébration de niveau

Inspirée de SkyrimSong, dans le style de NextStep (aucune musique ni image d'un autre jeu).

- À chaque niveau : bandeau au centre de l'écran, son tiré des fichiers du jeu, résumé de ce que le niveau apporte (sorts disponibles, jalons, zone suivante conseillée).
- Jamais en combat (différée), désactivable, son désactivable séparément ; graphismes générés avec FLUX, comme le logo.

### Logo et icônes

Une arche de pierre moussue, une étoile dorée sur la clé de voûte, des marches qui montent vers une lumière dorée : la prochaine étape. Généré avec FLUX.2 [klein] 4B, détouré, puis décliné par `Tools/logo/prepare.py` (voir [CREDITS.md](../CREDITS.md#logo)) :

| Fichier | Taille | Usage |
|---|---|---|
| `img/logo/nextstep-1024.png` | 1024 × 1024 | Maître détouré |
| `img/logo/nextstep-curseforge-400.png` | 400 × 400 | Page CurseForge, README |
| `addon/NextStep/Media/Icon.tga` | 128 × 128 | Liste des addons (`## IconTexture` du TOC) |
| `addon/NextStep/Media/IconSmall.tga` | 64 × 64 | Bouton de la minimap |
| `addon/NextStep/Media/RadarRing.tga` | 512 × 512 | Anneau du radar de récolte (`Tools/radar/textures.py`) |
| `addon/NextStep/Media/RadarMask.tga` | 64 × 64 | Masque transparent du radar : cache le terrain de la minimap (`Tools/radar/textures.py`) |

Les textures du jeu sont des TGA 32 bits non compressés, aux dimensions en puissances de 2. **[À vérifier]** l'affichage de `IconTexture` sur Forever. Si l'icône est trop chargée en 32 pixels sur la minimap, une version simplifiée (même arche, sans lierre ni rochers) sera faite.

---

## 9. Module UI

Sous-modules indépendants, chacun activable : `UnitText`, `Bags`, `Junk`, `Minimap`, `Radar`, `Clock`, `Windows`, `MapReveal`.

### Valeurs de vie et de ressources

- Cadres du joueur, de la cible, de la cible de la cible, du familier, du groupe, **et nameplates**.
- Format par défaut : `4 523 / 6 000 (75 %)` ; format court (`4,5k / 6k`) en option, réglable séparément pour les cadres et les nameplates.
- Stratégie : (1) option native « Texte de statut » si elle existe ; (2) nos propres textes ailleurs, les valeurs étant transmises sans calcul ; (3) repli sur un format autorisé en combat.
- **[À vérifier]** Fonctions de formatage des secret values ; nameplates verrouillées (alliés en donjon).

### Sacs et banque

- Option native « Sacs combinés » enrichie si elle existe, sinon fenêtre propre (boutons d'objets sécurisés).
- Recherche, tri, cases libres, or.
- Marques : améliorations (module Items), objets de quête et objets demandés par le guide, composants de métier, camelote ; niveau d'objet en option.
- **Banque unifiée**, **consultable à distance en lecture seule** (contenu mémorisé à chaque visite, avec la date).
- Mémoire des sacs et banques des autres personnages du compte ; compteurs dans les infobulles.
- **Réalisé en avance** (`Modules/UI/QuestItems.lua`, module `QuestItems`, actif par défaut) : marque dorée (`Media/Pin.tga`) en haut à gauche des objets utiles à une quête du journal, dans les sacs du client, et ligne « Objet de quête : <quête> » dans leur infobulle (`TooltipDataProcessor`). Objet de quête : selon le client (`C_Container.GetContainerItemQuestInfo`, quête du journal), ou demandé par un objectif « ramasser » du guide suivi pour une quête du journal. Accroches sur `UpdateItems` des cadres de sacs (`ContainerFrameCombinedBags`, `ContainerFrameN`), ou `ContainerFrame_Update` ; liste refaite à chaque mise à jour du journal et du guide. **[À vérifier]** sur Forever : boutons des sacs et `GetContainerItemQuestInfo`.

### Camelote

Vente automatique **activée par défaut** : objets gris uniquement, résumé dans le chat, liste d'exceptions. Les objets restent rachetables chez le marchand.

### Minimap

- **Carrée par défaut**, ronde en option (forme déclarée aux autres addons via `GetMinimapShape`).
- Zoom à la molette (retour automatique au zoom par défaut en option), coordonnées, horloge et zone lisibles, taille réglable.
- Bascule rapide du suivi herbes / minerais.
- **Réalisé** (`Modules/UI/Minimap.lua`, module `Minimap`, actif par défaut, mis de côté si SexyMap, BasicMinimap ou Chinchilla est chargé) : masque carré (`Interface\ChatFrame\ChatFrameBackground`) et liseré noir, décorations rondes cachées (`MinimapBorder`, `MinimapBorderTop`, `MinimapCompassTexture`, si elles existent), `GetMinimapShape` déclarée (la déclaration d'un autre addon est rendue en repassant en rond) ; zoom à la molette. Tout est rétabli à la désactivation ; changements différés après le combat si la minimap est protégée ; le radar ouvert garde son masque. Restent : coordonnées, horloge et zone, taille, retour au zoom par défaut, suivi herbes / minerais.

### Bouton NextStep et menu des addons

Un seul bouton sur la minimap, celui de NextStep (`Media/IconSmall.tga`), donne accès aux paramètres de **chaque addon installé** ; les boutons des autres addons sont masqués.

- **Clic gauche** : ouvre le menu des addons. **Clic droit** : options de NextStep. **Glisser** : déplace le bouton autour de la minimap (position mémorisée).
- **Menu des addons** : une ligne par addon chargé (`C_AddOns.GetNumAddOns`, `GetAddOnInfo`), avec son icône (`## IconTexture` du TOC) et son titre, triée par ordre alphabétique, avec une recherche au-delà de 15 addons. Les addons désactivés ou non chargés n'apparaissent pas.
- **Ce que fait un clic sur un addon**, dans cet ordre :
  1. l'action de son propre bouton de minimap, s'il en a un : lanceur LibDataBroker (`OnClick` de l'objet de données) ou clic transmis au bouton masqué ;
  2. sinon, son entrée du compartiment d'addons de Blizzard (`## AddonCompartmentFunc` du TOC), si ce compartiment existe sur Forever ;
  3. sinon, sa page dans *Options → AddOns* (`Settings.OpenToCategory`), retrouvée par le titre de l'addon ;
  4. sinon, la ligne est grisée, avec « Pas de paramètres » dans l'infobulle.
- **Boutons masqués** : les boutons de LibDBIcon (`LibDBIcon10_*`) et les autres enfants de `Minimap` et de `MinimapCluster` qui ne sont pas de Blizzard. Ceux de Blizzard (zoom, suivi, courrier, file d'attente, horloge, calendrier) sont reconnus par une liste dans les données. Recherche au `PLAYER_LOGIN`, puis quelques secondes plus tard et à chaque `ADDON_LOADED`, pour les boutons créés tardivement.
- **Masquage réversible** : NextStep cache les cadres (`Hide` et accroche sur `Show`) sans toucher aux réglages des autres addons ni à ceux de LibDBIcon. Désactiver l'option les fait réapparaître. Une liste d'exceptions dans les options garde visibles les boutons choisis.
- **Compartiment d'addons de Blizzard** (`AddonCompartmentFrame`) : masqué aussi en option, puisque le menu de NextStep le remplace.
- **Addons concurrents** (MinimapButtonButton, Bazooka, ButtonBin…) : le masquage se désactive et le signale ; le menu reste disponible.
- Le bouton peut être caché (option) ; le menu reste alors accessible par `/ns addons`.
- **Réalisé** (`Modules/UI/AddonsMenu.lua`, module `AddonsMenu`) : bouton sur la minimap, sur le cercle ou le bord du carré selon `GetMinimapShape` ; clic gauche : menu (`MenuUtil.CreateContextMenu`) avec en tête le **radar de récolte** et les options de NextStep, puis les addons chargés (hors NextStep) ; clic droit : options ; **clic milieu : radar** ; glisser : déplacement autour de la minimap. Action d'un addon : bouton LibDBIcon (`LibDBIcon10_<nom>`), puis `## AddonCompartmentFunc`, puis la page des options dont le nom est le nom ou le titre de l'addon (`SettingsPanel:GetAllCategories`) ; sinon ligne grisée. Masquage limité pour l'instant aux boutons `LibDBIcon10_*` (les enfants de Blizzard de la minimap n'ont pas de nom sur Forever), à la connexion, 5 s après et à chaque `ADDON_LOADED`. Restent : recherche au-delà de 15 addons, liste d'exceptions, option pour cacher le bouton, compartiment de Blizzard, addons concurrents.
- **[À vérifier]** Présence du compartiment d'addons (`AddonCompartmentFrame`) sur Forever ; catégories enregistrées dans les options (`SettingsPanel`) et moyen de retrouver celle d'un addon ; API de menu (`MenuUtil.CreateContextMenu`) ; liste des enfants de Blizzard de la minimap.

### Horloge

Panneau ouvert depuis l'horloge de la minimap :
- **alarmes** à heure fixe (locale ou serveur), nommées ;
- **minuteurs** multiples et nommés ; **chronomètre** ;
- signal sonore et alerte au centre de l'écran (affichée **même en combat**, en format réduit) ;
- les minuteurs survivent au `/reload` et à la déconnexion (heure de fin sauvegardée) ; un minuteur terminé hors ligne est signalé à la connexion.

### Fenêtres déplaçables

Inspiré de BlizzMove, dont le code est « All Rights Reserved » : code propre à NextStep.

- Les fenêtres Blizzard (personnage, grimoire, talents, journal de quêtes, marchands, maîtres…) se déplacent en les faisant glisser ; positions mémorisées, réinitialisables. Le mode Édition natif reste utilisé pour les éléments du HUD.
- Fenêtres chargées plus tard (`Blizzard_*`) prises en charge à leur chargement (`ADDON_LOADED`).
- Jamais en combat pour les cadres protégés ; retrait du gestionnaire de positions de `UIParent` sans écrire d'attributs sécurisés.

**Plusieurs fenêtres ouvertes en même temps.** Le gestionnaire de Blizzard (`ShowUIPanel`, table `UIPanelWindows`) ne garde que deux ou trois fenêtres, rangées à gauche ou au centre : ouvrir une fenêtre ferme ou décale les autres. NextStep sort de ce gestionnaire les fenêtres qu'il gère, pour qu'elles restent ouvertes ensemble, chacune à sa position mémorisée.

- **Fenêtres concernées** : seulement les fenêtres **non protégées**. Une fenêtre protégée garde le comportement de Blizzard (déplaçable hors combat seulement). Liste tenue dans les données, fenêtre par fenêtre, selon les résultats du diagnostic.
- **Sortie du gestionnaire** : hors combat uniquement, au chargement de la fenêtre. La fenêtre est retirée de `UIPanelWindows` et ajoutée à `UISpecialFrames`, pour que Échap la ferme toujours. Désactiver l'option la remet dans le gestionnaire au rechargement de l'interface (`/reload`).
- **Première ouverture** : une fenêtre sans position mémorisée s'ouvre en cascade, décalée par rapport à la précédente, pour ne pas en cacher une autre.
- **Focus** :
  - un clic n'importe où sur une fenêtre la passe au premier plan (`SetToplevel`, puis `Raise`) ;
  - toutes les fenêtres gérées sont dans la même strate, pour pouvoir passer l'une devant l'autre ;
  - une fenêtre qui s'ouvre prend le focus ;
  - NextStep tient la pile des fenêtres ouvertes, de la plus récente à la plus ancienne.
- **Échap** ferme seulement la fenêtre au premier plan, puis la suivante à chaque nouvel appui. En combat, ou si l'interception n'est pas possible, Échap garde le comportement de Blizzard et ferme toutes les fenêtres.
- **Option** : « Plusieurs fenêtres ouvertes » est activée par défaut et peut être désactivée séparément du déplacement.
- **Risque** : modifier `UIPanelWindows` peut souiller (*taint*) l'ouverture des fenêtres protégées. C'est la raison de la limite aux fenêtres non protégées et aux changements hors combat ; à tester fenêtre par fenêtre.
- **[À vérifier]** Liste des fenêtres déplaçables sans souillure (*taint*) sur Forever ; fenêtres non protégées sorties du gestionnaire sans erreur à l'ouverture en combat ; interception d'Échap pour ne fermer que la fenêtre au premier plan.

### Carte sans brouillard

Inspiré de Leatrix Maps et de Mapster, tous deux « All Rights Reserved » : code et table propres à NextStep.

- Les zones inexplorées de la carte du monde sont affichées, dans une teinte atténuée réglable ; désactivable.
- Le client ne fournit que les textures des zones explorées (`C_MapExplorationInfo`) : une table des textures de chaque carte est nécessaire, dans les données. Forever reprenant les cartes du Classic, une table du Classic devrait convenir.
- Table générée par un script d'import (non livré) à partir des tables de superposition de cartes du client Forever (`WorldMapOverlay`, `WorldMapOverlayTile`), comme les noms extraits des tables du client.
- Chaîne d'extraction (outils de développement, jamais livrés) : **TACTTool** de [TACTSharp](https://github.com/wowdev/TACTSharp) (MIT) lit le stockage CASC de l'installation locale (`-p wowf -d <dossier du jeu>`), **[DBCD](https://github.com/wowdev/DBCD)** (MIT) décode les DB2 avec les définitions de [WoWDBDefs](https://github.com/wowdev/WoWDBDefs), qui couvrent déjà la version de Forever installée (1.60.1.70707). Nécessite le SDK .NET 10 sur le poste de développement. Script : `Tools/worldmap/run.ps1` ([DATA_FORMAT.md](DATA_FORMAT.md#extraction-de-la-carte)).
- **Vérifié** (3 novembre 2026, client 1.60.1.70707, téléchargement en cours) : la chaîne d'extraction fonctionne ; 1 081 superpositions, 1 739 tuiles, 84 cartes (`UiMapArtID`). Tuiles de 256 pixels, rangée par rangée.
- Table de l'addon (`DB.mapOverlays`) : par `UiMapArtID` (`C_Map.GetMapArtID`), la liste des superpositions `{ largeur, hauteur, décalage X, décalage Y, FileDataID… }`, soit les champs de `C_MapExplorationInfo.GetExploredMapTextures`. Le module dessine celles que le client ne renvoie pas comme explorées ; la taille et le décalage les identifient.
- Module `MapReveal` (`Modules/UI/MapReveal.lua`), actif par défaut, mis de côté si Leatrix Maps ou Mapster est chargé. Il s'accroche (`hooksecurefunc`) à `RefreshOverlays` de la punaise d'exploration de `WorldMapFrame` (`MapExplorationPinTemplate`), ou attend `ADDON_LOADED` de `Blizzard_WorldMap` ; après chaque rafraîchissement, il dessine les superpositions inexplorées avec ses propres textures, sur la punaise, en couche `BORDER` (sous les textures explorées). Dernière tuile d'une rangée ou d'une colonne rognée (fichier à la puissance de 2 supérieure, 16 au minimum). Luminosité réglable de 20 à 100 % (60 % par défaut), par un curseur dans les options.
- **[À vérifier]** En jeu : absence de souillure (*taint*) de la carte du monde, en combat compris ; couche `BORDER` bien sous les textures explorées ; curseur sans modèle du client lisible dans le panneau d'options.
- **[À vérifier]** En jeu, avec le rapport de diagnostic (section « Carte : exploration ») : textures explorées identiques à celles de la table ; rôle du drapeau `Flags = 4`, porté par 555 superpositions de 43 cartes (aucune n'a de `PlayerConditionID`), voir `Tools/worldmap/last-import.md` : s'il correspond à `isShownByMouseOver` ou `isDrawOnTopLayer` de `GetExploredMapTextures`, l'ajouter à la table. 8 superpositions sans tuiles sont écartées.

### Radar de récolte

Aide au farm des ressources, sur le principe de FarmHud (code propre à NextStep) : la minimap s'affiche en grand et en transparence au centre de l'écran, autour du personnage, pour repérer herbes, filons et bancs de poissons sans quitter le personnage des yeux.

- Le client ne laisse pas un addon dessiner le terrain : le module `Radar` (`Modules/UI/Radar.lua`) **emprunte le vrai cadre `Minimap`**. À l'ouverture, il mémorise tout ce qu'il change (parent, points, taille, échelle, couche, transparence, souris et molette, zoom, option `rotateMinimap`, enfants affichés) et le rétablit à la fermeture ; le masque rendu suit `GetMinimapShape` (carré ou rond).
- Pendant le radar : minimap centrée, diamètre réglable (30 à 90 % de la hauteur de l'écran, 60 % par défaut), opacité réglable (20 à 100 %, 70 % par défaut), zoom le plus large, aucun clic intercepté, couche `BACKGROUND`. Le terrain est caché par un masque transparent (`Media/RadarMask.tga`) ; il peut être affiché en option. Les enfants de `Minimap` (boutons d'addons) sont cachés, sauf les cadres protégés.
- Rotation avec la caméra (option, activée par défaut) ; anneau (`Media/RadarRing.tga`) et points cardinaux N, E, S, O placés d'après `GetPlayerFacing`, cachés si le cap est inconnu ou secret.
- Ouverture et fermeture par `/ns radar`, un raccourci clavier, le clic milieu sur le bouton NextStep ; fermeture aussi par **Échap** (cadre dans `UISpecialFrames`) ou la **croix** en haut à droite de l'anneau, seul élément qui prend la souris (`Bindings.xml`, Raccourcis > NextStep). Si `Minimap` est protégée en combat, le changement est différé à la sortie du combat. L'option `rotateMinimap` est rendue à la déconnexion. Actif par défaut, désactivable, mis de côté si FarmHud est chargé.
- Plus tard : ouverture automatique sur une étape « farmer ici » d'une route de métier ; points de récolte de la base (phase 9) dessinés sur le radar.
- **[À vérifier]** En jeu : `Minimap` déplaçable et redimensionnable sur Forever, en combat compris ; points de suivi toujours visibles quand le terrain est masqué ; masque rond d'origine (`Textures\MinimapMask`) ; zoom 0 bien le plus large ; raccourci affiché dans le menu des raccourcis.

---

## 10. Idées à l'étude

Idées retenues sur le principe, pas encore planifiées.

### Prix de l'hôtel des ventes

Inspiré d'Auctionator, en version légère : prix mémorisés lors des visites à l'hôtel des ventes, utilisés pour le choix des récompenses de quête, l'objectif « or » des métiers et les infobulles. Pas d'interface de vente. **[À vérifier]** Type d'hôtel des ventes sur Forever (Classic ou moderne).

### Écartées

- **Auras** (Forever Aura) et **options diverses** (Leatrix Plus) : peu prioritaires ; les auras sont en outre très limitées par les *secret values*.
- **Refonte de l'interface** (EllesmereUI) : contraire au principe 3.
- **Guide de leveling** (RestedXP) : c'est déjà le cœur de NextStep.
- **Partage automatique des données entre joueurs NextStep** (noms appris, sorts des maîtres, points de récolte) : trop complexe (pas d'envoi « à proximité », protection contre les données fausses, limites des messages d'addon) et contraire au principe 2.
