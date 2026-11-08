"""Génère la texture de la flèche du guide (Modules/Guide/Arrow.lua).

    python Tools/arrow/textures.py

- Media/Arrow.tga (64 x 64) : pointe de flèche tournée vers le haut, blanche avec un
  léger dégradé et un contour sombre ; teintée en jeu (vert devant, doré, rouge derrière)
  et tournée vers la cible. Bords adoucis par suréchantillonnage (4 x 4).

TGA 32 bits non compressé, origine en haut à gauche, sans dépendance.
"""

import math
import os
import struct

MEDIA = os.path.join(os.path.dirname(__file__), "..", "..", "addon", "NextStep", "Media")
SIZE = 64
SAMPLES = 4
OUTLINE = 3.0 / SIZE   # épaisseur du contour, en fraction de la texture

# Contour de la flèche (x, y de 0 à 1, y vers le bas), sens horaire.
SHAPE = [
    (0.50, 0.05),   # pointe
    (0.90, 0.60),   # aile droite
    (0.63, 0.52),   # creux droit
    (0.63, 0.95),   # queue droite
    (0.37, 0.95),   # queue gauche
    (0.37, 0.52),   # creux gauche
    (0.10, 0.60),   # aile gauche
]


def write_tga(path, size, pixel):
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 0x28)
    data = bytearray()
    for y in range(size):
        for x in range(size):
            r, g, b, a = pixel(x, y)
            data += bytes((b, g, r, a))
    with open(path, "wb") as file:
        file.write(header + bytes(data))


def inside(px, py):
    """Point dans le polygone (règle pair-impair)."""
    result = False
    count = len(SHAPE)
    for i in range(count):
        x1, y1 = SHAPE[i]
        x2, y2 = SHAPE[(i + 1) % count]
        if (y1 > py) != (y2 > py):
            cross = x1 + (py - y1) * (x2 - x1) / (y2 - y1)
            if px < cross:
                result = not result
    return result


def edge_distance(px, py):
    best = math.inf
    count = len(SHAPE)
    for i in range(count):
        x1, y1 = SHAPE[i]
        x2, y2 = SHAPE[(i + 1) % count]
        dx, dy = x2 - x1, y2 - y1
        t = max(0.0, min(1.0, ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy)))
        best = min(best, math.hypot(px - (x1 + t * dx), py - (y1 + t * dy)))
    return best


def arrow(x, y):
    coverage, shade = 0.0, 0.0
    for sy in range(SAMPLES):
        for sx in range(SAMPLES):
            px = (x + (sx + 0.5) / SAMPLES) / SIZE
            py = (y + (sy + 0.5) / SAMPLES) / SIZE
            if inside(px, py):
                coverage += 1
                if edge_distance(px, py) <= OUTLINE:
                    shade += 0.12                     # contour sombre
                else:
                    shade += 1.0 - 0.25 * py          # dégradé : plus clair vers la pointe
    total = SAMPLES * SAMPLES
    if coverage == 0:
        return 0, 0, 0, 0
    value = int(round(255 * min(1.0, shade / coverage)))
    return value, value, value, int(round(255 * coverage / total))


def main():
    write_tga(os.path.join(MEDIA, "Arrow.tga"), SIZE, arrow)


if __name__ == "__main__":
    main()
