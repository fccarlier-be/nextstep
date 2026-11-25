# NextStep - Nav

Ce dossier est produit par `Tools/import/nav.py` à partir de Polestar_Nav_EK de
[Polestar](https://github.com/fitzforge/polestar) 0.4.2.2 (commit `bf2acf45dc639adc4437405ce440b06437cc5342`),
GPL-3.0-or-later. Ne pas le modifier à la main : relancer l'import.

Le calculateur de chemins à pied est celui de Polestar, parti de
[Shortest Path Forever](https://github.com/cjber/shortest-path-forever) de
Cillian Berragan (GPL-3.0-or-later) ; les cartes de marche viennent des cartes de
navigation de Leffe. Voir `CREDITS.md` et `LICENSE` (repris sans modification).

Seul changement : les noms globaux et les noms d'addon (`PolestarPathData` devient
`NextStepPathData`, `Polestar_NavEngine` devient `NextStep_NavEngine`, etc.), pour
que NextStep et Polestar installés ensemble ne se gênent pas.
