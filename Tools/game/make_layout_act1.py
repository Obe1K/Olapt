# -*- coding: utf-8 -*-
"""Схема карты Акта 1 (мир П): север страны, побережье на западе, путь на восток.

Сетка арта 320x480, картинки в 3 раза крупнее (960x1440) — образец для нейросети.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
W, H, S = 320, 480, 3

# 0 — деревня с башней, 1–4 — поселения Акта 1, "S" — большие города юга (закрыто).
P = {
    0: (95, 95, 30, "start"),
    1: (56, 242, 30, "vil"),
    2: (162, 272, 30, "vil"),
    3: (250, 132, 30, "vil"),
    4: (252, 335, 36, "fort"),
    "S": (80, 432, 30, "south"),
}
ROADS = [(0, 1), (1, 2), (2, 3), (3, 4), (2, 4)]
CLOSED = [(1, "S")]
# Берег; у Деревни сетей — небольшой мыс на запад, деревня стоит на нём краем
COAST = [(0, 0), (46, 0), (54, 68), (42, 138), (48, 200), (40, 218), (24, 228), (14, 242), (18, 256),
         (32, 266), (38, 282), (46, 348), (34, 418), (42, 480), (0, 480)]

C = {
    "land": (58, 50, 62), "sea": (40, 58, 92), "fields": (96, 84, 60), "forest": (34, 58, 44),
    "hills": (84, 74, 84), "river": (60, 86, 126), "road": (156, 124, 86), "clear": (126, 112, 98),
    "start": (120, 76, 160), "fort": (150, 44, 54), "mark": (230, 200, 120), "ink": (240, 232, 220),
    "fog": (24, 20, 30),
}


def s(v):
    return int(round(v * S))


def pts(seq):
    return [(s(x), s(y)) for x, y in seq]


def base(d):
    d.rectangle([0, 0, s(W), s(H)], fill=C["land"])
    # лес на востоке; выступом на запад он подходит вплотную к башне Маски
    # лес на востоке: от реки вдоль башни Маски с востока, потом дугой к долине
    d.polygon(pts([(137, 34), (320, 34), (320, 290), (285, 280), (240, 262), (205, 215), (190, 182),
                   (164, 161), (145, 153), (139, 123), (135, 80), (138, 70)]),
              fill=C["forest"])
    d.polygon(pts([(205, 300), (320, 292), (320, 392), (262, 388), (205, 365)]), fill=C["hills"])
    d.polygon(pts([(100, 215), (205, 225), (215, 310), (150, 325), (95, 295)]), fill=C["fields"])
    d.polygon(pts(COAST), fill=C["sea"])
    # Северная граница — река
    d.line(pts([(46, 34), (120, 26), (200, 36), (260, 24), (320, 32)]), fill=C["river"], width=s(5))


def roads(d):
    for a, b in ROADS:
        ax, ay = P[a][:2]
        bx, by = P[b][:2]
        d.line([s(ax), s(ay), s(bx), s(by)], fill=C["road"], width=s(3))
    for a, b in CLOSED:
        ax, ay = P[a][:2]
        bx, by = P[b][:2]
        n = 10
        for i in range(n):
            if i % 2:
                continue
            x1 = ax + (bx - ax) * i / n
            y1 = ay + (by - ay) * i / n
            x2 = ax + (bx - ax) * (i + 1) / n
            y2 = ay + (by - ay) * (i + 1) / n
            d.line([s(x1), s(y1), s(x2), s(y2)], fill=C["road"], width=s(3))
        cx, cy = ax + (bx - ax) * 0.45, ay + (by - ay) * 0.45
        d.line([s(cx - 7), s(cy - 7), s(cx + 7), s(cy + 7)], fill=C["fort"], width=s(3))
        d.line([s(cx - 7), s(cy + 7), s(cx + 7), s(cy - 7)], fill=C["fort"], width=s(3))


def clearings(d):
    for k, (x, y, r, kind) in P.items():
        if kind == "south":
            continue
        outline = {"start": C["start"], "fort": C["fort"]}.get(kind, C["mark"])
        d.ellipse([s(x - r), s(y - r), s(x + r), s(y + r)], fill=C["clear"], outline=outline, width=s(2))


def fog(img):
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(over)
    for i in range(60):
        y = 382 + i * 1.6
        od.rectangle([0, s(y), s(W), s(y + 2.4)], fill=C["fog"] + (min(170, 40 + i * 3),))
    od.rectangle([0, s(382 + 60 * 1.6), s(W), s(H)], fill=C["fog"] + (170,))
    x, y, r, _ = P["S"]
    od.rounded_rectangle([s(x - r), s(y - r * 0.7), s(x + r), s(y + r * 0.7)], radius=s(4),
                         outline=(150, 140, 160, 255), width=s(2))
    return Image.alpha_composite(img.convert("RGBA"), over).convert("RGB")


def labels(d):
    big = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", s(11))
    small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", s(8))
    for k, (x, y, r, kind) in P.items():
        if k == "S":
            d.text((s(x), s(y)), "юг", font=big, fill=(200, 190, 210), anchor="mm")
        else:
            d.text((s(x), s(y)), str(k), font=big, fill=C["ink"], anchor="mm")
    for word, (x, y) in {"граница": (180, 14), "море": (22, 250), "лес": (275, 110), "поля": (150, 280),
                         "холмы": (290, 320), "закрыто": (110, 330), "большие города юга": (160, 455)}.items():
        d.text((s(x), s(y)), word, font=small, fill=(210, 204, 220), anchor="mm")


def make(numbered):
    img = Image.new("RGB", (s(W), s(H)))
    d = ImageDraw.Draw(img)
    base(d)
    img = img.filter(ImageFilter.GaussianBlur(s(3)))
    d = ImageDraw.Draw(img)
    roads(d)
    clearings(d)
    img = fog(img)
    d = ImageDraw.Draw(img)
    if numbered:
        labels(d)
    return img


def make_guide():
    """Схема для нейросети: только местность, дороги и пустые поляны — без колец, крестика и подписей."""
    img = Image.new("RGB", (s(W), s(H)))
    d = ImageDraw.Draw(img)
    base(d)
    img = img.filter(ImageFilter.GaussianBlur(s(3)))
    d = ImageDraw.Draw(img)
    for a, b in ROADS + CLOSED:
        ax, ay = P[a][:2]
        bx, by = P[b][:2]
        d.line([s(ax), s(ay), s(bx), s(by)], fill=C["road"], width=s(3))
    for k, (x, y, r, kind) in P.items():
        if kind != "south":
            d.ellipse([s(x - r), s(y - r), s(x + r), s(y + r)], fill=C["clear"])
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(over)
    for i in range(60):
        y = 382 + i * 1.6
        od.rectangle([0, s(y), s(W), s(y + 2.4)], fill=C["fog"] + (min(170, 40 + i * 3),))
    od.rectangle([0, s(382 + 60 * 1.6), s(W), s(H)], fill=C["fog"] + (170,))
    return Image.alpha_composite(img.convert("RGBA"), over).convert("RGB")


os.makedirs(OUT, exist_ok=True)
make_guide().save(os.path.join(OUT, "map_act1_guide.png"))
make(True).save(os.path.join(OUT, "map_act1_layout.png"))
make(False).save(os.path.join(OUT, "map_act1_layout_clean.png"))
print("ok")
