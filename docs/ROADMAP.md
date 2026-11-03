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
| 1 | Vérifications en jeu | — | ⬜ |
| 2 | Import des données | — | ⬜ |
| 3 | Moteur du guide | — | ⬜ |
| 4 | Interface du guide | **v0.1** | ⬜ |
| 5 | Gains rapides du module UI | v0.2 | ⬜ |
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

État : tout est en place, et les tests passent en local. **Reste à confirmer** le chargement en jeu, dès la fin du téléchargement du client.

## Phase 1 : Vérifications en jeu *(dès la sortie du client)*

Un addon de diagnostic temporaire, qui teste et consigne les points marqués « à vérifier » dans [DESIGN.md](DESIGN.md) :

- numéro d'interface, suffixe TOC, chemin du dossier AddOns ;
- secret values : ce qui peut être affiché en combat et hors combat, fonctions de formatage disponibles ;
- options natives : texte de statut, sacs combinés, horloge et alarme, zoom de la carte du monde ;
- position et orientation du joueur, possibilité d'équiper un objet par addon, nameplates ;
- API des quêtes (`C_QuestLog`) ;
- faction connue au chargement pour la race Skyborne.

**Terminé quand** : un rapport de vérification est publié dans `docs/`, et la feuille de route est ajustée si nécessaire.

## Phase 2 : Import des données *(sans le jeu)*

- Script d'import : chargement isolé des fichiers compilés de Polestar (guides, items, noms français), contrôle du numéro de format, conversion vers le format NextStep.
- Couche d'accès aux données ; séparation commun / Alliance / Horde.

**Terminé quand** : les guides importés sont fidèles aux originaux (nombre de guides et d'étapes, échantillons comparés automatiquement).

## Phase 3 : Moteur du guide *(sans le jeu)*

- États des étapes, étape courante calculée, modes strict et libre, étapes bloquées, ignorées et hors sujet, détours.
- Tests avec joueurs simulés : départ niveau 1, détour, quête abandonnée, personnage en avance de niveau…

**Terminé quand** : tous les scénarios de test passent.

## Phase 4 : Interface du guide → v0.1

- Fenêtre du guide, journal (onglet Routes, « Choisis ton chemin »), flèche (version simple).
- Points sur la carte et la minimap (HereBeDragons), masquage du suivi de quêtes Blizzard.
- Commande `/ns`, raccourcis clavier.

**Terminé quand** : on peut monter un personnage du niveau 1 à 10 avec le guide.

## Phase 5 : Gains rapides du module UI → v0.2

- Minimap : carrée, zoom à la molette, coordonnées, tiroir de boutons.
- Vente automatique de la camelote.
- Horloge : alarmes, minuteurs, chronomètre.

Ces éléments sont indépendants du guide et peuvent être avancés si besoin.

## Phase 6 : Items → v0.3

- Calcul du score, détection de la spécialisation (modifiable à la main).
- Récompenses de quête mises en évidence, infobulles, alerte d'amélioration.

## Phase 7 : Valeurs de vie et de ressources → v0.4

- Cadres d'unité Blizzard et nameplates, selon les résultats de la phase 1.

## Phase 8 : Sacs et banque → v0.5

- Sacs et banque unifiés, banque consultable à distance, mémoire des autres personnages, marques sur les objets.

## Phase 9 : Métiers → v0.6

- Conseiller de métiers, routes de métiers, intégration dans la route de leveling, onglet Métiers.

## Phase 10 : Items à ne pas rater, jalons, mode libre → v0.7

- Items par tranche de niveaux intégrés à la route, jalons (sacs, monture, quêtes de classe), onglet Zones.

## Phase 11 : Finitions et publication → v1.0

- Graphismes définitifs (icône, flèche), relecture des traductions, options complètes.
- Page CurseForge, documentation utilisateur, vérification des crédits et licences.
- Prise de contact avec l'auteur de Polestar avant la publication.

---

## Maintenance continue

- **Après chaque mise à jour de Polestar** : relancer l'import.
- **Après chaque patch de WoW Forever** : relancer l'addon de diagnostic pour détecter les changements d'API.
