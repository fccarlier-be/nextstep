# Changelog

Toutes les modifications notables de NextStep sont consignées ici.

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/), et le projet respecte le [versionnage sémantique](https://semver.org/lang/fr/).

## [Non publié]

### Ajouté
- **Moteur du guide** (`Modules/Guide/`) : conditions (`only`, `when`), état des 26 types d'objectifs, étape courante calculée, étapes dépassées mémorisées par clé stable, sauts (`skipto`), objectifs en chemin (`along`), quêtes de groupe, modes strict et libre, détours, quêtes abandonnées signalées, conseils (personnage en avance, quêtes grises), guides suivants.
- **Module Guide** : guide actif et progression par personnage, ignorer et réactiver une étape, validations manuelles, réponses aux quêtes de groupe, suggestion du guide de départ selon la race, la classe et le niveau.
- Joueur simulé et joueur automatique pour les tests : chaque guide importé est parcouru jusqu'au bout.
- Module **Noms appris** : retient le nom des PNJ croisés dans la langue du client (cible, survol, nameplates, dialogue) et interroge l'infobulle du client pour les autres, afin de traduire les guides là où Polestar n'a pas de traduction. Actif par défaut sur les clients non anglais, jamais en combat, rien n'est envoyé ; désactivable, avec un bouton pour oublier les noms appris.
- Panneau d'options : une case à cocher par module, avec sa description et ses réglages.
- Import des guides de Polestar 0.3.0 : 256 guides (leveling des deux factions et de chaque race, classes, métiers, réputations, collection), noms anglais et français, traductions françaises des textes ; script d'import isolé, vérifié et reproductible (`Tools/import/`), rapport `Tools/import/last-import.md`.
- Couche d'accès aux données `ns.DB` : guides, noms dans la langue du client (traduction importée, puis noms fournis par le client, puis anglais), rendu des textes de guide.
- Documentation du format de données ([docs/DATA_FORMAT.md](docs/DATA_FORMAT.md)).
- Cœur de l'addon : espace de noms, répartition des événements et messages internes, sauvegardes avec schéma et migrations, registre de modules activables avec détection des addons concurrents, traductions (anglais par défaut, français), panneau d'options, commandes `/ns` et `/nextstep`.
- Addons de données `NextStep_Alliance` et `NextStep_Horde`, chargés à la demande selon la faction du personnage.
- Tests hors jeu avec simulation de l'API du jeu (86 tests), configuration luacheck et intégration continue GitHub.
- Scripts de développement : installation des outils (`Tools/setup.ps1`), vérifications (`Tools/check.ps1`), liaison au dossier AddOns du jeu (`Tools/deploy.ps1`).
- Documentation de conception : architecture, moteur du guide, modules Items, Métiers et UI ([docs/DESIGN.md](docs/DESIGN.md)).
- Feuille de route en 12 phases jusqu'à la v1.0 ([docs/ROADMAP.md](docs/ROADMAP.md)).
- Recensement des sources de données et de leurs licences ([docs/DATA_SOURCES.md](docs/DATA_SOURCES.md)).
- README, licence GPL-3.0, crédits, guide de contribution.
- Configuration du dépôt : modèles de tickets et de pull request, fichiers `.gitignore`, `.gitattributes` et `.editorconfig`.

[Non publié]: https://github.com/fccarlier-be/nextstep/commits/main
