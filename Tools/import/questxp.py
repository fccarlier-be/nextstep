"""Import de l'expérience des quêtes, pour la prévision de niveau du guide.

    python -I Tools/import/questxp.py <checkout de Polestar> [polestar.lock]

À lancer depuis la racine du dépôt (Tools\\import\\run.ps1 le fait). Source :
forever-db/data/quest.jsonl (GPL-3.0) : niveau de chaque quête et expérience de son
rendu à ce niveau.

Produit addon/NextStep/Data/Imported/Polestar/QuestXP.lua (format : docs/DATA_FORMAT.md,
« Expérience des quêtes »).
"""

import json
import os
import re
import statistics
import sys

SOURCE = sys.argv[1]
LOCK = sys.argv[2] if len(sys.argv) > 2 else "Tools/import/polestar.lock"
OUT = "addon/NextStep/Data/Imported/Polestar/QuestXP.lua"
DB_DIR = os.path.join(SOURCE, "forever-db", "data")


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


lock = {}
for line in read(LOCK).splitlines():
    m = re.match(r"^\s*([^#=]+?)\s*=\s*(.+?)\s*$", line)
    if m:
        lock[m.group(1)] = m.group(2)

quests = {}
byLevel = {}
with open(os.path.join(DB_DIR, "quest.jsonl"), encoding="utf-8") as f:
    for line in f:
        if not line.strip():
            continue
        row = json.loads(line)
        level, xp = row.get("level"), row.get("xp") or 0
        if not level or level < 1 or level > 99:
            continue
        quests[row["id"]] = xp * 100 + level
        if xp:
            byLevel.setdefault(level, []).append(xp)

commit = lock.get("commit", "?")[:12]
out = [
    "-- Généré par Tools/import/questxp.py depuis forever-db de Polestar %s (%s). Ne pas modifier."
    % (lock.get("version", "?"), commit),
    "-- Expérience du rendu de chaque quête, à son niveau : [quête] = xp * 100 + niveau",
    "-- (xp 0 : inconnue, la médiane du niveau en tient lieu). GPL-3.0 : ForeverDB-NOTICE.md.",
    "",
    "NextStep.DB.questXP = {",
]
for quest in sorted(quests):
    out.append("\t[%d] = %d," % (quest, quests[quest]))
out.append("}")
out.append("")
out.append("-- Médiane de l'expérience des quêtes de chaque niveau : [niveau] = xp.")
out.append("NextStep.DB.questXPByLevel = {")
for level in sorted(byLevel):
    out.append("\t[%d] = %d," % (level, round(statistics.median(byLevel[level]))))
out.append("}")
with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(out) + "\n")
known = sum(1 for v in quests.values() if v >= 100)
print("%d quêtes, %d avec leur expérience" % (len(quests), known))
