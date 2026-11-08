-- Généré par Tools/import/gear.lua depuis Polestar 0.3.0 (d48e609ecdac, 2026-11-03), Gear/Weights.lua et
-- Gear/SpecData.lua. Ne pas modifier : relancer Tools\import\run.ps1.
-- Polestar : Copyright (c) 2026 The Polestar authors, GPL-3.0-only. Poids mêlés aux
-- simulations de wowsims (MIT) et traits raciaux de ForeverLevelingBiS (MIT) :
-- Gear-LICENSE-DATA.txt dans ce dossier. Format : docs/DATA_FORMAT.md.

local DB = NextStep.DB

DB.gear = {
	bands = {
		DRUID = {
			balance = {
				{
					source = "polestar",
					upTo = 39,
					weights = { armor = 0.005, heal = 0.1, health = 0.05, int = 1, mana = 0.06, mp5 = 2, sp = 0.9, spArcane = 0.7, spNature = 0.9, spellCrit = 6, spellHit = 8, spi = 0.5, sta = 0.5 },
				},
				{
					source = "wowsims",
					upTo = 49,
					weights = { armor = 0.003, heal = 0.05, health = 0.025, int = 0.577, mana = 0.03, mp5 = 1, sp = 0.9, spArcane = 0.652, spNature = 0.599, spellCrit = 5.637, spellHit = 7.708, spi = 0.25, sta = 0.25 },
				},
				{
					source = "wowsims",
					upTo = 59,
					weights = { armor = 0.003, heal = 0.05, health = 0.025, int = 0.572, mana = 0.03, mp5 = 1, sp = 0.9, spArcane = 0.629, spNature = 0.621, spellCrit = 6.375, spellHit = 9.288, spi = 0.25, sta = 0.25 },
				},
				{
					source = "wowsims",
					upTo = 60,
					weights = { armor = 0.001, heal = 0.025, health = 0.013, int = 0.358, mana = 0.015, mp5 = 0.5, sp = 0.9, spArcane = 0.593, spNature = 0.482, spellCrit = 6.563, spellHit = 9.931, spi = 0.125, sta = 0.125 },
				},
			},
			feral = {
				{
					source = "polestar",
					upTo = 24,
					weights = { agi = 1, ap = 0.5, armor = 0.04, crit = 9, defense = 0.4, dodge = 6, health = 0.07, hit = 9, hp5 = 0.5, int = 0.2, spi = 0.15, sta = 0.65, str = 1 },
				},
				{
					source = "wowsims",
					upTo = 39,
					weights = { agi = 1, ap = 0.498, armor = 0.02, crit = 6.527, defense = 0.2, dodge = 3, health = 0.035, hit = 6.532, hp5 = 0.25, int = 0.266, mana = 0.01, mp5 = 0.114, spi = 0.095, sta = 0.325, str = 1.045 },
				},
				{
					source = "wowsims",
					upTo = 49,
					weights = { agi = 1, ap = 0.498, armor = 0.02, crit = 6.527, defense = 0.2, dodge = 3, health = 0.035, hit = 6.532, hp5 = 0.25, int = 0.266, mana = 0.01, mp5 = 0.114, spi = 0.095, sta = 0.325, str = 1.045 },
				},
				{
					source = "wowsims",
					upTo = 59,
					weights = { agi = 1, ap = 0.463, armor = 0.02, crit = 8.047, defense = 0.2, dodge = 3, health = 0.035, hit = 9.704, hp5 = 0.25, int = 0.243, mana = 0.009, mp5 = 0.098, spi = 0.092, sta = 0.325, str = 1.006 },
				},
				{
					source = "wowsims",
					upTo = 60,
					weights = { agi = 1, ap = 0.434, armor = 0.01, crit = 11.102, defense = 0.1, dodge = 1.5, health = 0.018, hit = 10.457, hp5 = 0.125, int = 0.238, mana = 0.009, mp5 = 0.244, spi = 0.155, sta = 0.163, str = 0.991 },
				},
			},
			restoration = {
				{
					source = "polestar",
					upTo = 60,
					weights = { armor = 0.005, heal = 0.7, health = 0.05, int = 1, mana = 0.06, mp5 = 2.2, sp = 0.1, spellCrit = 4, spi = 0.65, sta = 0.45 },
				},
			},
		},
		HUNTER = {
			beastmastery = {
				{
					source = "polestar",
					upTo = 39,
					weights = { agi = 1, ap = 0.5, armor = 0.02, crit = 10, dps = 0.5, health = 0.05, hit = 10, int = 0.35, mana = 0.02, mp5 = 1.2, rap = 0.45, rdps = 6.5, spi = 0.2, sta = 0.55, str = 0.1 },
				},
				{
					source = "wowsims",
					upTo = 49,
					weights = { agi = 1, ap = 1.031, armor = 0.01, crit = 8.477, dps = 1.898, health = 0.025, hit = 7.57, int = 0.191, mana = 0.01, mp5 = 0.639, rap = 1.006, rdps = 8.188, sp = 0.023, spArcane = 0.008, spNature = 0.008, spi = 0.1, sta = 0.275, str = 0.284 },
				},
				{
					source = "wowsims",
					upTo = 59,
					weights = { agi = 1, ap = 1.031, armor = 0.01, crit = 8.477, dps = 1.898, health = 0.025, hit = 7.57, int = 0.191, mana = 0.01, mp5 = 0.639, rap = 1.006, rdps = 8.188, sp = 0.023, spArcane = 0.008, spNature = 0.008, spi = 0.1, sta = 0.275, str = 0.284 },
				},
				{
					source = "wowsims",
					upTo = 60,
					weights = { agi = 1, ap = 1.297, armor = 0.005, crit = 7.715, dps = 2.598, health = 0.013, hit = 6.355, int = 0.111, mana = 0.005, mp5 = 0.359, rap = 1.284, rdps = 9.031, sp = 0.035, spArcane = 0.012, spNature = 0.012, spellCrit = 0.012, spi = 0.05, sta = 0.138, str = 0.377 },
				},
			},
			marksmanship = {
				{
					source = "polestar",
					upTo = 39,
					weights = { agi = 1, ap = 0.5, armor = 0.02, crit = 11, dps = 0.5, health = 0.05, hit = 11, int = 0.4, mana = 0.02, mp5 = 1.2, rap = 0.45, rdps = 7, spi = 0.2, sta = 0.5, str = 0.1 },
				},
				{
					source = "wowsims",
					upTo = 49,
					weights = { agi = 1, ap = 1.031, armor = 0.01, crit = 8.977, dps = 1.898, health = 0.025, hit = 8.07, int = 0.216, mana = 0.01, mp5 = 0.639, rap = 1.006, rdps = 8.438, sp = 0.023, spArcane = 0.008, spNature = 0.008, spi = 0.1, sta = 0.25, str = 0.284 },
				},
				{
					source = "wowsims",
					upTo = 59,
					weights = { agi = 1, ap = 1.031, armor = 0.01, crit = 8.977, dps = 1.898, health = 0.025, hit = 8.07, int = 0.216, mana = 0.01, mp5 = 0.639, rap = 1.006, rdps = 8.438, sp = 0.023, spArcane = 0.008, spNature = 0.008, spi = 0.1, sta = 0.25, str = 0.284 },
				},
				{
					source = "wowsims",
					upTo = 60,
					weights = { agi = 1, ap = 1.297, armor = 0.005, crit = 7.965, dps = 2.598, health = 0.013, hit = 6.605, int = 0.123, mana = 0.005, mp5 = 0.359, rap = 1.284, rdps = 9.156, sp = 0.035, spArcane = 0.012, spNature = 0.012, spellCrit = 0.012, spi = 0.05, sta = 0.125, str = 0.377 },
				},
			},
			survival = {
				{
					source = "polestar",
					upTo = 39,
					weights = { agi = 1.1, ap = 0.55, armor = 0.02, crit = 11, dps = 1, health = 0.05, hit = 10, int = 0.35, mana = 0.02, mp5 = 1, rap = 0.45, rdps = 6.5, spi = 0.2, sta = 0.55, str = 0.15 },
				},
				{
					source = "wowsims",
					upTo = 49,
					weights = { agi = 1.1, ap = 1.134, armor = 0.01, crit = 9.324, dps = 2.313, health = 0.025, hit = 7.827, int = 0.192, mana = 0.01, mp5 = 0.543, rap = 1.084, rdps = 8.681, sp = 0.026, spArcane = 0.009, spNature = 0.009, spi = 0.1, sta = 0.275, str = 0.333 },
				},
				{
					source = "wowsims",
					upTo = 59,
					weights = { agi = 1.1, ap = 1.134, armor = 0.01, crit = 9.324, dps = 2.313, health = 0.025, hit = 7.827, int = 0.192, mana = 0.01, mp5 = 0.543, rap = 1.084, rdps = 8.681, sp = 0.026, spArcane = 0.009, spNature = 0.009, spi = 0.1, sta = 0.275, str = 0.333 },
				},
				{
					source = "wowsims",
					upTo = 60,
					weights = { agi = 1.1, ap = 1.427, armor = 0.005, crit = 8.486, dps = 2.97, health = 0.013, hit = 6.741, int = 0.113, mana = 0.005, mp5 = 0.314, rap = 1.402, rdps = 9.772, sp = 0.039, spArcane = 0.013, spNature = 0.013, spellCrit = 0.013, spi = 0.05, sta = 0.138, str = 0.424 },
				},
			},
		},
		MAGE = {
			arcane = {
				{
					source = "polestar",
					upTo = 39,
					weights = { armor = 0.005, health = 0.05, int = 1, mana = 0.07, mp5 = 1.8, rdps = 1.5, sp = 1.1, spArcane = 1.1, spFire = 0.4, spFrost = 0.4, spellCrit = 7, spellHit = 9, spi = 0.55, sta = 0.55 },
				},
				{
					source = "wowsims",
					upTo = 49,
					weights = { armor = 0.003, health = 0.025, int = 0.61, mana = 0.035, mp5 = 0.95, rdps = 0.75, sp = 1.1, spArcane = 1.1, spFire = 0.75, spFrost = 0.75, spellCrit = 6.894, spellHit = 7.25, spi = 0.275, sta = 0.275 },
				},
				{
					source = "wowsims",
					upTo = 59,
					weights = { armor = 0.003, health = 0.025, int = 0.61, mana = 0.035, mp5 = 0.95, rdps = 0.75, sp = 1.1, spArcane = 1.1, spFire = 0.75, spFrost = 0.75, spellCrit = 6.894, spellHit = 7.25, spi = 0.275, sta = 0.275 },
				},
				{
					source = "wowsims",
					upTo = 60,
					weights = { armor = 0.001, health = 0.013, int = 0.654, mana = 0.018, mp5 = 0.541, rdps = 0.375, sp = 1.1, spArcane = 1.1, spFire = 0.925, spFrost = 0.925, spellCrit = 13.226, spellHit = 17.587, spi = 0.138, sta = 0.138 },
				},
			},
			fire = {
				{
					source = "polestar",
					upTo = 39,
					weights = { armor = 0.005, health = 0.05, int = 0.9, mana = 0.06, mp5 = 1.6, rdps = 1.5, sp = 1.1, spArcane = 0.2, spFire = 1.1, spFrost = 0.2, spellCrit = 9, spellHit = 9, spi = 0.5, sta = 0.55 },
				},
				{
					source = "wowsims",
					upTo = 49,
					weights = { armor = 0.003, health = 0.025, int = 0.56, mana = 0.03, mp5 = 0.85, rdps = 0.75, sp = 1.1, spArcane = 0.65, spFire = 1.1, spFrost = 0.65, spellCrit = 7.894, spellHit = 7.25, spi = 0.25, sta = 0.275 },
				},
				{
					source = "wowsims",
					upTo = 59,
					weights = { armor = 0.003, health = 0.025, int = 0.56, mana = 0.03, mp5 = 0.85, rdps = 0.75, sp = 1.1, spArcane = 0.65, spFire = 1.1, spFrost = 0.65, spellCrit = 7.894, spellHit = 7.25, spi = 0.25, sta = 0.275 },
				},
				{
					source = "wowsims",
					upTo = 60,
					weights = { armor = 0.001, health = 0.013, int = 0.629, mana = 0.015, mp5 = 0.491, rdps = 0.375, sp = 1.1, spArcane = 0.875, spFire = 1.1, spFrost = 0.875, spellCrit = 13.726, spellHit = 17.587, spi = 0.125, sta = 0.138 },
				},
			},
			frost = {
				{
					source = "polestar",
					upTo = 39,
					weights = { armor = 0.005, health = 0.06, int = 0.9, mana = 0.06, mp5 = 1.8, rdps = 1.5, sp = 1.1, spArcane = 0.2, spFire = 0.2, spFrost = 1.1, spellCrit = 6, spellHit = 9, spi = 0.6, sta = 0.6 },
				},
				{
					source = "wowsims",
					upTo = 49,
					weights = { armor = 0.003, health = 0.03, int = 0.56, mana = 0.03, mp5 = 0.95, rdps = 0.75, sp = 1.1, spArcane = 0.65, spFire = 0.65, spFrost = 1.1, spellCrit = 6.394, spellHit = 7.25, spi = 0.3, sta = 0.3 },
				},
				{
					source = "wowsims",
					upTo = 59,
					weights = { armor = 0.003, health = 0.03, int = 0.56, mana = 0.03, mp5 = 0.95, rdps = 0.75, sp = 1.1, spArcane = 0.65, spFire = 0.65, spFrost = 1.1, spellCrit = 6.394, spellHit = 7.25, spi = 0.3, sta = 0.3 },
				},
				{
					source = "wowsims",
					upTo = 60,
					weights = { armor = 0.001, health = 0.015, int = 0.629, mana = 0.015, mp5 = 0.541, rdps = 0.375, sp = 1.1, spArcane = 0.875, spFire = 0.875, spFrost = 1.1, spellCrit = 12.976, spellHit = 17.587, spi = 0.15, sta = 0.15 },
				},
			},
		},
		PALADIN = {
			holy = {
				{
					source = "polestar",
					upTo = 60,
					weights = { armor = 0.005, dps = 0.5, heal = 0.65, health = 0.05, int = 1, mana = 0.06, mp5 = 2.2, sp = 0.15, spHoly = 0.1, spellCrit = 7, spi = 0.5, sta = 0.45, str = 0.15 },
				},
			},
			protection = {
				{
					source = "polestar",
					upTo = 59,
					weights = { agi = 0.5, armor = 0.05, block = 6, blockValue = 0.4, defense = 1, dodge = 10, dps = 2, health = 0.1, hit = 4, int = 0.4, mp5 = 1, parry = 10, sp = 0.5, spHoly = 0.5, spellHit = 4, sta = 1, str = 0.5 },
				},
				{
					source = "wowsims",
					upTo = 60,
					weights = { agi = 2.281, ap = 0.116, armor = 0.129, block = 1.5, blockValue = 2.157, crit = 4.615, defense = 3.729, dodge = 27.978, dps = 1.675, health = 0.025, hit = 1, int = 0.106, mp5 = 0.25, parry = 27.777, sp = 0.169, spHoly = 0.159, spellCrit = 0.389, spellHit = 1.952, sta = 0.25, str = 0.5 },
				},
			},
			retribution = {
				{
					source = "polestar",
					upTo = 60,
					weights = { agi = 0.55, ap = 0.5, armor = 0.02, crit = 9, dps = 7, health = 0.05, hit = 9, hp5 = 0.5, int = 0.35, mana = 0.02, mp5 = 1, sp = 0.3, spHoly = 0.3, spi = 0.15, sta = 0.5, str = 1 },
				},
			},
		},
		PRIEST = {
			discipline = {
				{
					source = "polestar",
					upTo = 60,
					weights = { armor = 0.005, heal = 0.55, health = 0.05, int = 1, mana = 0.06, mp5 = 2, rdps = 2.5, sp = 0.45, spellCrit = 6, spellHit = 3, spi = 0.8, sta = 0.5 },
				},
			},
			holy = {
				{
					source = "polestar",
					upTo = 60,
					weights = { armor = 0.005, heal = 0.7, health = 0.05, int = 1, mana = 0.06, mp5 = 2.2, rdps = 2, sp = 0.3, spellCrit = 6, spi = 0.85, sta = 0.45 },
				},
			},
			shadow = {
				{
					source = "polestar",
					upTo = 49,
					weights = { armor = 0.005, heal = 0.05, health = 0.06, int = 0.85, mana = 0.05, mp5 = 1.8, rdps = 3, sp = 1, spShadow = 1, spellCrit = 3, spellHit = 9, spi = 0.9, sta = 0.65 },
				},
				{
					source = "wowsims",
					upTo = 59,
					weights = { armor = 0.003, heal = 0.025, health = 0.03, int = 0.505, mana = 0.025, mp5 = 0.9, rdps = 1.5, sp = 1, spShadow = 1, spellCrit = 4.495, spellHit = 7.255, spi = 0.455, sta = 0.325 },
				},
				{
					source = "wowsims",
					upTo = 60,
					weights = { armor = 0.001, heal = 0.013, health = 0.015, int = 0.333, mana = 0.013, mp5 = 0.45, rdps = 0.75, sp = 1, spShadow = 1, spellCrit = 5.243, spellHit = 6.383, spi = 0.233, sta = 0.163 },
				},
			},
		},
		ROGUE = {
			assassination = {
				{
					source = "polestar",
					upTo = 39,
					weights = { agi = 1, ap = 0.55, armor = 0.02, crit = 11, dodge = 2, dps = 5.5, health = 0.05, hit = 11, hp5 = 0.5, rdps = 0.4, spi = 0.05, sta = 0.45, str = 0.55 },
				},
				{
					source = "wowsims",
					upTo = 49,
					weights = { agi = 1, ap = 0.571, armor = 0.01, crit = 8.056, dodge = 1, dps = 3.62, health = 0.025, hit = 9.701, hp5 = 0.25, rdps = 0.2, spNature = 0.201, spellCrit = 0.592, spellHit = 1.639, spi = 0.025, sta = 0.225, str = 0.6 },
				},
				{
					source = "wowsims",
					upTo = 59,
					weights = { agi = 1, ap = 0.571, armor = 0.01, crit = 8.056, dodge = 1, dps = 3.62, health = 0.025, hit = 9.701, hp5 = 0.25, rdps = 0.2, spNature = 0.201, spellCrit = 0.592, spellHit = 1.639, spi = 0.025, sta = 0.225, str = 0.6 },
				},
				{
					source = "wowsims",
					upTo = 60,
					weights = { agi = 1, ap = 0.453, armor = 0.005, crit = 8.397, dodge = 0.5, dps = 4.681, health = 0.013, hit = 12.027, hp5 = 0.125, rdps = 0.1, spellCrit = 0.129, spellHit = 0.296, spi = 0.013, sta = 0.113, str = 0.535 },
				},
			},
			combat = {
				{
					source = "polestar",
					upTo = 39,
					weights = { agi = 1, ap = 0.55, armor = 0.02, crit = 10, dodge = 2, dps = 6, health = 0.05, hit = 12, hp5 = 0.5, rdps = 0.4, spi = 0.05, sta = 0.45, str = 0.55 },
				},
				{
					source = "wowsims",
					upTo = 49,
					weights = { agi = 1, ap = 0.571, armor = 0.01, crit = 7.556, dodge = 1, dps = 3.87, health = 0.025, hit = 10.201, hp5 = 0.25, rdps = 0.2, spNature = 0.201, spellCrit = 0.592, spellHit = 1.639, spi = 0.025, sta = 0.225, str = 0.6 },
				},
				{
					source = "wowsims",
					upTo = 59,
					weights = { agi = 1, ap = 0.571, armor = 0.01, crit = 7.556, dodge = 1, dps = 3.87, health = 0.025, hit = 10.201, hp5 = 0.25, rdps = 0.2, spNature = 0.201, spellCrit = 0.592, spellHit = 1.639, spi = 0.025, sta = 0.225, str = 0.6 },
				},
				{
					source = "wowsims",
					upTo = 60,
					weights = { agi = 1, ap = 0.453, armor = 0.005, crit = 8.147, dodge = 0.5, dps = 4.806, health = 0.013, hit = 12.277, hp5 = 0.125, rdps = 0.1, spellCrit = 0.129, spellHit = 0.296, spi = 0.013, sta = 0.113, str = 0.535 },
				},
			},
			subtlety = {
				{
					source = "polestar",
					upTo = 39,
					weights = { agi = 1, ap = 0.5, armor = 0.02, crit = 10, dodge = 2, dps = 5.5, health = 0.05, hit = 10, hp5 = 0.5, rdps = 0.4, spi = 0.05, sta = 0.5, str = 0.5 },
				},
				{
					source = "wowsims",
					upTo = 49,
					weights = { agi = 1, ap = 0.546, armor = 0.01, crit = 7.556, dodge = 1, dps = 3.62, health = 0.025, hit = 9.201, hp5 = 0.25, rdps = 0.2, spNature = 0.201, spellCrit = 0.592, spellHit = 1.639, spi = 0.025, sta = 0.25, str = 0.575 },
				},
				{
					source = "wowsims",
					upTo = 59,
					weights = { agi = 1, ap = 0.546, armor = 0.01, crit = 7.556, dodge = 1, dps = 3.62, health = 0.025, hit = 9.201, hp5 = 0.25, rdps = 0.2, spNature = 0.201, spellCrit = 0.592, spellHit = 1.639, spi = 0.025, sta = 0.25, str = 0.575 },
				},
				{
					source = "wowsims",
					upTo = 60,
					weights = { agi = 1, ap = 0.44, armor = 0.005, crit = 8.147, dodge = 0.5, dps = 4.681, health = 0.013, hit = 11.777, hp5 = 0.125, rdps = 0.1, spellCrit = 0.129, spellHit = 0.296, spi = 0.013, sta = 0.125, str = 0.522 },
				},
			},
		},
		SHAMAN = {
			elemental = {
				{
					source = "polestar",
					upTo = 39,
					weights = { agi = 0.15, armor = 0.01, dps = 1.5, health = 0.05, int = 1, mana = 0.06, mp5 = 2, sp = 0.9, spFire = 0.3, spFrost = 0.2, spNature = 0.9, spellCrit = 8, spellHit = 8, spi = 0.35, sta = 0.5, str = 0.2 },
				},
				{
					source = "wowsims",
					upTo = 49,
					weights = { agi = 0.075, armor = 0.005, dps = 0.75, health = 0.025, int = 0.563, mana = 0.03, mp5 = 1.036, sp = 0.9, spFire = 0.312, spFrost = 0.1, spNature = 0.738, spellCrit = 5.773, spellHit = 8.005, spi = 0.175, sta = 0.25, str = 0.1 },
				},
				{
					source = "wowsims",
					upTo = 59,
					weights = { agi = 0.075, ap = 0.005, armor = 0.005, dps = 0.75, health = 0.025, int = 0.793, mana = 0.03, mp5 = 1.009, sp = 0.9, spFire = 0.285, spFrost = 0.1, spNature = 0.765, spellCrit = 7.56, spellHit = 11.474, spi = 0.175, sta = 0.25, str = 0.105 },
				},
				{
					source = "wowsims",
					upTo = 60,
					weights = { agi = 0.038, ap = 0.007, armor = 0.003, dps = 0.375, health = 0.013, int = 0.345, mana = 0.015, mp5 = 0.514, sp = 0.9, spFire = 0.143, spFrost = 0.05, spNature = 0.9, spellCrit = 7.11, spellHit = 10.35, spi = 0.088, sta = 0.125, str = 0.057 },
				},
			},
			enhancement = {
				{
					source = "polestar",
					upTo = 39,
					weights = { agi = 0.7, ap = 0.5, armor = 0.02, block = 0.3, crit = 9, dps = 7, health = 0.05, hit = 9, int = 0.35, mana = 0.02, mp5 = 1, sp = 0.15, spNature = 0.15, spi = 0.15, sta = 0.5, str = 1 },
				},
				{
					source = "wowsims",
					upTo = 49,
					weights = { agi = 0.595, ap = 0.468, armor = 0.01, block = 0.15, crit = 7.731, dps = 5.28, health = 0.025, hit = 6.6, int = 0.179, mana = 0.01, mp5 = 0.502, sp = 0.326, spFire = 0.138, spNature = 0.18, spellCrit = 0.424, spellHit = 0.007, spi = 0.075, sta = 0.25, str = 1 },
				},
				{
					source = "wowsims",
					upTo = 59,
					weights = { agi = 0.595, ap = 0.468, armor = 0.01, block = 0.15, crit = 7.731, dps = 5.28, health = 0.025, hit = 6.6, int = 0.179, mana = 0.01, mp5 = 0.502, sp = 0.326, spFire = 0.138, spNature = 0.18, spellCrit = 0.424, spellHit = 0.007, spi = 0.075, sta = 0.25, str = 1 },
				},
				{
					source = "wowsims",
					upTo = 60,
					weights = { agi = 0.542, ap = 0.453, armor = 0.005, block = 0.075, crit = 7.097, dps = 4.419, health = 0.013, hit = 5.401, int = 0.094, mana = 0.005, mp5 = 0.253, sp = 0.414, spFire = 0.206, spNature = 0.195, spellCrit = 0.635, spellHit = 0.01, spi = 0.038, sta = 0.125, str = 1 },
				},
			},
			restoration = {
				{
					source = "polestar",
					upTo = 60,
					weights = { armor = 0.005, dps = 0.5, heal = 0.7, health = 0.05, int = 1, mana = 0.06, mp5 = 2.4, sp = 0.1, spellCrit = 6, spi = 0.35, sta = 0.45 },
				},
			},
		},
		WARLOCK = {
			affliction = {
				{
					source = "polestar",
					upTo = 59,
					weights = { armor = 0.005, health = 0.08, int = 0.75, mana = 0.05, mp5 = 1, rdps = 2, sp = 1, spFire = 0.2, spShadow = 1, spellCrit = 3, spellHit = 9, spi = 0.6, sta = 0.8 },
				},
				{
					source = "wowsims",
					upTo = 60,
					weights = { armor = 0.001, health = 0.02, int = 0.36, mana = 0.02, mp5 = 0.355, rdps = 0.5, sp = 1, spFire = 0.125, spShadow = 0.925, spellCrit = 6.69, spellHit = 11.843, spi = 0.15, sta = 0.208 },
				},
			},
			demonology = {
				{
					source = "polestar",
					upTo = 59,
					weights = { armor = 0.005, health = 0.1, int = 0.75, mana = 0.05, mp5 = 1, rdps = 2, sp = 0.85, spFire = 0.2, spShadow = 0.85, spellCrit = 3, spellHit = 8, spi = 0.55, sta = 1 },
				},
				{
					source = "wowsims",
					upTo = 60,
					weights = { armor = 0.001, health = 0.025, int = 0.334, mana = 0.019, mp5 = 0.339, rdps = 0.5, sp = 0.85, spFire = 0.114, spShadow = 0.786, spellCrit = 5.799, spellHit = 10.154, spi = 0.138, sta = 0.256 },
				},
			},
			destruction = {
				{
					source = "polestar",
					upTo = 59,
					weights = { armor = 0.005, health = 0.07, int = 0.85, mana = 0.05, mp5 = 1, rdps = 2, sp = 1, spFire = 0.6, spShadow = 0.8, spellCrit = 7, spellHit = 9, spi = 0.4, sta = 0.7 },
				},
				{
					source = "wowsims",
					upTo = 60,
					weights = { armor = 0.001, health = 0.018, int = 0.385, mana = 0.02, mp5 = 0.355, rdps = 0.5, sp = 1, spFire = 0.225, spShadow = 0.875, spellCrit = 7.69, spellHit = 11.843, spi = 0.1, sta = 0.183 },
				},
			},
		},
		WARRIOR = {
			arms = {
				{
					source = "polestar",
					upTo = 49,
					weights = { agi = 0.6, ap = 0.5, armor = 0.02, block = 0.3, blockValue = 0.05, crit = 10, defense = 0.2, dodge = 3, dps = 7, health = 0.05, hit = 9, hp5 = 1, parry = 3, rdps = 0.5, spi = 0.1, sta = 0.5, str = 1 },
				},
				{
					source = "wowsims",
					upTo = 59,
					weights = { agi = 0.671, ap = 0.449, armor = 0.016, block = 0.15, blockValue = 0.025, crit = 10, defense = 0.1, dodge = 1.5, dps = 5.874, health = 0.025, hit = 10.211, hp5 = 0.5, parry = 1.5, rdps = 0.25, spi = 0.05, sta = 0.25, str = 1 },
				},
				{
					source = "wowsims",
					upTo = 60,
					weights = { agi = 0.706, ap = 0.424, armor = 0.005, block = 0.075, blockValue = 0.013, crit = 10, defense = 0.05, dodge = 0.75, dps = 5.312, health = 0.013, hit = 10.817, hp5 = 0.25, parry = 0.75, rdps = 0.125, spi = 0.025, sta = 0.125, str = 1 },
				},
			},
			fury = {
				{
					source = "polestar",
					upTo = 49,
					weights = { agi = 0.65, ap = 0.5, armor = 0.02, crit = 11, defense = 0.2, dodge = 3, dps = 6.5, health = 0.05, hit = 11, hp5 = 1, parry = 3, rdps = 0.5, spi = 0.1, sta = 0.5, str = 1 },
				},
				{
					source = "wowsims",
					upTo = 59,
					weights = { agi = 0.696, ap = 0.449, armor = 0.016, crit = 10.5, defense = 0.1, dodge = 1.5, dps = 5.624, health = 0.025, hit = 11.211, hp5 = 0.5, parry = 1.5, rdps = 0.25, spi = 0.05, sta = 0.25, str = 1 },
				},
				{
					source = "wowsims",
					upTo = 60,
					weights = { agi = 0.718, ap = 0.424, armor = 0.005, crit = 10.25, defense = 0.05, dodge = 0.75, dps = 5.187, health = 0.013, hit = 11.317, hp5 = 0.25, parry = 0.75, rdps = 0.125, spi = 0.025, sta = 0.125, str = 1 },
				},
			},
			protection = {
				{
					source = "polestar",
					upTo = 60,
					weights = { agi = 0.7, ap = 0.25, armor = 0.06, block = 8, blockValue = 0.5, crit = 4, defense = 1.2, dodge = 12, dps = 2.5, health = 0.1, hit = 6, hp5 = 1.5, parry = 12, rdps = 0.3, spi = 0.05, sta = 1, str = 0.6 },
				},
			},
		},
	},
	classes = {
		DRUID = {
			bit = 1024,
			default = "feral",
			specs = {
				{ key = "balance", names = { "balance" } },
				{ key = "feral", names = { "feral", "feralcombat" } },
				{ key = "restoration", names = { "restoration" } },
			},
		},
		HUNTER = {
			bit = 4,
			default = "beastmastery",
			specs = {
				{ key = "beastmastery", names = { "beastmastery" } },
				{ key = "marksmanship", names = { "marksmanship" } },
				{ key = "survival", names = { "survival" } },
			},
		},
		MAGE = {
			bit = 128,
			default = "frost",
			specs = {
				{ key = "arcane", names = { "arcane" } },
				{ key = "fire", names = { "fire" } },
				{ key = "frost", names = { "frost" } },
			},
		},
		PALADIN = {
			bit = 2,
			default = "retribution",
			specs = {
				{ key = "holy", names = { "holy" } },
				{ key = "protection", names = { "protection" } },
				{ key = "retribution", names = { "retribution" } },
			},
		},
		PRIEST = {
			bit = 16,
			default = "shadow",
			specs = {
				{ key = "discipline", names = { "discipline" } },
				{ key = "holy", names = { "holy" } },
				{ key = "shadow", names = { "shadow" } },
			},
		},
		ROGUE = {
			bit = 8,
			default = "combat",
			specs = {
				{ key = "assassination", names = { "assassination" } },
				{ key = "combat", names = { "combat" } },
				{ key = "subtlety", names = { "subtlety" } },
			},
		},
		SHAMAN = {
			bit = 64,
			default = "enhancement",
			specs = {
				{ key = "elemental", names = { "elemental" } },
				{ key = "enhancement", names = { "enhancement" } },
				{ key = "restoration", names = { "restoration" } },
			},
		},
		WARLOCK = {
			bit = 256,
			default = "affliction",
			specs = {
				{ key = "affliction", names = { "affliction" } },
				{ key = "demonology", names = { "demonology" } },
				{ key = "destruction", names = { "destruction" } },
			},
		},
		WARRIOR = {
			bit = 1,
			default = "arms",
			specs = {
				{ key = "arms", names = { "arms" } },
				{ key = "fury", names = { "fury" } },
				{ key = "protection", names = { "protection" } },
			},
		},
	},
	proficiency = {
		DRUID = { armor = 2, relic = 8, weapons = { [4] = true, [5] = true, [10] = true, [13] = true, [15] = true } },
		HUNTER = {
			armor = 2,
			armorAt40 = 3,
			dualWield = 20,
			weapons = { [0] = true, [1] = true, [2] = true, [3] = true, [6] = true, [7] = true, [8] = true, [10] = true, [13] = true, [15] = true, [16] = true, [18] = true },
		},
		MAGE = { armor = 1, weapons = { [7] = true, [10] = true, [15] = true, [19] = true } },
		PALADIN = {
			armor = 3,
			armorAt40 = 4,
			relic = 7,
			shield = true,
			weapons = { [0] = true, [1] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true },
		},
		PRIEST = { armor = 1, weapons = { [4] = true, [10] = true, [15] = true, [19] = true } },
		ROGUE = {
			armor = 2,
			dualWield = 10,
			weapons = { [2] = true, [3] = true, [4] = true, [7] = true, [13] = true, [15] = true, [16] = true, [18] = true },
		},
		SHAMAN = {
			armor = 2,
			armorAt40 = 3,
			relic = 9,
			shield = true,
			weapons = { [0] = true, [1] = true, [4] = true, [5] = true, [10] = true, [13] = true, [15] = true },
		},
		WARLOCK = { armor = 1, weapons = { [7] = true, [10] = true, [15] = true, [19] = true } },
		WARRIOR = {
			armor = 3,
			armorAt40 = 4,
			dualWield = 20,
			shield = true,
			weapons = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [10] = true, [13] = true, [15] = true, [16] = true, [18] = true },
		},
	},
	racials = {
		[1] = { statMult = { spi = 1.05 }, weaponCrit = { pct = 2, subclasses = { [7] = true, [8] = true } } },
		[2] = { weaponCrit = { pct = 1, subclasses = { [0] = true, [1] = true } } },
		[3] = { weaponCrit = { pct = 1, subclasses = { [4] = true, [5] = true } } },
		[7] = { statMult = { int = 1.05 } },
	},
	weights = {
		DRUID = {
			balance = { armor = 0.005, heal = 0.1, health = 0.05, int = 1, mana = 0.06, mp5 = 2, sp = 0.9, spArcane = 0.7, spNature = 0.9, spellCrit = 6, spellHit = 8, spi = 0.5, sta = 0.5 },
			feral = { agi = 1, ap = 0.5, armor = 0.04, crit = 9, defense = 0.4, dodge = 6, health = 0.07, hit = 9, hp5 = 0.5, int = 0.2, spi = 0.15, sta = 0.65, str = 1 },
			restoration = { armor = 0.005, heal = 0.7, health = 0.05, int = 1, mana = 0.06, mp5 = 2.2, sp = 0.1, spellCrit = 4, spi = 0.65, sta = 0.45 },
		},
		HUNTER = {
			beastmastery = { agi = 1, ap = 0.5, armor = 0.02, crit = 10, dps = 0.5, health = 0.05, hit = 10, int = 0.35, mana = 0.02, mp5 = 1.2, rap = 0.45, rdps = 6.5, spi = 0.2, sta = 0.55, str = 0.1 },
			marksmanship = { agi = 1, ap = 0.5, armor = 0.02, crit = 11, dps = 0.5, health = 0.05, hit = 11, int = 0.4, mana = 0.02, mp5 = 1.2, rap = 0.45, rdps = 7, spi = 0.2, sta = 0.5, str = 0.1 },
			survival = { agi = 1.1, ap = 0.55, armor = 0.02, crit = 11, dps = 1, health = 0.05, hit = 10, int = 0.35, mana = 0.02, mp5 = 1, rap = 0.45, rdps = 6.5, spi = 0.2, sta = 0.55, str = 0.15 },
		},
		MAGE = {
			arcane = { armor = 0.005, health = 0.05, int = 1, mana = 0.07, mp5 = 1.8, rdps = 1.5, sp = 1.1, spArcane = 1.1, spFire = 0.4, spFrost = 0.4, spellCrit = 7, spellHit = 9, spi = 0.55, sta = 0.55 },
			fire = { armor = 0.005, health = 0.05, int = 0.9, mana = 0.06, mp5 = 1.6, rdps = 1.5, sp = 1.1, spArcane = 0.2, spFire = 1.1, spFrost = 0.2, spellCrit = 9, spellHit = 9, spi = 0.5, sta = 0.55 },
			frost = { armor = 0.005, health = 0.06, int = 0.9, mana = 0.06, mp5 = 1.8, rdps = 1.5, sp = 1.1, spArcane = 0.2, spFire = 0.2, spFrost = 1.1, spellCrit = 6, spellHit = 9, spi = 0.6, sta = 0.6 },
		},
		PALADIN = {
			holy = { armor = 0.005, dps = 0.5, heal = 0.65, health = 0.05, int = 1, mana = 0.06, mp5 = 2.2, sp = 0.15, spHoly = 0.1, spellCrit = 7, spi = 0.5, sta = 0.45, str = 0.15 },
			protection = { agi = 0.5, armor = 0.05, block = 6, blockValue = 0.4, defense = 1, dodge = 10, dps = 2, health = 0.1, hit = 4, int = 0.4, mp5 = 1, parry = 10, sp = 0.5, spHoly = 0.5, spellHit = 4, sta = 1, str = 0.5 },
			retribution = { agi = 0.55, ap = 0.5, armor = 0.02, crit = 9, dps = 7, health = 0.05, hit = 9, hp5 = 0.5, int = 0.35, mana = 0.02, mp5 = 1, sp = 0.3, spHoly = 0.3, spi = 0.15, sta = 0.5, str = 1 },
		},
		PRIEST = {
			discipline = { armor = 0.005, heal = 0.55, health = 0.05, int = 1, mana = 0.06, mp5 = 2, rdps = 2.5, sp = 0.45, spellCrit = 6, spellHit = 3, spi = 0.8, sta = 0.5 },
			holy = { armor = 0.005, heal = 0.7, health = 0.05, int = 1, mana = 0.06, mp5 = 2.2, rdps = 2, sp = 0.3, spellCrit = 6, spi = 0.85, sta = 0.45 },
			shadow = { armor = 0.005, heal = 0.05, health = 0.06, int = 0.85, mana = 0.05, mp5 = 1.8, rdps = 3, sp = 1, spShadow = 1, spellCrit = 3, spellHit = 9, spi = 0.9, sta = 0.65 },
		},
		ROGUE = {
			assassination = { agi = 1, ap = 0.55, armor = 0.02, crit = 11, dodge = 2, dps = 5.5, health = 0.05, hit = 11, hp5 = 0.5, rdps = 0.4, spi = 0.05, sta = 0.45, str = 0.55 },
			combat = { agi = 1, ap = 0.55, armor = 0.02, crit = 10, dodge = 2, dps = 6, health = 0.05, hit = 12, hp5 = 0.5, rdps = 0.4, spi = 0.05, sta = 0.45, str = 0.55 },
			subtlety = { agi = 1, ap = 0.5, armor = 0.02, crit = 10, dodge = 2, dps = 5.5, health = 0.05, hit = 10, hp5 = 0.5, rdps = 0.4, spi = 0.05, sta = 0.5, str = 0.5 },
		},
		SHAMAN = {
			elemental = { agi = 0.15, armor = 0.01, dps = 1.5, health = 0.05, int = 1, mana = 0.06, mp5 = 2, sp = 0.9, spFire = 0.3, spFrost = 0.2, spNature = 0.9, spellCrit = 8, spellHit = 8, spi = 0.35, sta = 0.5, str = 0.2 },
			enhancement = { agi = 0.7, ap = 0.5, armor = 0.02, block = 0.3, crit = 9, dps = 7, health = 0.05, hit = 9, int = 0.35, mana = 0.02, mp5 = 1, sp = 0.15, spNature = 0.15, spi = 0.15, sta = 0.5, str = 1 },
			restoration = { armor = 0.005, dps = 0.5, heal = 0.7, health = 0.05, int = 1, mana = 0.06, mp5 = 2.4, sp = 0.1, spellCrit = 6, spi = 0.35, sta = 0.45 },
		},
		WARLOCK = {
			affliction = { armor = 0.005, health = 0.08, int = 0.75, mana = 0.05, mp5 = 1, rdps = 2, sp = 1, spFire = 0.2, spShadow = 1, spellCrit = 3, spellHit = 9, spi = 0.6, sta = 0.8 },
			demonology = { armor = 0.005, health = 0.1, int = 0.75, mana = 0.05, mp5 = 1, rdps = 2, sp = 0.85, spFire = 0.2, spShadow = 0.85, spellCrit = 3, spellHit = 8, spi = 0.55, sta = 1 },
			destruction = { armor = 0.005, health = 0.07, int = 0.85, mana = 0.05, mp5 = 1, rdps = 2, sp = 1, spFire = 0.6, spShadow = 0.8, spellCrit = 7, spellHit = 9, spi = 0.4, sta = 0.7 },
		},
		WARRIOR = {
			arms = { agi = 0.6, ap = 0.5, armor = 0.02, block = 0.3, blockValue = 0.05, crit = 10, defense = 0.2, dodge = 3, dps = 7, health = 0.05, hit = 9, hp5 = 1, parry = 3, rdps = 0.5, spi = 0.1, sta = 0.5, str = 1 },
			fury = { agi = 0.65, ap = 0.5, armor = 0.02, crit = 11, defense = 0.2, dodge = 3, dps = 6.5, health = 0.05, hit = 11, hp5 = 1, parry = 3, rdps = 0.5, spi = 0.1, sta = 0.5, str = 1 },
			protection = { agi = 0.7, ap = 0.25, armor = 0.06, block = 8, blockValue = 0.5, crit = 4, defense = 1.2, dodge = 12, dps = 2.5, health = 0.1, hit = 6, hp5 = 1.5, parry = 12, rdps = 0.3, spi = 0.05, sta = 1, str = 0.6 },
		},
	},
}
