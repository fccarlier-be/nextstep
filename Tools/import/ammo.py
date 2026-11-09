"""Import des vendeurs de munitions (flèches, balles) pour l'alerte du chasseur.

    python -I Tools/import/ammo.py <checkout de Polestar> [polestar.lock]

À lancer depuis la racine du dépôt (Tools\\import\\run.ps1 le fait). Source :
forever-db/data/*.jsonl (GPL-3.0) : PNJ (titre, faction) et positions.

forever-db ne dit pas ce que vend chaque marchand : un vendeur est retenu sur son titre
(« Bowyer », « Gunsmith », « General Supplies »...). C'est une présomption : en jeu,
l'addon apprend à chaque ouverture de marchand ce qu'il vend vraiment (Modules/Items/Ammo.lua).

Produit addon/NextStep/Data/Imported/Polestar/AmmoVendors.lua (format : docs/DATA_FORMAT.md,
« Vendeurs de munitions »).
"""

import json
import os
import re
import sys

SOURCE = sys.argv[1]
LOCK = sys.argv[2] if len(sys.argv) > 2 else "Tools/import/polestar.lock"
OUT = "addon/NextStep/Data/Imported/Polestar/AmmoVendors.lua"
DB_DIR = os.path.join(SOURCE, "forever-db", "data")

# Titre -> munitions présumées : a flèches, b balles. L'ordre compte : le premier motif
# qui correspond l'emporte. Les maîtres d'armes (« Bow Trainer ») sont écartés.
TITLES = [
    (r"trainer", None),
    (r"bow.*gun|gun.*bow", "ab"),
    (r"ammo|bullet|gun", "b"),
    (r"\bbow|arrow|fletch", "a"),
    (r"^general (supplies|goods)", "ab"),
]

# Modèles de faction (FactionTemplate) des villes : A Alliance, H Horde ; les autres
# (gobelins, Cenarion...) sont accueillants pour les deux.
ALLIANCE = {11, 12, 55, 79, 80, 694, 894, 1217}
HORDE = {29, 68, 104, 105, 126, 1215}


def read_jsonl(name):
    with open(os.path.join(DB_DIR, name + ".jsonl"), encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


lock = {}
for line in read(LOCK).splitlines():
    m = re.match(r"^\s*([^#=]+?)\s*=\s*(.+?)\s*$", line)
    if m:
        lock[m.group(1)] = m.group(2)

spawns = {}
for row in read_jsonl("spawn"):
    if row["kind"] == "npc":
        spawns.setdefault(row["id"], []).append(row)
ui_maps = read_jsonl("ui_map")


def map_point(spawn):
    """Carte du client la plus petite qui contient le point, x, y (%)."""
    best = None
    for frame in ui_maps:
        if frame["map"] != spawn["map"]:
            continue
        top, bottom, left, right = frame["top"], frame["bottom"], frame["left"], frame["right"]
        if not (bottom <= spawn["x"] <= top and right <= spawn["y"] <= left):
            continue
        area = (top - bottom) * (left - right)
        if best is None or area < best[0]:
            best = (area, frame)
    if not best:
        return None
    frame = best[1]
    x = (frame["left"] - spawn["y"]) / (frame["left"] - frame["right"]) * 100
    y = (frame["top"] - spawn["x"]) / (frame["top"] - frame["bottom"]) * 100
    return frame["ui_map"], round(x, 1), round(y, 1)


def kind_of(title):
    title = title.lower()
    for pattern, kind in TITLES:
        if re.search(pattern, title):
            return kind
    return None


rows = []
for npc in read_jsonl("npc"):
    kind = npc.get("subname") and kind_of(npc["subname"])
    if not kind or npc["id"] not in spawns:
        continue
    template = npc.get("faction_template")
    faction = "A" if template in ALLIANCE else "H" if template in HORDE else "N"
    # Un seul point par vendeur : le premier sur une carte connue (les doublons d'un
    # même PNJ sont rares chez les marchands).
    for spawn in spawns[npc["id"]]:
        point = map_point(spawn)
        if point:
            rows.append((npc["id"], kind, faction, spawn, point, npc["name"]))
            break

commit = lock.get("commit", "?")[:12]
out = [
    "-- Généré par Tools/import/ammo.py depuis forever-db de Polestar %s (%s). Ne pas modifier."
    % (lock.get("version", "?"), commit),
    "-- Vendeurs présumés de munitions, retenus sur leur titre :",
    '-- [PNJ] = "<a flèches, b balles> <faction A, H ou N> <carte monde> <nord> <ouest> '
    '<carte du client> <x> <y>|<nom anglais>"',
    "-- (positions monde en yards comme UnitPosition ; carte du client en pour cent).",
    "-- GPL-3.0 : ForeverDB-NOTICE.md.",
    "",
    "NextStep.DB.ammoVendors = {",
]
for npc, kind, faction, spawn, (ui_map, x, y), name in sorted(rows):
    name = name.replace("\\", "").replace('"', "'").replace("|", "")
    out.append('\t[%d] = "%s %s %d %s %s %d %s %s|%s",' % (
        npc, kind, faction, spawn["map"], round(spawn["x"], 1), round(spawn["y"], 1), ui_map, x, y, name))
out.append("}")
with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(out) + "\n")
print("%d vendeurs de munitions" % len(rows))
