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
│       ├── Guide/           -- moteur et interface du guide
│       ├── Navigation/      -- flèche, points sur carte et minimap
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
| `Core/Slash.lua` | `/ns` et `/nextstep` : `help`, `version`, `modules`, `enable`, `disable`, `options` ; les modules ajoutent leurs commandes |
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
- **Guide de départ** : `Guide:Suggest` propose les guides de leveling de la faction, de la race et de la classe du personnage, à son niveau ; ceux propres à la race d'abord.
- Un guide actif remplacé dans Polestar (identifiant retiré) est abandonné à la connexion.
- **Mode conseil** (phase 10) : sans route active, les zones et les quêtes adaptées au niveau, à la race et à la classe.

### Recalcul

`Guide:Refresh` évalue le guide actif, mémorise les étapes dépassées et envoie le message `NEXTSTEP_GUIDE_UPDATED` (le résultat complet) à l'interface. En phase 4, il sera déclenché par les événements du jeu : quêtes (acceptées, rendues, mises à jour), niveau, zone, sacs, compétences, argent. Un minuteur ne tournera que pendant un objectif `goto`.

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

### Flèche

- En haut au centre ; **désactivable**.
- Dessin plat et épuré (chevron avec contour sombre), couleur passant du doré Blizzard au vert dans la bonne direction, rouge-orangé à l'opposé ; rotation fluide ; distance et temps estimé ; coche à l'arrivée.
- Pour `kill` / `collect`, vise la zone de mobs la plus proche.
- **[À vérifier]** Position et orientation du joueur indisponibles en instance : flèche masquée en donjon.

### Carte du monde et minimap

- Points via **HereBeDragons** : cibles de l'étape, zones de mobs, et en mode conseil les donneurs de quêtes adaptés.
- Waypoint natif (`C_Map.SetUserWaypoint`) en option. Ne pas utiliser `C_SuperTrack.SetSuperTrackedUserWaypoint`.
- **Zoom à la molette** sur la minimap et sur la carte du monde. **[À vérifier]** zoom natif de la carte sur Forever.
- **Niveau des zones** affiché sur la carte du monde (tranche de niveaux, couleur selon le niveau du joueur), en appui du conseil de zone suivante.

### Journal

Grande fenêtre à onglets : **Routes** (dont « Choisis ton chemin »), **Métiers**, **Items**, **Zones**, **Options**.

### Divers

- Le suivi d'objectifs Blizzard est **masqué quand le guide est actif**.
- Commande `/ns`, raccourcis clavier, bouton minimap optionnel.

### Sorts à apprendre

Données reprises de What's Training (MIT, prend en charge Forever), importées comme celles de Polestar.

- Liste des sorts disponibles chez le maître de classe pour le niveau actuel et les suivants, selon la classe et la race, avec leur coût et le total.
- Dans la route : étape « maître de classe » quand des sorts sont disponibles et qu'on passe dans une ville qui en a un ; avertissement si l'or ne suffit pas.
- Données : table par classe (sort, rang, niveau, coût, race éventuelle) dans les données, complétée et corrigée par la liste lue chez le maître à chaque visite (mémorisée au niveau du compte, comme les [noms appris](#noms-appris)).
- **[À vérifier]** Exactitude des tables de What's Training pour Forever ; lecture des services du maître sur Forever.

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

Les textures du jeu sont des TGA 32 bits non compressés, aux dimensions en puissances de 2. **[À vérifier]** l'affichage de `IconTexture` sur Forever. Si l'icône est trop chargée en 32 pixels sur la minimap, une version simplifiée (même arche, sans lierre ni rochers) sera faite.

---

## 9. Module UI

Sous-modules indépendants, chacun activable : `UnitText`, `Bags`, `Junk`, `Minimap`, `Clock`, `Windows`, `MapReveal`.

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

### Camelote

Vente automatique **activée par défaut** : objets gris uniquement, résumé dans le chat, liste d'exceptions. Les objets restent rachetables chez le marchand.

### Minimap

- **Carrée par défaut**, ronde en option (forme déclarée aux autres addons via `GetMinimapShape`).
- Zoom à la molette (retour automatique au zoom par défaut en option), coordonnées, horloge et zone lisibles, taille réglable.
- Tiroir regroupant les boutons d'addons.
- Bascule rapide du suivi herbes / minerais.

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
- **[À vérifier]** Liste des fenêtres déplaçables sans souillure (*taint*) sur Forever.

### Carte sans brouillard

Inspiré de Leatrix Maps et de Mapster, tous deux « All Rights Reserved » : code et table propres à NextStep.

- Les zones inexplorées de la carte du monde sont affichées, dans une teinte atténuée réglable ; désactivable.
- Le client ne fournit que les textures des zones explorées (`C_MapExplorationInfo`) : une table des textures de chaque carte est nécessaire, dans les données. Forever reprenant les cartes du Classic, une table du Classic devrait convenir.
- Table générée par un script d'import (non livré) à partir des tables de superposition de cartes du client Forever (`WorldMapOverlay`, `WorldMapOverlayTile`), comme les noms extraits des tables du client.
- Chaîne d'extraction (outils de développement, jamais livrés) : **TACTTool** de [TACTSharp](https://github.com/wowdev/TACTSharp) (MIT) lit le stockage CASC de l'installation locale (`-p wowf -d <dossier du jeu>`), **[DBCD](https://github.com/wowdev/DBCD)** (MIT) décode les DB2 avec les définitions de [WoWDBDefs](https://github.com/wowdev/WoWDBDefs), qui couvrent déjà la version de Forever installée (1.60.1.70707). Nécessite le SDK .NET 10 sur le poste de développement. Script : `Tools/worldmap/run.ps1` ([DATA_FORMAT.md](DATA_FORMAT.md#extraction-de-la-carte)).
- **Vérifié** (3 novembre 2026, client 1.60.1.70707, téléchargement en cours) : la chaîne d'extraction fonctionne ; 1 081 superpositions, 1 739 tuiles, 84 cartes (`UiMapArtID`). Tuiles de 256 pixels, rangée par rangée.
- Table de l'addon (`DB.mapOverlays`) : par `UiMapArtID` (`C_Map.GetMapArtID`), la liste des superpositions `{ largeur, hauteur, décalage X, décalage Y, FileDataID… }`, soit les champs de `C_MapExplorationInfo.GetExploredMapTextures`. Le module dessine celles que le client ne renvoie pas comme explorées ; la taille et le décalage les identifient.
- **[À vérifier]** En jeu, avec le rapport de diagnostic (section « Carte : exploration ») : textures explorées identiques à celles de la table ; rôle du drapeau `Flags = 4`, porté par 555 superpositions de 43 cartes (aucune n'a de `PlayerConditionID`), voir `Tools/worldmap/last-import.md` : s'il correspond à `isShownByMouseOver` ou `isDrawOnTopLayer` de `GetExploredMapTextures`, l'ajouter à la table. 8 superpositions sans tuiles sont écartées.

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
