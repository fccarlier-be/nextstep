# Changelog

Toutes les modifications notables de NextStep sont consignées ici.

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/), et le projet respecte le [versionnage sémantique](https://semver.org/lang/fr/).

## [Non publié]

### Ajouté
- Import des guides de Polestar 0.3.0 : 256 guides (leveling des deux factions et de chaque race, classes, métiers, réputations, collection), noms anglais et français, traductions françaises des textes ; script d'import isolé, vérifié et reproductible (`Tools/import/`), rapport `Tools/import/last-import.md`.
- Couche d'accès aux données `ns.DB` : guides, noms dans la langue du client (traduction importée, puis noms fournis par le client, puis anglais), rendu des textes de guide.
- Documentation du format de données ([docs/DATA_FORMAT.md](docs/DATA_FORMAT.md)).
- Cœur de l'addon : espace de noms, répartition des événements et messages internes, sauvegardes avec schéma et migrations, registre de modules activables avec détection des addons concurrents, traductions (anglais par défaut, français), panneau d'options, commandes `/ns` et `/nextstep`.
- Addons de données `NextStep_Alliance` et `NextStep_Horde`, chargés à la demande selon la faction du personnage.
- Tests hors jeu avec simulation de l'API du jeu (37 tests), configuration luacheck et intégration continue GitHub.
- Scripts de développement : installation des outils (`Tools/setup.ps1`), vérifications (`Tools/check.ps1`), liaison au dossier AddOns du jeu (`Tools/deploy.ps1`).
- Documentation de conception : architecture, moteur du guide, modules Items, Métiers et UI ([docs/DESIGN.md](docs/DESIGN.md)).
- Feuille de route en 12 phases jusqu'à la v1.0 ([docs/ROADMAP.md](docs/ROADMAP.md)).
- Recensement des sources de données et de leurs licences ([docs/DATA_SOURCES.md](docs/DATA_SOURCES.md)).
- README, licence GPL-3.0, crédits, guide de contribution.
- Configuration du dépôt : modèles de tickets et de pull request, fichiers `.gitignore`, `.gitattributes` et `.editorconfig`.

[Non publié]: https://github.com/fccarlier-be/nextstep/commits/main
