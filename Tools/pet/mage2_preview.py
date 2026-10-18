"""Preview sheets for the mage redesign: python3 mage2_preview.py OUT_DIR"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image, ImageDraw, ImageFont  # noqa: E402
from hires import (W, H, make_room, open_book, candle, room_lighting, item_cauldron, item_crystal_ball,  # noqa: E402
                   item_hourglass, item_raven)
import mage2  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FONT = os.path.join(ROOT, "OlaPT", "Resources", "Fonts", "Tiny5-Bold.ttf")
MX, MY = 63, 17   # sprite position in the scene (hand on the book)


def scene(variant, pose="read", phase=0, kind="library"):
    cv = make_room(kind)
    cv.paste(item_cauldron(0), 4, 72)
    cv.paste(item_crystal_ball(0), 176, 76) if False else None
    for i in range(4):
        candle(cv, 12 + i * 12, 21, lit=True, frame=i, h=10 + (i % 2) * 3)
    open_book(cv, 103, 52, glow=False)
    sprite, top = mage2.build(variant, pose, phase)
    cv.paste(sprite, MX, MY)
    room_lighting(cv, kind, 4)
    mage2.rune_smoke(cv, (MX + top[0], MY + top[1]), mage2.VARIANTS[variant], phase)
    return cv.img


def label(img, text, sub=None):
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT, 28)
    d.rectangle([0, 0, img.width, 40], fill=(10, 9, 8))
    d.text((14, 4), text, font=f, fill=(226, 190, 118))
    if sub:
        f2 = ImageFont.truetype(FONT, 18)
        d.text((14 + d.textlength(text, font=f) + 16, 12), sub, font=f2, fill=(150, 140, 120))
    return img


def main(out):
    s = 3
    names = ["hermit", "warlock", "shade", "masked"]
    subs = {"hermit": "верёвка с узлами, лунный камень",
            "warlock": "красный пояс, руны по подолу",
            "shade": "тает в дыму, посох с черепом",
            "masked": "фарфоровая маска, лиловый фонарь"}
    tiles = []
    for i, n in enumerate(names):
        img = scene(n, phase=3).resize((W * s, H * s), Image.NEAREST)
        tile = Image.new("RGB", (W * s, H * s + 40), (10, 9, 8))
        tile.paste(img, (0, 40))
        label(tile, f"{i + 1}. {mage2.VARIANTS[n]['title']}", subs[n])
        tiles.append(tile)
    gap = 16
    sheet = Image.new("RGB", (W * s * 2 + gap, (H * s + 40) * 2 + gap), (30, 28, 26))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % 2) * (W * s + gap), (i // 2) * (H * s + 40 + gap)))
    sheet.save(os.path.join(out, "mage_variants_scenes.png"))

    # close-ups of the sprites
    z = 6
    cw = mage2.SW * z
    close = Image.new("RGB", (cw * 4 + gap * 5, mage2.SH * z + 60 + gap), (12, 11, 14))
    d = ImageDraw.Draw(close)
    f = ImageFont.truetype(FONT, 28)
    for i, n in enumerate(names):
        sp, top = mage2.build(n, "read", 0)
        bg = Image.new("RGBA", (mage2.SW, mage2.SH), (26, 24, 30, 255))
        bg.alpha_composite(sp.img)
        x = gap + i * (cw + gap)
        close.paste(bg.resize((cw, mage2.SH * z), Image.NEAREST), (x, 50))
        d.text((x + 8, 10), f"{i + 1}. {mage2.VARIANTS[n]['title']}", font=f, fill=(226, 190, 118))
    close.save(os.path.join(out, "mage_variants_closeup.png"))
    print("ok")


if __name__ == "__main__":
    main(sys.argv[1])


def animated(out, frames=15, s=2):
    """2x2 grid GIF: each variant reading while its staff puffs runes."""
    from PIL import Image as _I
    names = ["hermit", "warlock", "shade", "masked"]
    gap = 8
    shots = []
    for ph in range(frames):
        sheet = _I.new("RGB", (W * s * 2 + gap, (H * s + 30) * 2 + gap), (30, 28, 26))
        d = ImageDraw.Draw(sheet)
        f = ImageFont.truetype(FONT, 20)
        for i, n in enumerate(names):
            pose = "read2" if ph % 8 == 7 else "read"
            img = scene(n, pose=pose, phase=ph).resize((W * s, H * s), _I.NEAREST)
            x, y = (i % 2) * (W * s + gap), (i // 2) * (H * s + 30 + gap)
            d.rectangle([x, y, x + W * s, y + 30], fill=(10, 9, 8))
            d.text((x + 8, y + 4), f"{i + 1}. {mage2.VARIANTS[n]['title']}", font=f, fill=(226, 190, 118))
            sheet.paste(img, (x, y + 30))
        shots.append(sheet.convert("P", palette=_I.ADAPTIVE, colors=255))
    shots[0].save(os.path.join(out, "mage_variants.gif"), save_all=True, append_images=shots[1:],
                  duration=180, loop=0, disposal=2)


if __name__ == "__main__" and len(sys.argv) > 2 and sys.argv[2] == "gif":
    animated(sys.argv[1])
