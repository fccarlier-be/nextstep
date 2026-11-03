# Page CurseForge

Ce document contient le texte de la page CurseForge de NextStep et la liste des règles à respecter, tirées de la [politique de modération de CurseForge](https://support.curseforge.com/support/solutions/articles/9000197279-moderation-policies).

## Règles de modération à respecter

| Règle CurseForge | Application à NextStep |
|---|---|
| Nom en anglais, sans nom du jeu, de classe ni numéro de version | « NextStep » : conforme. Ne pas écrire « NextStep - WoW Forever ». |
| Résumé : un aperçu court, idéalement une phrase, qui ne répète pas la description | Résumé ci-dessous, formulé autrement que l'accroche de la description. |
| Description : dire ce que l'addon ajoute ou change, avec des informations concrètes | Seules les fonctionnalités **présentes dans le fichier publié** sont décrites ; le reste tient en une ligne « prévu ». |
| Autres langues autorisées, mais **l'anglais d'abord** | Un seul champ de description : anglais en premier, puis français. |
| Avatar 400×400, pas en WebP, ni couleur unie ni image protégée | `img/logo/nextstep-curseforge-400.png` (PNG 400×400, logo original). |
| Images retouchées par IA qui pourraient tromper sur l'addon : mention visible | Le logo n'est pas une capture d'écran ; il est quand même signalé comme généré par IA en bas de page. Les captures de la galerie doivent être de vraies captures en jeu, sans retouche. |
| Liens vers son site, son dépôt, ses dons : **uniquement en bas** de la description | Le lien GitHub n'apparaît que dans la dernière section. Aucun lien de don. |
| Aucun lien de téléchargement externe | Aucun : le fichier est téléchargé sur CurseForge. |
| Contenu réutilisé : sous licence ou avec permission (la permission est recommandée même sous licence), et crédité | Polestar (GPL-3.0), HereBeDragons (BSD) et les autres sources sont crédités et liés. **Contacter l'auteur de Polestar avant la publication** (prévu en phase 11 de la [feuille de route](ROADMAP.md)). |
| Logiciel libre accepté si sa licence est respectée | NextStep est sous GPL-3.0, comme Polestar ; fichier `LICENSE` inclus dans le paquet. |
| Respect du jeu, de son éditeur et de ses conditions d'utilisation | Aucune automatisation interdite ; mention des marques de Blizzard. |
| Proposer un canal de retour (bugs, idées) | Tickets GitHub et commentaires CurseForge, cités en bas de page. |
| Un changelog pour chaque fichier envoyé | Coller la section de la version tirée de [CHANGELOG.md](../CHANGELOG.md) à chaque envoi. |
| Pas de mises à jour vides ni de renvois pour gagner en visibilité | Ne publier que des versions qui changent quelque chose. |

**À chaque version** : relire la description et retirer de « Planned » ce qui est devenu disponible (et l'inverse), pour que la page décrive toujours le fichier publié.

## Résumé (champ « Summary »)

> Leveling guide with detour support, map arrow and French translations, plus planned gear, profession and UI helpers, all in one addon.

## Description (champ « Description », Markdown)

Copier tout ce qui se trouve entre les deux marques.

<!-- Début de la description -->

# NextStep

**One addon to take your characters from level 1 to the top on WoW Forever.**

*Version française plus bas.*

## What it does

**Leveling guide**
- **256 guides**: leveling for both factions and every race, plus class, profession, reputation and collection guides.
- A **step-by-step route** tailored to your race, class and level. NextStep suggests the right starting guide for your character.
- **Detours are fine**: follow an off-route quest chain and the guide catches up on its own when you come back.
- An abandoned quest is **flagged** instead of sending the guide backwards.
- **Tips** when you are ahead of the curve or when quests turn grey, and the **next guide** offered when you finish one.
- A navigation **arrow**, and pins on the **world map** and **minimap**.
- Progress saved **per character**.

**Translations**
- Guides in **English and French**.
- Where a French name is missing, NextStep **learns NPC names** as you meet them, in your client's language (target, mouseover, nameplates, dialogue). It never runs in combat, sends nothing, and can be turned off in the options.

**Planned**: profession advisor and routes, quest reward and gear upgrade hints, health and resource values, unified bags and bank, minimap and clock improvements.

## How to use it

- Type `/ns` or `/nextstep` to open NextStep.
- Options are under *Options → AddOns → NextStep*. Each module has its own checkbox.

## Good to know

- **No data leaves your PC**: NextStep talks to no server.
- It **enhances the Blizzard UI** rather than replacing it, to avoid errors and conflicts with other addons.
- Only your faction's data is loaded.
- Languages: English and French.

---

# NextStep (français)

**Un seul addon pour monter tes personnages du niveau 1 jusqu'au sommet sur WoW Forever.**

## Ce que fait l'addon

**Guide de leveling**
- **256 guides** : leveling des deux factions et de chaque race, et guides de classe, de métiers, de réputation et de collection.
- Une **route étape par étape**, adaptée à ta race, ta classe et ton niveau. NextStep te suggère le bon guide de départ.
- **Les détours ne posent pas de problème** : suis une suite de quêtes hors route, le guide se recale tout seul à ton retour.
- Une quête abandonnée est **signalée**, sans faire reculer le guide.
- Des **conseils** quand tu es en avance de niveau ou que les quêtes deviennent grises, et le **guide suivant** proposé à la fin.
- Une **flèche** de navigation, et des points sur la **carte du monde** et la **minimap**.
- Progression enregistrée **par personnage**.

**Traduction**
- Guides en **français et en anglais**.
- Quand un nom français manque, NextStep **apprend le nom des PNJ** que tu croises, dans la langue de ton client (cible, survol, barres de nom, dialogue). Jamais en combat, rien n'est envoyé, et le module se désactive dans les options.

**Prévu** : conseiller et routes de métiers, récompenses de quête et améliorations d'équipement conseillées, valeurs de vie et de ressources, sacs et banque unifiés, minimap et horloge améliorées.

## Utilisation

- Tape `/ns` ou `/nextstep` pour ouvrir NextStep.
- Les options sont dans *Options → AddOns → NextStep*. Chaque module a sa case à cocher.

## Bon à savoir

- **Aucune donnée ne quitte ton PC** : NextStep ne communique avec aucun serveur.
- Il **améliore l'interface Blizzard** au lieu de la remplacer, pour éviter les erreurs et les conflits avec d'autres addons.
- Seules les données de ta faction sont chargées.
- Langues : français et anglais.

---

## Credits / Crédits

NextStep builds on these open-source projects. Thanks to their authors. / NextStep s'appuie sur ces projets libres. Merci à leurs auteurs.

- **[Polestar](https://github.com/fitzforge/polestar)**: leveling, class and profession guides, translated names and texts / guides, noms et textes traduits (GPL-3.0).
- **[HereBeDragons](https://github.com/Nevcairiel/HereBeDragons)** by Nevcairiel: map, minimap and coordinates / carte, minimap et coordonnées (BSD).

The logo was generated with AI (FLUX.2 [klein], background removed with BiRefNet). / Le logo a été généré par IA (FLUX.2 [klein], détourage avec BiRefNet).

*World of Warcraft* and *WoW Forever* are trademarks of Blizzard Entertainment. NextStep is a fan project, not affiliated with Blizzard. / *World of Warcraft* et *WoW Forever* sont des marques de Blizzard Entertainment. NextStep est un projet de fans, sans lien avec Blizzard.

## Feedback / Retours

Found a bug or a wrong guide step, or have an idea? Leave a comment here or open an issue on GitHub. / Un bug, une étape incorrecte, une idée ? Laisse un commentaire ici ou ouvre un ticket sur GitHub.

Source code, full credits and licence (GPL-3.0) / Code source, crédits complets et licence : [github.com/fccarlier-be/nextstep](https://github.com/fccarlier-be/nextstep)

<!-- Fin de la description -->
