# Publier une version

NextStep est empaqueté par le [BigWigs packager](https://github.com/BigWigsMods/packager), dans GitHub Actions ([`.github/workflows/release.yml`](../.github/workflows/release.yml)). La configuration est dans [`.pkgmeta`](../.pkgmeta).

## Ce que contient l'archive

`NextStep-<version>.zip` contient les trois dossiers à copier dans `Interface\AddOns` : `NextStep`, `NextStep_Alliance` et `NextStep_Horde`. Le reste du dépôt (outils, dont l'addon de diagnostic, tests, documentation, images) n'est jamais livré.

Dans le dépôt, les TOC portent `## Version: @project-version@` ; le packager le remplace par le nom du tag. Lancé depuis le dépôt (jonctions de `Tools/deploy.ps1`), l'addon affiche la version `dev`.

## Publier

1. Dans `CHANGELOG.md`, renommer la section « Non publié » en `## [0.1.0] - AAAA-MM-JJ`, ouvrir une nouvelle section « Non publié » vide, et ajouter le lien de comparaison en bas du fichier.
2. Relire la description CurseForge ([CURSEFORGE.md](CURSEFORGE.md)) : elle ne décrit que ce qui est dans le fichier publié.
3. Fusionner ces changements dans `main`, puis créer et pousser un tag **annoté** :

   ```powershell
   git tag -a v0.1.0 -m "v0.1.0"
   git push origin v0.1.0
   ```

4. Le workflow « Empaquetage » crée la release GitHub avec l'archive, et l'envoie sur CurseForge si celui-ci est configuré (voir plus bas).

Type de version, d'après le tag : `v0.1.0-alpha1` → alpha, `v0.1.0-beta1` → bêta, `v0.1.0` → version stable. Une alpha ou une bêta permet de faire tester une version à quelques joueurs sans l'annoncer à tous.

Les compléments du guide (phase 4b de la [feuille de route](ROADMAP.md)) sont publiés un par un : un tag `v0.1.1`, `v0.1.2`… dès que l'un d'eux est fusionné.

## Vérifier l'archive sans rien publier

Une pull request qui modifie `.pkgmeta`, le workflow ou un TOC construit l'archive sans l'envoyer. Le workflow peut aussi être lancé à la main (onglet Actions, « Empaquetage », *Run workflow*). L'archive est jointe à l'exécution, dans la section *Artifacts*.

## Configurer CurseForge (une seule fois)

Sans ces deux réglages, le workflow publie seulement sur GitHub.

1. Créer le projet sur CurseForge, puis ajouter son identifiant dans `addon/NextStep/NextStep.toc` : `## X-Curse-Project-ID: 123456`.
2. Créer un jeton d'API sur <https://authors.curseforge.com/account/api-tokens>, et l'enregistrer dans le dépôt comme secret `CF_API_KEY` (*Settings → Secrets and variables → Actions*, ou `gh secret set CF_API_KEY`).

Le packager détecte la version du jeu à partir de `## Interface`. Si CurseForge ne reconnaît pas celle de WoW Forever, la forcer avec l'option `-g` dans le workflow.

## Bibliothèques

Les bibliothèques (LibStub, HereBeDragons…) seront déclarées dans la section `externals` de `.pkgmeta`, au moment où un module en aura besoin (complément « Carte et minimap »). Le packager les télécharge à chaque empaquetage. Elles ne sont pas copiées dans le dépôt : pour jouer depuis le dépôt, `Tools/setup.ps1` devra les télécharger aux mêmes versions (dossier ignoré par git).
