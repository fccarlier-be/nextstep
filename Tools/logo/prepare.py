"""Prépare le logo de NextStep à partir d'une image générée : détourage, recadrage carré, tailles finales.

    python Tools/logo/prepare.py <image source> [--marge 0.04]

Produit :
    img/logo/nextstep-1024.png                     maître détouré (fond transparent)
    img/logo/nextstep-curseforge-400.png           icône du projet CurseForge
    addon/NextStep/Media/Icon.tga                   128 x 128 : liste des addons (TOC IconTexture)
    addon/NextStep/Media/IconSmall.tga              64 x 64 : bouton de la minimap

Détourage par BiRefNet (rembg). Script repris de C:\\Cabinet\\depot\\outils\\images\\detourer.py ; il s'exécute
avec l'environnement C:\\Cabinet\\outils\\venv-images (Pillow, rembg), modèles dans C:\\Cabinet\\modeles\\rembg.
Les textures du jeu doivent avoir des dimensions en puissances de 2 : TGA 32 bits non compressé.
"""

import argparse
import os
from pathlib import Path

os.environ.setdefault("U2NET_HOME", r"C:\Cabinet\modeles\rembg")

from PIL import Image  # noqa: E402
from rembg import new_session, remove  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUTPUTS = {
    "master": (ROOT / "img/logo/nextstep-1024.png", 1024),
    "curseforge": (ROOT / "img/logo/nextstep-curseforge-400.png", 400),
    "icon": (ROOT / "addon/NextStep/Media/Icon.tga", 128),
    "small": (ROOT / "addon/NextStep/Media/IconSmall.tga", 64),
}


def square(subject: Image.Image, size: int, margin: float) -> Image.Image:
    """Centre le sujet dans une toile carrée transparente, avec une marge uniforme."""
    room = size * (1 - 2 * margin)
    scale = min(room / subject.width, room / subject.height)
    resized = subject.resize((round(subject.width * scale), round(subject.height * scale)), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(resized, ((size - resized.width) // 2, (size - resized.height) // 2), resized)
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source")
    parser.add_argument("--marge", type=float, default=0.04, help="marge autour du sujet, en part du côté")
    parser.add_argument("--seuil", type=int, default=8, help="alpha en dessous duquel un pixel est vide")
    args = parser.parse_args()

    image = Image.open(args.source).convert("RGB")
    cut = remove(image, session=new_session("birefnet-general"))
    alpha = cut.getchannel("A").point(lambda v: 0 if v < args.seuil else v)
    cut.putalpha(alpha)
    box = alpha.getbbox()
    if box is None:
        raise SystemExit("aucun sujet détecté")
    subject = cut.crop(box)

    master = square(subject, 1024, args.marge)
    for name, (path, size) in OUTPUTS.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        result = master if size == 1024 else master.resize((size, size), Image.LANCZOS)
        if path.suffix == ".tga":
            result.save(path, compression=None)
        else:
            result.save(path, optimize=True)
        print(f"{name}: {path.relative_to(ROOT)} ({size} x {size})")


if __name__ == "__main__":
    main()
