"""Importe le calculateur de chemins à pied de Polestar et ses cartes de marche.

Usage : python -I Tools/import/nav.py <cache Polestar> <polestar.lock>

Polestar_Nav, Polestar_Nav_EK et Polestar_Nav_Kalimdor (GPL-3.0-or-later, partis de
Shortest Path Forever de Cillian Berragan, cartes de navigation de Leffe) deviennent
addon/NextStep_Nav, NextStep_Nav_EK et NextStep_Nav_Kalimdor, chargés à la demande
par NextStep (Modules/Guide/Route.lua).

Seul changement au code : les noms globaux et les noms d'addon, pour que NextStep et
Polestar installés ensemble ne partagent rien :
  PolestarPathData, PolestarNavChokepoints, Polestar_NavCosts, Polestar_NavEngine
  -> NextStepPathData, NextStepNavChokepoints, NextStep_NavCosts, NextStep_NavEngine ;
  "Polestar_Nav_EK" / "Polestar_Nav_Kalimdor" -> "NextStep_Nav_EK" / "NextStep_Nav_Kalimdor" ;
  les deux crochets facultatifs vers le module de danger et les trajets de Polestar
  (Polestar.Nav.danger, Polestar.Nav.travel) lisent NextStep_NavHooks, absent : le
  calculateur fait alors ce qu'il fait sans eux.
Le contenu des cartes garde sa valeur, mais leurs chaînes aux octets de contrôle bruts
sont réécrites avec des échappements (escape_controls : l'empaqueteur les abîmait).
Les fichiers sont traités en octets.
"""

import os
import re
import shutil
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

ADDONS = {
    "Polestar_Nav": "NextStep_Nav",
    "Polestar_Nav_EK": "NextStep_Nav_EK",
    "Polestar_Nav_Kalimdor": "NextStep_Nav_Kalimdor",
}

RENAMES = [
    (b"Polestar and Polestar.Nav and Polestar.Nav.", b"NextStep_NavHooks and NextStep_NavHooks."),
    (b"PolestarPathData", b"NextStepPathData"),
    (b"PolestarNavChokepoints", b"NextStepNavChokepoints"),
    (b"Polestar_NavCosts", b"NextStep_NavCosts"),
    (b"Polestar_NavEngine", b"NextStep_NavEngine"),
    (b'"Polestar_Nav_EK"', b'"NextStep_Nav_EK"'),
    (b'"Polestar_Nav_Kalimdor"', b'"NextStep_Nav_Kalimdor"'),
]

# Après renommage, aucun de ces noms ne doit rester hors commentaire.
LEFTOVER = re.compile(rb"PolestarPathData|PolestarNavChokepoints|Polestar_Nav\w*|Polestar\.Nav")

TOC = {
    "NextStep_Nav": {
        "title": "NextStep - Nav",
        "notes": "NextStep walking routes: the arrow and the route lines follow real paths. "
                 "Polestar's walking router, started from Shortest Path Forever by Cillian Berragan. "
                 "Loaded on demand, do not disable.",
        "notes_fr": "Chemins à pied de NextStep : la flèche et le tracé suivent les vrais chemins. "
                    "Calculateur de Polestar, issu de Shortest Path Forever de Cillian Berragan. "
                    "Chargé à la demande, ne pas désactiver.",
        "deps": "NextStep",
    },
    "NextStep_Nav_EK": {
        "title": "NextStep - Nav (Eastern Kingdoms)",
        "notes": "Walking maps of the Eastern Kingdoms for NextStep, from Leffe's navigation maps "
                 "(via Polestar). Loaded on demand on that continent.",
        "notes_fr": "Cartes de marche des Royaumes de l'Est pour NextStep, tirées des cartes de "
                    "navigation de Leffe (via Polestar). Chargé à la demande sur ce continent.",
        "deps": "NextStep_Nav",
    },
    "NextStep_Nav_Kalimdor": {
        "title": "NextStep - Nav (Kalimdor)",
        "notes": "Walking maps of Kalimdor for NextStep, from Leffe's navigation maps "
                 "(via Polestar). Loaded on demand on that continent.",
        "notes_fr": "Cartes de marche de Kalimdor pour NextStep, tirées des cartes de "
                    "navigation de Leffe (via Polestar). Chargé à la demande sur ce continent.",
        "deps": "NextStep_Nav",
    },
}

NOTICE = """# NextStep - Nav

Ce dossier est produit par `Tools/import/nav.py` à partir de {source} de
[Polestar](https://github.com/fitzforge/polestar) {version} (commit `{commit}`),
GPL-3.0-or-later. Ne pas le modifier à la main : relancer l'import.

Le calculateur de chemins à pied est celui de Polestar, parti de
[Shortest Path Forever](https://github.com/cjber/shortest-path-forever) de
Cillian Berragan (GPL-3.0-or-later) ; les cartes de marche viennent des cartes de
navigation de Leffe. Voir `CREDITS.md` et `LICENSE` (repris sans modification).

Seul changement : les noms globaux et les noms d'addon (`PolestarPathData` devient
`NextStepPathData`, `Polestar_NavEngine` devient `NextStep_NavEngine`, etc.), pour
que NextStep et Polestar installés ensemble ne se gênent pas.
"""


def read_lock(path):
    lock = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"^\s*([^#=]+?)\s*=\s*(.+?)\s*$", line)
            if m:
                lock[m.group(1)] = m.group(2)
    return lock


def toc_files(path):
    files = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                files.append(line)
    return files


def strip_comments(data):
    out = []
    for line in data.split(b"\n"):
        code = line.split(b"--", 1)[0]
        out.append(code)
    return b"\n".join(out)


LONG_OPEN = re.compile(rb"\[(=*)\[")


def needs_escape(byte):
    return byte < 32 or byte == 127


def quote(value):
    """Chaîne Lua entre guillemets de même valeur : octets de contrôle en \\ddd."""
    out = bytearray(b'"')
    for byte in value:
        if byte == 0x5C:
            out += b"\\\\"
        elif byte == 0x22:
            out += b'\\"'
        elif needs_escape(byte):
            out += b"\\%03d" % byte
        else:
            out.append(byte)
    out += b'"'
    return bytes(out)


def escape_controls(data):
    """Réécrit les chaînes qui portent des octets de contrôle bruts.

    Le BigWigs packager retire une partie des octets \\x01 des fichiers .lua et passe les
    fins de ligne en CRLF : une chaîne longue [[...]] aux octets bruts en sort abîmée
    (calculateur sans carte, « offmesh » partout). Chaque chaîne longue qui contient un
    octet de contrôle devient une chaîne entre guillemets de même valeur, aux octets de
    contrôle échappés ; dans une chaîne entre guillemets, seuls les octets de contrôle
    bruts sont échappés. Le reste du fichier (code, commentaires) est copié tel quel.
    """
    out = bytearray()
    i, n = 0, len(data)
    while i < n:
        c = data[i]
        if c == 0x2D and data[i + 1:i + 2] == b"-":   # commentaire
            m = LONG_OPEN.match(data, i + 2)
            if m:
                close = b"]" + m.group(1) + b"]"
                end = data.index(close, m.end()) + len(close)
            else:
                end = data.find(b"\n", i)
                end = n if end < 0 else end
            out += data[i:end]
            i = end
        elif c in (0x22, 0x27):                        # chaîne entre guillemets
            j = i + 1
            piece = bytearray([c])
            while data[j] != c:
                if data[j] == 0x5C:
                    piece += data[j:j + 2]
                    if needs_escape(data[j + 1]) and data[j + 1] not in (0x0A, 0x0D):
                        raise SystemExit("octet de contrôle après une barre oblique inverse")
                    j += 2
                    continue
                if needs_escape(data[j]):
                    if data[j] in (0x0A, 0x0D):
                        raise SystemExit("fin de ligne dans une chaîne entre guillemets")
                    piece += b"\\%03d" % data[j]
                else:
                    piece.append(data[j])
                j += 1
            piece.append(c)
            out += piece
            i = j + 1
        elif c == 0x5B and LONG_OPEN.match(data, i):    # chaîne longue
            m = LONG_OPEN.match(data, i)
            close = b"]" + m.group(1) + b"]"
            end = data.index(close, m.end())
            value = data[m.end():end]
            # Comme Lua : la fin de ligne qui suit l'ouverture n'en fait pas partie,
            # et toute fin de ligne vaut « \n ».
            if value[:2] in (b"\r\n", b"\n\r"):
                value = value[2:]
            elif value[:1] in (b"\n", b"\r"):
                value = value[1:]
            if any(needs_escape(b) for b in value):
                value = re.sub(rb"\r\n|\n\r|\r", b"\n", value)
                out += quote(value)
            else:
                out += data[i:end + len(close)]
            i = end + len(close)
        else:
            out.append(c)
            i += 1
    return bytes(out)


def main():
    cache, lock_path = sys.argv[1], sys.argv[2]
    lock = read_lock(lock_path)
    for source, target in ADDONS.items():
        src = os.path.join(cache, "addon", source)
        dst = os.path.join(ROOT, "addon", target)
        if not os.path.isdir(src):
            raise SystemExit(f"{src} absent : lancer Tools/import/fetch.ps1")
        files = toc_files(os.path.join(src, source + ".toc"))
        if os.path.isdir(dst):
            shutil.rmtree(dst)
        count = 0
        for dirpath, _, names in os.walk(src):
            for name in names:
                if name.endswith(".toc"):
                    continue
                rel = os.path.relpath(os.path.join(dirpath, name), src)
                out = os.path.join(dst, rel)
                os.makedirs(os.path.dirname(out), exist_ok=True)
                with open(os.path.join(dirpath, name), "rb") as f:
                    data = f.read()
                if name.endswith((".lua", ".xml")):
                    for old, new in RENAMES:
                        data = data.replace(old, new)
                if name.endswith(".lua"):
                    data = escape_controls(data)
                    if any(needs_escape(b) and b not in (0x09, 0x0A, 0x0D) for b in data):
                        raise SystemExit(f"{rel} : octet de contrôle restant")
                    left = LEFTOVER.search(strip_comments(data))
                    if left:
                        raise SystemExit(f"{rel} : nom de Polestar restant : {left.group(0)!r}")
                with open(out, "wb") as f:
                    f.write(data)
                count += 1
        meta = TOC[target]
        lines = [
            "## Interface: 16001",
            f"## Title: {meta['title']}",
            f"## Notes: {meta['notes']}",
            f"## Notes-frFR: {meta['notes_fr']}",
            "## Author: fccarlier-be; walking router: Polestar, from Cillian Berragan's Shortest Path Forever; "
            "walking maps: Leffe",
            "## Version: @project-version@",
            "## X-License: GPL-3.0-or-later",
            f"## Dependencies: {meta['deps']}",
            "## LoadOnDemand: 1",
            f"# Écrit par Tools/import/nav.py depuis {source} (Polestar {lock.get('version')}).",
            "",
        ] + files
        with open(os.path.join(dst, target + ".toc"), "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines) + "\n")
        # Licence et crédits de Polestar_Nav, aussi dans les dossiers de cartes.
        for extra in ("LICENSE", "CREDITS.md"):
            if not os.path.exists(os.path.join(dst, extra)):
                shutil.copyfile(os.path.join(cache, "addon", "Polestar_Nav", extra), os.path.join(dst, extra))
        with open(os.path.join(dst, "NOTICE.md"), "w", encoding="utf-8", newline="\n") as f:
            f.write(NOTICE.format(source=source, version=lock.get("version"), commit=lock.get("commit")))
        print(f"{target} : {count} fichiers")


if __name__ == "__main__":
    main()
