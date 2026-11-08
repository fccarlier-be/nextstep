# Feuille de route

Ce document décrit l'ordre de développement de NextStep. Chaque phase a un critère de fin clair. Les versions numérotées sont des jalons jouables.

Trois principes guident l'ordre :

1. **D'abord ce qui se fait sans le jeu** (structure, import, moteur), testé hors du jeu.
2. **Vérifier tôt les inconnues** (secret values, options natives du client) : leurs réponses peuvent modifier les phases suivantes.
3. **Une version utilisable au plus vite** : le guide d'abord, c'est le cœur de l'addon.

Chaque phase correspond à un [jalon GitHub](https://github.com/fccarlier-be/nextstep/milestones) qui regroupe ses tickets.

Légende : ⬜ à faire · 🟨 en cours · ✅ terminé

| Phase | Contenu | Version | État |
|---|---|---|---|
| — | Conception | — | ✅ |
| 0 | Fondations | — | 🟨 |
| 1 | Vérifications en jeu | — | 🟨 |
| 2 | Import des données | — | ✅ |
| 2b | Noms appris | — | ✅ |
| 3 | Moteur du guide | — | ✅ |
| 4 | Interface du guide, version minimale | **v0.1** | ✅ |
| 4b | Compléments du guide | v0.1.x | 🟨 |
| 5 | Gains rapides du module UI | v0.2 | 🟨 |
| 6 | Items | v0.3 | ⬜ |
| 7 | Valeurs de vie et de ressources | v0.4 | ⬜ |
| 8 | Sacs et banque | v0.5 | ⬜ |
| 9 | Métiers | v0.6 | ⬜ |
| 10 | Items à ne pas rater, jalons, mode libre | v0.7 | ⬜ |
| 11 | Finitions et publication | **v1.0** | ⬜ |

---

## Phase 0 : Fondations *(sans le jeu)*

- Structure du projet, fichiers TOC (cœur et dossiers de faction chargés à la demande).
- Le cœur : initialisation, événements, sauvegardes (SavedVariables), système de modules activables, squelette des options, traductions (frFR, enUS).
- Outils : Lua 5.1 en local, banc de test simulant l'API du jeu, luacheck, intégration continue sur GitHub.
- Script reliant le dossier de développement au dossier AddOns du jeu (lien de répertoire, un `/reload` suffit pour tester).

**Terminé quand** : l'addon se charge en jeu (vide) et les tests tournent en local et sur GitHub.

État : tout est en place, et les tests passent en local (LuaJIT) et sur GitHub (Lua 5.1). **Reste à confirmer** le chargement en jeu, dès la fin du téléchargement du client.

## Phase 1 : Vérifications en jeu *(dès la sortie du client)*

Un addon de diagnostic temporaire, qui teste et consigne les points marqués « à vérifier » dans [DESIGN.md](DESIGN.md) :

- numéro d'interface, suffixe TOC, chemin du dossier AddOns ;
- secret values : ce qui peut être affiché en combat et hors combat, fonctions de formatage disponibles ;
- options natives : texte de statut, sacs combinés, horloge et alarme, zoom de la carte du monde ;
- position et orientation du joueur, possibilité d'équiper un objet par addon, nameplates ;
- API des quêtes (`C_QuestLog`) ;
- noms fournis par le client (régions, zones, sorts, objets, quêtes) et `raceFile` de Skyborne ;
- noms appris : `UnitGUID` et `UnitName` sur cible, survol, nameplates et dialogue ; infobulle d'un PNJ par `C_TooltipInfo.GetHyperlink` ; panneau d'options (`Settings`, `UICheckButtonTemplate`) ;
- faction connue au chargement pour la race Skyborne ;
- chargement des données importées : temps et mémoire ;
- ajoutés après la conception : liste du maître de classe à l'ouverture (services, niveaux, coûts), textures d'exploration de la carte (`C_MapExplorationInfo`), fenêtres Blizzard à rendre déplaçables et à ouvrir ensemble (protection, `UIPanelWindows`, `UISpecialFrames`, strate), journal des donjons natif (`EncounterJournal`), boutons de la minimap et options des addons (`AddonCompartmentFrame`, `SettingsPanel`, LibDBIcon), source d'un butin et détection d'une récolte (`GetLootSourceInfo`, dernier sort lancé).

**Terminé quand** : un rapport de vérification est publié dans `docs/`, et la feuille de route est ajustée si nécessaire.

État : l'addon de diagnostic est **prêt** (`Tools/diagnostic/`, commande `/nsdiag`) ; il reste à le lancer en jeu à la sortie du client. Procédure : [docs/reports/README.md](reports/README.md).

## Phase 2 : Import des données *(sans le jeu)*

- Script d'import : chargement isolé des fichiers compilés de Polestar (guides, noms et textes français), contrôle du numéro de format, conversion vers le format NextStep.
- Couche d'accès aux données ; séparation commun / Alliance / Horde.

**Terminé quand** : les guides importés sont fidèles aux originaux (nombre de guides et d'étapes, échantillons comparés automatiquement).

État : **terminé**. 256 guides, 6 046 étapes et 17 450 objectifs importés, vérifiés objectif par objectif, et relus à l'identique ; import reproductible. Le format est décrit dans [DATA_FORMAT.md](DATA_FORMAT.md). Les statistiques d'items et les faits de forever-db seront importés avec les modules qui les utilisent (phases 6 et 10).

## Phase 2b : Noms appris *(sans le jeu)*

Ajoutée après l'import : Polestar ne traduit qu'environ la moitié des PNJ.

- Module qui retient le nom des PNJ croisés, dans la langue du client (cible, survol, nameplates, dialogue), et interroge l'infobulle du client pour les PNJ jamais croisés.
- Actif par défaut sur les clients non anglais, désactivable dans les options ; premières cases à cocher du panneau d'options.

État : **terminé** ; les API concernées sont à vérifier en jeu (phase 1).

## Phase 3 : Moteur du guide *(sans le jeu)*

- États des étapes, étape courante calculée, modes strict et libre, étapes bloquées, ignorées et hors sujet, détours.
- Tests avec joueurs simulés : départ niveau 1, détour, quête abandonnée, personnage en avance de niveau…

**Terminé quand** : tous les scénarios de test passent.

État : **terminé**. 23 scénarios du moteur, 10 tests d'intégration sur les vrais guides, et un joueur automatique qui termine chacun des guides importés, pour chaque faction. Changement de conception : une étape dépassée garde son résultat (sémantique de Polestar), et une quête abandonnée est signalée au lieu de faire reculer le guide (voir [DESIGN.md](DESIGN.md#5-moteur-du-guide)).

## Phase 4 : Interface du guide, version minimale → v0.1

Le plus petit guide jouable : tout ce qui sert à suivre la route, rien de plus. Les compléments (phase 4b) suivent aussitôt, en petites versions.

- État du joueur lu dans le jeu (journal de quêtes, sacs, compétences, position, conversion des coordonnées « era ») et recalcul du guide sur les événements ; validations automatiques par événements (dialogue, marchand, maître).
- Fenêtre du guide (voir [DESIGN.md](DESIGN.md#fenêtre-du-guide)), flèche (version simple), masquage du suivi de quêtes Blizzard.
- Commande `/ns`, raccourcis clavier.

**Terminé quand** : on peut monter un personnage du niveau 1 à 10 avec le guide.

État : **écrit et testé hors jeu** : état du joueur lu dans l'API, recalcul sur les événements, validations automatiques (dialogue, marchand, maître, carte des vols, sort lancé), fenêtre, flèche, masquage du suivi Blizzard, `/ns guide`, `/ns arrow` et trois raccourcis. La conversion des coordonnées « era » n'est pas nécessaire pour la flèche (calcul en coordonnées monde, voir [DESIGN.md](DESIGN.md#flèche)). Vérifié en jeu le 2026-11-05 (un elfe de la nuit chasseur a fini le guide d'Elwynn et commencé le suivant) ; les problèmes relevés en jeu sont corrigés. **Terminé** : publiée en v0.1.0.

## Phase 4b : Compléments du guide → v0.1.x

Chaque complément est indépendant des autres et ne dépend que de la v0.1 : il a sa branche, sa pull request et **sa propre version** (v0.1.1, v0.1.2…), publiée dès qu'il est prêt en poussant un tag (voir [RELEASE.md](RELEASE.md)). L'ordre ci-dessous est indicatif ; plusieurs peuvent avancer en parallèle.

| Complément | Contenu |
|---|---|
| Carte et minimap | Points de l'étape sur la carte du monde et la minimap : écrit et testé hors jeu (`Modules/Guide/Pins.lua`), à vérifier en jeu. |
| Sorts à apprendre | Sorts disponibles chez le maître selon la classe, la race et le niveau, avec leur coût ; étape « maître de classe » dans la route ; liste mémorisée à chaque visite chez le maître. **Écrit et testé hors jeu** (tables de What's Training, coût, étape « maître de classe » validée quand il n'y a rien à apprendre) ; **liste lue chez le maître** (retenue à chaque visite, elle remplace les tables tant que le niveau ne change pas) et **rappel en ville** (maître de classe à moins de 400 m avec des sorts à apprendre : ligne cliquable qui pointe la flèche vers lui) écrits et testés hors jeu ; à vérifier en jeu. |
| Célébration de niveau | Bandeau, son du jeu, nouveaux sorts disponibles et zone suivante conseillée. **Écrit et testé hors jeu** (`Modules/Guide/Celebration.lua`) ; à vérifier en jeu, graphismes en phase 11. |
| Niveau des zones | Niveau des zones affiché sur la carte du monde. **Écrit et testé hors jeu** (module `ZoneLevels`) ; à vérifier en jeu. |
| Journal | Journal du guide : onglet Routes, « Choisis ton chemin ». **Écrit et testé hors jeu** (onglets Routes et Sorts de classe) ; à vérifier en jeu. |

**Terminé quand** : tous les compléments sont publiés, et le guide signale les visites au maître de classe.

## Phase 5 : Gains rapides du module UI → v0.2

- Minimap : carrée, zoom à la molette, coordonnées, bouton NextStep avec le menu des addons (accès aux paramètres de chaque addon installé), boutons des autres addons masqués.
- **Radar de récolte** : minimap en grand et en transparence au centre de l'écran, pour farmer les ressources.
- Vente automatique de la camelote.
- Horloge : alarmes, minuteurs, chronomètre.
- **Fenêtres déplaçables** : personnage, grimoire, journal de quêtes, etc. ; positions mémorisées ; plusieurs fenêtres ouvertes en même temps, avec passage au premier plan au clic et Échap qui ferme la fenêtre au premier plan.
- **Carte sans brouillard** : zones inexplorées affichées (désactivable).

Ces éléments sont indépendants du guide et peuvent être avancés si besoin.

État : **carte sans brouillard avancée** : module `MapReveal` écrit et testé hors jeu, données extraites du client ; reste à le vérifier en jeu (voir [DESIGN.md](DESIGN.md#carte-sans-brouillard)). **Radar de récolte avancé** : module `Radar` écrit et testé hors jeu ; reste à le vérifier en jeu (voir [DESIGN.md](DESIGN.md#radar-de-récolte)). **Minimap et bouton NextStep avancés** : modules `Minimap` (carrée, molette) et `AddonsMenu` (bouton, menu des addons, radar, boutons LibDBIcon masqués) écrits et testés hors jeu ; restent la vérification en jeu. Coordonnées : déjà affichées par le client Forever sous la minimap. **Camelote et fenêtres déplaçables écrites et testées hors jeu** (modules `Junk` et `Windows`) ; **horloge écrite et testée hors jeu** (module `Clock` : alarmes, minuteurs, chronomètre) ; passage au premier plan au clic fait ; **plusieurs fenêtres de Blizzard ouvertes ensemble écarté** : il faudrait retirer les fenêtres de la table `UIPanelWindows`, ce qui souille l'interface (erreurs « action bloquée »).

## Phase 6 : Items → v0.3

- Import des statistiques d'items et des poids de stats (Polestar_ItemDB).
- Calcul du score, détection de la spécialisation (modifiable à la main).
- Récompenses de quête mises en évidence, infobulles, alerte d'amélioration.

État : **écrit et testé hors jeu** (module `Items`, `Modules/Items/`) : poids de stats importés de Polestar (`Tools/import/gear.lua`, tranches de niveau mêlées à wowsims), stats lues dans le client (`C_Item.GetItemStats`, chiffres propres à Forever), spécialisation détectée par les talents ou choisie dans les options, gain ou perte dans l'infobulle, récompense de quête conseillée avec la raison, alerte d'amélioration (hors combat, groupée, seuil, équiper d'un clic), `/ns gear`. Complété ensuite : onglet **Donjons** du journal (quêtes à prendre avant chaque donjon, étapes restantes de leur suite de quêtes avec donneur et zone, flèche vers le donneur, butin des boss avec le gain, butin vu en jeu) et onglet **Équipement** (prochains jalons : sorts, quêtes de classe, sacs, monture ; équipement à ne pas rater d'ici cinq niveaux avec sa provenance) ; récompenses qui améliorent l'équipement signalées sur les lignes du guide. Données : `Tools/import/dungeons.py` (forever-db, `Polestar_ItemDB`). **Phase terminée hors jeu** ; reste la vérification en jeu.

## Phase 7 : Valeurs de vie et de ressources → v0.4

- Cadres d'unité Blizzard et nameplates, selon les résultats de la phase 1.

## Phase 8 : Sacs et banque → v0.5

- Sacs et banque unifiés, banque consultable à distance, mémoire des autres personnages, marques sur les objets.

## Phase 9 : Métiers → v0.6

- Conseiller de métiers, routes de métiers, intégration dans la route de leveling, onglet Métiers.
- **Points de récolte** : enregistrement automatique des herbes, minerais et autres ressources récoltés, affichés sur la carte et la minimap.

## Phase 10 : Items à ne pas rater, jalons, mode libre → v0.7

- Import des faits de forever-db (quêtes, PNJ) pour le mode conseil.
- Items par tranche de niveaux intégrés à la route, jalons (sacs, monture, quêtes de classe), onglet Zones.
- **Butin des donjons** : récompenses de chaque donjon, améliorations pour la spécialisation du joueur mises en évidence (enrichit le journal natif s'il existe).

## Phase 11 : Finitions et publication → v1.0

- Graphismes définitifs (flèche ; le logo est fait), relecture des traductions, options complètes.
- Page CurseForge (texte prêt, empaquetage automatique en place : [RELEASE.md](RELEASE.md)), documentation utilisateur, vérification des crédits et licences.
- Prise de contact avec l'auteur de Polestar avant la publication.

## Après la v1.0 *(à l'étude)*

- **Prix de l'hôtel des ventes** : prix mémorisés lors des visites, utilisés pour les récompenses de quête, l'objectif « or » des métiers et les infobulles (voir [DESIGN.md](DESIGN.md#10-idées-à-létude)).

---

## Maintenance continue

- **Après chaque mise à jour de Polestar** : relancer l'import.
- **Après chaque patch de WoW Forever** : relancer l'addon de diagnostic pour détecter les changements d'API.
