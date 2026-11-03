# Dernière extraction de la carte

Généré par `Tools/worldmap/generate.lua`. Ne pas modifier à la main.

- Client : WoW Forever 1.60.1.70707 (produit `wowf`)
- Outils : TACTSharp `79f58445bc81d0d13f84540f1d1d52e94188cc08`, WoWDBDefs `92bb4dc62114a0afdc2beda7e414383b47e34c85`, DBCD (NuGet, voir `Export/Export.csproj`)
- Cartes (UiMapArtID) : 84
- Superpositions : 1081 lues, 1073 gardées, 8 sans tuiles
- Tuiles : 1739 lues sur la couche 0, 1739 gardées ; autres couches : 0
- Vérifications : grille complète pour chaque superposition, nombre de tuiles attendu d'après la taille (256 pixels), relecture exacte du fichier produit.

## Superpositions sans tuiles (8)

Absentes des données : rien à afficher.

| ID | UiMapArtID | Taille | AreaID |
|---|---|---|---|
| 5252 | 2160 | 256x256 | 19,0,0,0 |
| 5545 | 2031 | 0x0 | 16635,0,0,0 |
| 5546 | 2031 | 0x0 | 17678,16635,0,0 |
| 5547 | 2031 | 0x0 | 16623,0,0,0 |
| 5548 | 2031 | 0x0 | 16623,0,0,0 |
| 5549 | 2031 | 0x0 | 16626,0,0,0 |
| 5550 | 2054 | 0x0 | 16734,0,0,0 |
| 5551 | 1200 | 0x0 | 358,0,0,0 |

## Superpositions conditionnelles (555)

Gardées dans les données ; `PlayerConditionID` ou `Flags` non nuls, à examiner pour le module.

| PlayerConditionID | Flags | Superpositions | Cartes (UiMapArtID) |
|---|---|---|---|
| 0 | 4 | 555 | 1200, 1997, 2031, 2054, 2121, 2126, 2130, 2133, 2134, 2147, 2148, 2149, 2150, 2151, 2152, 2153, 2154, 2156, 2157, 2158, 2159, 2160, 2161, 2162, 2164, 2165, 2166, 2167, 2168, 2169, 2170, 2171, 2173, 2174, 2177, 2178, 2179, 2180, 2181, 2182, 2184, 2185, 2186 |

## Avertissements (0)

