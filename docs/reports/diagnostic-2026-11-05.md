# Rapport de diagnostic

Généré par `Tools/diagnostic/report.ps1` à partir de l'addon NextStep - Diagnostic.

## Vérifications hors combat

Client 1.60.1, build 70790 (Nov  3 2026), interface 16001, langue frFR, relevé le 2026-11-05 03:35.

### Client

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ✅ | Interface | 16001 | attendu : 16001 |
| ℹ️ | WOW_PROJECT_ID | 18 |  |
| ℹ️ | WOW_PROJECT_CAMELOT | 18 |  |
| ℹ️ | Langue | frFR |  |
| ℹ️ | UnitRace (raceFile) | NightElf | Elfe de la nuit |
| ℹ️ | UnitClass (classFile) | HUNTER |  |
| ✅ | UnitFactionGroup | Alliance \| Alliance |  |
| ℹ️ | Faction au chargement | Alliance | UnitFactionGroup lu à ADDON_LOADED |
| ℹ️ | raceFile au chargement | NightElf |  |

### API : Quêtes

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ✅ | C_QuestLog.GetNumQuestLogEntries | function |  |
| ✅ | C_QuestLog.GetInfo | function |  |
| ✅ | C_QuestLog.GetLogIndexForQuestID | function |  |
| ✅ | C_QuestLog.IsOnQuest | function |  |
| ✅ | C_QuestLog.IsComplete | function |  |
| ✅ | C_QuestLog.IsQuestFlaggedCompleted | function |  |
| ✅ | C_QuestLog.GetQuestObjectives | function |  |
| ✅ | C_QuestLog.GetTitleForQuestID | function |  |
| ✅ | C_QuestLog.GetAllCompletedQuestIDs | function |  |
| ❌ | GetQuestsCompleted |  |  |
| ❌ | GetQuestLogTitle |  |  |

### API : Cartes et position

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ✅ | C_Map.GetBestMapForUnit | function |  |
| ✅ | C_Map.GetPlayerMapPosition | function |  |
| ✅ | C_Map.GetMapInfo | function |  |
| ✅ | C_Map.GetAreaInfo | function |  |
| ✅ | C_Map.GetWorldPosFromMapPos | function |  |
| ✅ | C_Map.GetMapPosFromWorldPos | function |  |
| ✅ | C_Map.SetUserWaypoint | function |  |
| ✅ | C_Map.CanSetUserWaypointOnMap | function |  |
| ✅ | C_SuperTrack | table |  |
| ✅ | GetPlayerFacing | function |  |
| ✅ | CreateVector2D | function |  |
| ✅ | UiMapPoint.CreateFromCoordinates | function |  |
| ✅ | C_MapExplorationInfo.GetExploredAreaIDsAtPosition | function |  |
| ✅ | GetZoneText | function |  |
| ✅ | GetSubZoneText | function |  |
| ✅ | GetRealZoneText | function |  |
| ✅ | GetMinimapZoneText | function |  |
| ✅ | IsIndoors | function |  |

### API : Objets et sacs

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ✅ | C_Item.GetItemNameByID | function |  |
| ✅ | C_Item.GetItemCount | function |  |
| ✅ | C_Item.GetItemInfo | function |  |
| ✅ | C_Item.EquipItemByName | function |  |
| ❌ | EquipItemByName |  |  |
| ✅ | C_Container.GetContainerNumSlots | function |  |
| ✅ | C_Container.GetContainerItemInfo | function |  |
| ✅ | C_Container.SortBags | function |  |
| ✅ | C_Container.UseContainerItem | function |  |
| ❌ | GetItemStats |  |  |
| ✅ | C_TooltipInfo.GetBagItem | function |  |

### API : Sorts, métiers, réputation

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ✅ | C_Spell.GetSpellName | function |  |
| ✅ | C_Spell.GetSpellInfo | function |  |
| ✅ | IsPlayerSpell | function |  |
| ✅ | IsSpellKnown | function |  |
| ✅ | C_SpellBook | table |  |
| ❌ | GetNumSkillLines |  |  |
| ❌ | GetSkillLineInfo |  |  |
| ✅ | C_TradeSkillUI | table |  |
| ✅ | C_Reputation.GetFactionDataByID | function |  |
| ❌ | GetFactionInfoByID |  |  |
| ✅ | GetBindLocation | function |  |
| ✅ | GetMoney | function |  |
| ✅ | UnitXP | function |  |
| ✅ | UnitXPMax | function |  |
| ✅ | C_TaxiMap.GetAllTaxiNodes | function |  |
| ✅ | TaxiNodeName | function |  |
| ✅ | NumTaxiNodes | function |  |

### API : Unités et combat

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ✅ | UnitHealth | function |  |
| ✅ | UnitHealthMax | function |  |
| ✅ | UnitPower | function |  |
| ✅ | UnitPowerMax | function |  |
| ✅ | UnitHealthPercent | function |  |
| ✅ | UnitPowerPercent | function |  |
| ✅ | AbbreviateNumbers | function |  |
| ✅ | AbbreviateLargeNumbers | function |  |
| ✅ | BreakUpLargeNumbers | function |  |
| ✅ | issecretvalue | function |  |
| ✅ | canaccessvalue | function |  |
| ✅ | UnitGUID | function |  |
| ✅ | UnitName | function |  |
| ✅ | UnitRace | function |  |
| ✅ | UnitClass | function |  |
| ✅ | InCombatLockdown | function |  |
| ✅ | C_NamePlate.GetNamePlateForUnit | function |  |
| ✅ | C_NamePlate.GetNamePlates | function |  |
| ✅ | C_TooltipInfo.GetHyperlink | function |  |
| ✅ | C_TooltipInfo.GetUnit | function |  |
| ❌ | CombatLogGetCurrentEventInfo |  |  |

### API : Interface et addons

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ✅ | Settings.RegisterCanvasLayoutCategory | function |  |
| ✅ | Settings.RegisterAddOnCategory | function |  |
| ✅ | Settings.OpenToCategory | function |  |
| ✅ | C_AddOns.LoadAddOn | function |  |
| ✅ | C_AddOns.IsAddOnLoaded | function |  |
| ✅ | C_AddOns.GetAddOnMetadata | function |  |
| ❌ | C_AddOns.GetAddOnMemoryUsage |  |  |
| ✅ | UpdateAddOnMemoryUsage | function |  |
| ✅ | GetAddOnMemoryUsage | function |  |
| ✅ | C_Timer.After | function |  |
| ✅ | C_CVar.GetCVar | function |  |
| ❌ | GetMinimapShape |  |  |
| ✅ | HandleModifiedItemClick | function |  |
| ✅ | C_AddOns.EnableAddOn | function |  |
| ✅ | C_AddOns.GetNumAddOns | function |  |
| ✅ | C_AddOns.GetAddOnInfo | function |  |
| ✅ | SettingsPanel | table |  |
| ✅ | Settings.GetCategory | function |  |
| ✅ | MenuUtil.CreateContextMenu | function |  |
| ✅ | AddonCompartmentFrame | table |  |
| ✅ | MinimapCluster | table |  |
| ❌ | LibStub |  |  |

### API : Maîtres et butin

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ✅ | GetNumTrainerServices | function |  |
| ✅ | GetTrainerServiceInfo | function |  |
| ✅ | GetTrainerServiceCost | function |  |
| ✅ | GetTrainerServiceLevelReq | function |  |
| ✅ | GetTrainerServiceSkillReq | function |  |
| ✅ | GetTrainerServiceTypeFilter | function |  |
| ✅ | SetTrainerServiceTypeFilter | function |  |
| ✅ | C_TooltipInfo.GetTrainerService | function |  |
| ✅ | GetNumLootItems | function |  |
| ✅ | GetLootSlotInfo | function |  |
| ✅ | GetLootSlotLink | function |  |
| ✅ | GetLootSlotType | function |  |
| ✅ | GetLootSourceInfo | function |  |
| ✅ | C_Loot | table |  |

### API : Donjons, carte, fenêtres, sons

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ✅ | EJ_GetNumTiers | function |  |
| ✅ | EJ_SelectTier | function |  |
| ✅ | EJ_GetInstanceByIndex | function |  |
| ✅ | EJ_SelectInstance | function |  |
| ✅ | EJ_GetEncounterInfoByIndex | function |  |
| ❌ | EJ_GetLootInfoByIndex |  |  |
| ✅ | C_EncounterJournal | table |  |
| ❌ | EncounterJournal_LoadUI |  |  |
| ✅ | C_MapExplorationInfo.GetExploredMapTextures | function |  |
| ✅ | C_Map.GetMapArtID | function |  |
| ✅ | C_Map.GetMapArtLayers | function |  |
| ✅ | C_Map.GetMapArtLayerTextures | function |  |
| ✅ | MapExplorationDataProviderMixin | table |  |
| ✅ | UIPanelWindows | table |  |
| ✅ | UpdateUIPanelPositions | function |  |
| ✅ | ShowUIPanel | function |  |
| ✅ | HideUIPanel | function |  |
| ✅ | GetUIPanel | function |  |
| ✅ | UISpecialFrames | table |  |
| ✅ | CloseSpecialWindows | function |  |
| ✅ | CloseAllWindows | function |  |
| ✅ | PlaySound | function |  |
| ✅ | PlaySoundFile | function |  |
| ✅ | SOUNDKIT | table |  |
| ❌ | LevelUpDisplay |  |  |

### Valeurs lues hors combat

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ✅ | Niveau et expérience | 8 \| 1495/5400 |  |
| ✅ | Argent | 1177 |  |
| ✅ | Quêtes dans le journal | 9 \| 7 |  |
| ℹ️ | Première quête du journal | 91777 |  |
| ✅ | Titre de cette quête | Des livres rares |  |
| ✅ | Objectifs de cette quête | 2 \| La Géomancie pour les jeunes sorciers curieux : 0/1 / fini=false |  |
| ✅ | Quête 783 rendue ? (IsQuestFlaggedCompleted) | true |  |
| ✅ | Quêtes rendues (GetAllCompletedQuestIDs) | 45 |  |
| ✅ | Région 12 (C_Map.GetAreaInfo) | Forêt d'Elwynn | Forêt d'Elwynn attendue |
| ✅ | Carte 1429 (C_Map.GetMapInfo) | Forêt d'Elwynn | Forêt d'Elwynn attendue |
| ✅ | Sort 6603 (C_Spell.GetSpellName) | Attaque | Attaque attendue |
| ✅ | Objet 6948 (C_Item.GetItemNameByID) | Pierre de foyer | Pierre de foyer attendue (peut être nil au premier appel) |
| ✅ | Pierre de foyer dans les sacs (C_Item.GetItemCount) | 1 |  |
| ✅ | Foyer (GetBindLocation) | Hurlevent |  |
| ✅ | Zone / sous-zone | Auberge de la Fierté du lion \|  |  |
| ⚠️ | Compétences (GetNumSkillLines) |  | erreur : attempt to call a nil value |
| ✅ | Points de vol connus (C_TaxiMap.GetAllTaxiNodes) | 0 | souvent vide hors de la carte des vols |
| ✅ | Orientation (GetPlayerFacing) | 5.9341640472412 |  |
| ✅ | PNJ 197 par infobulle (C_TooltipInfo.GetHyperlink) | Maréchal McBride | Maréchal McBride attendu (si le client le connaît) |
| ✅ | PNJ 6 par infobulle | Vermine kobold | Vermine kobold attendue |
| ⚠️ | Cible : GUID |  | cibler un PNJ avant /nsdiag |
| ⚠️ | Cible : nom |  | cibler un PNJ avant /nsdiag |
| ✅ | Santé du joueur hors combat secrète ? | true | false attendu |

### Interface native

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ✅ | CVar statusText | 0 | texte de statut des cadres d'unité |
| ✅ | CVar statusTextDisplay | NONE | NUMERIC, PERCENT, BOTH |
| ✅ | CVar combinedBags | 1 | sacs combinés |
| ✅ | CVar nameplateShowEnemies | 1 |  |
| ✅ | Horloge Blizzard (Blizzard_TimeManager) | true \| true | chargée \| cadre présent |
| ✅ | Zoom de la carte du monde | true | ScrollContainer et fonctions de zoom |
| ✅ | Niveaux de zoom de la minimap | 6 \| 0 |  |
| ✅ | Molette sur la minimap | true | false : à activer nous-mêmes |
| ✅ | Modèle UICheckButtonTemplate |  |  |
| ✅ | Modèle UIPanelButtonTemplate |  |  |
| ✅ | Modèle BackdropTemplate |  |  |
| ✅ | Modèle UIPanelScrollFrameTemplate |  |  |
| ✅ | Modèle ContainerFrameItemButtonTemplate |  |  |
| ✅ | Sacs combinés : cadre | true |  |
| ✅ | Suivi d'objectifs Blizzard | true \| ObjectiveTrackerFrame |  |

### NextStep

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ✅ | NextStep chargé | dev |  |
| ✅ | Mémoire NextStep (Ko) | 11313 | nil : non chargé |
| ✅ | Mémoire NextStep_Alliance (Ko) | 9907 | nil : non chargé |
| ⚠️ | Mémoire NextStep_Horde (Ko) |  | nil : non chargé |
| ✅ | Faction chargée | Alliance |  |
| ✅ | Guides disponibles | 179 |  |
| ✅ | Rendu d'un texte de guide | Maréchal McBride Forêt d'Elwynn Forêt d'Elwynn Attaque Pierre de foyer | noms dans la langue du client |
| ✅ | Noms appris | 31 \| true | nombre \| module actif |
| ✅ | Panneau d'options | enregistré |  |

### Coordonnées

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ℹ️ | Carte du joueur (uiMapID) | 1429 |  |
| ✅ | Position du joueur | 43.48, 66.06 |  |
| ✅ | Position monde | continent 0 : -9468.5, 26.4 |  |
| ✅ | Écart repère era / client (yards) | 0.0 | carte identique au Classic |

### Carte : exploration

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ℹ️ | Carte du joueur (uiMapID) | 1429 |  |
| ✅ | MapArtID (C_Map.GetMapArtID) | 2153 | clé des tables WorldMapOverlay |
| ✅ | Couches (C_Map.GetMapArtLayers) | 1002x668, tuiles 256x256 | taille de la carte \| taille des tuiles |
| ✅ | Textures explorées (nombre) | 5 |  |
| ✅ | Première texture explorée | 256x256 en 422,332, 1 fichier(s), premier 8061956 | taille, décalage, fichiers : champs que la table devra fournir |

### Fenêtres Blizzard

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ✅ | CharacterFrame | protégée=false, déplaçable=true, UIPanelWindows=left, Échap=non, strate=MEDIUM, premier plan=true |  |
| ℹ️ | SpellBookFrame |  | absente (chargée à la demande ?) |
| ℹ️ | PlayerSpellsFrame |  | absente (chargée à la demande ?) |
| ℹ️ | PlayerTalentFrame |  | absente (chargée à la demande ?) |
| ℹ️ | TalentFrame |  | absente (chargée à la demande ?) |
| ℹ️ | QuestLogFrame |  | absente (chargée à la demande ?) |
| ✅ | FriendsFrame | protégée=false, déplaçable=true, UIPanelWindows=left, Échap=non, strate=MEDIUM, premier plan=true |  |
| ✅ | GossipFrame | protégée=false, déplaçable=true, UIPanelWindows=left, Échap=non, strate=MEDIUM, premier plan=true |  |
| ✅ | QuestFrame | protégée=false, déplaçable=true, UIPanelWindows=left, Échap=non, strate=MEDIUM, premier plan=true |  |
| ✅ | MerchantFrame | protégée=false, déplaçable=true, UIPanelWindows=left, Échap=non, strate=MEDIUM, premier plan=true |  |
| ℹ️ | ClassTrainerFrame |  | absente (chargée à la demande ?) |
| ℹ️ | TradeSkillFrame |  | absente (chargée à la demande ?) |
| ℹ️ | ProfessionsFrame |  | absente (chargée à la demande ?) |
| ✅ | MailFrame | protégée=false, déplaçable=false, UIPanelWindows=left, Échap=non, strate=MEDIUM, premier plan=true |  |
| ✅ | BankFrame | protégée=false, déplaçable=true, UIPanelWindows=left, Échap=non, strate=MEDIUM, premier plan=true |  |
| ℹ️ | AuctionHouseFrame |  | absente (chargée à la demande ?) |
| ℹ️ | AuctionFrame |  | absente (chargée à la demande ?) |
| ✅ | WorldMapFrame | protégée=false, déplaçable=false, UIPanelWindows=left, Échap=non, strate=MEDIUM, premier plan=true |  |
| ℹ️ | EncounterJournal |  | absente (chargée à la demande ?) |
| ✅ | DressUpFrame | protégée=false, déplaçable=false, UIPanelWindows=left, Échap=non, strate=MEDIUM, premier plan=true |  |
| ✅ | TaxiFrame | protégée=false, déplaçable=true, UIPanelWindows=left, Échap=non, strate=MEDIUM, premier plan=true |  |
| ✅ | LootFrame | protégée=false, déplaçable=false, UIPanelWindows=left, Échap=non, strate=HIGH, premier plan=true |  |

### Journal des donjons

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ✅ | Blizzard_EncounterJournal | présent, chargeable=true  | nil : absent du client |
| ✅ | Cadre EncounterJournal | false | false : pas encore chargé |
| ✅ | Tiers (EJ_GetNumTiers) | 0 |  |
| ⚠️ | Premier donjon du dernier tier |  | erreur : Interface/AddOns/NextStep_Diagnostic/Diagnostic.lua:518: Usage: EJ_SelectTier(index) Invalid index 0 |

### Minimap et options des addons

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ✅ | Addons installés (C_AddOns.GetNumAddOns) | 4 |  |
| ✅ | Compartiment d'addons (AddonCompartmentFrame) | présent, 0 addon(s) inscrit(s), affiché=false | nil : absent de Forever |
| ✅ | Catégories d'options (SettingsPanel) | 23 \| Commandes, Interface, Barres d’actions, Combat, Social, Manette (bêta), Système des pings, Raccourcis clavier, Avancées, Barres d’info, NoDisplayKB, NoDisplayKB | nombre \| premiers noms |
| ✅ | Enfants de Minimap | 4 \| <sans nom>, <sans nom>, <sans nom>, MinimapBackdrop | nombre \| noms : Blizzard et boutons d'addons |
| ✅ | Enfants de MinimapCluster | 10 \| <sans nom>, <sans nom>, <sans nom>, <sans nom>, <sans nom>, <sans nom>, <sans nom>, AddonCompartmentFrame, GameTimeFrame, TimeManagerClockButton |  |
| ⚠️ | Boutons LibDBIcon |  | erreur : Interface/AddOns/NextStep_Diagnostic/Diagnostic.lua:559: attempt to call a nil value |
| ⚠️ | Lanceurs LibDataBroker |  | erreur : Interface/AddOns/NextStep_Diagnostic/Diagnostic.lua:563: attempt to call a nil value |

Total : 195 OK, 7 à revoir, 14 absents, 21 informations.

## Maître de classe (à l'ouverture)

Client 1.60.1, build 70790 (Nov  3 2026), interface 16001, langue frFR, relevé le 2026-11-05 02:29.

### Maître : Michelle Belle

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ℹ️ | GUID du maître | Creature-0-7085-0-5-2329-E851CB5C86 |  |
| ✅ | Filtre available | true |  |
| ✅ | Filtre unavailable | true |  |
| ✅ | Filtre used | false |  |
| ✅ | Services listés | 0 |  |
| ⚠️ | Identifiant du sort (C_TooltipInfo.GetTrainerService) |  | id \| type de données |

Total : 4 OK, 1 à revoir, 0 absents, 1 informations.

## Derniers butins et récoltes

Client 1.60.1, build 70790 (Nov  3 2026), interface 16001, langue frFR, relevé le 2026-11-05 00:20.

### Butin du 03:26:53 : 1 objet(s)

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ℹ️ | Carte et position | 1429 38.23, 75.28 |  |
| ℹ️ | En instance | false |  |
| ℹ️ | Dernier sort du joueur | 8613 | Dépeçage |
| ✅ | Emplacement 1 | \|cnIQ1:\|Hitem:2934::::::::8:1485:::::::::\|h[Lanières de cuir déchirées]\|h\|r (type 1), source Creature-0-7085-0-5-113-D1E84FA33B | objet (type), GUID de la source : Creature-… ou GameObject-… |

### Butin du 03:27:05 : 1 objet(s)

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ℹ️ | Carte et position | 1429 39.11, 77.06 |  |
| ℹ️ | En instance | false |  |
| ℹ️ | Dernier sort du joueur | 75 | Tir automatique |
| ✅ | Emplacement 1 | \|cnIQ1:\|Hitem:286215::::::::8:1485:::::::::\|h[Fiole de sang d’animal]\|h\|r (type 1), source Creature-0-7085-0-5-113-868C6EABD1 | objet (type), GUID de la source : Creature-… ou GameObject-… |

### Butin du 03:27:08 : 1 objet(s)

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ℹ️ | Carte et position | 1429 39.11, 77.06 |  |
| ℹ️ | En instance | false |  |
| ℹ️ | Dernier sort du joueur | 8613 | Dépeçage |
| ✅ | Emplacement 1 | \|cnIQ1:\|Hitem:2934::::::::8:1485:::::::::\|h[Lanières de cuir déchirées]\|h\|r (type 1), source Creature-0-7085-0-5-113-868C6EABD1 | objet (type), GUID de la source : Creature-… ou GameObject-… |

### Butin du 03:27:31 : 1 objet(s)

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ℹ️ | Carte et position | 1429 38.88, 74.53 |  |
| ℹ️ | En instance | false |  |
| ℹ️ | Dernier sort du joueur | 8613 | Dépeçage |
| ✅ | Emplacement 1 | \|cnIQ1:\|Hitem:2592::::::::8:1485:::::::::\|h[Etoffe de laine]\|h\|r (type 1), source Creature-0-7085-0-5-1933-0A9CC14313 | objet (type), GUID de la source : Creature-… ou GameObject-… |

### Butin du 03:28:23 : 2 objet(s)

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ℹ️ | Carte et position | 1429 42.82, 70.27 |  |
| ℹ️ | En instance | false |  |
| ℹ️ | Dernier sort du joueur | 75 | Tir automatique |
| ✅ | Emplacement 1 | \|cnIQ0:\|Hitem:2590::::::::8:1485:::::::::\|h[Toile d'araignée des bois]\|h\|r (type 1), source Creature-0-7085-0-5-30-7845E3521B | objet (type), GUID de la source : Creature-… ou GameObject-… |
| ✅ | Emplacement 2 | \|cnIQ0:\|Hitem:1476::::::::8:1485:::::::::\|h[Patte d'araignée brisée]\|h\|r (type 1), source Creature-0-7085-0-5-30-7845E3521B | objet (type), GUID de la source : Creature-… ou GameObject-… |

### Butin du 03:28:35 : 1 objet(s)

| | Point vérifié | Valeur | Remarque |
|---|---|---|---|
| ℹ️ | Carte et position | 1429 42.81, 69.83 |  |
| ℹ️ | En instance | false |  |
| ℹ️ | Dernier sort du joueur | 8613 | Dépeçage |
| ✅ | Emplacement 1 | \|cnIQ1:\|Hitem:2934::::::::8:1485:::::::::\|h[Lanières de cuir déchirées]\|h\|r (type 1), source Creature-0-7085-0-5-883-9C62FDBED1 | objet (type), GUID de la source : Creature-… ou GameObject-… |

Total : 7 OK, 0 à revoir, 0 absents, 18 informations.
