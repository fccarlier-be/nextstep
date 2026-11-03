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
| Contenu réutilisé : sous licence ou avec permission (la permission est recommandée même sous licence), et crédité | Polestar (GPL-3.0-only), pfQuest (MIT), Ding/DingDB (GPL-3.0) et les autres sources sont crédités et liés ; leurs notices sont livrées dans les `LICENSE-DATA.txt` de l'addon. **Contacter l'auteur de Polestar avant la publication** (prévu en phase 11 de la [feuille de route](ROADMAP.md)). |
| Logiciel libre accepté si sa licence est respectée | NextStep est sous GPL-3.0-only, comme Polestar ; texte de la licence inclus dans le paquet (`NextStep/LICENSE.txt`), avec les notices des données (`LICENSE-DATA.txt`). |
| Respect du jeu, de son éditeur et de ses conditions d'utilisation | Aucune automatisation interdite ; mention des marques de Blizzard. |
| Proposer un canal de retour (bugs, idées) | Tickets GitHub et commentaires CurseForge, cités en bas de page. |
| Un changelog pour chaque fichier envoyé | Coller la section de la version tirée de [CHANGELOG.md](../CHANGELOG.md) à chaque envoi. |
| Pas de mises à jour vides ni de renvois pour gagner en visibilité | Ne publier que des versions qui changent quelque chose. |

**À chaque version** : relire la description et retirer de « Planned » ce qui est devenu disponible (et l'inverse), pour que la page décrive toujours le fichier publié. La section du guide décrit le contenu de la v0.1 (phase 4 de la feuille de route), dont les sorts à apprendre et la célébration de niveau.

## Résumé (champ « Summary »)

> Leveling guide with detour support, map arrow, trainer reminders and French translations, plus planned gear, profession and UI helpers, all in one addon.

## Description (champ « Description », Markdown)

Copier tout ce qui se trouve entre les deux marques. Mise en page en Markdown pur (pas de HTML) : logo, emoji, citations, tableaux. Le logo est chargé depuis la branche `main` du dépôt. Après le collage, vérifier le rendu dans l'aperçu de CurseForge, et ajouter de vraies captures d'écran en jeu dans la galerie dès la v0.1.

<!-- Début de la description -->

![NextStep](https://raw.githubusercontent.com/fccarlier-be/nextstep/main/img/logo/nextstep-curseforge-400.png)

# ✨ NextStep

> **One addon to take your characters from level 1 to the top on WoW Forever.**
>
> Follow the route, take any detour you like, and always know your next step.

🇬🇧 **English** · 🇫🇷 *Version française plus bas*

---

## 🗺️ Leveling guide

**256 guides** ready to go: leveling for both factions and every race, plus class, profession, reputation and collection guides.

- 🎯 **Made for your character**: the route adapts to your **race, class and level**, and NextStep picks the right starting guide for you.
- 🧭 **Arrow and map pins**: a navigation arrow, with pins on the world map and the minimap, and zone levels shown on the world map.
- 📜 **Spells to learn**: what your class trainer has for you at your level, with the cost, and a reminder in the route when you pass by.
- 🎉 **Level-up celebration**: a banner at each level with your new spells and the next zone to head to.
- 🔀 **Detours are fine**: follow an off-route quest chain, and the guide catches up on its own when you come back.
- 🚩 **No surprises**: an abandoned quest is flagged instead of sending the guide backwards.
- 💡 **Tips along the way**: when you are ahead of the curve, when quests turn grey, and the next guide offered when you finish one.
- 💾 **Per character**: each character keeps their own progress.

## 🌍 Speaks your language

- Guides in **English and French**.
- 🧠 **Learns as you play**: where a French NPC name is missing, NextStep picks it up from your client as you meet the NPC (target, mouseover, nameplates, dialogue).
- It never runs in combat, sends nothing anywhere, and can be turned off in one click.

## 🛡️ Built to stay out of your way

| | |
|---|---|
| 🔒 **Private** | No data leaves your PC. NextStep talks to no server. |
| 🧩 **Blizzard-friendly** | Enhances the Blizzard UI instead of replacing it, to avoid errors and conflicts with other addons. |
| 🪶 **Lightweight** | Only your faction's data is loaded. |
| ☑️ **Modular** | Every module has its own checkbox in the options. |

## ⌨️ Getting started

1. Install NextStep and log in.
2. Type **`/ns`** (or `/nextstep`) to open it.
3. Fine-tune it under *Options → AddOns → NextStep*.

## 🚧 On the road map

| Module | What's coming |
|---|---|
| ⚒️ **Professions** | Profession advisor and routes, woven into the leveling guide; gathering nodes recorded as you farm and shown on the map |
| 🗡️ **Gear** | Recommended quest rewards, upgrade hints in tooltips, loot alerts, dungeon loot with the upgrades for your spec |
| ❤️ **Unit values** | Health and resource numbers on unit frames and nameplates |
| 🎒 **Bags and bank** | Unified bags and bank, bank viewable from anywhere, junk auto-sell |
| 🧭 **Minimap and clock** | Square minimap, wheel zoom, coordinates, alarms and timers |
| 🪟 **Windows and map** | Movable Blizzard windows, whole world map revealed (no more fog) |

---
---

# ✨ NextStep (français)

> **Un seul addon pour monter tes personnages du niveau 1 jusqu'au sommet sur WoW Forever.**
>
> Suis la route, fais tous les détours que tu veux, et sache toujours quelle est ta prochaine étape.

## 🗺️ Guide de leveling

**256 guides** prêts à l'emploi : leveling des deux factions et de chaque race, et guides de classe, de métiers, de réputation et de collection.

- 🎯 **Fait pour ton personnage** : la route s'adapte à ta **race, ta classe et ton niveau**, et NextStep choisit pour toi le bon guide de départ.
- 🧭 **Flèche et points sur la carte** : une flèche de navigation, avec des points sur la carte du monde et la minimap, et le niveau des zones affiché sur la carte.
- 📜 **Sorts à apprendre** : ce que ton maître de classe a pour toi à ton niveau, avec le coût, et un rappel dans la route quand tu passes à côté.
- 🎉 **Célébration de niveau** : un bandeau à chaque niveau, avec tes nouveaux sorts et la prochaine zone où aller.
- 🔀 **Les détours ne posent pas de problème** : suis une suite de quêtes hors route, le guide se recale tout seul à ton retour.
- 🚩 **Pas de mauvaise surprise** : une quête abandonnée est signalée, sans faire reculer le guide.
- 💡 **Des conseils en chemin** : quand tu es en avance de niveau, quand les quêtes deviennent grises, et le guide suivant proposé à la fin.
- 💾 **Par personnage** : chaque personnage garde sa propre progression.

## 🌍 En français dans le texte

- Guides en **français et en anglais**.
- 🧠 **Apprend en jouant** : quand le nom français d'un PNJ manque, NextStep le récupère auprès de ton client quand tu le croises (cible, survol, barres de nom, dialogue).
- Jamais en combat, rien n'est envoyé, et ça se désactive d'un clic.

## 🛡️ Conçu pour rester discret

| | |
|---|---|
| 🔒 **Privé** | Aucune donnée ne quitte ton PC. NextStep ne communique avec aucun serveur. |
| 🧩 **Respectueux de Blizzard** | Améliore l'interface Blizzard au lieu de la remplacer, pour éviter les erreurs et les conflits avec d'autres addons. |
| 🪶 **Léger** | Seules les données de ta faction sont chargées. |
| ☑️ **Modulaire** | Chaque module a sa case à cocher dans les options. |

## ⌨️ Pour commencer

1. Installe NextStep et connecte-toi.
2. Tape **`/ns`** (ou `/nextstep`) pour l'ouvrir.
3. Règle-le dans *Options → AddOns → NextStep*.

## 🚧 Au programme

| Module | Ce qui arrive |
|---|---|
| ⚒️ **Métiers** | Conseiller et routes de métiers, intégrés au guide de leveling ; points de récolte enregistrés pendant que tu farmes et affichés sur la carte |
| 🗡️ **Équipement** | Récompenses de quête conseillées, gains dans les infobulles, alerte au butin, butin des donjons avec les améliorations pour ta spécialisation |
| ❤️ **Valeurs** | Vie et ressources en chiffres sur les cadres d'unité et les barres de nom |
| 🎒 **Sacs et banque** | Sacs et banque unifiés, banque consultable partout, vente de la camelote |
| 🧭 **Minimap et horloge** | Minimap carrée, zoom à la molette, coordonnées, alarmes et minuteurs |
| 🪟 **Fenêtres et carte** | Fenêtres Blizzard déplaçables, carte du monde entièrement dévoilée (plus de brouillard) |

---
---

## 🙏 Credits / Crédits

NextStep builds on these open-source projects. Thanks to their authors! / NextStep s'appuie sur ces projets libres. Merci à leurs auteurs !

- **[Polestar](https://github.com/fitzforge/polestar)**: leveling, class and profession guides, translated names and texts / guides, noms et textes traduits *(GPL-3.0-only)*
- **[pfQuest](https://github.com/shagu/pfQuest)** by Shagu, via Polestar: quest, NPC, object and item facts, French names / faits de quêtes, PNJ, objets et items, noms français *(MIT)*
- **[Ding!](https://github.com/moust4ki/DingGuideWoWForever)** and DingDB by Yendi, via Polestar: French names / noms français *(GPL-3.0)*
- **[CMaNGOS classic-db](https://github.com/cmangos/classic-db)**, via Polestar: NPC spawn heights and walk areas, quest objective counts / hauteurs d'apparition et zones de déplacement des PNJ, nombre d'objectifs des quêtes *(GPL-3.0)*
- **[HereBeDragons](https://github.com/Nevcairiel/HereBeDragons)** by Nevcairiel: map, minimap and coordinates / carte, minimap et coordonnées *(BSD)*
- **[What's Training](https://github.com/fusionpit/WhatsTraining)** by Fusionpit: class trainer spells / sorts des maîtres de classe *(MIT)*
- **[GatherMate2](https://github.com/Nevcairiel/GatherMate2)** by kagaro, Xinhuan and Nevcairiel: gathering detection / détection des récoltes *(GPL-2.0-or-later)*

🎨 The logo was generated with AI (FLUX.2 [klein], background removed with BiRefNet). / Le logo a été généré par IA (FLUX.2 [klein], détourage avec BiRefNet).

## 💬 Feedback / Retours

🐞 Found a bug or a wrong guide step, or have an idea? **Leave a comment here** or open an issue on GitHub.

🐞 Un bug, une étape incorrecte, une idée ? **Laisse un commentaire ici** ou ouvre un ticket sur GitHub.

📦 Source code, full credits and licence (GPL-3.0-only) / Code source, crédits complets et licence : **[github.com/fccarlier-be/nextstep](https://github.com/fccarlier-be/nextstep)**

---

*World of Warcraft* and *WoW Forever* are trademarks of Blizzard Entertainment. NextStep is a fan project, not affiliated with Blizzard. / *World of Warcraft* et *WoW Forever* sont des marques de Blizzard Entertainment. NextStep est un projet de fans, sans lien avec Blizzard.

<!-- Fin de la description -->
