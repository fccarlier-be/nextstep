"""Échantillons d'images pour /nsdiag media (addon de diagnostic).

    python Tools/diagnostic/samples.py

Écrit Tools/diagnostic/NextStep_Diagnostic/Media/<nom>.<ext> : la même image
(256 x 64, un morceau d'illustration de zone et son nom écrit dessus) dans plusieurs
formats, pour savoir lesquels le client Forever lit :

- tga_plain.tga       TGA 24 bits non compressé (référence : lu, v0.4.1)
- tga_rle.tga         TGA 24 bits compressé RLE
- blp_pillow.blp      BLP2 en palette écrit par Pillow, sans mipmaps (référence :
                      NON lu, cartes vertes en v0.4.0)
- blp_pal_mips.blp    BLP2 en palette, avec mipmaps (écrit ici)
- blp_dxt1_mips.blp   BLP2 compressé DXT1, avec mipmaps (écrit ici)
- blp_dxt1.blp        BLP2 compressé DXT1, sans mipmaps
- blp_argb_mips.blp   BLP2 non compressé (BGRA 32 bits), avec mipmaps

Le diagnostic essaie aussi un fichier absent, pour savoir ce que SetTexture renvoie
dans ce cas.
"""

import os
import struct

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, "NextStep_Diagnostic", "Media")
SOURCE = os.path.join(HERE, "..", "..", "addon", "NextStep", "Media", "Zones", "1429.tga")
W, H = 256, 64


def sample(label):
    image = Image.open(SOURCE).convert("RGB").crop((128, 32, 384, 96))
    draw = ImageDraw.Draw(image)
    try:
        font = ImageFont.truetype("arialbd.ttf", 16)
    except OSError:
        font = ImageFont.load_default()
    draw.rectangle([0, 0, 255, 22], fill=(0, 0, 0))
    draw.text((6, 2), label, font=font, fill=(255, 210, 0))
    return image


def mips(image):
    chain = [image]
    w, h = image.size
    while w > 1 or h > 1:
        w, h = max(1, w // 2), max(1, h // 2)
        chain.append(image.resize((w, h), Image.LANCZOS))
    return chain


def rgb565(c):
    r, g, b = c[:3]
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)


def unpack565(v):
    r, g, b = (v >> 11) & 31, (v >> 5) & 63, v & 31
    return (r << 3 | r >> 2, g << 2 | g >> 4, b << 3 | b >> 2)


def dxt1(image):
    """Compression DXT1 simple : extrêmes de luminance du bloc, 4 couleurs."""
    w, h = image.size
    px = image.convert("RGB").load()
    out = bytearray()
    for by in range(0, max(h, 4), 4):
        for bx in range(0, max(w, 4), 4):
            block = [px[min(bx + x, w - 1), min(by + y, h - 1)] for y in range(4) for x in range(4)]
            lum = [0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2] for c in block]
            c0 = rgb565(block[lum.index(max(lum))])
            c1 = rgb565(block[lum.index(min(lum))])
            if c0 < c1:
                c0, c1 = c1, c0
            if c0 == c1:
                out += struct.pack("<HHI", c0, c1, 0)
                continue
            a, b = unpack565(c0), unpack565(c1)
            palette = [a, b, tuple((2 * a[i] + b[i]) // 3 for i in range(3)),
                       tuple((a[i] + 2 * b[i]) // 3 for i in range(3))]
            bits = 0
            for i, c in enumerate(block):
                best = min(range(4), key=lambda k: sum((c[j] - palette[k][j]) ** 2 for j in range(3)))
                bits |= best << (2 * i)
            out += struct.pack("<HHI", c0, c1, bits)
    return bytes(out)


def blp2(path, image, encoding, with_mips):
    chain = mips(image) if with_mips else [image]
    palette = bytes(1024)
    datas = []
    if encoding == 1:
        quantized = image.quantize(256, method=Image.Quantize.MEDIANCUT)
        pal = quantized.getpalette()[:768] + [0] * (768 - len(quantized.getpalette()[:768]))
        palette = b"".join(bytes((pal[i * 3 + 2], pal[i * 3 + 1], pal[i * 3], 255)) for i in range(256))
        for level in chain:
            datas.append(level.quantize(palette=quantized, dither=Image.Dither.NONE).tobytes())
        alpha_type = 0
    elif encoding == 2:
        datas = [dxt1(level) for level in chain]
        alpha_type = 0
    else:   # 3 : BGRA non compressé
        for level in chain:
            r, g, b = level.convert("RGB").split()
            a = Image.new("L", level.size, 255)
            datas.append(Image.merge("RGBA", (b, g, r, a)).tobytes())
        alpha_type = 0
    alpha_depth = 8 if encoding == 3 else 0
    offsets, sizes = [], []
    position = 4 + 4 + 4 + 8 + 64 + 64 + 1024
    for data in datas:
        offsets.append(position)
        sizes.append(len(data))
        position += len(data)
    offsets += [0] * (16 - len(offsets))
    sizes += [0] * (16 - len(sizes))
    header = b"BLP2" + struct.pack("<I4BII", 1, encoding, alpha_depth, alpha_type, 1 if with_mips else 0, *image.size)
    header += struct.pack("<16I", *offsets) + struct.pack("<16I", *sizes) + palette
    with open(path, "wb") as f:
        f.write(header + b"".join(datas))


def main():
    os.makedirs(OUT, exist_ok=True)
    sample("TGA").save(os.path.join(OUT, "tga_plain.tga"), format="TGA", compression=None)
    sample("TGA RLE").save(os.path.join(OUT, "tga_rle.tga"), format="TGA", compression="tga_rle")
    image = sample("BLP Pillow")
    image.quantize(256, method=Image.Quantize.MEDIANCUT).save(os.path.join(OUT, "blp_pillow.blp"))
    blp2(os.path.join(OUT, "blp_pal_mips.blp"), sample("BLP palette + mips"), 1, True)
    blp2(os.path.join(OUT, "blp_dxt1_mips.blp"), sample("BLP DXT1 + mips"), 2, True)
    blp2(os.path.join(OUT, "blp_dxt1.blp"), sample("BLP DXT1"), 2, False)
    blp2(os.path.join(OUT, "blp_argb_mips.blp"), sample("BLP ARGB + mips"), 3, True)
    for name in sorted(os.listdir(OUT)):
        print(name, os.path.getsize(os.path.join(OUT, name)))


if __name__ == "__main__":
    main()
