"""Mockup of the dark gothic pixel UI (not shipped; for design review)."""
import sys, os, random
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image, ImageDraw, ImageFont
import dark as D

S = 2  # render scale (pt -> px)
W, H = 390, 844
FONTS = sys.argv[2]
PIX = lambda size: ImageFont.truetype(os.path.join(FONTS, "Tiny5-Bold.ttf"), size * S)
PIXR = lambda size: ImageFont.truetype(os.path.join(FONTS, "Tiny5-Regular.ttf"), size * S)
GOTH = lambda size: ImageFont.truetype(os.path.join(FONTS, "JacquardaBastarda9-Regular.ttf"), size * S)
SANS = lambda size: ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", size * S)
SANSB = lambda size: ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", size * S)

C = {
    "bg": (13, 11, 10), "stone": (27, 24, 22), "stone2": (36, 32, 29), "mortar": (20, 18, 16),
    "gold": (176, 141, 74), "gold_hi": (227, 194, 122), "gold_lo": (94, 74, 38),
    "text": (232, 220, 192), "text2": (156, 143, 120),
    "blood": (122, 22, 16), "blood_hi": (168, 40, 28), "moss": (94, 140, 58), "red": (192, 57, 43),
}


def stone_bg(img):
    d = ImageDraw.Draw(img)
    u = 2 * S
    d.rectangle([0, 0, img.width, img.height], fill=C["bg"])
    rnd = random.Random(3)
    bw, bh = 24, 12
    for row in range(0, H // bh + 2):
        off = (bw // 2) if row % 2 else 0
        for col in range(-1, W // bw + 2):
            x0 = (col * bw + off) * S
            y0 = row * bh * S
            shade = rnd.choice([0, 0, 1, 2])
            fill = [(16, 14, 13), (19, 17, 15), (22, 19, 17)][shade]
            d.rectangle([x0 + u, y0 + u, x0 + bw * S - 1, y0 + bh * S - 1], fill=fill)
            if rnd.random() < 0.3:
                px = x0 + rnd.randint(2, bw - 4) * S
                py = y0 + rnd.randint(2, bh - 3) * S
                d.rectangle([px, py, px + u - 1, py + u - 1], fill=(26, 23, 20))


def frame(d, x0, y0, x1, y1, fill=None, border="gold"):
    """Pixel panel: notched corners, 2-pt gold border with highlight and shadow."""
    u = 2 * S
    X0, Y0, X1, Y1 = x0 * S, y0 * S, x1 * S, y1 * S
    if fill:
        d.rectangle([X0 + u, Y0 + u, X1 - u, Y1 - u], fill=fill)
    g, hi, lo = C[border], C["gold_hi"], C["gold_lo"]
    if border == "blood":
        g, hi, lo = C["gold"], C["gold_hi"], C["gold_lo"]
    # outer lines (skip corners)
    d.rectangle([X0 + u, Y0, X1 - u, Y0 + u - 1], fill=hi)
    d.rectangle([X0 + u, Y1 - u + 1, X1 - u, Y1], fill=lo)
    d.rectangle([X0, Y0 + u, X0 + u - 1, Y1 - u], fill=g)
    d.rectangle([X1 - u + 1, Y0 + u, X1, Y1 - u], fill=g)
    # inner corner pixels
    for (cx, cy) in [(X0 + u, Y0 + u), (X1 - 2 * u + 1, Y0 + u), (X0 + u, Y1 - 2 * u + 1), (X1 - 2 * u + 1, Y1 - 2 * u + 1)]:
        d.rectangle([cx, cy, cx + u - 1, cy + u - 1], fill=g)
    # inner dark line
    d.rectangle([X0 + 2 * u, Y0 + u, X1 - 2 * u, Y0 + u + S - 1], fill=(0, 0, 0))


def text(d, x, y, s, font, fill, shadow=True, anchor="la"):
    if shadow:
        d.text((x * S + S, y * S + S), s, font=font, fill=(0, 0, 0), anchor=anchor)
    d.text((x * S, y * S), s, font=font, fill=fill, anchor=anchor)


def divider(d, x0, x1, y, label, font):
    tw = d.textlength(label, font=font) / S
    mid = (x0 + x1) / 2
    text(d, mid, y, label, font, C["gold"], anchor="mm")
    for (a, b) in [(x0, mid - tw / 2 - 8), (mid + tw / 2 + 8, x1)]:
        d.rectangle([a * S, (y) * S, b * S, y * S + S], fill=C["gold_lo"])
    # diamonds
    for xx in (mid - tw / 2 - 5, mid + tw / 2 + 5):
        d.polygon([(xx * S, (y - 2) * S), ((xx + 2) * S, y * S), (xx * S, (y + 2) * S), ((xx - 2) * S, y * S)], fill=C["gold"])


ICONS = {
    "candle": ["....3...", "...333..", "....3...", "...222..", "...2.2..", "...2.2..", "...2.2..", "..22222."],
    "book": ["........", ".33..33.", "3223322.", "32233223", "32233223", "32233223", ".333333.", "........"],
    "chest": ["........", ".333333.", "32222223", "33333333", "32233223", "32222223", "33333333", "........"],
    "quill": [".......3", "......33", ".....33.", "....33..", "...33...", "..33....", ".2......", "2......."],
    "gear": ["...33...", ".3.33.3.", "..3223..", "33200233", "33200233", "..3223..", ".3.33.3.", "...33..."],
}


def icon(d, name, x, y, color, px=3):
    for r, row in enumerate(ICONS[name]):
        for c, ch in enumerate(row):
            if ch != ".":
                col = color if ch == "3" else tuple(int(v * 0.6) for v in color)
                d.rectangle([(x + c * px) * S, (y + r * px) * S, (x + c * px + px) * S - 1, (y + r * px + px) * S - 1], fill=col)


def tabbar(d, selected):
    y0 = H - 84
    d.rectangle([0, y0 * S, W * S, H * S], fill=(8, 7, 6))
    d.rectangle([0, y0 * S, W * S, y0 * S + 2 * S - 1], fill=C["gold_lo"])
    items = [("candle", "Сегодня"), ("book", "Словарь"), ("chest", "Коллекции"), ("quill", "Глаголы"), ("gear", "Настройки")]
    for i, (ic, label) in enumerate(items):
        cx = W / 5 * (i + 0.5)
        col = C["gold_hi"] if i == selected else (110, 100, 86)
        icon(d, ic, cx - 12, y0 + 10, col)
        text(d, cx, y0 + 44, label, PIXR(11), col, shadow=False, anchor="ma")
    if selected == 0:
        # badge
        bx = W / 10 + 10
        d.rectangle([bx * S, (y0 + 6) * S, (bx + 18) * S, (y0 + 18) * S], fill=C["blood_hi"])
        text(d, bx + 9, y0 + 12, "18", PIX(10), C["text"], shadow=False, anchor="mm")


def status_bar(d):
    text(d, 30, 16, "9:41", SANSB(15), C["text"], shadow=False)


def today():
    img = Image.new("RGB", (W * S, H * S))
    stone_bg(img)
    d = ImageDraw.Draw(img)
    status_bar(d)
    text(d, 20, 50, "Сегодня", PIX(32), C["gold_hi"])
    # pet screen
    g = D.tower_scene(); D.candles(g, 4); D.put(g, D.SPRITES["mage_read"], 34, 12)
    pet = Image.new("RGB", (96, 60))
    for yy, row in enumerate(g):
        for xx, v in enumerate(row):
            pet.putpixel((xx, yy), D.PALETTE[v])
    pw = W - 40
    ph = int(pw * 60 / 96)
    pet = pet.resize((pw * S, ph * S), Image.NEAREST)
    img.paste(pet, (20 * S, 100 * S))
    frame(d, 16, 96, W - 16, 100 + ph + 4)
    text(d, W / 2, 100 + ph + 14, "Сыт и доволен — читает книгу заклинаний", SANS(13), C["text2"], anchor="ma")
    # plan panel
    y = 100 + ph + 42
    frame(d, 16, y, W - 16, y + 150, fill=(24, 21, 19))
    divider(d, 28, W - 28, y + 18, "ПЛАН НА СЕГОДНЯ", PIX(13))
    text(d, 30, y + 34, "18", PIX(44), C["text"])
    text(d, 92, y + 52, "слов", PIX(20), C["text"])
    text(d, W - 30, y + 52, "≈ 6 мин", PIX(20), C["text2"], anchor="ra")
    d.rectangle([30 * S, (y + 92) * S, 36 * S, (y + 98) * S], fill=C["gold"])
    text(d, 42, y + 89, "8 повторить", SANS(13), C["text2"], shadow=False)
    d.rectangle([150 * S, (y + 92) * S, 156 * S, (y + 98) * S], fill=C["blood_hi"])
    text(d, 162, y + 89, "10 новых", SANS(13), C["text2"], shadow=False)
    # button
    by = y + 108
    frame(d, 28, by, W - 28, by + 34, fill=C["blood"])
    d.rectangle([32 * S, (by + 4) * S, (W - 32) * S, (by + 6) * S], fill=C["blood_hi"])
    text(d, W / 2, by + 18, "НАЧАТЬ", PIX(18), C["text"], anchor="mm")
    # forecast
    y2 = y + 166
    frame(d, 16, y2, W - 16, y2 + 120, fill=(24, 21, 19))
    divider(d, 28, W - 28, y2 + 18, "ПОВТОРЕНИЯ НА НЕДЕЛЮ", PIX(13))
    rows = [("Завтра", "12 слов · ≈ 3 мин"), ("Послезавтра", "4 слова · ≈ 1 мин"), ("Вторник, 20 октября", "—"), ("Среда, 21 октября", "9 слов · ≈ 2 мин")]
    for i, (a, b) in enumerate(rows):
        yy = y2 + 32 + i * 21
        text(d, 30, yy, a, SANS(13), C["text"], shadow=False)
        text(d, W - 30, yy, b, SANS(13), C["text2"], shadow=False, anchor="ra")
    tabbar(d, 0)
    return img


def exercise():
    img = Image.new("RGB", (W * S, H * S))
    stone_bg(img)
    d = ImageDraw.Draw(img)
    status_bar(d)
    text(d, 20, 54, "ЗАКРЫТЬ", PIX(14), C["gold"])
    text(d, W / 2, 54, "Сегодня", PIX(17), C["gold_hi"], anchor="ma")
    # progress bar pixel
    frame(d, 20, 84, W - 20, 98, fill=(10, 9, 8))
    d.rectangle([24 * S, 88 * S, 160 * S, 94 * S], fill=C["blood_hi"])
    text(d, W / 2, 128, "Выберите перевод", SANS(13), C["text2"], anchor="ma", shadow=False)
    text(d, W / 2, 150, "o pão", SANSB(36), C["text"], anchor="ma")
    opts = [("хлеб", "ok"), ("сыр", None), ("масло", "bad"), ("молоко", None)]
    for i, (o, st) in enumerate(opts):
        y = 230 + i * 62
        fill = (30, 27, 24)
        if st == "ok":
            fill = (36, 58, 26)
        if st == "bad":
            fill = (70, 18, 14)
        frame(d, 20, y, W - 20, y + 50, fill=fill)
        text(d, 36, y + 15, o, SANS(19), C["text"])
        if st == "ok":
            text(d, W - 40, y + 13, "✓", SANSB(20), (150, 200, 100), anchor="ra")
        if st == "bad":
            text(d, W - 40, y + 13, "✗", SANSB(20), (230, 90, 70), anchor="ra")
    text(d, W / 2, 500, "НЕВЕРНО", PIX(22), C["red"], anchor="ma")
    text(d, W / 2, 530, "Правильный ответ: хлеб", SANSB(16), C["text"], anchor="ma")
    return img


if __name__ == "__main__":
    out = sys.argv[1]
    a, b = today(), exercise()
    pad = 30
    sheet = Image.new("RGB", (a.width * 2 + pad * 3, a.height + pad * 2), (240, 240, 240))
    sheet.paste(a, (pad, pad)); sheet.paste(b, (a.width + pad * 2, pad))
    sheet = sheet.resize((sheet.width // 2, sheet.height // 2), Image.LANCZOS)
    sheet.save(out)
    print(out)
