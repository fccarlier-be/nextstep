"""Assemble les traductions françaises des textes de guide que Polestar ne traduit pas.

    python Tools/translate/build.py

Entrées, dans Tools/translate/ :
- <lot>.texts.txt : les textes anglais des guides, un par ligne (retours à la ligne
  écrits \\n : une note peut avoir plusieurs paragraphes) ;
- <lot>.en.txt : leurs paragraphes, un par ligne ;
- <lot>.fr.txt : la traduction de chaque paragraphe, à la même ligne.
Un texte est traduit quand tous ses paragraphes le sont.

Chaque traduction doit garder exactement les mêmes noms ({npc:123}, {zone:45}...) que
l'anglais, sinon le script s'arrête. Sortie : addon/NextStep/Locales/GuideNotes_frFR.lua,
traductions communes à tous les guides (DB:AddTexts), utilisées après celles de
Polestar. Vouvoiement, comme Polestar.
"""

import collections
import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
OUT = os.path.join(ROOT, "addon", "NextStep", "Locales", "GuideNotes_frFR.lua")
TOKEN = re.compile(r"\{[a-z]+:\d+\}")
NEWLINE = "\n"
ESCAPED_NEWLINE = "\\n"   # deux caractères : barre oblique inverse et n


def read_lines(path):
    with open(path, encoding="utf-8") as handle:
        return [line.rstrip("\r\n") for line in handle]


def lua_string(text):
    text = text.replace(ESCAPED_NEWLINE, NEWLINE)
    escaped = text.replace("\\", "\\\\").replace('"', '\\"').replace(NEWLINE, ESCAPED_NEWLINE)
    return '"' + escaped + '"'


def main():
    paragraphs = {}
    errors = []
    texts = []
    for en_path in sorted(glob.glob(os.path.join(HERE, "*.en.txt"))):
        batch = os.path.basename(en_path)[:-len(".en.txt")]
        fr_path = os.path.join(HERE, batch + ".fr.txt")
        english = read_lines(en_path)
        french = read_lines(fr_path) if os.path.exists(fr_path) else []
        if len(french) > len(english):
            errors.append("%s : %d traductions pour %d paragraphes" % (batch, len(french), len(english)))
            continue
        for index, (en, fr) in enumerate(zip(english, french), start=1):
            if not fr.strip():
                continue
            if collections.Counter(TOKEN.findall(en)) != collections.Counter(TOKEN.findall(fr)):
                errors.append("%s ligne %d : noms différents" % (batch, index) + NEWLINE + "  " + en
                              + NEWLINE + "  " + fr)
                continue
            paragraphs[en] = fr
        texts_path = os.path.join(HERE, batch + ".texts.txt")
        texts += read_lines(texts_path) if os.path.exists(texts_path) else english
        print("%s : %d / %d paragraphes traduits" % (batch, min(len(french), len(english)), len(english)))
    if errors:
        print(NEWLINE.join(errors), file=sys.stderr)
        sys.exit(1)

    pairs, seen = [], set()
    for text in texts:
        if not text or text in seen:
            continue
        parts = text.split(ESCAPED_NEWLINE)
        if all(part in paragraphs for part in parts):
            seen.add(text)
            pairs.append((text, ESCAPED_NEWLINE.join(paragraphs[part] for part in parts)))

    lines = [
        "-- Généré par Tools/translate/build.py. Ne pas modifier : éditer les fichiers",
        "-- Tools/translate/*.fr.txt puis relancer le script.",
        "-- Traductions françaises, par NextStep, des textes des guides de Polestar que",
        "-- Polestar ne traduit pas (GPL-3.0-only, comme les guides). Utilisées après les",
        "-- traductions de Polestar (DB:Translate).",
        "",
        "local _, ns = ...",
        "",
        'if GetLocale() ~= "frFR" then',
        "    return",
        "end",
        "",
        'ns.DB:AddTexts("frFR", nil, function() return {',
    ]
    for en, fr in pairs:
        lines.append("\t[%s] = %s," % (lua_string(en), lua_string(fr)))
    lines.append("} end)")
    lines.append("")
    with open(OUT, "w", encoding="utf-8", newline=NEWLINE) as handle:
        handle.write(NEWLINE.join(lines))
    total = len(set(t for t in texts if t))
    print("%d textes traduits sur %d, écrits dans %s" % (len(pairs), total, os.path.relpath(OUT, ROOT)))


if __name__ == "__main__":
    main()
