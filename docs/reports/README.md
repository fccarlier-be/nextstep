# Rapports de diagnostic

Les rapports de ce dossier sont produits par l'addon de développement **NextStep - Diagnostic** (`Tools/diagnostic/`), qui vérifie en jeu les points marqués **[À vérifier]** dans [DESIGN.md](../DESIGN.md) : phase 1 de la [feuille de route](../ROADMAP.md), puis après chaque patch du jeu.

## Procédure

1. Une fois : `.\Tools\deploy.ps1` (relie aussi l'addon de diagnostic au dossier AddOns du jeu).
2. En jeu, avec un personnage :
   - cibler un PNJ, puis taper `/nsdiag` : vérifications hors combat, résumé dans le chat ;
   - taper `/nsdiag combat`, puis attaquer un monstre : capture du comportement des *secret values* en combat ;
   - taper `/reload` : le jeu écrit le rapport dans les sauvegardes.
3. Sur le PC : `.\Tools\diagnostic\report.ps1` écrit `docs/reports/diagnostic-<date>.md`.

`/nsdiag show` affiche le dernier rapport dans une fenêtre, pour le copier si besoin.

## Ce qui est vérifié

| Section | Contenu |
|---|---|
| Client | Interface, projet, langue, `raceFile` et `classFile`, faction connue au chargement |
| API | Existence d'environ 90 fonctions : quêtes, cartes et position, objets et sacs, sorts et métiers, unités et combat, interface et addons |
| Valeurs lues hors combat | Journal de quêtes, noms fournis par le client (région, carte, sort, objet), foyer, zone, compétences, orientation, nom d'un PNJ par son infobulle, cible |
| Interface native | Texte de statut, sacs combinés, horloge, zoom de la carte et de la minimap, modèles de cadres, suivi d'objectifs |
| NextStep | Chargement, mémoire de chaque addon, faction chargée, guides, rendu d'un texte, noms appris, panneau d'options |
| Coordonnées | Écart entre le repère *era* importé et la position donnée par le client, sur la carte du joueur |
| Combat | Valeurs secrètes ou non (santé, ressource, nom, GUID), opérations permises (calcul, comparaison, `string.format`, `SetText`, barres, fonctions de formatage), nameplates |

L'addon de diagnostic n'est jamais livré aux joueurs.
