"""Génère la texture des repères du guide (Modules/Guide/Pins.lua).

    python Tools/pins/textures.py

- Media/Pin.tga (32 x 32) : disque blanc adouci au bord sombre, teinté en jeu
  (cible, lieu, zone de mobs).

TGA 32 bits non compressé, origine en haut à gauche, sans dépendance.
"""

import math
import os
import struct

MEDIA = os.path.join(os.path.dirname(__file__), "..", "..", "addon", "NextStep", "Media")


def write_tga(path, size, pixel):
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 0x28)
    data = bytearray()
    for y in range(size):
        for x in range(size):
            r, g, b, a = pixel(x, y)
            data += bytes((b, g, r, a))
    with open(path, "wb") as file:
        file.write(header + bytes(data))


def pin(x, y, size=32):
    center = (size - 1) / 2
    distance = math.hypot(x - center, y - center)
    outer = size / 2 - 1
    inner = outer - 3
    alpha = min(1.0, max(0.0, outer - distance + 0.5))   # bord adouci
    if distance <= inner - 0.5:
        shade = 1.0                                       # disque, teinté en jeu
    elif distance >= inner + 0.5:
        shade = 0.1                                       # contour sombre
    else:
        shade = 0.1 + 0.9 * (inner + 0.5 - distance)
    value = int(round(255 * shade))
    return value, value, value, int(round(255 * alpha))


def main():
    write_tga(os.path.join(MEDIA, "Pin.tga"), 32, pin)


if __name__ == "__main__":
    main()
