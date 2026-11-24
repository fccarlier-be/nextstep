"""Génère les illustrations des cartes du journal (Modules/Guide/Journal.lua) avec FLUX.

    python Tools/theme/illustrations.py            # ce qui manque
    python Tools/theme/illustrations.py 1429 Class # seulement ces clés (régénère)

Une peinture par zone de guide (identifiant de carte du client) et par catégorie de
guides sans zone. Les originaux (1536 x 384) sont gardés dans Tools/theme/cache/
(non versionnés) ; l'addon reçoit addon/NextStep/Media/Zones/<clé>.blp, 512 x 128,
BLP2 en palette de 256 couleurs (environ 65 Ko chacune).

Demande ComfyUI lancé en local (Tools/theme/comfy.py).
"""

import os
import sys

from PIL import Image

from comfy import generate

HERE = os.path.dirname(__file__)
CACHE = os.path.join(HERE, "cache")
OUT = os.path.join(HERE, "..", "..", "addon", "NextStep", "Media", "Zones")

STYLE = ("Wide panoramic painted fantasy landscape banner in the hand-painted style of a classic "
         "high-fantasy MMORPG loading screen: {}. Soft painterly brushwork, vibrant saturated colours, "
         "strong depth, no text, no logo, no people, no frame.")

SCENES = {
    # Continents et monde
    "947": "the whole world of Azeroth seen from high above, two continents across a vast blue ocean, clouds",
    "1414": "Kalimdor, red canyons, golden savanna and ancient purple night-elf forests under a wide sky",
    "1415": "the Eastern Kingdoms, green hills, stone castles, snowy dwarven peaks and a distant volcano",
    # Royaumes de l'Est
    "1416": "Alterac Mountains, snowy pine slopes, a ruined grey stone city, cold blue light",
    "1417": "Arathi Highlands, rolling grassy hills, a ruined human fortress, standing stones, windy sky",
    "1418": "the Badlands, dry red rock mesas, cracked earth, dragon bones, scorching orange sun",
    "1419": "the Blasted Lands, scorched red wasteland, a gigantic dark portal of stone glowing green, ash sky",
    "1420": "Tirisfal Glades, grey haunted forest, crooked trees, a ruined abbey, sickly green fog",
    "1421": "Silverpine Forest, dark misty pine woods on a rocky coast, a grim stone keep, moonlight",
    "1422": "Western Plaguelands, blighted farmland, wooden windmill, dead trees, plague-green haze",
    "1423": "Eastern Plaguelands, rotten corrupted forest, a ruined cathedral, purple and green plague sky",
    "1424": "Hillsbrad Foothills, green farmland, orchards, a coastal village with red roofs, summer light",
    "1425": "the Hinterlands, wild forested hills, jungle troll ziggurats, a griffon aerie on a cliff",
    "1426": "Dun Morogh, snowy mountains, a dwarven stone gate carved into the mountain, warm torchlight",
    "1427": "Searing Gorge, volcanic quarry, rivers of lava, iron chains and dark dwarven machinery",
    "1428": "the Burning Steppes, black volcanic plains, rivers of lava, burning sky, a dark mountain fortress",
    "1429": "Elwynn Forest, lush green hills, tall oaks and pines, a winding road, a stone abbey with blue roofs",
    "1430": "a desolate grey mountain pass, a narrow canyon, dead trees, a dark ominous tower under a stormy sky",
    "1431": "Duskwood, dark eternal night forest, twisted trees, a lonely lantern-lit village, a pale moon",
    "1432": "Loch Modan, a huge stone dam holding a blue lake, green hills, dwarven farms",
    "1433": "Redridge Mountains, red rocky peaks, a calm lake, a stone bridge and a village with red roofs",
    "1434": "Stranglethorn Vale, dense tropical jungle, ancient troll ruins, a pirate harbour on a turquoise sea",
    "1435": "the Swamp of Sorrows, gloomy swamp, misty murky water, mangrove trees, a sunken temple",
    "1436": "Westfall, golden wheat fields, a red wooden windmill, a farmhouse, a lighthouse on the coast",
    "1437": "the Wetlands, rainy marshes, a dwarven harbour, ruined stone fortress, grey sea",
    "1453": "Stormwind City, a great white stone city with blue roofs, a cathedral, canals, banners",
    "1455": "Ironforge, a vast dwarven hall carved in a mountain, a great forge, molten metal glow",
    "1458": "Undercity, gloomy underground ruined royal city, green sewer canals, dark stone arches",
    # Kalimdor
    "1411": "Durotar, red rocky desert, spiky orc huts, a great orc city with walls, coastal cliffs",
    "1412": "Mulgore, vast green grassy plains, tall mesas, tauren totems and tents, a peaceful sky",
    "1413": "the Barrens, dry yellow savanna, acacia trees, thorny spikes, giraffe-like creatures, dusty sun",
    "1438": "Teldrassil, a colossal world tree, glowing purple and blue night-elf forest, moonwells",
    "1439": "Darkshore, a misty moonlit coast, ancient night-elf ruins, tall dark trees, silver sea",
    "1440": "Ashenvale, deep enchanted purple and teal forest, huge trees, glowing moonlight",
    "1441": "Thousand Needles, towering stone spires in a vast salt flat canyon, rope bridges",
    "1442": "Stonetalon Mountains, rocky peaks, deforested slopes, goblin machinery, a hidden green valley",
    "1443": "Desolace, grey desolate wasteland, centaur camps, bones of giant beasts, pale sky",
    "1444": "Feralas, lush rainforest, enormous ancient trees, elven ruins overgrown by vines",
    "1445": "Dustwallow Marsh, foggy swamp, a stone island fortress with a harbour, a dark dragon cave",
    "1446": "Tanaris, golden sand dunes, a goblin desert town, ancient desert temples, blazing sun",
    "1447": "Azshara, autumn red and orange forest on cliffs, ancient elven ruins, a deep blue sea",
    "1448": "Felwood, corrupted sickly green forest, toxic ooze, twisted dark trees, demonic glow",
    "1449": "Un'Goro Crater, primeval jungle in a giant crater, a smoking volcano, dinosaurs, crystals",
    "1450": "Moonglade, a serene sacred lake with a small island, druid huts, eternal starry twilight",
    "1451": "Silithus, alien yellow desert, giant insect hives, crystal spires, a hot purple sky",
    "1452": "Winterspring, snowy enchanted valley, frozen lakes, icy pines, hot springs, aurora sky",
    "1454": "Orgrimmar, a great orc city of red rock and spiked iron walls, war banners, desert light",
    "1456": "Thunder Bluff, tauren city on tall mesas linked by rope bridges, totems, sunset over plains",
    "1457": "Darnassus, night-elf city among giant trees, white marble temples, moonlit lakes",
    # Zones ajoutées par Forever
    "2482": "Mount Hyjal, a sacred mountain forest with a giant world tree at its summit, clouds, moonlight",
    "2521": "Zephras Isle, a floating island in the sky, waterfalls falling into the clouds, airships, sunrise",
    "2548": "the Riverglades, a wide green river valley, a logging camp, farms, a goblin port, forested hills",
    "2652": "Shen'dralas, ancient night-elf highborne ruins on a mystical island, arcane blue glow, twilight",
    # Catégories sans zone
    "Class": "an ancient library of a mage tower, open spellbooks, weapons and armour on racks, candlelight",
    "Professions": "a busy fantasy crafting workshop, a blacksmith anvil with sparks, herbs, alchemy flasks",
    "Reputation": "a hall of great banners and heraldic tabards of many factions, golden light",
    "Collectibles": "a fantasy stable with mounts, a griffon, a horse and a raptor, small companion pets",
    "Exploration": "an explorer's map table with an old parchment world map, a compass, a spyglass, candles",
    "Legacy": "a hall of heroes with golden statues and trophies, ancient relics on pedestals",
    "Miscellaneous": "a cosy fantasy inn at night, a fireplace, wooden tables, a bedroll and backpacks",
}


# Graine décalée pour une image ratée (texte incrusté…), afin de la régénérer autrement.
SEED_SHIFT = {"1430": 1}


def build(key):
    source = os.path.join(CACHE, key + ".png")
    if not os.path.exists(source) or key in sys.argv[1:]:
        os.makedirs(CACHE, exist_ok=True)
        seed = sum(ord(c) for c in key) * 7919 + SEED_SHIFT.get(key, 0)
        generate(STYLE.format(SCENES[key]), width=1536, height=384, seed=seed).save(source)
    image = Image.open(source).convert("RGB").resize((512, 128), Image.LANCZOS)
    palette = image.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)
    os.makedirs(OUT, exist_ok=True)
    palette.save(os.path.join(OUT, key + ".blp"))
    print("écrit", key)


if __name__ == "__main__":
    keys = sys.argv[1:] or list(SCENES)
    for key in keys:
        target = os.path.join(OUT, key + ".blp")
        if sys.argv[1:] or not os.path.exists(target):
            build(key)
