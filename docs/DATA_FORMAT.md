# Format des données

Ce document décrit les fichiers de données de NextStep et la couche d'accès qui les lit (`Core/DB.lua`). Le moteur du guide (phase 3) s'appuie sur ce format : toute modification doit être reportée ici et dans le [CHANGELOG](../CHANGELOG.md).

## Fichiers

| Fichier | Contenu | Chargé |
|---|---|---|
| `addon/NextStep/Data/Imported/Polestar/Meta.lua` | Source importée, guides retirés, repères de cartes « era » | Toujours |
| `addon/NextStep/Data/Imported/Polestar/Guides.lua` | Guides communs aux deux factions (classes, métiers, réputations, collection…) | Toujours |
| `addon/NextStep/Data/Imported/Polestar/Names_enUS.lua` | Noms anglais de toutes les entités citées par les guides | Toujours (repli) |
| `addon/NextStep/Data/Imported/Polestar/Names_frFR.lua` | Noms français | Client frFR uniquement |
| `addon/NextStep/Data/Imported/Polestar/Texts_frFR.lua` | Traductions des textes des guides | Client frFR uniquement |
| `addon/NextStep_Alliance/Data/Guides.lua` | Guides Alliance | Personnage Alliance |
| `addon/NextStep_Horde/Data/Guides.lua` | Guides Horde | Personnage Horde |

Tous sont **générés** par `Tools/import/import.lua` (voir [l'import](#import)) et ne doivent jamais être modifiés à la main. Les corrections iront dans `Data/Overrides/`.

## Couche d'accès : `ns.DB`

| Fonction | Rôle |
|---|---|
| `DB:GetGuide(id)` | Un guide par identifiant |
| `DB:IterateGuides(filter)` | Parcours dans l'ordre de chargement, filtre facultatif `filter(guide)` |
| `DB:GetName(kind, id, guide)` | Nom d'une entité dans la langue du client |
| `DB:Translate(text, guide)` | Traduction d'un texte de guide (anglais si absente) |
| `DB:Render(text, guide)` | Texte prêt à afficher : traduit, puis `{genre:id}` remplacés par les noms (`?` si introuvable) |
| `DB.mapFrames.era[uiMapID]` | Cadre « era » d'une carte (conversion des coordonnées) |
| `DB.retired[id]` | Ancien identifiant de guide, remplacé dans Polestar |
| `DB.sources` | Sources importées (nom, version, commit, date, format) |

Fonctions de remplissage, appelées par les fichiers générés : `DB.AddGuide(build)`, `DB:AddNames(locale, kind, build)`, `DB:AddTexts(locale, guideID, build)`, `DB:AddMapFrames(frame, build)`, `DB:RetireGuides(list)`, `DB:SetSource(source)`. Chaque `build` est une fonction qui renvoie une table : en Lua 5.1, le nombre de constantes est limité **par fonction**, d'où un constructeur par guide et des tables de noms découpées par blocs de 2 000.

### Résolution des noms

Les textes des guides contiennent des emplacements `{genre:id}`, par exemple `{npc:197}`. Genres rencontrés : `area`, `faction`, `item`, `npc`, `object`, `quest`, `skill`, `spell`, `zone` (`zone` = `uiMapID`).

Ordre de recherche d'un nom :

| Client | Ordre |
|---|---|
| Anglais | variante du guide → nom anglais importé → nom fourni par le client |
| Autre langue | nom appris en jeu → nom traduit importé → nom fourni par le client → infobulle du client (PNJ) → variante du guide → nom anglais importé |

- **Nom appris en jeu** : noms de PNJ retenus par le module Noms appris (voir [DESIGN.md](DESIGN.md#noms-appris)), fournis par `DB:SetLearnedNames`. Le dernier recours avant l'anglais est un résolveur par genre (`DB:SetResolver`), utilisé pour interroger l'infobulle d'un PNJ.
- **Variante du guide** : un guide peut employer un nom anglais adapté à ses phrases, souvent sans article (« Slaughtered Lamb » pour pouvoir écrire « the {object:2164}'s cellar »). Elles sont dans `guide.names`.
- **Nom fourni par le client** : `C_Map.GetAreaInfo` (area), `C_Map.GetMapInfo` (zone), `C_Spell.GetSpellName` (spell), `C_Item.GetItemNameByID` (item), `C_QuestLog.GetTitleForQuestID` (quest). **[À vérifier]** sur Forever. Les régions, zones, sorts et compétences n'ont pas de traduction importée : le client est leur seule source en français.

La couverture des noms est publiée à chaque import dans [`Tools/import/last-import.md`](../Tools/import/last-import.md). Au premier import, la moitié des PNJ cités n'ont pas de nom français dans Polestar : ils s'affichent en anglais jusqu'à ce que le module Noms appris les rencontre.

## Guide

```lua
G(function() return {
    id = "forever/alliance/human/01-elwynn-forest",
    title = "{area:12}",
    category = "Leveling",
    faction = "Alliance",
    races = { "HUMAN" },
    minLevel = 1,
    maxLevel = 11,
    zone = 1429,
    next = { "forever/alliance/02-westfall" },
    pool = { { npc = 911, map = 1429, x = 50.24, y = 42.29, z = 82.3, f = "e", faction = "A", classes = { "WARRIOR" } } },
    steps = { ... },
} end)
```

| Champ | Type | Signification |
|---|---|---|
| `id` | texte | Identifiant unique et stable (celui de Polestar) |
| `title` | texte | Titre (gabarit) |
| `category` | texte | `Leveling`, `Class`, `Professions`, `Reputation`, `Collectibles`, `Exploration`, `Legacy`, `Miscellaneous` |
| `folder` | texte | Sous-dossier d'affichage (ex. `Druid`) |
| `faction` | texte | `Alliance`, `Horde`, ou absent (deux factions) |
| `races` | liste | Jetons de race ; absent = toutes |
| `classes` | liste | Jetons de classe (`WARRIOR`, `DRUID`…) ; absent = toutes |
| `minLevel`, `maxLevel` | nombres | Tranche de niveaux |
| `zone` | nombre | `uiMapID` de la zone principale |
| `next` | liste | Guides suivants ; plusieurs = choix (« Choisis ton chemin »), le premier par défaut |
| `names` | table | Variantes anglaises propres au guide (`["genre:id"] = nom`) |
| `pool` | liste | Fiches de maîtres (PNJ, position, faction `A`/`H`/`AH`, classes), référencées par `candidates` |
| `steps` | liste | Étapes, dans l'ordre |
| `keywords`, `collects`, `reward`, `why`, `group`, `version` | divers | Repris de Polestar : mots-clés de recherche, objets collectés, récompense du guide, argument, contenu de groupe, version |

### Jetons de race

Ceux de `UnitRace` (champ `raceFile`, qui est en casse mixte : `Human`, `NightElf`, `Scourge`), mis en majuscules : `HUMAN`, `DWARF`, `GNOME`, `NIGHTELF`, `ORC`, `TROLL`, `TAUREN`, `SCOURGE` (mort-vivant), `SKYBORNE`. **[À vérifier]** le `raceFile` exact de Skyborne. Jamais de masques de bits : les ID raciaux de Skyborne dépassent 32 bits.

## Étape

```lua
{
    title = "The kobold camp",
    note = "{npc:6} dig in the vineyards north-east of the Abbey.",
    only = { classes = { "WARLOCK" } },
    when = { { k = "level", op = "<", n = 6 } },
    goals = { ... },
}
```

| Champ | Signification |
|---|---|
| `title`, `note` | Titre et conseil (gabarits) |
| `only` | Pour qui : `races`, `classes`, `factions`. Les listes d'un même champ sont des OU, les champs entre eux des ET |
| `when` | Conditions d'état, toutes requises (voir ci-dessous) |
| `label` | Nom de l'étape, cible de `skipto` et de `when done` |
| `along` | Objectifs faisables en chemin vers l'étape `label` indiquée, sans arrêter la route |
| `skipto` | Saut vers une étape nommée |

### Conditions (`when`)

Chaque condition est une table `{ k = genre, ... }`, `neg = true` l'inverse. Genres prévus par Polestar : `level` (`op`, `n`, `frac` : fraction du niveau), `onquest` (`q` : liste), `turnedin`, `complete`, `available`, `group` (quête de groupe, le joueur choisit), `done` (`label`), `money` (`op`, `n` en cuivre), `skill` (`n`, `skillLine`, `name`), `knows` (`spell`), `zone` (`area`, `name`), `has`, `dungeon`, `bound`, `cooldown`, `subzone`, `upgrade`, `rep`.

Sémantique héritée de Polestar : **une fois l'étape passée, son résultat est conservé**, même si la condition change ensuite. Le moteur les interprète tous ; un genre inconnu est considéré comme vrai (l'étape s'affiche, le joueur décide). Voir [DESIGN.md](DESIGN.md#conditions-et-sauts).

## Objectif

Une ligne par objectif ; `t` donne le type.

```lua
{ t = "accept", quest = 7, npc = 197, map = 1429, x = 48.92, y = 41.61, z = 82, f = "e", minLevel = 1, qlvl = 2, pre = { 783 } }
```

| Type `t` | Nombre | Accompli quand… |
|---|---|---|
| `accept` | 4 038 | quête dans le journal ou rendue |
| `turnin` | 4 186 | quête rendue |
| `collect` | 2 376 | avec `quest` : objectif de quête rempli, quête terminée ou rendue ; sinon objets dans les sacs (`count`) |
| `goto` | 1 725 | joueur dans le rayon `r` (8 yards par défaut), ou signalé par l'interface |
| `kill` | 1 125 | avec `quest` : objectif rempli ; sinon validation manuelle |
| `explore` | 825 | région découverte ou joueur dedans (région tirée de `text`), sinon comme `goto` |
| `level` | 461 | niveau atteint (avec la fraction `frac`) |
| `train` | 358 | rang de métier atteint (`profLine`, `rankMax`) ; maître de classe ou PNJ : validation manuelle |
| `buy` | 328 | objets dans les sacs |
| `note` | 285 | jamais bloquant |
| `fly` | 235 | joueur dans la région d'arrivée (`area`) |
| `complete` | 234 | quête terminée ou rendue |
| `skill` | 173 | rang de compétence atteint (`skillLine`, `level`) |
| `rep` | 162 | réputation atteinte (`standing`) |
| `craft` | 139 | `untilSkill` atteint ; sinon validation manuelle |
| `talk` | 129 | validation manuelle |
| `use` | 124 | avec `quest` : objectif rempli ; sinon validation manuelle |
| `learn` | 116 | sort ou recette connu |
| `getfp` | 95 | point de vol connu (`node`) ; sans `node`, validation manuelle |
| `vendor` | 95 | validation manuelle |
| `interact` | 75 | avec `quest` : objectif rempli ; sinon validation manuelle |
| `sethome` | 74 | foyer lié à la région (`area`) |
| `hearth` | 66 | joueur dans la région d'arrivée |
| `money` | 13 | argent possédé |
| `task` | 9 | validation manuelle |
| `die` | 4 | jamais : raccourci par la mort désactivé, objectif hors sujet |

Les déplacements (`goto`, `fly`, `hearth`, `enter`, `explore`) sont aussi accomplis dès qu'un objectif suivant de leur étape l'est. Les validations manuelles pourront être faites automatiquement par des événements du jeu (phase 4 : dialogue ouvert, marchand visité…). Un type inconnu est traité en validation manuelle.

*(Nombres au premier import, Polestar 0.3.0.)*

### Champs des objectifs

| Champ | Signification |
|---|---|
| `quest`, `npc`, `object`, `item`, `spell` | Identifiants des entités concernées |
| `count`, `oi` | Quantité, index de l'objectif de quête |
| `map`, `x`, `y`, `z` | `uiMapID`, coordonnées en pourcentage (0-100), hauteur |
| `f` | Repère des coordonnées : `"e"` = repère **era** (Classic) ; absent = repère du client |
| `r` | Rayon d'arrivée (yards) |
| `spotsPacked` | Zones d'apparition : `x,y,z,densité,nombre;…` (décodées à la demande) |
| `optional` | Ne bloque jamais l'étape |
| `only` | Restriction propre à l'objectif (même forme que pour l'étape) |
| `minLevel`, `qlvl` | Niveau requis et niveau de la quête |
| `pre`, `preAll`, `closedBy` | Prérequis (un parmi, tous) et quêtes exclusives |
| `candidates` | Indices dans `guide.pool` (maîtres possibles ; le plus proche est choisi en jeu) |
| `note`, `text` | Conseil et libellé (gabarits) |
| `from*`, `fromNpcs` | Provenance d'un objet (PNJ ou objet du monde) |
| `rewards`, `choose`, `direct`, `xp`, `money` | Récompenses, choix, rendu direct, expérience, argent |
| `skillLine`, `untilSkill`, `rank`, `rankMax`, `reagents`, `profLine`, `profName`, `profRank` | Métiers |
| `standing`, `faction` | Réputation |
| `escort`, `group` | Escorte ; contenu de groupe (`kind` : `elite`, `group`, `dungeon`, `raid`) |

Les autres champs sont repris tels quels de Polestar et documentés au fur et à mesure de leur prise en charge par le moteur.

### Coordonnées

Les coordonnées marquées `f = "e"` sont exprimées dans le repère **era** des cartes du Classic. Quand Forever a modifié une carte, il faut les convertir **en jeu** : passage en coordonnées monde avec `DB.mapFrames.era[map]`, puis retour en pourcentage de la carte du client avec `C_Map.GetMapPosFromWorldPos`. Cette conversion ne peut pas se faire à l'import, car les repères du client ne sont connus qu'en jeu. Elle sera faite par le module Navigation (phase 4).

## Import

```powershell
.\Tools\import\run.ps1    # télécharge, convertit, puis lance luacheck et les tests
```

1. `fetch.ps1` télécharge le commit de Polestar indiqué dans `polestar.lock` (extraction partielle, en cache dans `Tools/import/cache/`, ignoré par git).
2. `import.lua` exécute les fichiers compilés de Polestar dans un environnement isolé (sans accès aux fichiers ni au système, bytecode refusé), vérifie le numéro de format, convertit, écrit les fichiers, puis les relit pour comparer avec la source. Toute fonction `Polestar.*` inconnue arrête l'import : c'est le signe d'un changement de format.
3. Le rapport [`Tools/import/last-import.md`](../Tools/import/last-import.md) donne les totaux, la couverture des noms et les avertissements.

L'import est **reproductible** : deux exécutions sur le même commit produisent des fichiers identiques, ce qui rend les différences lisibles dans git.

Pour importer une nouvelle version de Polestar : modifier `commit`, `date` et `version` dans `polestar.lock`, relancer `run.ps1`, relire le rapport et la différence. Si le `format` change, revoir la conversion avant de modifier `polestar.lock`.

### Transformations

| Polestar | NextStep |
|---|---|
| Races `Human`, `Scourge`, `NightElf`… | `HUMAN`, `SCOURGE`, `NIGHTELF`… |
| `next` texte | `next` liste |
| `npcName`, `itemName`, `objName`, `spellName`, `factionName`, titre de quête, `preTitles`, `from` | Tables de noms anglais (retirés des objectifs) |
| `names` du guide | Tables de noms ; seules les variantes différentes restent dans `guide.names` |
| `candidates` (fiches partagées) | `guide.pool` + indices |
| `author`, `pack`, `written`, `zoneName` | Retirés (`written` se recalcule à partir des noms) |
| Noms et textes français | Seuls ceux que les guides utilisent |
