# -*- coding: utf-8 -*-
"""Картинки вкладки «Империя»: карта Акта 1, поселения, значок вкладки.

Готовые картинки автора лежат в Tools/game/art под именами из ТЗ (settle_1_redes.png и т. д.).
Если картинки ещё нет, рисуется заглушка того же размера — когда автор пришлёт рисунок,
достаточно положить его в Tools/game/art и запустить скрипт снова: код приложения не меняется.

Запуск: python3 Tools/game/build_game_assets.py
"""
import json
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ART = os.path.join(ROOT, "Tools", "game", "art")
OUT = os.path.join(ROOT, "OlaPT", "Assets.xcassets", "Game")
TAB = os.path.join(ROOT, "OlaPT", "Assets.xcassets", "tab-mask.imageset")

# Карта — 320×480 точек; картинки хранятся втрое подробнее (как экран iPhone @3x),
# чтобы рисунки автора не превращались на телефоне в кашу из крупных пикселей.
SCALE = 3
# Поселения: имя файла и размер на карте в точках карты (Swift: MapLayout.spriteSize)
SETTLEMENTS = [
    ("settle_0_calada", 96, 112),
    ("settle_1_redes", 96, 96),
    ("settle_2_trigo", 96, 96),
    ("settle_3_souto", 96, 96),
    ("settle_4_monte", 112, 112),
]
MAP = ("map_act1", 320, 480)
# Поселения, дороги и большие города юга нарисованы прямо на карте (map_act1_base.png);
# отдельные картинки поселений нужны для шапки карточки поселения.


def imageset(name, img, scales=(1,), template=False, folder=OUT):
    d = os.path.join(folder, name + ".imageset") if folder == OUT else folder
    os.makedirs(d, exist_ok=True)
    images = []
    for s in scales:
        fn = name + ("" if s == 1 and len(scales) == 1 else "@%dx" % s) + ".png"
        im = img if s == 1 else img.resize((img.width * s, img.height * s), Image.NEAREST)
        im.save(os.path.join(d, fn), optimize=True)
        images.append({"filename": fn, "idiom": "universal", "scale": "%dx" % s})
    meta = {"images": images, "info": {"author": "xcode", "version": 1}}
    if template:
        meta["properties"] = {"template-rendering-intent": "template"}
    with open(os.path.join(d, "Contents.json"), "w") as f:
        json.dump(meta, f, indent=2)


# Подгонка света под ночную карту: (яркость, оттенок RGB, насыщенность). Окна и факелы не трогаем.
GRADE = {
    # долина пришла заметно светлее и золотистее остальных поселений
    "settle_2_trigo": (0.72, (1.0, 0.92, 1.08), 0.72),
}


def graded(img, k, tint, sat):
    import numpy as np
    a = np.asarray(img.convert("RGBA")).astype(float)
    rgb, al = a[..., :3], a[..., 3]
    hsv = np.asarray(img.convert("RGB").convert("HSV")).astype(float)
    lights = ((hsv[..., 2] > 200) & (hsv[..., 1] > 120) & (hsv[..., 0] < 40))[..., None].astype(float)
    out = rgb * np.array(tint) * k
    g = out.mean(2, keepdims=True)
    out = g + (out - g) * sat
    out = out * (1 - lights) + rgb * lights
    return Image.fromarray(np.dstack([np.clip(out, 0, 255), al]).astype("uint8"))


# Карта темнее и мрачнее рисунка автора: (яркость, гамма, насыщенность, виньетка).
# Огни окон, факелов и фиолетовые руны почти не трогаем — на тёмной карте они горят ярче.
MAP_GRADE = (0.82, 1.16, 0.75, 0.30)


def grim(img, k, gamma, sat, vignette):
    import numpy as np
    a = np.asarray(img.convert("RGB")).astype(float) / 255
    hsv = np.asarray(img.convert("RGB").convert("HSV")).astype(float)
    hue, s, v = hsv[..., 0], hsv[..., 1] / 255, hsv[..., 2] / 255

    def smooth(x, lo, hi):
        t = np.clip((x - lo) / (hi - lo), 0, 1)
        return t * t * (3 - 2 * t)

    warm = (hue < 35) | (hue > 245)
    purple = (hue > 185) & (hue < 235)
    light = smooth(v, 0.62, 0.85) * smooth(s, 0.35, 0.6) * (warm | purple)
    light = Image.fromarray((light * 255).astype("uint8")).filter(ImageFilter.GaussianBlur(1.2))
    light = np.asarray(light).astype(float)[..., None] / 255 * 0.85
    out = a ** gamma * k
    grey = (out * np.array([0.30, 0.55, 0.15])).sum(2, keepdims=True)
    out = grey + (out - grey) * sat
    # тени холоднее
    shadow = 1 - np.clip(grey / 0.35, 0, 1)
    out = out * (1 + shadow * np.array([-0.04, -0.02, 0.08]))
    h, w = out.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2) / np.sqrt(2)
    out = out * (1 - vignette * smooth(d, 0.45, 1.0))[..., None]
    out = out * (1 - light) + a * light
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype("uint8"))


def sprite_from_art(path, w, h, colors=None):
    """Картинка автора → спрайт: обрезать по содержимому и уменьшить (colors — свести к палитре)."""
    src = Image.open(path).convert("RGBA")
    a = src.split()[3].point(lambda v: 255 if v >= 128 else 0)
    src.putalpha(a)
    box = src.getbbox()
    src = src.crop(box)
    # вписать с сохранением пропорций, по центру снизу
    k = min(w / src.width, h / src.height)
    sw, sh = max(1, round(src.width * k)), max(1, round(src.height * k))
    small = src.resize((sw, sh), Image.LANCZOS)
    alpha = small.split()[3].point(lambda v: 255 if v >= 110 else 0)
    rgb = small.convert("RGB")
    if colors:
        rgb = rgb.quantize(colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    rgb.putalpha(alpha)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(rgb, ((w - sw) // 2, h - sh), rgb)
    return out


# ---------- заглушки ----------

ROOF = [(122, 40, 34), (104, 34, 30), (138, 52, 40)]
WALL = [(92, 80, 72), (78, 68, 62), (104, 92, 80)]
DARK = (24, 20, 26)
WINDOW = (255, 184, 92)


def house(d, x, y, w, h, rnd, lit=True, roof=None):
    wall = rnd.choice(WALL)
    roof = roof or rnd.choice(ROOF)
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=wall, outline=DARK)
    d.polygon([(x - 1, y), (x + w // 2, y - h // 2 - 1), (x + w, y)], fill=roof, outline=DARK)
    if lit and w >= 6:
        d.rectangle([x + 2, y + 2, x + 3, y + 3], fill=WINDOW if rnd.random() < 0.7 else DARK)


def ground(d, w, h, color=(46, 42, 52)):
    d.ellipse([2, h * 0.45, w - 3, h - 2], fill=color, outline=(30, 26, 34))


def placeholder(name, w, h, seed):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ground(d, w, h)
    if name == "settle_0_calada":
        for i in range(6):
            house(d, 8 + (i % 3) * 22, h - 34 + (i // 3) * 12, 12, 9, rnd, lit=False, roof=(60, 52, 58))
        # кладбище
        for i in range(5):
            d.rectangle([w - 18 + (i % 3) * 5, h - 22 + (i // 3) * 6, w - 17 + (i % 3) * 5, h - 19 + (i // 3) * 6],
                        fill=(140, 136, 130))
        # башня Маски
        tx = w // 2 - 6
        d.rectangle([tx, 14, tx + 12, h - 30], fill=(40, 34, 46), outline=DARK)
        d.polygon([(tx - 2, 14), (tx + 6, 0), (tx + 14, 14)], fill=(30, 26, 36), outline=DARK)
        d.rectangle([tx + 5, 24, tx + 7, 28], fill=(170, 100, 230))
    elif name == "settle_2_trigo":
        d.rectangle([6, h - 30, 30, h - 14], fill=(150, 128, 60))          # поле
        for i in range(7):
            house(d, 30 + (i % 4) * 11, h - 40 + (i // 4) * 14, 9, 8, rnd)
        d.rectangle([60, h - 56, 66, h - 38], fill=(110, 92, 70), outline=DARK)   # мельница
        d.line([(63, h - 56), (55, h - 64)], fill=(170, 160, 140))
        d.line([(63, h - 56), (71, h - 48)], fill=(170, 160, 140))
        d.line([(63, h - 56), (71, h - 64)], fill=(170, 160, 140))
        d.line([(63, h - 56), (55, h - 48)], fill=(170, 160, 140))
    elif name == "settle_3_souto":
        for i in range(9):
            house(d, 10 + (i % 5) * 12, h - 40 + (i // 5) * 14, 9, 8, rnd)
        for i in range(6):  # каштаны
            cx, cy = 6 + i * 13, h - 50 + (i % 2) * 4
            d.ellipse([cx, cy, cx + 10, cy + 9], fill=(34, 62, 44), outline=DARK)
        d.rectangle([w // 2 - 6, h - 44, w // 2 + 6, h - 30], fill=(96, 88, 84), outline=DARK)   # храм
        d.rectangle([w // 2 - 1, h - 42, w // 2 + 1, h - 36], fill=(150, 30, 34))
        for x in range(4, w - 4, 3):  # частокол
            d.line([(x, h - 12), (x, h - 16)], fill=(100, 76, 52))
    elif name == "settle_4_monte":
        d.rectangle([10, h - 46, w - 11, h - 16], fill=(70, 66, 74), outline=DARK)   # стены
        for x in range(10, w - 10, 6):
            d.rectangle([x, h - 49, x + 2, h - 46], fill=(70, 66, 74))
        d.rectangle([w // 2 - 5, h - 26, w // 2 + 5, h - 16], fill=(30, 24, 22))   # ворота
        d.rectangle([w // 2 - 2, h - 25, w // 2 + 2, h - 23], fill=WINDOW)
        for i in range(8):
            house(d, 16 + (i % 4) * 16, h - 42 + (i // 4) * 10, 10, 7, rnd)
        d.rectangle([w // 2 - 8, 14, w // 2 + 8, h - 50], fill=(84, 78, 86), outline=DARK)   # поместье
        for x in range(w // 2 - 8, w // 2 + 8, 4):
            d.rectangle([x, 11, x + 2, 14], fill=(84, 78, 86))
        d.rectangle([w // 2 - 2, 22, w // 2 + 1, 26], fill=WINDOW)
    else:
        for i in range(6):
            house(d, 12 + (i % 3) * 18, h - 36 + (i // 3) * 12, 11, 8, rnd)
    return img


def map_placeholder():
    """Ночная карта из схемы: те же места, дороги и поляны, но в пикселях и ночных цветах."""
    guide = Image.open(os.path.join(ART, "map_act1_guide.png")).convert("RGB")
    small = guide.resize((MAP[1], MAP[2]), Image.LANCZOS)
    px = small.load()
    rnd = random.Random(5)
    for y in range(MAP[2]):
        for x in range(MAP[1]):
            r, g, b = px[x, y]
            n = rnd.randint(-6, 6)
            # ночь: темнее и холоднее, немного шума, как от травы и камня
            px[x, y] = (max(0, int(r * 0.62) + n), max(0, int(g * 0.66) + n), max(0, int(b * 0.8) + n + 6))
    return small.quantize(40, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")


def tab_icon():
    """Значок вкладки: маска Маски, 24×24, шаблон (красится цветом панели)."""
    rows = [
        "........................",
        "........................",
        "......############......",
        ".....##############.....",
        "....################....",
        "....################....",
        "...##################...",
        "...####...####...####...",
        "...###.....##.....###...",
        "...####...####...####...",
        "...##################...",
        "...##################...",
        "....################....",
        "....#######..#######....",
        ".....######..######.....",
        ".....##############.....",
        "......############......",
        "......###.######.###....",
        ".......##########.......",
        "........########........",
        ".........######.........",
        "..........####..........",
        "........................",
        "........................",
    ]
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c == "#":
                img.putpixel((x, y), (0, 0, 0, 255))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}, "properties": {"provides-namespace": False}}, f, indent=2)
    report = []
    for i, (name, w, h) in enumerate(SETTLEMENTS):
        path = os.path.join(ART, name + ".png")
        if os.path.exists(path):
            img = sprite_from_art(path, w * SCALE, h * SCALE)
            if name in GRADE:
                img = graded(img, *GRADE[name])
            report.append(name + ": рисунок автора" + (" (свет подогнан под карту)" if name in GRADE else ""))
        else:
            img = placeholder(name, w, h, seed=i).resize((w * SCALE, h * SCALE), Image.NEAREST)
            report.append(name + ": заглушка")
        imageset(name, img)
    path = os.path.join(ART, "map_act1_base.png")
    if os.path.exists(path):
        img = grim(Image.open(path).convert("RGB"), *MAP_GRADE)
        img = img.resize((MAP[1] * SCALE, MAP[2] * SCALE), Image.LANCZOS)
        report.append("карта: рисунок автора (темнее и мрачнее)")
    else:
        img = map_placeholder().resize((MAP[1] * SCALE, MAP[2] * SCALE), Image.NEAREST)
        report.append("карта: заглушка по схеме")
    imageset(MAP[0], img)
    imageset("tab-mask", tab_icon(), scales=(1, 2, 3), template=True, folder=TAB)
    print("\n".join(report))


if __name__ == "__main__":
    main()
