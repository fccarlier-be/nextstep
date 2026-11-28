# NextStep - Nav

Ce dossier est produit par `Tools/import/nav.py` à partir de Polestar_Nav_EK de
[Polestar](https://github.com/fitzforge/polestar) 0.4.3.1 (commit `efccd3c027327537746819a6e60ec689ca2e6a71`),
GPL-3.0-or-later. Ne pas le modifier à la main : relancer l'import.

Le calculateur de chemins à pied est celui de Polestar, parti de
[Shortest Path Forever](https://github.com/cjber/shortest-path-forever) de
Cillian Berragan (GPL-3.0-or-later) ; les cartes de marche viennent des cartes de
navigation de Leffe. Voir `CREDITS.md` et `LICENSE` (repris sans modification).

Dans `NextStep_Nav`, `Travel.lua` et `FlightTracks.lua` sont les tables de voyage de Polestar
(`Polestar/Nav/TravelData.lua`, `Polestar/Maps/FlightPaths.lua`), même licence,
exposées en `NextStepTravelData` et `NextStepFlightTracks` : points de vol, vols,
bateaux, zeppelins et portails, pour les voyages de NextStep.

Seul changement : les noms globaux et les noms d'addon (`PolestarPathData` devient
`NextStepPathData`, `Polestar_NavEngine` devient `NextStep_NavEngine`, etc.), pour
que NextStep et Polestar installés ensemble ne se gênent pas.
