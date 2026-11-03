# Contribuer à NextStep

Merci de l'intérêt que tu portes au projet. Voici les conventions à respecter.

## Signaler un problème ou proposer une idée

Utilise les [tickets GitHub](https://github.com/fccarlier-be/nextstep/issues) et choisis le modèle adapté. Pour un bug, indique ta version de NextStep, ta race, ta classe, ton niveau et l'étape du guide concernée.

## Branches

- `main` : toujours dans un état fonctionnel.
- Les développements se font sur des branches dédiées, nommées par type : `feat/…`, `fix/…`, `docs/…`, `data/…` (import de données), `chore/…`.
- Fusion dans `main` par pull request.

## Messages de commit

Format [Conventional Commits](https://www.conventionalcommits.org/fr/) :

```
type(portée): résumé court à l'impératif

Explication facultative du pourquoi.
```

Types : `feat`, `fix`, `docs`, `data`, `refactor`, `test`, `chore`.
Exemples : `feat(guide): calcul de l'étape courante`, `data(polestar): import de la version 0.3.0`.

## Code

- Lua 5.1, indentation de 4 espaces, fin de ligne LF.
- Aucune variable globale hors de l'espace de noms de l'addon.
- Aucune comparaison ni opération sur une valeur potentiellement secrète (voir [DESIGN.md](docs/DESIGN.md#secret-values)).
- Le code doit passer `luacheck` et les tests hors jeu.

## Données

- Ne jamais modifier `Data/Imported/` à la main : relancer le script d'import.
- Les corrections vont dans `Data/Overrides/`, avec la source de l'information en commentaire.
- Toute nouvelle source de données doit avoir une licence compatible avec la GPL-3.0 et être ajoutée à [DATA_SOURCES.md](docs/DATA_SOURCES.md) et [CREDITS.md](CREDITS.md).

## Documentation

- Toute décision de conception modifiée est reportée dans [DESIGN.md](docs/DESIGN.md).
- Toute modification visible est ajoutée au [CHANGELOG](CHANGELOG.md), section « Non publié ».
- L'état d'avancement est tenu à jour dans [ROADMAP.md](docs/ROADMAP.md).

## Licence

En contribuant, tu acceptes que ta contribution soit distribuée sous la licence [GPL-3.0](LICENSE) du projet.
