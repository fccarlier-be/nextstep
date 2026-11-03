# Page CurseForge

Ce document contient la description de NextStep pour [CurseForge](https://www.curseforge.com/), en français et en anglais. Copier chaque version dans l'éditeur de CurseForge (format Markdown).

Les fonctionnalités sont marquées **disponible** ou **à venir** : mettre ces marques à jour à chaque version, selon la [feuille de route](ROADMAP.md).

**Résumé court** (champ « Summary », 1 phrase) :

- FR : L'addon tout-en-un pour monter ses personnages sur WoW Forever : guide de leveling, métiers, équipement et interface.
- EN : The all-in-one addon to level your characters on WoW Forever: leveling guide, professions, gear and UI.

---

## Version française

<!-- Début de la description FR -->

# NextStep

**L'addon tout-en-un pour monter ses personnages sur WoW Forever.**

Pour bien monter un personnage, on finit souvent par installer une quinzaine d'addons : un guide, un suivi de quêtes, une flèche, un comparateur d'équipement, des sacs unifiés, une minimap améliorée… NextStep les regroupe en **un seul addon cohérent**, avec **une seule fenêtre d'options**.

## Guide de leveling

- **256 guides** : leveling des deux factions et de chaque race, classes, métiers, réputations et collection.
- Une route **étape par étape**, adaptée à **ta race, ta classe et ton niveau**. Le guide de départ est suggéré automatiquement.
- **Les détours sont acceptés** : prends une suite de quêtes hors route, le guide se recale tout seul à ton retour.
- Une quête abandonnée est **signalée**, sans faire reculer le guide.
- Des **conseils** quand tu es en avance de niveau ou que les quêtes deviennent grises, et le **guide suivant** proposé à la fin.
- Une **flèche** de navigation et des points sur la **carte** et la **minimap**.
- **Mode strict** (une étape à la fois) et **mode libre** *(à venir)* : tu choisis l'ordre des objectifs d'un même lieu.
- Progression enregistrée **par personnage**.

## En français dans le texte

- Les guides sont **traduits en français**.
- Là où la traduction manque, NextStep **apprend le nom des PNJ** que tu croises, dans la langue de ton client (cible, survol, barres de nom, dialogue). Rien n'est envoyé, rien ne se passe en combat, et le module se désactive dans les options.

## À venir

**Métiers**
- Un conseiller qui suggère des métiers selon ta race, ta classe et ton objectif (leveling, or, end game).
- Des routes de métier (où farmer, quoi fabriquer, quand voir le maître), intégrées au guide de leveling.

**Équipement**
- Les récompenses de quête conseillées, mises en évidence (jamais choisies à ta place).
- Le gain ou la perte affiché dans les infobulles, et une alerte quand tu ramasses une amélioration.
- Les items à ne pas rater à chaque tranche de niveaux, et les jalons importants (sacs, monture, quêtes de classe).

**Interface**
- Valeurs de vie et de ressources sur les cadres d'unité et les barres de nom.
- Sacs et banque unifiés, banque consultable à distance, vente automatique de la camelote.
- Minimap carrée, zoom à la molette, coordonnées, boutons d'addons rangés, horloge avec alarmes et minuteurs.

## Principes

- **Un seul addon** à installer. Chaque module s'active ou se désactive d'une case à cocher.
- **Aucune donnée envoyée** : NextStep ne communique avec aucun serveur. Tout reste sur ton PC.
- **Améliorer l'interface Blizzard plutôt que la remplacer**, pour limiter les erreurs et les conflits avec d'autres addons.
- **Léger** : les données de la faction adverse ne sont jamais chargées.
- **Libre et open source**, sous licence GPL-3.0.

## Utilisation

- `/ns` ou `/nextstep` : ouvre NextStep.
- Les options sont aussi dans *Options → AddOns → NextStep*.

## Compatibilité

- **Jeu** : WoW Forever.
- **Langues** : français et anglais.

## Crédits

NextStep s'appuie sur le travail de projets libres. Merci à leurs auteurs :

- **[Polestar](https://github.com/fitzforge/polestar)** : guides de leveling, de classe et de métiers, noms et textes traduits (GPL-3.0).
- **[HereBeDragons](https://github.com/Nevcairiel/HereBeDragons)**, par Nevcairiel : carte, minimap et coordonnées (BSD).
- **ForeverLevelingBiS**, par Thunder, et **[wowsims](https://github.com/wowsims)** : statistiques des items et poids de stats (MIT).

Liste complète : [CREDITS.md](https://github.com/fccarlier-be/nextstep/blob/main/CREDITS.md).

## Signaler un problème

Un bug, une étape de guide incorrecte, une idée ? Ouvre un ticket sur [GitHub](https://github.com/fccarlier-be/nextstep/issues).

*World of Warcraft* et *WoW Forever* sont des marques de Blizzard Entertainment. NextStep est un projet de fans, sans lien avec Blizzard.

<!-- Fin de la description FR -->

---

## English version

<!-- Start of the EN description -->

# NextStep

**The all-in-one addon to level your characters on WoW Forever.**

Leveling a character well usually means installing a dozen or more addons: a guide, a quest tracker, an arrow, a gear comparer, unified bags, a better minimap… NextStep brings them together in **one consistent addon**, with **one options window**.

## Leveling guide

- **256 guides**: leveling for both factions and every race, classes, professions, reputations and collections.
- A **step-by-step** route tailored to **your race, class and level**. The starting guide is suggested automatically.
- **Detours are welcome**: follow an off-route quest chain, and the guide catches up on its own when you come back.
- An abandoned quest is **flagged**, without sending the guide backwards.
- **Tips** when you are ahead of the curve or quests turn grey, and the **next guide** offered when you finish one.
- A navigation **arrow** and pins on the **world map** and **minimap**.
- **Strict mode** (one step at a time) and **free mode** *(coming soon)*: pick the order of objectives in the same area.
- Progress saved **per character**.

## Speaks your language

- Guides are available in **English and French**.
- Where a translation is missing, NextStep **learns the names of the NPCs** you meet, in your client's language (target, mouseover, nameplates, dialogue). Nothing is sent anywhere, nothing runs in combat, and the module can be turned off in the options. It is on by default on non-English clients only.

## Coming soon

**Professions**
- An advisor that suggests professions for your race, class and goal (leveling, gold, end game).
- Profession routes (where to farm, what to craft, when to visit the trainer), woven into the leveling guide.

**Gear**
- Recommended quest rewards, highlighted (never picked for you).
- Upgrade or downgrade shown in tooltips, and an alert when you loot an upgrade.
- Must-have items for each level bracket, and key milestones (bags, mount, class quests).

**Interface**
- Health and resource values on unit frames and nameplates.
- Unified bags and bank, bank viewable from anywhere, automatic junk selling.
- Square minimap, mouse-wheel zoom, coordinates, tidy addon buttons, clock with alarms and timers.

## Principles

- **One addon** to install. Each module is turned on or off with a single checkbox.
- **No data sent**: NextStep talks to no server. Everything stays on your PC.
- **Enhance the Blizzard UI rather than replace it**, to keep errors and conflicts with other addons to a minimum.
- **Lightweight**: the other faction's data is never loaded.
- **Free and open source**, under the GPL-3.0 licence.

## Usage

- `/ns` or `/nextstep`: opens NextStep.
- Options are also under *Options → AddOns → NextStep*.

## Compatibility

- **Game**: WoW Forever.
- **Languages**: English and French.

## Credits

NextStep builds on the work of open-source projects. Thanks to their authors:

- **[Polestar](https://github.com/fitzforge/polestar)**: leveling, class and profession guides, translated names and texts (GPL-3.0).
- **[HereBeDragons](https://github.com/Nevcairiel/HereBeDragons)**, by Nevcairiel: map, minimap and coordinates (BSD).
- **ForeverLevelingBiS**, by Thunder, and **[wowsims](https://github.com/wowsims)**: item stats and stat weights (MIT).

Full list: [CREDITS.md](https://github.com/fccarlier-be/nextstep/blob/main/CREDITS.md).

## Report a problem

A bug, a wrong guide step, an idea? Open an issue on [GitHub](https://github.com/fccarlier-be/nextstep/issues).

*World of Warcraft* and *WoW Forever* are trademarks of Blizzard Entertainment. NextStep is a fan project, not affiliated with Blizzard.

<!-- End of the EN description -->
