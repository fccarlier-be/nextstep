"""Import des donjons : quêtes à prendre (et leurs chaînes), butin des boss, provenance
des objets de leveling et leurs caractéristiques.

    python -I Tools/import/dungeons.py <checkout de Polestar> [polestar.lock]

À lancer depuis la racine du dépôt (Tools\\import\\run.ps1 le fait). Sources, toutes
dans le checkout de Polestar :

- forever-db/data/*.jsonl (GPL-3.0) : quêtes, donneurs, prérequis, récompenses, positions ;
- addon/Polestar_ItemDB/Forever.lua (faits de ForeverLevelingBiS, MIT) : butin choisi des
  boss avec son taux, provenance des objets de leveling, quêtes marquées « donjon » ;
- addon/Polestar_ItemDB/Items.lua (tables du client, GPL-3.0 de Polestar) : emplacement,
  niveau, qualité et caractéristiques des objets retenus.

Produit addon/NextStep/Data/Imported/Polestar/Dungeons.lua (format : docs/DATA_FORMAT.md,
« Donjons ») et recopie les notices (ItemDB-LICENSE-DATA.txt, ForeverDB-NOTICE.md).
La liste des donjons (zone, niveaux, faction) et les quêtes rattachées par leur titre sont
écrites ici, à la main : ce sont des faits du jeu.
"""

import json
import os
import re
import sys

SOURCE = sys.argv[1]
LOCK = sys.argv[2] if len(sys.argv) > 2 else "Tools/import/polestar.lock"
OUT_DIR = "addon/NextStep/Data/Imported/Polestar/"
DB_DIR = os.path.join(SOURCE, "forever-db", "data")
ITEMDB = os.path.join(SOURCE, "addon", "Polestar_ItemDB")

# Donjons : clé, zone (AreaTable), carte d'instance (GetInstanceInfo), niveaux conseillés,
# faction ("A", "H" ou None pour les deux), zone d'entrée (AreaTable), propre à Forever.
DUNGEONS = [
    ("ragefire", 2437, 389, 13, 18, "H", 1637, False),
    ("wailing", 718, 43, 17, 24, None, 17, False),
    ("deadmines", 1581, 36, 17, 26, None, 40, False),
    ("thanes", 16919, None, 14, 22, None, 1, True),
    ("shadowfang", 209, 33, 22, 30, None, 130, False),
    ("lordaeron", 16611, None, 20, 26, None, 85, True),
    ("blackfathom", 719, 48, 24, 32, None, 331, False),
    ("stockade", 717, 34, 24, 32, "A", 1519, False),
    ("gnomeregan", 721, 90, 29, 38, None, 1, False),
    ("excavation", 16732, None, 29, 35, None, 11, True),
    ("kraul", 491, 47, 29, 38, None, 17, False),
    ("dalaran", 16544, None, 30, 36, None, 267, True),
    ("scarlet", 796, 189, 34, 45, None, 85, False),
    ("downs", 722, 129, 37, 46, None, 17, False),
    ("uldaman", 1337, 70, 41, 51, None, 3, False),
    ("zulfarrak", 1176, 209, 44, 54, None, 440, False),
    ("maraudon", 2100, 349, 46, 55, None, 405, False),
    ("temple", 1477, 109, 50, 60, None, 8, False),
    ("depths", 1584, 230, 52, 60, None, 51, False),
    ("spire", 1583, 229, 55, 60, None, 46, False),
    ("diremaul", 2557, 429, 55, 60, None, 357, False),
    ("stratholme", 2017, 329, 58, 60, None, 139, False),
    ("scholomance", 2057, 289, 58, 60, None, 28, False),
]
# Zones de butin de ForeverLevelingBiS rattachées à un donjon.
LOOT_ZONES = {17803: "depths", 17804: "spire", 1417: "temple"}

# Quêtes de donjon que forever-db range dans la zone du donneur : par titre (toutes les
# quêtes de ce titre, versions Alliance et Horde comprises).
BY_TITLE = {
    "gnomeregan": ["Gnogaine", "The Only Cure is More Green Glow", "Gyrodrillmatic Excavationators",
                   "Essential Artificials", "Data Rescue", "A Fine Mess", "Rig Wars", "Grime-Encrusted Ring"],
    "kraul": ["Blueleaf Tubers", "Mortality Wanes", "Willix the Importer", "The Crone of the Kraul",
              "A Vengeful Fate", "Going, Going, Guano!"],
    "uldaman": ["Power Stones", "Solution to Doom", "Agmond's Fate", "The Lost Dwarves", "The Hidden Chamber",
                "The Platinum Discs", "The Lost Tablets of Will", "Power in Uldaman", "The Shattered Necklace",
                "Uldaman Reagent Run"],
    "zulfarrak": ["Gahz'rilla", "Divino-matic Rod", "Troll Temper", "Scarab Shells", "Tiara of the Deep",
                  "The Prophecy of Mosh'aru", "Nekrum's Medallion", "The Spider God"],
    "temple": ["Into The Temple of Atal'Hakkar", "The Temple of Atal'Hakkar", "The Essence of Eranikus",
               "Jammal'an the Prophet", "Haze of Evil", "The Atal'ai Exile", "Zapper Fuel", "Secret of the Circle",
               "The God Hakkar", "Pool of Tears"],
}

MAX_FOLLOW = 4      # suites de quête gardées après une quête de donjon
EQUIP_QUALITY = 2   # butin : vert et mieux


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

# ---------------------------------------------------------------------------
# forever-db
# ---------------------------------------------------------------------------

quests = {q["id"]: q for q in read_jsonl("quest")}
starts, ends, prereqs, rewards, objectives = {}, {}, {}, {}, {}
for row in read_jsonl("quest_start"):
    starts.setdefault(row["quest"], []).append(row)
for row in read_jsonl("quest_end"):
    ends.setdefault(row["quest"], []).append(row)
for row in read_jsonl("quest_prereq"):
    prereqs.setdefault(row["quest"], []).append(row)
for row in read_jsonl("quest_reward"):
    rewards.setdefault(row["quest"], []).append(row)
for row in read_jsonl("quest_objective"):
    objectives.setdefault(row["quest"], []).append(row)
npcs = {n["id"]: n for n in read_jsonl("npc")}
objects = {o["id"]: o for o in read_jsonl("object")}
items = {i["id"]: i for i in read_jsonl("item")}
drops_by_item = {}
other_source = set()     # objets qu'on obtient aussi autrement que sur un PNJ
for row in read_jsonl("item_source"):
    if row["kind"] == "npc":
        drops_by_item.setdefault(row["item"], set()).add(row["id"])
    else:
        other_source.add(row["item"])
spawns = {}
for row in read_jsonl("spawn"):
    key = (row["kind"], row["id"])
    if key not in spawns:
        spawns[key] = row
ui_maps = read_jsonl("ui_map")

# Suites : quête -> quêtes qui l'attendent.
follow_ups = {}
for quest, rows in prereqs.items():
    for row in rows:
        follow_ups.setdefault(row["pre"], set()).add(quest)


def map_point(kind, ident):
    """Point d'un PNJ ou d'un objet : carte du client la plus petite qui le contient, x, y (%)."""
    spawn = spawns.get((kind, ident))
    if not spawn:
        return None
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


# ---------------------------------------------------------------------------
# Polestar_ItemDB
# ---------------------------------------------------------------------------

def lua_entries(text, start, stop=None):
    block = text[start:stop]
    return {int(k): v for k, v in re.findall(r'\[(\d+)\]="((?:[^"\\]|\\.)*)"', block)}


forever = read(os.path.join(ITEMDB, "Forever.lua"))
item_stats = lua_entries(read(os.path.join(ITEMDB, "Items.lua")), 0)
overlay_end = forever.index("DB.RegisterLeveling")
item_stats.update(lua_entries(forever, 0, overlay_end))


def section(name):
    start = forever.index("\n" + name + " = {", overlay_end)
    stop = forever.index("\n}", start)
    return lua_entries(forever, start, stop)


flb_sources = section("src")
flb_quests = section("quests")
flb_npcs = section("npcs")

dungeon_by_area = {d[1]: d[0] for d in DUNGEONS}

# Butin des boss : [donjon][pnj] = [(objet, taux en pour mille)].
loot = {}
for item, text in flb_sources.items():
    for source in text.split("|"):
        m = re.match(r"^d(\d+)x(\d+)z(\d+)$", source)
        if not m:
            continue
        npc, chance, zone = int(m.group(1)), int(m.group(2)), int(m.group(3))
        key = dungeon_by_area.get(zone) or LOOT_ZONES.get(zone)
        if key and npc:
            loot.setdefault(key, {}).setdefault(npc, []).append((item, chance))
boss_dungeon = {npc: key for key, bosses in loot.items() for npc in bosses}

# ---------------------------------------------------------------------------
# Quêtes de chaque donjon
# ---------------------------------------------------------------------------

by_title = {}
for q in quests.values():
    by_title.setdefault(q.get("title"), []).append(q["id"])

dungeon_quests = {d[0]: set() for d in DUNGEONS}
for q in quests.values():
    key = dungeon_by_area.get(q.get("zone_area"))
    if key:
        dungeon_quests[key].add(q["id"])
for q in quests.values():
    for obj in objectives.get(q["id"], []):
        targets = set()
        if obj["kind"] == "kill":
            targets.add(obj["target"])
        elif obj["kind"] == "item" and (items.get(obj["target"]) or {}).get("quest_item"):
            # Objet de quête que seuls des boss d'un même donjon laissent tomber.
            droppers = drops_by_item.get(obj["target"], set())
            keys = {boss_dungeon.get(npc) for npc in droppers}
            if droppers and len(keys) == 1 and None not in keys:
                targets |= droppers
        for npc in targets:
            if npc in boss_dungeon:
                dungeon_quests[boss_dungeon[npc]].add(q["id"])
missing_titles = []
for key, titles in BY_TITLE.items():
    for title in titles:
        ids = by_title.get(title)
        if not ids:
            missing_titles.append(title)
        for ident in ids or []:
            dungeon_quests[key].add(ident)
# Une quête de suite (ou un prérequis) d'une quête de donjon, elle-même marquée comme
# telle par ForeverLevelingBiS, rejoint le même donjon.
flb_dungeon = {qid for qid, text in flb_quests.items() if text.split("|")[0].split()[6:7] == ["1"]}
for key in dungeon_quests:
    for qid in list(dungeon_quests[key]):
        for other in follow_ups.get(qid, set()) | {p["pre"] for p in prereqs.get(qid, [])}:
            if other in flb_dungeon:
                dungeon_quests[key].add(other)

# Quêtes à décrire : celles des donjons, leurs prérequis (toute la chaîne) et leurs suites.
described = set()


def add_chain(qid):
    if qid in described or qid not in quests:
        return
    described.add(qid)
    for row in prereqs.get(qid, []):
        add_chain(row["pre"])


for ids in dungeon_quests.values():
    for qid in ids:
        add_chain(qid)
        frontier = {qid}
        for _ in range(MAX_FOLLOW):
            frontier = {f for q in frontier for f in follow_ups.get(q, set()) if f in quests}
            for f in frontier:
                add_chain(f)

# ---------------------------------------------------------------------------
# Objets : butin, récompenses, provenance des objets de leveling
# ---------------------------------------------------------------------------

def equippable(item):
    text = item_stats.get(item)
    if not text:
        return False
    fields = text.split()
    return int(fields[0]) > 0 and int(fields[3]) >= EQUIP_QUALITY


kept_items = set(flb_sources)
for bosses in loot.values():
    for drops in bosses.values():
        kept_items |= {item for item, _ in drops}
for qid in described:
    for row in rewards.get(qid, []):
        if row["kind"] in ("item", "choice"):
            kept_items.add(row["id"])
kept_items = {i for i in kept_items if i in item_stats}

# ---------------------------------------------------------------------------
# Écriture
# ---------------------------------------------------------------------------

def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def point_of(row):
    kind, ident = row["kind"], row["id"]
    entry = ["k = " + lua_string(kind[0]), "id = %d" % ident]
    name = None
    if kind == "npc" and ident in npcs:
        name = npcs[ident].get("name")
    elif kind == "object" and ident in objects:
        name = objects[ident].get("name")
    elif kind == "item" and ident in items:
        name = items[ident].get("name")
    if name:
        entry.append("name = " + lua_string(name))
    point = map_point(kind, ident) if kind in ("npc", "object") else None
    if point:
        entry.append("map = %d, x = %s, y = %s" % point)
    return "{ " + ", ".join(entry) + " }"


def quest_line(qid):
    q = quests[qid]
    parts = ["t = " + lua_string(q.get("title") or "#%d" % qid), "l = %d" % q.get("level", 0),
             "m = %d" % q.get("min_level", 0)]
    if q.get("side"):
        parts.append("s = %d" % q["side"])
    if q.get("races"):
        parts.append("r = %d" % q["races"])
    if q.get("classes"):
        parts.append("c = %d" % q["classes"])
    if q.get("zone_area"):
        parts.append("z = %d" % q["zone_area"])
    if starts.get(qid):
        parts.append("st = " + point_of(starts[qid][0]))
    if ends.get(qid):
        parts.append("en = " + point_of(ends[qid][0]))
    groups = {}
    for row in sorted(prereqs.get(qid, []), key=lambda r: r["pre"]):
        if row["pre"] not in quests:
            continue
        name = "bc" if row.get("breadcrumb") else ("all" if row["mode"] == "all" else "any")
        groups.setdefault(name, []).append(str(row["pre"]))
    for name in ("all", "any", "bc"):
        if groups.get(name):
            parts.append("%s = { %s }" % (name, ", ".join(groups[name])))
    choices = [str(r["id"]) for r in rewards.get(qid, []) if r["kind"] == "choice"]
    given = [str(r["id"]) for r in rewards.get(qid, []) if r["kind"] == "item"]
    if choices:
        parts.append("ch = { %s }" % ", ".join(choices))
    if given:
        parts.append("it = { %s }" % ", ".join(given))
    return "\t[%d] = { %s }," % (qid, ", ".join(parts))


def source_text(item):
    """Provenance d'un objet de leveling, réduite aux formes connues."""
    keep = []
    for source in flb_sources.get(item, "").split("|"):
        if re.match(r"^q\d+$", source) or re.match(r"^d\d+x\d+z\d+$", source) or re.match(r"^c\d+p\d+s\d+$", source):
            keep.append(source)
    return "|".join(keep)


commit = lock.get("commit", "?")[:12]
out = [
    "-- Généré par Tools/import/dungeons.py depuis Polestar %s (%s, %s). Ne pas modifier :"
    % (lock.get("version", "?"), commit, lock.get("date", "?")),
    "-- relancer Tools\\import\\run.ps1. Quêtes, PNJ et positions : forever-db de Polestar (GPL-3.0,",
    "-- ForeverDB-NOTICE.md). Butin des boss et provenance des objets : ForeverLevelingBiS (MIT),",
    "-- caractéristiques des objets : tables du client via Polestar_ItemDB (ItemDB-LICENSE-DATA.txt).",
    "-- Format : docs/DATA_FORMAT.md, « Donjons ».",
    "",
    "local DB = NextStep.DB",
    "",
    "DB.dungeons = {",
]
for key, area, instance, low, high, side, entrance, is_forever in DUNGEONS:
    parts = ["key = " + lua_string(key), "area = %d" % area, "min = %d" % low, "max = %d" % high,
             "zone = %d" % entrance]
    if instance:
        parts.append("instance = %d" % instance)
    if side:
        parts.append("side = " + lua_string(side))
    if is_forever:
        parts.append("forever = true")
    qids = sorted(dungeon_quests[key], key=lambda i: (quests[i].get("level", 0), i))
    parts.append("quests = { %s }" % ", ".join(str(i) for i in qids))
    bosses = []
    for npc, drops in sorted(loot.get(key, {}).items()):
        drop_text = ", ".join("{ %d, %d }" % (item, chance)
                              for item, chance in sorted(drops, key=lambda d: (-d[1], d[0])) if equippable(item))
        name = flb_npcs.get(npc) or (npcs.get(npc) or {}).get("name") or "#%d" % npc
        bosses.append("\t\t\t{ npc = %d, name = %s, loot = { %s } }," % (npc, lua_string(name), drop_text))
    if bosses:
        parts.append("bosses = {\n" + "\n".join(bosses) + "\n\t\t}")
    out.append("\t{ " + ", ".join(parts) + " },")
out.append("}")
out.append("")
out.append("-- [quête] = { t titre, l niveau, m niveau minimal, s faction (1 A, 2 H), r races, c classes,")
out.append("--   z zone, st donneur, en destinataire ({ k n/o/i, id, name, map, x, y }), all / any / bc")
out.append("--   prérequis (tous, l'un d'eux, quête d'introduction), ch choix, it objets donnés }")
out.append("DB.dungeonQuests = {")
for qid in sorted(described):
    out.append(quest_line(qid))
out.append("}")
out.append("")
out.append("-- Caractéristiques des objets retenus (format de Polestar_ItemDB : emplacement, niveau")
out.append("-- d'objet, niveau requis, qualité, classe, sous-classe, puis stats).")
out.append("DB.itemStats = {")
for item in sorted(kept_items):
    out.append("\t[%d] = %s," % (item, lua_string(item_stats[item])))
out.append("}")
out.append("")
out.append("-- Provenance des objets de leveling : q<quête>, d<PNJ>x<taux pour mille>z<zone>,")
out.append("-- c<sort>p<métier>s<compétence>, séparés par « | ».")
out.append("DB.itemSources = {")
for item in sorted(flb_sources):
    text = source_text(item)
    if text and item in kept_items:
        out.append("\t[%d] = %s," % (item, lua_string(text)))
out.append("}")
out.append("")
out.append("-- Quêtes citées par la provenance : [quête] = { titre, niveau, faction (1 A, 2 H, 3 les deux), zone }.")
out.append("DB.itemQuests = {")
for qid in sorted(flb_quests):
    head, _, _, name = flb_quests[qid].split("|")
    fields = head.split()
    out.append("\t[%d] = { %s, %s, %s, %s }," % (qid, lua_string(name), fields[0], fields[2], fields[3]))
out.append("}")
out.append("")
out.append("-- Noms anglais des zones citées (repli quand le client ne les donne pas).")
out.append("DB.itemZones = {")
for area, name in sorted(section("zones").items()):
    out.append("\t[%d] = %s," % (area, lua_string(name)))
out.append("}")

# ---------------------------------------------------------------------------
# Quêtes élites ou de groupe (toutes les quêtes) : type de la quête, sinon rang des
# monstres visés (tuer, ou objet que seuls des élites laissent tomber).
# ---------------------------------------------------------------------------

QUEST_TYPES = {1: "g", 81: "d", 62: "r"}
ELITE_RANKS = {1, 2, 3}


def elite_npc(ident):
    return (npcs.get(ident) or {}).get("rank") in ELITE_RANKS


groups = {}
for q in quests.values():
    kind = QUEST_TYPES.get(q.get("type"))
    if not kind:
        for obj in objectives.get(q["id"], []):
            if obj["kind"] == "kill" and elite_npc(obj["target"]):
                kind = "e"
            elif obj["kind"] == "item" and obj["target"] not in other_source:
                droppers = drops_by_item.get(obj["target"], set())
                if droppers and all(elite_npc(n) for n in droppers):
                    kind = "e"
    if kind:
        groups[q["id"]] = kind

group_lines = [
    "-- Généré par Tools/import/dungeons.py depuis forever-db de Polestar %s (%s). Ne pas modifier."
    % (lock.get("version", "?"), commit),
    "-- Quêtes élites ou de groupe : e élite (monstres visés élites, rares élites ou boss),",
    "-- g groupe, d donjon, r raid (type de la quête). GPL-3.0 : ForeverDB-NOTICE.md.",
    "",
    "NextStep.DB.questGroups = {",
]
for qid in sorted(groups):
    group_lines.append('\t[%d] = "%s",' % (qid, groups[qid]))
group_lines.append("}")
with open(OUT_DIR + "QuestGroups.lua", "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(group_lines) + "\n")
print("quêtes élites ou de groupe : %d" % len(groups))

# ---------------------------------------------------------------------------
# Mode conseil (phase 10) : toutes les quêtes qu'on prend hors instance, en chaînes
# compactes, et le nom anglais de leurs donneurs.
#   "<niveau> <niveau min> <faction> <races> <classes> <zone> <carte> <x> <y>|<tous>|<l'un>|<titre>|<k> <donneur>"
# ---------------------------------------------------------------------------

advice_lines = []
givers = {}
for qid in sorted(quests):
    q = quests[qid]
    if q.get("repeatable") or not q.get("level") or q["level"] > 60 or not starts.get(qid):
        continue
    start = starts[qid][0]
    if start["kind"] not in ("npc", "object"):
        continue
    point = map_point(start["kind"], start["id"])
    if not point:
        continue
    pre_all = [str(r["pre"]) for r in prereqs.get(qid, []) if r["mode"] == "all" and not r.get("breadcrumb")
               and r["pre"] in quests]
    pre_any = [str(r["pre"]) for r in prereqs.get(qid, []) if r["mode"] == "any" and not r.get("breadcrumb")
               and r["pre"] in quests]
    head = "%d %d %d %d %d %d %d %s %s" % (q["level"], q.get("min_level", 0), q.get("side", 0), q.get("races", 0),
                                         q.get("classes", 0), q.get("zone_area", 0), point[0], point[1], point[2])
    title = (q.get("title") or "").replace("|", "/")
    advice_lines.append('\t[%d] = %s,' % (qid, lua_string("%s|%s|%s|%s|%s %d" % (
        head, ",".join(pre_all), ",".join(pre_any), title, start["kind"][0], start["id"]))))
    if start["kind"] == "npc":
        givers[start["id"]] = (npcs.get(start["id"]) or {}).get("name")
    else:
        givers[-start["id"]] = (objects.get(start["id"]) or {}).get("name")

advice_out = [
    "-- Généré par Tools/import/dungeons.py depuis forever-db de Polestar %s (%s). Ne pas modifier."
    % (lock.get("version", "?"), commit),
    "-- Mode conseil : quêtes prises hors instance. GPL-3.0 : ForeverDB-NOTICE.md. Format : docs/DATA_FORMAT.md.",
    "",
    "local DB = NextStep.DB",
    "",
    "DB.adviceQuests = {",
] + advice_lines + ["}", "", "-- Donneurs : [PNJ] = nom anglais ; [-objet] = nom de l'objet.", "DB.adviceGivers = {"]
for ident in sorted(givers):
    if givers[ident]:
        advice_out.append("\t[%d] = %s," % (ident, lua_string(givers[ident])))
advice_out.append("}")
with open(OUT_DIR + "AdviceQuests.lua", "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(advice_out) + "\n")
print("mode conseil : %d quêtes, %d donneurs" % (len(advice_lines), len(givers)))

with open(OUT_DIR + "Dungeons.lua", "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(out) + "\n")
with open(OUT_DIR + "ItemDB-LICENSE-DATA.txt", "w", encoding="utf-8", newline="\n") as f:
    f.write(read(os.path.join(ITEMDB, "LICENSE-DATA.txt")))
with open(OUT_DIR + "ForeverDB-NOTICE.md", "w", encoding="utf-8", newline="\n") as f:
    f.write(read(os.path.join(SOURCE, "forever-db", "NOTICE.md")))

total = sum(len(v) for v in dungeon_quests.values())
print("dungeons: %d donjons, %d quêtes de donjon, %d quêtes décrites, %d objets, %d boss"
      % (len(DUNGEONS), total, len(described), len(kept_items), len(boss_dungeon)))
for key, ids in dungeon_quests.items():
    print("  %-12s %3d quêtes, %2d boss" % (key, len(ids), len(loot.get(key, {}))))
if missing_titles:
    print("titres introuvables : " + ", ".join(missing_titles))
