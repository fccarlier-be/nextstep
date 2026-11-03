"""Génère les textures du radar de récolte (Modules/UI/Radar.lua).

    python Tools/radar/textures.py

- Media/RadarRing.tga (256 x 256) : anneau blanc adouci et deux cercles discrets,
  teintés en jeu ;
- Media/RadarMask.tga (64 x 64) : masque entièrement transparent, qui cache le
  terrain de la minimap et ne laisse que les points de suivi.

TGA 32 bits non compressés, origine en haut à gauche, sans dépendance.
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


def band(distance, radius, width):
    """Opacité (0 à 1) d'un trait circulaire de rayon radius et de demi-largeur width."""
    return max(0.0, 1.0 - abs(distance - radius) / width)


def ring(x, y, size=256):
    center = (size - 1) / 2
    distance = math.hypot(x - center, y - center)
    outer = size / 2 - 3
    alpha = max(
        band(distance, outer, 2.5),                 # bord
        0.25 * band(distance, outer * 2 / 3, 1.5),  # cercles intérieurs, discrets
        0.25 * band(distance, outer / 3, 1.5),
    )
    return 255, 255, 255, int(round(255 * min(1.0, alpha)))


def main():
    write_tga(os.path.join(MEDIA, "RadarRing.tga"), 256, ring)
    write_tga(os.path.join(MEDIA, "RadarMask.tga"), 64, lambda x, y: (0, 0, 0, 0))


if __name__ == "__main__":
    main()
