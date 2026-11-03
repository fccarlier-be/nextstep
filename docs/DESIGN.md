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
NextStep/                    -- cœur + données communes, toujours chargé
├── NextStep_Camelot.toc
├── Core/                    -- initialisation, événements, sauvegardes, modules, options
├── Libs/                    -- LibStub, CallbackHandler, HereBeDragons
├── Locales/                 -- frFR, enUS
├── Data/
│   ├── Imported/            -- généré par le script d'import, jamais modifié à la main
│   └── Overrides/           -- corrections et ajouts NextStep, appliqués en dernier
└── Modules/
    ├── Guide/               -- moteur et interface du guide
    ├── Navigation/          -- flèche, points sur carte et minimap
    ├── Professions/
    ├── Items/
    └── UI/
NextStep_Alliance/           -- données Alliance, chargées à la demande
NextStep_Horde/              -- données Horde, chargées à la demande
Tools/                       -- scripts d'import et de développement (non distribués)
tests/                       -- tests hors jeu
```

### Chargement par faction

Le cœur et les données communes (classes, métiers, réputations, zones, PNJ neutres) sont toujours chargés. À la connexion, le cœur lit la faction du personnage et charge `NextStep_Alliance` ou `NextStep_Horde` (`C_AddOns.LoadAddOn`). L'autre n'est jamais lu.

**[À vérifier]** La race Skyborne existe dans les deux factions : s'assurer que la faction est connue au moment du chargement.

### Couche d'accès aux données

Le moteur n'accède jamais directement aux tables de données ; il passe par `NS.DB` (`DB:GetQuest(id)`, `DB:GetGuide(id)`, `DB:GetNPC(id)`…). Changer de source, de format ou de stratégie de chargement ne touche que cette couche.

### Modules

Chaque module (et chaque sous-module UI) s'enregistre auprès du cœur, peut être activé ou désactivé dans les options, et se désactive s'il détecte un addon concurrent (Bagnon, ElvUI…), en le signalant.

---

## 4. Données

Les sources et licences sont détaillées dans [DATA_SOURCES.md](DATA_SOURCES.md).

### Import

Le script d'import charge les fichiers compilés de Polestar dans un environnement Lua **isolé** (aucun accès aux fichiers ni au système), remplace `Polestar.RegisterGuide` et les fonctions apparentées par des fonctions de capture, puis convertit les tables capturées vers le format NextStep. Il vérifie le numéro de format (`format = 8` au 2026-11-03) et **refuse** un format inconnu plutôt que de produire des données fausses. La version de la source importée est consignée.

### Faits

```lua
NS.DB.quests[7] = {
    level = 2, minLevel = 1,
    races = nil, classes = nil,      -- nil = tous ; sinon jetons ("HUMAN", "WARRIOR")
    start = { npc = 197 }, finish = { npc = 197 },
    pre = { 783 },                   -- prérequis
    closedBy = nil,                  -- quêtes exclusives
}
NS.DB.npcs[197] = { map = 1429, x = 48.92, y = 41.61 }   -- uiMapID + pourcentage 0-100
```

- **Races et classes en jetons**, jamais en masques de bits : les ID raciaux de Skyborne (95, 96) dépassent 32 bits, la limite de la bibliothèque `bit` de Lua 5.1.
- **Coordonnées** en pourcentage de carte, déjà converties au repère Forever lors de l'import (forever-db stocke des mètres monde ; Polestar distingue les repères *era* et *live*).
- **Pas de noms** dans les faits : ils viennent du client ou des tables de traduction.

### Routes

Une route est une liste d'**étapes** ; chaque étape regroupe des **objectifs** à accomplir ensemble au même endroit.

```lua
NS:RegisterRoute({
    id = "forever/alliance/human/01-elwynn-forest",
    faction = "Alliance", races = { "HUMAN" },
    levels = { 1, 11 },
    next = { "forever/alliance/02-westfall" },
    steps = {
        {
            title = "Le camp des kobolds",
            note = "...",
            goals = {
                { t = "kill", quest = 7, npc = 6, count = 10, spots = { ... } },
                { t = "collect", item = 247834, count = 1, optional = true },
            },
        },
    },
})
```

Le vocabulaire des objectifs est aligné sur celui de Polestar pour que l'import soit quasi direct :

| Type | Signification | Accompli quand… |
|---|---|---|
| `accept` | Accepter une quête | dans le journal, **ou** déjà rendue |
| `complete` / `kill` / `collect` / `interact`… | Objectifs de quête | objectif rempli, **ou** quête rendue |
| `turnin` | Rendre une quête | quête marquée terminée |
| `goto` | Se rendre à un point | passage dans le rayon (mémorisé pour la session) |
| `level` | Atteindre un niveau | niveau ≥ cible |
| `train` | Maître de classe ou de métier | rang appris / validation manuelle |
| `sethome`, `hearth`, `getfp`, `fly` | Déplacements | changement constaté |
| `buy` | Acheter un objet | objet dans les sacs |
| `craft`, `skill` | Métiers | compétence ≥ cible |
| `note`, `task` | Texte / tâche manuelle | validation manuelle (`note` ne bloque jamais) |

Options communes à un objectif ou une étape : `races`, `classes`, `optional`, conditions (`when` : niveau, quête en cours, terminée…), `reward` (choix de récompense).

---

## 5. Moteur du guide

### Règles fondamentales

1. **L'étape courante est calculée, jamais stockée.** À chaque changement d'état, le moteur prend la première étape qui n'est ni faite, ni ignorée, ni hors sujet. Une route modifiée ou un jeu sans l'addon ne désynchronise rien.
2. **Seuls les choix du joueur sont sauvegardés** (étapes ignorées, validations manuelles), par **clé stable** (`"accept:783"`, ou un `id` explicite), jamais par position.
3. **Un objectif accompli le reste** : chaque objectif tient compte des états qui le suivent (`accept` est accompli si la quête est déjà rendue). Seul l'abandon d'une quête fait reculer le guide, avec un message.

### États d'une étape

| État | Signification | Affichage |
|---|---|---|
| Faite | Tous les objectifs non facultatifs sont accomplis | Masquée |
| Hors sujet | Ne concerne pas cette race, cette classe ou ces conditions | Masquée |
| Ignorée | Choix du joueur, réversible | Masquée, restaurable |
| Bloquée | Impossible pour l'instant (niveau, prérequis) | Raison affichée, propositions : farmer, ignorer, autre zone |
| À faire | — | Affichée |

En mode strict, une étape bloquée **arrête** le guide au lieu d'être sautée en silence.

### Modes

- **Strict** : une seule étape à la fois.
- **Libre** : tous les objectifs à faire d'un même lieu, triés par distance.

Les deux modes utilisent **le même moteur** ; seul l'affichage change.

### Détours

| Situation | Réaction |
|---|---|
| Quête hors route acceptée | Listée comme « détour », sans contredire le joueur |
| Étape faite en avance | Validée automatiquement |
| Retour après un détour | Reprise à la première étape non faite |
| Niveaux pris pendant le détour | Proposition de sauter les quêtes devenues grises ou de passer à la zone suivante |
| Niveau insuffisant | Proposition d'autres zones ou d'un spot de farm |

### Enchaînement

- Le champ `next` peut proposer plusieurs routes (« Choisis ton chemin », avec arguments `pitch`, `pro`, `con`).
- **Mode conseil** : sans route active, le guide propose les zones et les quêtes adaptées au niveau, à la race et à la classe, à partir des faits seuls.
- **Donjons** : objectifs facultatifs recommandés au bon niveau, avec les quêtes à prendre avant.

### Recalcul

Déclenché par les événements : quêtes (acceptées, rendues, mises à jour), niveau, zone, sacs, compétences. Un minuteur ne tourne que pendant un objectif `goto`.

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
| Jalons | Sacs, quêtes de classe, monture, sorts à apprendre ; seuils dans les données |

**[À vérifier]** Possibilité d'équiper un objet depuis l'alerte. Sinon, le clic ouvre les sacs avec l'objet en surbrillance.

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

### Journal

Grande fenêtre à onglets : **Routes** (dont « Choisis ton chemin »), **Métiers**, **Items**, **Zones**, **Options**.

### Divers

- Le suivi d'objectifs Blizzard est **masqué quand le guide est actif**.
- Commande `/ns`, raccourcis clavier, bouton minimap optionnel.

---

## 9. Module UI

Sous-modules indépendants, chacun activable : `UnitText`, `Bags`, `Junk`, `Minimap`, `Clock`.

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
