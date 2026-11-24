"""Génère les textures de l'habillage des fenêtres (Core/Style.lua).

    python Tools/theme/textures.py

Écrit dans addon/NextStep/Media/Theme/ (TGA 32 bits, tailles en puissances de deux) :

- Background.tga (256 x 256) : pierre sombre, raccordable dans les deux sens (bruit
  périodique), posée en mosaïque sous les fenêtres.
- Edge.tga (64 x 16) : bordure horizontale dorée biseautée (bord extérieur en haut),
  raccordable horizontalement ; tournée par SetTexCoord pour les quatre côtés.
- Corner.tga (32 x 32) : coin haut gauche orné (équerre dorée et rivet en losange) ;
  retourné par SetTexCoord pour les trois autres coins.
- Close.tga (32 x 32) : bouton de fermeture rond, rouge, cerclé d'or, croix claire.
- Glow.tga (64 x 64) : halo doré radial (survol des cartes et des boutons ronds).
- Ring.tga (64 x 64) : anneau doré des onglets ronds, intérieur transparent.

Dessin en Python pur (Pillow pour l'écriture et le lissage), sans dépendance au jeu.
"""

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "addon", "NextStep", "Media", "Theme")

GOLD_LIGHT = (255, 226, 140)
GOLD = (214, 170, 72)
GOLD_DARK = (110, 78, 28)
OUTLINE = (12, 9, 6)


def save(image, name):
    os.makedirs(OUT, exist_ok=True)
    image.save(os.path.join(OUT, name), format="TGA", compression=None)
    print("écrit", name, image.size)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


# --- Fond : bruit de valeur périodique, plusieurs octaves, teinte pierre sombre. ---
def periodic_noise(size, cells, seed):
    rnd = random.Random(seed)
    grid = [[rnd.random() for _ in range(cells)] for _ in range(cells)]
    out = [[0.0] * size for _ in range(size)]
    for y in range(size):
        gy = y * cells / size
        y0 = int(gy) % cells
        y1 = (y0 + 1) % cells
        ty = gy - int(gy)
        ty = ty * ty * (3 - 2 * ty)
        for x in range(size):
            gx = x * cells / size
            x0 = int(gx) % cells
            x1 = (x0 + 1) % cells
            tx = gx - int(gx)
            tx = tx * tx * (3 - 2 * tx)
            a = grid[y0][x0] + (grid[y0][x1] - grid[y0][x0]) * tx
            b = grid[y1][x0] + (grid[y1][x1] - grid[y1][x0]) * tx
            out[y][x] = a + (b - a) * ty
    return out


def background():
    size = 256
    octaves = [(4, 0.5), (8, 0.25), (16, 0.15), (64, 0.10)]
    layers = [periodic_noise(size, cells, 17 + i) for i, (cells, _) in enumerate(octaves)]
    veins = periodic_noise(size, 6, 99)
    image = Image.new("RGBA", (size, size))
    pixels = image.load()
    dark = (14, 13, 16)
    light = (38, 34, 33)
    for y in range(size):
        for x in range(size):
            value = sum(layers[i][y][x] * w for i, (_, w) in enumerate(octaves))
            # Fines veines claires là où le bruit lent passe près de 0,5.
            vein = max(0.0, 1 - abs(veins[y][x] - 0.5) * 22)
            t = min(1.0, max(0.0, (value - 0.25) * 1.3 + vein * 0.12))
            r, g, b = lerp(dark, light, t)
            pixels[x, y] = (r, g, b, 255)
    save(image, "Background.tga")


# --- Bordure : profil vertical (extérieur en haut), répété en largeur. ---
EDGE_PROFILE = [
    OUTLINE, OUTLINE,
    GOLD_DARK, GOLD_LIGHT, GOLD_LIGHT, GOLD, GOLD, GOLD_DARK,
    OUTLINE,
    (60, 44, 20), (36, 27, 14),
]


def edge():
    width, height = 64, 16
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    pixels = image.load()
    for y, color in enumerate(EDGE_PROFILE):
        alpha = 255 if y < 9 else 150
        for x in range(width):
            # Grain léger le long du métal, périodique sur la largeur.
            shade = 1 + 0.06 * math.sin(x * 2 * math.pi / 16) * (1 if 2 <= y <= 7 else 0)
            pixels[x, y] = tuple(min(255, int(c * shade)) for c in color) + (alpha,)
    # Ombre intérieure qui s'efface.
    for y in range(len(EDGE_PROFILE), height):
        alpha = int(110 * (1 - (y - len(EDGE_PROFILE) + 1) / (height - len(EDGE_PROFILE) + 1)))
        for x in range(width):
            pixels[x, y] = (0, 0, 0, alpha)
    save(image, "Edge.tga")


def corner():
    scale = 4
    size = 32
    big = Image.new("RGBA", (size * scale, size * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(big)

    def s(v):
        return int(v * scale)

    # Équerre : deux barres épaisses dorées le long des bords haut et gauche.
    for inset, color in ((0, OUTLINE), (1, GOLD_DARK), (2, GOLD_LIGHT), (4, GOLD), (6, GOLD_DARK)):
        draw.rectangle([s(inset), s(inset), s(size - 1), s(9 - inset / 2)], fill=color)
        draw.rectangle([s(inset), s(inset), s(9 - inset / 2), s(size - 1)], fill=color)
    # Rivet en losange, au coin.
    cx, cy, r = 10.5, 10.5, 7.5
    draw.polygon([(s(cx), s(cy - r)), (s(cx + r), s(cy)), (s(cx), s(cy + r)), (s(cx - r), s(cy))], fill=OUTLINE)
    r2 = r - 1.5
    draw.polygon([(s(cx), s(cy - r2)), (s(cx + r2), s(cy)), (s(cx), s(cy + r2)), (s(cx - r2), s(cy))], fill=GOLD)
    draw.polygon([(s(cx), s(cy - r2)), (s(cx + r2), s(cy)), (s(cx), s(cy)), (s(cx - r2), s(cy))], fill=GOLD_LIGHT)
    r3 = 2.2
    draw.polygon([(s(cx), s(cy - r3)), (s(cx + r3), s(cy)), (s(cx), s(cy + r3)), (s(cx - r3), s(cy))],
                 fill=(150, 30, 20))
    image = big.resize((size, size), Image.LANCZOS)
    save(image, "Corner.tga")


def disc_image(size, painter):
    scale = 4
    big = Image.new("RGBA", (size * scale, size * scale), (0, 0, 0, 0))
    painter(ImageDraw.Draw(big), size * scale)
    return big.resize((size, size), Image.LANCZOS)


def close():
    def paint(draw, n):
        draw.ellipse([0, 0, n - 1, n - 1], fill=OUTLINE)
        draw.ellipse([n * 0.06, n * 0.06, n * 0.94, n * 0.94], fill=GOLD)
        draw.ellipse([n * 0.12, n * 0.12, n * 0.88, n * 0.88], fill=GOLD_DARK)
        draw.ellipse([n * 0.16, n * 0.16, n * 0.84, n * 0.84], fill=(120, 14, 10))
        draw.ellipse([n * 0.2, n * 0.18, n * 0.8, n * 0.62], fill=(190, 40, 26))
        w = n * 0.09
        for (x0, y0, x1, y1) in ((0.34, 0.34, 0.66, 0.66), (0.66, 0.34, 0.34, 0.66)):
            draw.line([(x0 * n, y0 * n), (x1 * n, y1 * n)], fill=(40, 6, 4), width=int(w * 1.6))
            draw.line([(x0 * n, y0 * n), (x1 * n, y1 * n)], fill=(255, 236, 200), width=int(w))
    save(disc_image(32, paint), "Close.tga")


def glow():
    size = 64
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pixels = image.load()
    for y in range(size):
        for x in range(size):
            d = math.hypot(x + 0.5 - size / 2, y + 0.5 - size / 2) / (size / 2)
            alpha = max(0.0, 1 - d) ** 1.8
            pixels[x, y] = (255, 214, 110, int(255 * alpha))
    save(image, "Glow.tga")


def ring():
    def paint(draw, n):
        draw.ellipse([0, 0, n - 1, n - 1], fill=OUTLINE)
        draw.ellipse([n * 0.04, n * 0.04, n * 0.96, n * 0.96], fill=GOLD_DARK)
        draw.ellipse([n * 0.06, n * 0.05, n * 0.94, n * 0.9], fill=GOLD_LIGHT)
        draw.ellipse([n * 0.08, n * 0.08, n * 0.92, n * 0.92], fill=GOLD)
        draw.ellipse([n * 0.13, n * 0.13, n * 0.87, n * 0.87], fill=OUTLINE)
        draw.ellipse([n * 0.15, n * 0.15, n * 0.85, n * 0.85], fill=(0, 0, 0, 0))
    save(disc_image(64, paint), "Ring.tga")


if __name__ == "__main__":
    background()
    edge()
    corner()
    close()
    glow()
    ring()
