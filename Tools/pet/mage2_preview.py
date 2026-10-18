"""Preview of the grim tower with the masked mage: python3 mage2_preview.py OUT_DIR [gif]"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image, ImageDraw, ImageFont  # noqa: E402
import hires  # noqa: E402
from hires import (W, H, Canvas, make_room, open_book, candle, room_lighting, ITEMS, banner, fire, chain,  # noqa: E402
                   item_cauldron, item_raven, item_crystal_ball, item_star_map, item_hourglass, item_cat,
                   item_bats, item_armor, item_magic_circle, skeleton_hi, thought_bubble_potion, BOOK_X, BOOK_Y,
                   arena_bg, boss_dragon)
import mage2  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FONT = os.path.join(ROOT, "OlaPT", "Resources", "Fonts", "Tiny5-Bold.ttf")
MX, MY = 65, 28          # tower mage sprite position (hand on the book, feet on the floor)
ANGRY_X, ANGRY_Y = 40, 28


def place_items(cv, kind, items, frame=0):
    funcs = {"cauldron": item_cauldron, "raven": item_raven, "crystal": item_crystal_ball,
             "starmap": lambda f=0: item_star_map(), "hourglass": item_hourglass, "cat": item_cat,
             "bats": item_bats, "armor": lambda f=0: item_armor(), "circle": item_magic_circle}
    for (th, key, title, x, y) in ITEMS[:items]:
        if key == "banner":
            if kind != "hall" and kind != "summit":
                banner(cv, x, y, 22, 34)
            continue
        if kind == "summit" and key in ("starmap",):
            continue
        cv.paste(funcs[key](frame), x, y)


def scene(kind, items=4, pose="read", phase=0, lit=4, mood="happy"):
    cv = make_room("dungeon" if kind.startswith("dungeon") else kind)
    if kind.startswith("dungeon"):
        if kind == "dungeon_chained":
            for rx in (40, 88):
                cv.ellipse(rx - 3, 56, rx + 3, 62, None, outline="st4")
                chain(cv, rx, 63, 76)
            cv.paste(mage2.mask_on_floor(), 106, 103)
    else:
        place_items(cv, kind, items, phase)
        if kind == "hall":
            fire(cv, 4, 93, phase % 3)
    for i in range(4):
        candle(cv, 12 + i * 12, 21, lit=i < lit, frame=i + phase, h=10 + (i % 2) * 3)
    if kind == "dungeon":
        cv.paste(mage2.angry(phase % 2), ANGRY_X, ANGRY_Y)
    elif kind == "dungeon_chained":
        cv.paste(skeleton_hi(0), 36, 54)
    else:
        open_book(cv, BOOK_X, BOOK_Y, glow=False)
        sprite, top = mage2.build(pose, phase)
        cv.paste(sprite, MX, MY)
    room_lighting(cv, "dungeon" if kind.startswith("dungeon") else kind, lit)
    if not kind.startswith("dungeon") and mood == "happy":
        sprite, top = mage2.build(pose, phase)
        mage2.rune_smoke(cv, (MX + top[0], MY + top[1]), phase)
    if mood == "ok":
        cv.paste(thought_bubble_potion(), 92, 0)
    return cv.img


def tile(img, text, s=3):
    big = img.resize((W * s, H * s), Image.NEAREST)
    t = Image.new("RGB", (W * s, H * s + 36), (10, 9, 8))
    t.paste(big, (0, 36))
    d = ImageDraw.Draw(t)
    d.text((12, 4), text, font=ImageFont.truetype(FONT, 24), fill=(226, 190, 118))
    return t


def main(out):
    shots = [
        (scene("cellar", items=1, phase=2), "Подвал · котёл под окном"),
        (scene("hall", items=4, phase=3), "Зал · 4 вещи"),
        (scene("library", items=7, phase=5), "Библиотека · 7 вещей"),
        (scene("summit", items=10, phase=7), "Вершина · все 10 вещей"),
        (scene("library", items=7, pose="tired", lit=3, mood="ok"), "Проголодался"),
        (scene("hall", items=4, pose="drink", phase=1), "Пьёт зелье"),
        (scene("dungeon", lit=1, phase=1, mood="angry"), "Темница · злится"),
        (scene("dungeon_chained", lit=0, mood="skeleton"), "Скелет, маска упала"),
    ]
    tiles = [tile(img, t) for img, t in shots]
    gap = 14
    tw, th = tiles[0].size
    sheet = Image.new("RGB", (tw * 2 + gap, (th + gap) * 4 - gap), (30, 28, 26))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % 2) * (tw + gap), (i // 2) * (th + gap)))
    sheet.save(os.path.join(out, "grim_tower.png"))

    # close-up of the mage poses
    z = 6
    poses = ["read", "read2", "tired", "drink", "wave"]
    close = Image.new("RGB", ((mage2.SW * z + gap) * len(poses) + gap, mage2.SH * z + gap * 2), (12, 11, 14))
    for i, p in enumerate(poses):
        sp, top = mage2.build(p, 0)
        bg = Image.new("RGBA", (mage2.SW, mage2.SH), (26, 24, 30, 255))
        bg.alpha_composite(sp.img)
        close.paste(bg.resize((mage2.SW * z, mage2.SH * z), Image.NEAREST), (gap + i * (mage2.SW * z + gap), gap))
    close.save(os.path.join(out, "mage_poses.png"))
    print("ok")


def animated(out, frames=20, s=3):
    shots = []
    for ph in range(frames):
        pose = "read2" if ph % 10 == 9 else "read"
        img = scene("library", items=7, pose=pose, phase=ph).resize((W * s, H * s), Image.NEAREST)
        shots.append(img.convert("P", palette=Image.ADAPTIVE, colors=255))
    shots[0].save(os.path.join(out, "grim_tower.gif"), save_all=True, append_images=shots[1:],
                  duration=220, loop=0, disposal=2)


if __name__ == "__main__":
    main(sys.argv[1])
    if len(sys.argv) > 2 and sys.argv[2] == "gif":
        animated(sys.argv[1])
