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


# ---------- метки на карте ----------

MARKS_DIR = os.path.join(ART, "marks")
SWIFT_MARKS = os.path.join(ROOT, "OlaPT", "Views", "Game", "MapMarks.swift")
# (имя, как вырезать, точка «на земле» в пикселях исходника, сколько точек карты в пикселе исходника).
# Метка ложится на холст так, что точка на земле — ровно в центре: в Swift её ставят .position(точка).
OBELISK = 30 / 1369          # обелиск от острия до края земли — 30 точек карты (заметно выше домов)
MARKS = [
    ("obelisk_dark", "alpha", (525, 1310), OBELISK),
    ("obelisk_lit", "glow", (525, 1310), OBELISK),      # правка тёмного: тот же силуэт + свечение
    ("obelisk_broken", "rubble", (500, 1275), OBELISK * 1.2),  # нарисован мельче — подгоняем
    ("banner_mask", "alpha", (468, 1195), 26 / 1186),   # флажок с древком — 26 точек
    ("banner_lord", "alpha", (468, 1195), 26 / 1186),
    ("map_patrol", "alpha", (660, 1160), 30 / 1069),     # двое стражников с копьями — 30 точек
    ("map_legion", "legion", None, 24 / 508),           # колонна марионеток — 24 точки в высоту
]
# Огонь над крышами: три кадра в ряд на чёрном фоне; основание пламени — точка «на земле».
FIRE = ("fx_fire", 3, 22 / 680)
# Значки интерфейса: квадрат, картинка по центру с полями (Tools/game/art/icons)
ICONS = [
    ("icon_aura", "aura.png"), ("icon_puppets", "puppets.png"),
    ("icon_act_assault", "act_assault.png"), ("icon_act_infiltrate", "act_infiltrate.png"),
    ("icon_act_abduct", "act_abduct.png"), ("icon_st_control", "st_control.png"),
    ("icon_st_guard", "st_guard.png"), ("icon_st_walls", "st_walls.png"),
    ("icon_st_faith", "st_faith.png"), ("icon_st_alert", "st_alert.png"),
    ("icon_st_charge", "st_charge.png"), ("icon_law_fear", "law_fear.png"),
]
ICON_PX = 120


def smooth(x, lo, hi):
    import numpy as np
    t = np.clip((x - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def cut_alpha(img):
    """Настоящая прозрачность: только убрать почти невидимую дымку по краям."""
    import numpy as np
    a = np.asarray(img.convert("RGBA")).copy()
    a[..., 3][a[..., 3] < 20] = 0
    return Image.fromarray(a, "RGBA")


def cut_glow(img, base):
    """Горящий обелиск на тёмном фоне: силуэт берём у тёмного, вокруг — фиолетовое свечение."""
    import numpy as np
    rgb = np.asarray(img.convert("RGB")).astype(float)
    hsv = np.asarray(img.convert("RGB").convert("HSV")).astype(float)
    hue, v = hsv[..., 0], hsv[..., 2]
    da = np.asarray(base.convert("RGBA"))[..., 3].astype(float) / 255
    glow = smooth(v, 40, 120) * ((hue > 170) & (hue < 235)) * 0.9
    alpha = np.maximum(da, glow)
    m = (da < 0.5) & (alpha > 0.01)
    rgb[m] = np.clip(rgb[m] / alpha[m, None], 0, 255)
    return Image.fromarray(np.dstack([rgb, alpha * 255]).astype("uint8"), "RGBA")


def cut_rubble(img):
    """Сломанный обелиск на чёрном фоне с тёплым светом у земли: камни целиком, земля — пятном."""
    import numpy as np
    from scipy import ndimage as nd
    rgb = np.asarray(img.convert("RGB")).astype(float)
    hsv = np.asarray(img.convert("RGB").convert("HSV")).astype(float)
    hue, sat, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    stone = (v > 24) & ((sat < 110) | ((hue > 150) & (hue < 255)))
    stone = nd.binary_fill_holes(nd.binary_closing(stone, iterations=2))
    stone = nd.binary_opening(stone, iterations=1)
    lab, n = nd.label(stone)
    sizes = nd.sum(stone, lab, range(1, n + 1))
    stone = np.isin(lab, 1 + np.nonzero(sizes >= 60)[0])
    w, h = img.size
    ground = Image.new("L", img.size, 0)
    ImageDraw.Draw(ground).ellipse([w * 0.093, h * 0.729, w * 0.913, h * 0.941], fill=255)
    ground = np.asarray(ground.filter(ImageFilter.GaussianBlur(28))).astype(float) / 255
    warm = (hue < 40) | (hue > 240)
    alpha = np.maximum(stone.astype(float), ground * smooth(v, 22, 55) * warm)
    alpha = nd.gaussian_filter(alpha, 0.8)
    return Image.fromarray(np.dstack([rgb, alpha * 255]).astype("uint8"), "RGBA")


def cut_black(img, thr=10):
    """Ровный чёрный фон: заливка от краёв по пикселям темнее thr, край чуть смягчён."""
    import numpy as np
    from scipy import ndimage as nd
    rgb = np.asarray(img.convert("RGB")).astype(float)
    low = rgb.max(2) <= thr
    lab, n = nd.label(low)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    alpha = (~np.isin(lab, list(edge))).astype(float)
    alpha = nd.gaussian_filter(alpha, 0.7)
    return Image.fromarray(np.dstack([rgb, alpha * 255]).astype("uint8"), "RGBA")


def cut_legion(img):
    """Колонна марионеток: из четырёх фигур берём три (вторая, согнутая, читается хуже) и сдвигаем вплотную."""
    cut = cut_black(img)
    pieces = [cut.crop((27, 280, 393, 812)), cut.crop((815, 280, 1489, 812))]
    gap = 24
    out = Image.new("RGBA", (sum(p.width for p in pieces) + gap, 532), (0, 0, 0, 0))
    x = 0
    for piece in pieces:
        out.alpha_composite(piece, (x, 0))
        x += piece.width + gap
    return out, (out.width / 2, 515)


def cut_glowing_black(img):
    """Огонь и дым на чёрном: прозрачность по яркости, цвет «расправлен», чтобы дым не грязнел."""
    import numpy as np
    rgb = np.asarray(img.convert("RGB")).astype(float)
    alpha = smooth(rgb.max(2), 6, 70)
    m = alpha > 0.01
    rgb[m] = np.clip(rgb[m] / alpha[m, None], 0, 255)
    return Image.fromarray(np.dstack([rgb, alpha * 255]).astype("uint8"), "RGBA")


def build_fire(sizes, report):
    import numpy as np
    name, frames, upp = FIRE
    path = os.path.join(MARKS_DIR, name + ".png")
    if not os.path.exists(path):
        return
    src = Image.open(path).convert("RGB")
    fw = src.width // frames
    cut = []
    for i in range(frames):
        part = src.crop((i * fw, 0, (i + 1) * fw, src.height))
        v = np.asarray(part).max(2)
        hy, hx = np.nonzero(v > 200)
        cut.append((cut_glowing_black(part), (hx.mean(), hy.max())))
    # общий холст для всех кадров, чтобы пламя не прыгало
    half_w = max(max(ax - im.getbbox()[0], im.getbbox()[2] - ax) for im, (ax, ay) in cut)
    half_h = max(max(ay - im.getbbox()[1], im.getbbox()[3] - ay) for im, (ax, ay) in cut)
    for i, (im, (ax, ay)) in enumerate(cut):
        box = (round(ax - half_w), round(ay - half_h), round(ax + half_w), round(ay + half_h))
        frame, size = placed(im.crop(box), (half_w, half_h), upp, keep_canvas=True)
        imageset("%s%d" % (name, i), frame)
    sizes[name] = size
    report.append("%s: рисунок автора, %d кадра, %.1f × %.1f точек карты" % ((name, frames) + size))


def build_icons(report):
    for name, file in ICONS:
        path = os.path.join(ART, "icons", file)
        if not os.path.exists(path):
            continue
        img = cut_alpha(Image.open(path))
        img = img.crop(img.getbbox())
        inner = round(ICON_PX * 0.92)
        k = inner / max(img.width, img.height)
        small = img.resize((max(1, round(img.width * k)), max(1, round(img.height * k))), Image.LANCZOS)
        out = Image.new("RGBA", (ICON_PX, ICON_PX), (0, 0, 0, 0))
        out.alpha_composite(small, ((ICON_PX - small.width) // 2, (ICON_PX - small.height) // 2))
        imageset(name, out)
        report.append(name + ": значок автора")


def placed(img, anchor, upp, keep_canvas=False):
    """Обрезать по содержимому и положить на холст точкой на земле в центр; SCALE пикселей на точку карты."""
    box = (0, 0, img.width, img.height) if keep_canvas else img.getbbox()
    ax, ay = anchor
    half_w = max(ax - box[0], box[2] - ax) * upp
    half_h = max(ay - box[1], box[3] - ay) * upp
    k = upp * SCALE
    crop = img.crop(box)
    small = crop.resize((max(1, round(crop.width * k)), max(1, round(crop.height * k))), Image.LANCZOS)
    cw, ch = round(half_w * 2 * SCALE), round(half_h * 2 * SCALE)
    out = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    out.paste(small, (round(cw / 2 - (ax - box[0]) * k), round(ch / 2 - (ay - box[1]) * k)), small)
    return out, (cw / SCALE, ch / SCALE)


def graded_mark(img):
    """Тот же мрачный фильтр, что у карты (без виньетки), прозрачность не трогаем."""
    alpha = img.split()[3]
    out = grim(img.convert("RGB"), *MAP_GRADE[:3], 0).convert("RGBA")
    out.putalpha(alpha)
    return out


def build_marks(report):
    sizes = {}
    for name, how, anchor, upp in MARKS:
        path = os.path.join(MARKS_DIR, name + ".png")
        if not os.path.exists(path):
            continue
        img = Image.open(path)
        if how == "glow":
            img = cut_glow(img, Image.open(os.path.join(MARKS_DIR, "obelisk_dark.png")))
        elif how == "rubble":
            img = cut_rubble(img)
        elif how == "legion":
            img, anchor = cut_legion(img)
        else:
            img = cut_alpha(img)
        img, size = placed(img, anchor, upp)
        # обелиски — часть местности, темнеют вместе с картой; флажки — знак владельца, их видно издалека
        imageset(name, graded_mark(img) if name.startswith("obelisk") else img)
        sizes[name] = size
        report.append(name + ": рисунок автора, %.1f × %.1f точек карты" % size)
    build_fire(sizes, report)
    lines = ["import CoreGraphics", "",
             "// Создано Tools/game/build_game_assets.py — не править руками.",
             "/// Метки на карте: размер холста в точках карты. Точка «на земле» — в центре холста.",
             "enum MapMarks {",
             "    static let size: [String: CGSize] = ["]
    for name in sorted(sizes):
        w, h = sizes[name]
        lines.append('        "%s": CGSize(width: %.1f, height: %.1f),' % (name, w, h))
    lines += ["    ]", "", "    static func size(_ name: String) -> CGSize {",
              "        return size[name] ?? CGSize(width: 10, height: 10)", "    }", "}", ""]
    with open(SWIFT_MARKS, "w") as f:
        f.write("\n".join(lines))


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
    build_marks(report)
    build_icons(report)
    imageset("tab-mask", tab_icon(), scales=(1, 2, 3), template=True, folder=TAB)
    print("\n".join(report))


if __name__ == "__main__":
    main()
