# -*- coding: utf-8 -*-
"""Сцена башни (экран «Сегодня») из картинок автора.

Вход — Tools/tower/src: зал и пять поз мага, уже сведённые на один зал и уменьшенные до 320×200
(без палитры). Выход:
  - OlaPT/Assets.xcassets/Tower/*.imageset — кадры поз (целиком), мерцание свечей, пыль в луче;
  - OlaPT/Models/TowerAtlas.swift — имена слоёв, их места и размеры.

Палитра пока снимается с самих картинок (28 цветов + 4 запасённых под маску, огонь и страницы).
Когда придёт референс в полном размере, палитру заменим здесь же — код приложения не меняется.

Запуск: python3 Tools/tower/build_tower.py
"""
import json
import os
import random
import shutil
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "Tools", "tower", "src")
ASSETS = os.path.join(ROOT, "OlaPT", "Assets.xcassets", "Tower")
SWIFT = os.path.join(ROOT, "OlaPT", "Models", "TowerAtlas.swift")

W, H = 320, 200
POSES = ["read", "bored", "drink", "cast", "weak"]
# Запасные цвета: маска (два тона), язычок пламени, страницы книги
RESERVED = [(105, 14, 16), (150, 24, 24), (255, 190, 90), (240, 225, 190)]


def load(name):
    return Image.open(os.path.join(SRC, name)).convert("RGB")


def build_palette(images):
    """28 цветов по всем кадрам (зона мага — с тройным весом) + запасные."""
    focus_box = (80, 40, 180, 170)
    fw, fh = focus_box[2] - focus_box[0], focus_box[3] - focus_box[1]
    train = Image.new("RGB", (W, H * len(images) + fh * 3))
    for i, im in enumerate(images):
        train.paste(im, (0, i * H))
    focus = Image.new("RGB", (W, fh))
    for i, im in enumerate(images[1:]):
        x = (i * fw) % W
        focus.paste(im.crop(focus_box), (x, 0))
    for j in range(3):
        train.paste(focus, (0, H * len(images) + fh * j))
    pal = train.quantize(28, method=Image.Quantize.MEDIANCUT, kmeans=4).getpalette()[:28 * 3]
    for c in RESERVED:
        pal += list(c)
    return [tuple(pal[i:i + 3]) for i in range(0, len(pal), 3)]


def quantize(img, palette):
    p = Image.new("P", (1, 1))
    flat = [v for c in palette for v in c]
    p.putpalette(flat + [0] * (768 - len(flat)))
    return img.quantize(palette=p, dither=Image.Dither.NONE).convert("RGB")


def nearest(c, palette):
    return min(palette, key=lambda p: sum((a - b) ** 2 for a, b in zip(p, c)))


def components(mask_pts):
    """Связные группы точек (4-соседство)."""
    left = set(mask_pts)
    groups = []
    while left:
        start = left.pop()
        q = deque([start])
        g = [start]
        while q:
            x, y = q.popleft()
            for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if n in left:
                    left.remove(n)
                    q.append(n)
                    g.append(n)
        groups.append(g)
    return groups


def is_flame(c):
    r, g, b = c
    return r >= 200 and g >= 120 and b <= 150


def candle_frames(room, frame, palette, count=4, seed=7):
    """Кадры мерцания свечей: у каждого огонька свой ритм — язычок то вытягивается, то приседает.
    Огоньки ищем на пустом зале, а берём только те, что в этой позе не заслонил маг."""
    px, fp = room.load(), frame.load()
    pts = [(x, y) for y in range(H) for x in range(W) if is_flame(px[x, y])]
    flames = [g for g in components(pts) if 1 <= len(g) <= 40
              and all(fp[x, y] == px[x, y] for x, y in g)
              and all(y == 0 or fp[x, y - 1] == px[x, y - 1] for x, y in g)]
    rnd = random.Random(seed)
    phase = {i: rnd.randrange(count) for i in range(len(flames))}
    frames = []
    for f in range(count):
        out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        op = out.load()
        for i, g in enumerate(flames):
            v = (f + phase[i]) % count
            top_y = min(y for _, y in g)
            tips = [(x, y) for x, y in g if y == top_y]
            if v == 1:  # язычок выше на пиксель
                for x, y in tips:
                    if y > 0:
                        op[x, y - 1] = px[x, y] + (255,)
            elif v == 2:  # язычок ниже, огонь чуть тусклее
                for x, y in tips:
                    if y > 0:
                        op[x, y] = px[x, y - 1] + (255,)
                for x, y in g:
                    if (x, y) not in tips:
                        c = px[x, y]
                        op[x, y] = nearest(tuple(int(v_ * 0.82) for v_ in c), palette) + (255,)
            elif v == 3:  # чуть ярче
                for x, y in g:
                    c = px[x, y]
                    op[x, y] = nearest(tuple(min(255, int(v_ * 1.12) + 6) for v_ in c), palette) + (255,)
        frames.append(out)
    return frames, len(flames)


def is_glow(c):
    """Фиолетовый свет фонаря и рун."""
    r, g, b = c
    return b >= 110 and r >= 70 and b > g + 40 and r > g + 10


def glow_variant(layer, palette, factor):
    """Тот же слой мага, но фиолетовый свет ярче или тусклее — мерцание фонаря."""
    out = layer.copy()
    p = out.load()
    for y in range(H):
        for x in range(W):
            r, g, b, a = p[x, y]
            if a and is_glow((r, g, b)):
                c = tuple(max(0, min(255, int(v * factor))) for v in (r, g, b))
                p[x, y] = nearest(c, palette) + (255,)
    return out


def dust_frames(count=8, motes=14, seed=3):
    """Пылинки в лунном луче: от окна вниз влево, медленно."""
    a, b = (196, 66), (132, 118)  # верх и низ луча
    rnd = random.Random(seed)
    specs = [(rnd.random(), rnd.uniform(-9, 9), rnd.choice([150, 110, 80])) for _ in range(motes)]
    frames = []
    for f in range(count):
        out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        op = out.load()
        for t0, off, alpha in specs:
            t = (t0 + f / (count * 3.0)) % 1.0
            x = a[0] + (b[0] - a[0]) * t + off * 0.6
            y = a[1] + (b[1] - a[1]) * t + off
            xi, yi = int(round(x)), int(round(y))
            if 0 <= xi < W and 0 <= yi < H:
                op[xi, yi] = (176, 186, 224, alpha)
        frames.append(out)
    return frames


def crop(img):
    box = img.getbbox()
    if box is None:
        return img.crop((0, 0, 1, 1)), (0, 0, 1, 1)
    return img.crop(box), box


def write_imageset(name, img):
    d = os.path.join(ASSETS, name + ".imageset")
    os.makedirs(d, exist_ok=True)
    img.save(os.path.join(d, name + ".png"), optimize=True)
    with open(os.path.join(d, "Contents.json"), "w") as f:
        json.dump({"images": [{"filename": name + ".png", "idiom": "universal", "scale": "1x"}],
                   "info": {"author": "xcode", "version": 1}}, f, indent=2)


def main():
    room_src = load("room.png")
    frames_src = {p: load("mage_%s.png" % p) for p in POSES}
    palette = build_palette([room_src] + [frames_src[p] for p in POSES])
    room = quantize(room_src, palette)
    frames = {p: quantize(frames_src[p], palette) for p in POSES}

    if os.path.isdir(ASSETS):
        shutil.rmtree(ASSETS)
    os.makedirs(ASSETS)
    with open(os.path.join(ASSETS, "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}, "properties": {"provides-namespace": False}}, f, indent=2)

    layers = []

    def add(name, img, full=False):
        if full:
            write_imageset(name, img)
            layers.append((name, 0, 0, img.width, img.height))
            return
        part, box = crop(img)
        write_imageset(name, part)
        layers.append((name, box[0], box[1], part.width, part.height))

    # Каждая поза — целый кадр: тёмная мантия на тёмной стене почти не отличается от зала,
    # и вырезанный слой выходил бы дырявым. Второй кадр — фонарь (руны) ярче или тусклее.
    for p in POSES:
        full = frames[p].convert("RGBA")
        add("tower_%s0" % p, full, full=True)
        add("tower_%s1" % p, glow_variant(full, palette, 1.25 if p == "cast" else 0.8), full=True)
    n_flames = 0
    for p in POSES:
        cands, n_flames = candle_frames(room, frames[p], palette)
        for i, c in enumerate(cands):
            add("tower_candles_%s%d" % (p, i), c)
    for i, d in enumerate(dust_frames()):
        add("tower_dust%d" % i, d)

    lines = [
        "// Сгенерировано Tools/tower/build_tower.py — не редактировать вручную.",
        "",
        "/// Слои сцены башни 320×200: картинка из Assets/Tower и её место.",
        "enum TowerAtlas {",
        "    static let width = %d" % W,
        "    static let height = %d" % H,
        "    static let candleFrames = 4",
        "    static let dustFrames = 8",
        "",
        "    static let layers: [String: PetLayer] = [",
    ]
    body = ["        \"%s\": PetLayer(name: \"%s\", x: %d, y: %d, w: %d, h: %d)" % (n, n, x, y, w, h)
            for n, x, y, w, h in layers]
    lines.append(",\n".join(body))
    lines += ["    ]", "}", ""]
    with open(SWIFT, "w") as f:
        f.write("\n".join(lines))
    print("layers:", len(layers), "flames:", n_flames)


if __name__ == "__main__":
    main()
