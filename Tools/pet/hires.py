"""Hi-res pixel art (192x120) for the pet scenes. Rich dark-gothic palette.

Draws with aliased PIL primitives; exports PNG layers for the app.
"""
import random
from PIL import Image, ImageDraw

W, H = 192, 120

P = {
    "void": (7, 7, 10),
    "st0": (14, 13, 18), "st1": (24, 22, 29), "st2": (34, 31, 40), "st3": (48, 44, 56), "st4": (66, 61, 76),
    "wd0": (30, 18, 12), "wd1": (52, 32, 20), "wd2": (78, 50, 30), "wd3": (106, 72, 42),
    "gd0": (96, 72, 34), "gd1": (168, 132, 68), "gd2": (226, 190, 118),
    "fl0": (200, 96, 30), "fl1": (245, 170, 60), "fl2": (255, 236, 180),
    "bl0": (60, 14, 12), "bl1": (124, 26, 20), "bl2": (176, 46, 34),
    "pa0": (150, 132, 100), "pa1": (206, 190, 156), "pa2": (238, 228, 200),
    "rb0": (22, 20, 32), "rb1": (40, 36, 56), "rb2": (62, 56, 84), "rb3": (92, 84, 120),
    "sk0": (10, 12, 26), "sk1": (18, 22, 44), "sk2": (30, 36, 66), "star": (150, 160, 196),
    "bone": (228, 220, 200), "eye": (255, 230, 150),
    "mo0": (36, 70, 40), "mo1": (70, 128, 60), "mo2": (126, 196, 100),
    "ic0": (40, 70, 110), "ic1": (80, 140, 196), "ic2": (170, 214, 245),
}


class Canvas:
    def __init__(self, w=W, h=H, bg=None):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0) if bg is None else P[bg] + (255,))
        self.d = ImageDraw.Draw(self.img)

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((int(x), int(y)), P[c] + (255,) if isinstance(c, str) else c)

    def get(self, x, y):
        return self.img.getpixel((x, y))

    def rect(self, x0, y0, x1, y1, c):
        if x1 < x0 or y1 < y0:
            return
        self.d.rectangle([x0, y0, x1, y1], fill=P[c] + (255,))

    def line(self, pts, c, w=1):
        self.d.line(pts, fill=P[c] + (255,), width=w)

    def ellipse(self, x0, y0, x1, y1, c, outline=None):
        self.d.ellipse([x0, y0, x1, y1], fill=P[c] + (255,) if c else None,
                       outline=P[outline] + (255,) if outline else None)

    def poly(self, pts, c, outline=None):
        self.d.polygon(pts, fill=P[c] + (255,) if c else None, outline=P[outline] + (255,) if outline else None)

    def dither(self, x0, y0, x1, y1, c, density=0.5, seed=0):
        """Ordered dither (Bayer 4x4) over a rect."""
        bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
        for y in range(max(0, y0), min(self.h, y1 + 1)):
            for x in range(max(0, x0), min(self.w, x1 + 1)):
                if (bayer[y % 4][x % 4] + 0.5) / 16 < density:
                    self.px(x, y, c)

    def glow(self, cx, cy, r, c, strength=0.6, mask=None):
        """Radial ordered-dither glow of colour c."""
        bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
        for y in range(int(cy - r), int(cy + r) + 1):
            for x in range(int(cx - r), int(cx + r) + 1):
                if not (0 <= x < self.w and 0 <= y < self.h):
                    continue
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / r
                if d >= 1:
                    continue
                dens = strength * (1 - d) ** 1.6
                if mask and not mask(x, y):
                    continue
                if (bayer[y % 4][x % 4] + 0.5) / 16 < dens:
                    self.px(x, y, c)

    def sprite(self, rows, x, y, legend):
        for r, row in enumerate(rows):
            for c, ch in enumerate(row):
                if ch in legend and legend[ch]:
                    self.px(x + c, y + r, legend[ch])

    def paste(self, other, x, y):
        self.img.alpha_composite(other.img, (x, y))


# ------------------------------------------------------------------ helpers

def scale2x(rows):
    """EPX / Scale2x for char grids ('.' = empty)."""
    h, w = len(rows), len(rows[0])
    g = lambda x, y: rows[y][x] if 0 <= x < w and 0 <= y < h else "."
    out = [[""] * (w * 2) for _ in range(h * 2)]
    for y in range(h):
        for x in range(w):
            P_ = g(x, y)
            A, B, C, D = g(x, y - 1), g(x + 1, y), g(x - 1, y), g(x, y + 1)
            e0 = e1 = e2 = e3 = P_
            if C == A and C != D and A != B:
                e0 = A
            if A == B and A != C and B != D:
                e1 = B
            if D == C and D != B and C != A:
                e2 = C
            if B == D and B != A and D != C:
                e3 = D
            out[2 * y][2 * x] = e0
            out[2 * y][2 * x + 1] = e1
            out[2 * y + 1][2 * x] = e2
            out[2 * y + 1][2 * x + 1] = e3
    return ["".join(r) for r in out]


# ------------------------------------------------------------------ backgrounds

def stone_wall(cv, x0, y0, x1, y1, seed=1, bw=16, bh=8, dark=False):
    rnd = random.Random(seed)
    cv.rect(x0, y0, x1, y1, "st1")
    for row in range((y1 - y0) // bh + 2):
        off = (bw // 2) if row % 2 else 0
        for col in range(-1, (x1 - x0) // bw + 2):
            bx = x0 + col * bw + off
            by = y0 + row * bh
            shade = rnd.choice(["st2", "st2", "st2", "st3", "st1"]) if not dark else rnd.choice(["st1", "st1", "st2"])
            fx0, fy0, fx1, fy1 = max(x0, bx + 1), max(y0, by + 1), min(x1, bx + bw - 1), min(y1, by + bh - 1)
            if fx0 > fx1 or fy0 > fy1:
                continue
            cv.rect(fx0, fy0, fx1, fy1, shade)
            # top highlight, bottom shadow
            hl = "st3" if shade == "st2" else ("st4" if shade == "st3" else "st2")
            if by + 1 >= y0:
                cv.line([(fx0, fy0), (fx1 - 1, fy0)], hl)
            cv.line([(fx0 + 1, fy1), (fx1, fy1)], "st1" if shade != "st1" else "st0")
            # chips and cracks
            if rnd.random() < 0.35:
                cx, cy = rnd.randint(fx0, fx1), rnd.randint(fy0, fy1)
                cv.px(cx, cy, "st1")
                if rnd.random() < 0.5:
                    cv.px(cx + 1, cy + 1, "st1")
            if rnd.random() < 0.12:
                cx = rnd.randint(fx0 + 2, max(fx0 + 2, fx1 - 2))
                for k in range(rnd.randint(2, 5)):
                    cv.px(cx + rnd.choice([-1, 0, 1]), fy0 + k, "st0")


def vignette(cv, strength=0.55):
    """Smooth darkening toward the edges (lighting, not palette dither)."""
    px = cv.img.load()
    for y in range(cv.h):
        for x in range(cv.w):
            dx = abs(x - cv.w / 2) / (cv.w / 2)
            dy = abs(y - cv.h * 0.42) / (cv.h * 0.62)
            d = min(1.0, max(0.0, (dx ** 2 + dy ** 2) ** 0.5 - 0.5) / 0.65)
            k = 1 - strength * d
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (int(r * k), int(g * k), int(b * k), a)


def light(cv, cx, cy, r, color, strength=0.5):
    """Warm light pool: blends pixels toward color with radial falloff."""
    px = cv.img.load()
    cr, cg, cb = P[color]
    for y in range(max(0, int(cy - r)), min(cv.h, int(cy + r) + 1)):
        for x in range(max(0, int(cx - r)), min(cv.w, int(cx + r) + 1)):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / r
            if d >= 1:
                continue
            a = strength * (1 - d) ** 2
            R, G, B, A = px[x, y]
            if A:
                # screen-like blend: brighten toward the light colour
                px[x, y] = (int(R + (cr - R) * a * 0.6 + cr * a * 0.25),
                            int(G + (cg - G) * a * 0.6 + cg * a * 0.25),
                            int(B + (cb - B) * a * 0.6 + cb * a * 0.25), A)
                px[x, y] = tuple(min(255, v) for v in px[x, y][:3]) + (A,)


def wood_floor(cv, y0, seed=2):
    rnd = random.Random(seed)
    cv.rect(0, y0, cv.w - 1, cv.h - 1, "wd1")
    y = y0
    k = 0
    while y < cv.h:
        hgt = 4 + (k // 2)  # boards get taller toward the viewer (perspective)
        cv.rect(0, y, cv.w - 1, min(cv.h - 1, y + hgt - 1), "wd1" if k % 2 == 0 else "wd2")
        cv.line([(0, y), (cv.w - 1, y)], "wd0")
        cv.line([(0, y + 1), (cv.w - 1, y + 1)], "wd2" if k % 2 == 0 else "wd3")
        x = rnd.randint(-30, 10)
        while x < cv.w:
            x += rnd.randint(28, 56)
            cv.line([(x, y + 1), (x, y + hgt - 1)], "wd0")
            # grain
            gx = x + rnd.randint(4, 20)
            cv.line([(gx, y + 2 + hgt // 3), (gx + rnd.randint(4, 10), y + 2 + hgt // 3)], "wd0" if k % 2 else "wd1")
        y += hgt
        k += 1


def arched_window(cv, x0, y0, x1, y1, moon=True, seed=3):
    rnd = random.Random(seed)
    w = x1 - x0
    r = w / 2
    cx = (x0 + x1) / 2
    top = y0 + r

    def inside(x, y, pad=0):
        if y >= top:
            return x0 + pad <= x <= x1 - pad and y <= y1 - pad
        return (x - cx) ** 2 + (y - top) ** 2 <= (r - pad) ** 2 and y >= y0 + pad

    # stone frame (voussoirs)
    for y in range(int(y0) - 5, int(y1) + 4):
        for x in range(int(x0) - 5, int(x1) + 6):
            if inside(x, y, -4) and not inside(x, y, 0):
                cv.px(x, y, "st3" if (x + y) % 7 else "st2")
    # embrasure (deep sides): left lit, right dark
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            if inside(x, y, 0) and not inside(x, y, 3):
                cv.px(x, y, "st4" if x < cx else "st1")
    # sky
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            if inside(x, y, 3):
                t = (y - y0) / (y1 - y0)
                c = "sk0" if t < 0.35 else ("sk1" if t < 0.75 else "sk2")
                cv.px(x, y, c)
    # sky dithering bands
    cv.dither(int(x0), int(y0 + (y1 - y0) * 0.30), int(x1), int(y0 + (y1 - y0) * 0.40), "sk1", 0.5)
    cv.dither(int(x0), int(y0 + (y1 - y0) * 0.70), int(x1), int(y0 + (y1 - y0) * 0.80), "sk2", 0.5)
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            if not inside(x, y, 3) and inside(x, y, 0):
                pass
    # moon with glow
    if moon:
        mx, my, mr = cx + w * 0.18, y0 + r * 0.9, 6
        cv.glow(mx, my, 16, "sk2", 0.5, mask=lambda x, y: inside(x, y, 3))
        for y in range(int(my - mr), int(my + mr) + 1):
            for x in range(int(mx - mr), int(mx + mr) + 1):
                d1 = (x - mx) ** 2 + (y - my) ** 2
                d2 = (x - mx + 3) ** 2 + (y - my + 2) ** 2
                if d1 <= mr * mr and d2 > (mr - 1) ** 2 and inside(x, y, 3):
                    cv.px(x, y, "bone")
    # stars
    for _ in range(int(w * 0.6)):
        x, y = rnd.randint(int(x0) + 4, int(x1) - 4), rnd.randint(int(y0) + 4, int(y1) - 6)
        if inside(x, y, 4) and cv.get(x, y)[:3] in (P["sk0"], P["sk1"], P["sk2"]):
            cv.px(x, y, "star" if rnd.random() < 0.7 else "bone")
    # lead cames: cross bars
    for y in range(int(y0) + 3, int(y1) + 1):
        if inside(cx, y, 3):
            cv.px(int(cx), y, "st0")
    yb = int(top + (y1 - top) * 0.35)
    for x in range(int(x0), int(x1) + 1):
        if inside(x, yb, 3):
            cv.px(x, yb, "st0")
    # sill
    cv.rect(int(x0) - 7, int(y1) + 1, int(x1) + 7, int(y1) + 3, "st4")
    cv.line([(int(x0) - 7, int(y1) + 1), (int(x1) + 7, int(y1) + 1)], "pa0")
    cv.line([(int(x0) - 6, int(y1) + 4), (int(x1) + 6, int(y1) + 4)], "st0")
    return inside


BOOK_COLORS = [("bl1", "bl2"), ("rb2", "rb3"), ("mo0", "mo1"), ("wd2", "wd3"), ("gd0", "gd1"), ("st3", "st4"), ("bl0", "bl1")]


def bookshelf(cv, x0, y0, x1, y1, seed=5):
    rnd = random.Random(seed)
    cv.rect(x0, y0, x1, y1, "wd0")
    cv.rect(x0 + 3, y0 + 3, x1 - 3, y1, "st0")
    # frame highlights
    cv.line([(x0, y0), (x1, y0)], "wd3")
    cv.line([(x0, y0), (x0, y1)], "wd2")
    cv.line([(x1, y0), (x1, y1)], "wd1")
    cv.rect(x0 - 1, y0 - 2, x1 + 1, y0, "wd2")
    cv.line([(x0 - 1, y0 - 2), (x1 + 1, y0 - 2)], "wd3")
    shelves = [y0 + 3 + (y1 - y0 - 3) * k // 3 for k in range(1, 4)]
    top = y0 + 3
    for sy in shelves:
        cv.rect(x0 + 1, sy - 1, x1 - 1, sy + 1, "wd2")
        cv.line([(x0 + 1, sy - 1), (x1 - 1, sy - 1)], "wd3")
        x = x0 + 4
        while x < x1 - 4:
            if rnd.random() < 0.08:
                x += 3
                continue
            bw = rnd.choice([2, 3, 3, 4])
            if x + bw > x1 - 4:
                break
            bh = rnd.randint(max(5, sy - top - 8), sy - top - 3)
            c0, c1 = rnd.choice(BOOK_COLORS)
            lean = rnd.random() < 0.07
            cv.rect(x, sy - 1 - bh, x + bw - 1, sy - 2, c0)
            cv.line([(x, sy - 1 - bh), (x, sy - 2)], c1)
            # spine bands
            cv.line([(x, sy - bh + 1), (x + bw - 1, sy - bh + 1)], "gd1" if rnd.random() < 0.5 else c1)
            if bh > 8:
                cv.line([(x, sy - 5), (x + bw - 1, sy - 5)], "gd0")
            x += bw + (1 if rnd.random() < 0.25 else 0)
        top = sy + 2


def lectern(cv, x, y):
    """Wooden lectern; book is drawn separately (animated). Top board at (x..x+34, y)."""
    # slanted top board
    for i in range(36):
        cv.px(x + i, y + 14 - i // 6, "wd2")
        cv.px(x + i, y + 15 - i // 6, "wd1")
        cv.px(x + i, y + 16 - i // 6, "wd0")
    # post with carving
    cv.rect(x + 14, y + 16, x + 21, y + 40, "wd1")
    cv.line([(x + 14, y + 16), (x + 14, y + 40)], "wd3")
    cv.line([(x + 21, y + 16), (x + 21, y + 40)], "wd0")
    for k in range(3):
        cv.rect(x + 13, y + 20 + k * 7, x + 22, y + 21 + k * 7, "wd2")
    # feet
    cv.rect(x + 6, y + 40, x + 29, y + 43, "wd1")
    cv.line([(x + 6, y + 40), (x + 29, y + 40)], "wd3")
    cv.line([(x + 6, y + 43), (x + 29, y + 43)], "wd0")


def open_book(cv, x, y, glow=True, turn=0):
    """Open book ~36x16 on the lectern; pages curve to the spine."""
    spine = x + 18
    for i in range(36):
        xx = x + i
        d = abs(xx - spine + 0.5) / 18
        top = y + round(3 * (1 - d) ** 0.7) - i // 6
        bot = top + 11
        cv.line([(xx, top), (xx, bot)], "pa2" if i % 18 not in (0, 17) else "pa1")
        cv.px(xx, top - 1, "pa0")
        cv.px(xx, bot + 1, "pa0")
        cv.px(xx, bot + 2, "bl0")   # cover edge
        # text lines
        if i not in (0, 1, 16, 17, 18, 19, 34, 35):
            for k, ty in enumerate(range(top + 2, bot - 1, 2)):
                if (i * 7 + k * 3) % 9 not in (0, 4):
                    cv.px(xx, ty, "pa0")
        # illuminated initial
        if i in (3, 4, 5) :
            for ty in range(top + 2, top + 6):
                cv.px(xx, ty, "bl1")
            cv.px(xx, top + 2, "gd1")
    for yy in range(y - 2, y + 13):
        cv.px(spine, yy - 3, "pa0")
    # ribbon
    cv.line([(spine + 1, y + 11 - 3), (spine + 1, y + 17 - 3)], "bl1")
    if turn:
        # page lifting
        for i in range(10):
            xx = x + 4 + i
            yy = y - 4 - (5 - abs(i - 5))
            cv.line([(xx, yy), (xx, yy + 6)], "pa2")
            cv.px(xx, yy, "pa1")
    if glow:
        cv.glow(spine, y - 6, 18, "gd2", 0.22)


def wall_shelf(cv, x0, x1, y):
    cv.rect(x0, y, x1, y + 2, "wd2")
    cv.line([(x0, y), (x1, y)], "wd3")
    cv.line([(x0, y + 3), (x1, y + 3)], "st0")
    for bx in (x0 + 3, x1 - 4):
        cv.poly([(bx, y + 3), (bx + 2, y + 3), (bx + 2, y + 8)], "wd1")


def candle(cv, x, y, lit=True, frame=0, h=12):
    """Candle at base (x, y) bottom; width 4."""
    cv.rect(x, y - h, x + 3, y, "pa1")
    cv.line([(x, y - h), (x, y)], "pa2")
    cv.line([(x + 3, y - h), (x + 3, y)], "pa0")
    # drips
    cv.px(x + 1, y - h + 2, "pa2")
    cv.px(x + 2, y - h + 4, "pa0")
    cv.px(x + 1, y - h - 1, "st0")  # wick
    if lit:
        fy = y - h - 2
        dx = (0, 1, 0, -1)[frame % 4]
        cv.px(x + 1 + dx, fy - 4, "fl0")
        cv.rect(x + 1, fy - 3, x + 2, fy, "fl1")
        cv.px(x + 1, fy - 1, "fl2")
        cv.px(x + 2, fy - 2, "fl2")
        cv.px(x, fy - 1, "fl0")
        cv.px(x + 3, fy - 1, "fl0")
    else:
        # smoke wisp
        sx = x + 1
        for k, (ox, oy) in enumerate([(0, -3), (1, -5), (0, -7), (-1, -9), (0, -11)]):
            cv.px(sx + ox + (frame % 2), y - h + oy, "st3" if k < 3 else "st2")


# ------------------------------------------------------------------ mage (hi-res from the 28x35 profile via Scale2x)

def mage_hi(pose="read", phase=0):
    import side
    rows = side.mage_side(pose, phase)
    big = scale2x(rows)
    h, w = len(big), len(big[0])
    mask = {(x, y) for y in range(h) for x in range(w) if big[y][x] != "."}
    cv = Canvas(w + 2, h + 2)
    face = {(x, y) for (x, y) in mask if big[y][x] == "0" and y < 34}
    bright = {(x, y) for (x, y) in mask if big[y][x] == "3"}
    # eyes: bright pixels touching the face shadow
    eyes = {p for p in bright if any((p[0] + dx, p[1] + dy) in face for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))}
    # hands / flask: bright pixels beyond the robe front at chest height
    hands = {p for p in bright if p not in eyes and p[0] >= 34 and 18 <= p[1] <= 50}
    flask = set()
    if pose == "drink":
        flask = {p for p in bright if p not in eyes and 30 <= p[0] <= 44 and 14 <= p[1] <= 34}
        hands -= flask
    bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    for (x, y) in mask:
        if (x, y) in face:
            c = "void"
        else:
            out_r = (x + 1, y) not in mask
            out_l = (x - 1, y) not in mask
            out_u = (x, y - 1) not in mask
            out_d = (x, y + 1) not in mask
            if out_r:
                c = "gd1" if 30 <= y <= 60 else "rb3"   # warm rim from the book, cool above
            elif out_l or out_u or out_d:
                c = "rb0"
            else:
                # body shading: lighter toward the front/top, darker at the back/bottom
                t = (y / h) * 0.6 + (1 - x / w) * 0.5
                c = "rb2" if t < 0.45 else "rb1"
                if t > 0.72 and (bayer[y % 4][x % 4] + 0.5) / 16 < (t - 0.72) * 1.6:
                    c = "rb0"
                # second rim pixel at the front
                if (x + 2, y) not in mask and 30 <= y <= 60:
                    c = "gd0"
        cv.px(x + 1, y + 1, c)
    # hood inner edge highlight around the face
    for (x, y) in face:
        for dx, dy in ((-1, 0), (0, -1)):
            q = (x + dx, y + dy)
            if q in mask and q not in face:
                cv.px(q[0] + 1, q[1] + 1, "rb3")
    for (x, y) in eyes:
        cv.px(x + 1, y + 1, "eye")
    for (x, y) in hands:
        cv.px(x + 1, y + 1, "pa1" if (x + y) % 3 else "pa0")
    for (x, y) in flask:
        cv.px(x + 1, y + 1, "mo2" if y > 22 else "pa2")
    # robe folds
    for fx in (12, 20, 28):
        for y in range(44, h - 3):
            if (fx, y) in mask and (fx + 1, y) in mask:
                cv.px(fx + 1, y + 1, "rb0")
    return cv


# ------------------------------------------------------------------ dungeon

def dungeon_wall(cv, x0, y0, x1, y1, seed=7):
    rnd = random.Random(seed)
    cv.rect(x0, y0, x1, y1, "st0")
    y = y0
    while y < y1:
        h = rnd.choice([9, 10, 11, 12])
        x = x0 - rnd.randint(0, 14)
        while x < x1:
            w = rnd.choice([14, 18, 20, 24])
            shade = rnd.choice(["st1", "st1", "st2"])
            cv.rect(max(x0, x + 1), y + 1, min(x1, x + w - 1), min(y1, y + h - 1), shade)
            cv.line([(max(x0, x + 1), y + 1), (min(x1, x + w - 2), y + 1)], "st2" if shade == "st1" else "st3")
            cv.line([(max(x0, x + 2), min(y1, y + h - 1)), (min(x1, x + w - 1), min(y1, y + h - 1))], "st0")
            # damp moss / stains
            if rnd.random() < 0.25:
                mx = rnd.randint(x + 2, x + w - 3)
                for k in range(rnd.randint(2, 6)):
                    cv.px(mx + rnd.randint(-2, 2), y + h - 2 - rnd.randint(0, 2), "mo0")
            if rnd.random() < 0.2:
                cx = rnd.randint(x + 2, x + w - 3)
                for k in range(rnd.randint(3, 7)):
                    cv.px(cx + rnd.choice([-1, 0, 0, 1]), y + 2 + k, "void")
            x += w
        y += h


def barred_window(cv, x0, y0, x1, y1):
    cv.rect(x0 - 2, y0 - 2, x1 + 2, y1 + 2, "st3")
    cv.rect(x0, y0, x1, y1, "sk0")
    cv.dither(x0, y0 + (y1 - y0) // 2, x1, y1, "sk1", 0.5)
    for x in range(x0 + 3, x1, 5):
        cv.rect(x, y0, x + 1, y1, "st0")
        cv.px(x, y0, "st3")
    cv.line([(x0 - 2, y1 + 2), (x1 + 2, y1 + 2)], "pa0")


def light_shaft(cv, x0, x1, y0, y1, slope=0.45, strength=0.18):
    px = cv.img.load()
    cr, cg, cb = P["ic2"]
    for y in range(y0, y1):
        off = int((y - y0) * slope)
        for x in range(x0 + off, x1 + off):
            if 0 <= x < cv.w:
                t = 1 - (y - y0) / (y1 - y0)
                a = strength * t
                R, G, B, A = px[x, y]
                px[x, y] = (int(R + (cr - R) * a), int(G + (cg - G) * a), int(B + (cb - B) * a), A)


def straw_floor(cv, y0, seed=8):
    rnd = random.Random(seed)
    cv.rect(0, y0, cv.w - 1, cv.h - 1, "st1")
    cv.line([(0, y0), (cv.w - 1, y0)], "st3")
    # flagstones
    for row, y in enumerate(range(y0 + 1, cv.h, 7)):
        x = -rnd.randint(0, 20)
        while x < cv.w:
            w = rnd.randint(16, 30)
            cv.rect(max(0, x + 1), y + 1, min(cv.w - 1, x + w - 1), min(cv.h - 1, y + 6), rnd.choice(["st1", "st2"]))
            x += w
    for _ in range(140):
        x, y = rnd.randint(0, cv.w - 4), rnd.randint(y0 + 2, cv.h - 2)
        c = rnd.choice(["gd0", "gd0", "wd2", "gd1"])
        cv.line([(x, y), (x + rnd.randint(2, 4), y + rnd.choice([-1, 0, 1]))], c)


def front_bars(cv, x0, x1):
    for x in range(x0, x1, 9):
        cv.rect(x, 0, x + 2, cv.h - 1, "st0")
        cv.line([(x, 0), (x, cv.h - 1)], "st3")
        cv.line([(x + 1, 0), (x + 1, cv.h - 1)], "st2")
    for y in (14, 80):
        cv.rect(x0 - 3, y, cv.w - 1, y + 3, "st0")
        cv.line([(x0 - 3, y), (cv.w - 1, y)], "st3")
        for x in range(x0, x1, 9):
            cv.px(x + 1, y + 1, "st4")


def chain(cv, x, y0, y1):
    for y in range(y0, y1):
        k = (y - y0) % 4
        if k in (0, 2):
            cv.px(x, y, "st4")
        else:
            cv.px(x - 1, y, "st3")
            cv.px(x + 1, y, "st3")


def recolor_grey(rows, mapping):
    cv = Canvas(len(rows[0]), len(rows))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != "." and mapping.get(ch):
                cv.px(x, y, mapping[ch])
    return cv


# ------------------------------------------------------------------ hungry mage (front, thin, shaking fists)

def mage_angry_hi(phase=0):
    import dark
    W_, H_ = 60, 76
    cv = Canvas(W_, H_)
    cx = 30
    mask = set()
    # hood
    for (x, y) in dark.ellipse(cx, 20, 12.5, 13):
        mask.add((x, y))
    for (x, y) in dark.hood_tip(cx + 2, 10, cx + 12, 0, 6):
        mask.add((x, y))
    # thin ragged robe
    for y in range(30, H_ - 2):
        t = (y - 30) / (H_ - 32)
        l = round(cx - 9 - 3 * t)
        r = round(cx + 9 + 3 * t)
        for x in range(l, r + 1):
            mask.add((x, y))
    # ragged hem
    for x in range(0, W_):
        for k in range(1, 5):
            if (x * 7 + k * 3) % 5 < (k + 1) // 2 + 1:
                mask.discard((x, H_ - 2 - k + 1))
    # arms raised: thin sleeves going up-out
    d = 1 if phase else 0
    arms = []
    for i in range(14):
        arms.append((cx - 10 - i // 2 - d, 34 - i))
        arms.append((cx + 10 + i // 2 + d, 34 - i))
    for (x, y) in arms:
        for dx in (-1, 0, 1):
            mask.add((x + dx, y))
    bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    for (x, y) in mask:
        out_r = (x + 1, y) not in mask
        out_any = any((x + dx, y + dy) not in mask for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if out_r:
            c = "st4"      # cold moonlight rim
        elif out_any:
            c = "rb0"
        else:
            c = "rb1" if (bayer[y % 4][x % 4] + 0.5) / 16 > 0.25 + y / H_ * 0.4 else "rb0"
        cv.px(x, y, c)
    # face opening
    for (x, y) in dark.ellipse(cx - 1, 22, 8.5, 8):
        if (x, y) in mask:
            cv.px(x, y, "void")
    # angry red eyes (slanted)
    for (x, y) in [(cx - 6, 19), (cx - 5, 20), (cx - 4, 20), (cx - 5, 21), (cx - 4, 21),
                   (cx + 4, 19), (cx + 3, 20), (cx + 2, 20), (cx + 3, 21), (cx + 2, 21)]:
        cv.px(x, y, "bl2")
    cv.px(cx - 5, 20, "fl1"); cv.px(cx + 3, 20, "fl1")
    # shouting mouth
    cv.rect(cx - 3, 25 + d, cx + 1, 27 + d, "bl0")
    # ribs through the torn robe
    for k, y in enumerate((36, 40, 44)):
        for x in range(cx - 6, cx + 6):
            if (x, y) in mask:
                cv.px(x, y, "pa0" if abs(x - cx) > 1 else "rb0")
    # bony fists
    for sx in (-1, 1):
        fx = cx + sx * (17 + d) - (2 if sx < 0 else 0)
        fy = 18 - d
        cv.rect(fx, fy, fx + 3, fy + 3, "pa1")
        cv.line([(fx, fy), (fx + 3, fy)], "pa2")
        cv.px(fx + 1, fy + 1, "pa0"); cv.px(fx + 2, fy + 2, "pa0")
        cv.px(fx + (0 if sx < 0 else 3), fy + 3, "pa0")
    return cv


def thought_bubble_potion():
    cv = Canvas(30, 28)
    cv.ellipse(2, 0, 28, 20, "pa2", outline="pa0")
    cv.ellipse(4, 2, 26, 18, "pa2")
    # potion inside
    cv.rect(13, 3, 16, 5, "wd2")            # cork
    cv.rect(13, 6, 16, 8, "ic2")            # neck
    cv.ellipse(9, 8, 20, 18, "mo2", outline="mo0")
    cv.rect(11, 9, 18, 11, "ic2")           # glass top (air)
    cv.px(11, 12, "pa2"); cv.px(11, 13, "pa2")
    # trail
    cv.ellipse(4, 21, 8, 24, "pa2", outline="pa0")
    cv.ellipse(1, 25, 3, 27, "pa2")
    return cv


def heart_hi():
    rows = [
        ".##..##.",
        "########",
        "########",
        ".######.",
        "..####..",
        "...##...",
    ]
    cv = Canvas(8, 6)
    cv.sprite(rows, 0, 0, {"#": "bl2"})
    cv.px(1, 1, "fl2"); cv.px(2, 1, "pa2")
    return cv


# ------------------------------------------------------------------ rooms (backgrounds without dynamic parts)

def room_base(cv, wall="stone", floor="wood", seed=1):
    if wall == "stone":
        stone_wall(cv, 0, 0, W - 1, 92, seed=seed)
    else:
        dungeon_wall(cv, 0, 0, W - 1, 92, seed=seed)
    cv.rect(0, 92, W - 1, 94, "st0")
    cv.line([(0, 92), (W - 1, 92)], "st3")
    if floor == "wood":
        wood_floor(cv, 95)
    else:
        straw_floor(cv, 93, seed=seed + 3)


def rug(cv):
    cv.rect(52, 100, 140, 114, "bl0")
    cv.rect(54, 101, 138, 113, "bl1")
    cv.rect(56, 102, 136, 112, "bl0")
    for x in range(58, 136, 6):
        cv.px(x, 104, "gd1"); cv.px(x + 3, 110, "gd1")
    cv.line([(54, 101), (138, 101)], "gd0")


def barrels(cv, x0, y1):
    def barrel(x, y, w=16, h=20):
        cv.ellipse(x, y, x + w, y + h, "wd1", outline="wd0")
        cv.rect(x + 2, y + 1, x + w - 2, y + h - 1, "wd1")
        for k in range(x + 3, x + w - 2, 3):
            cv.line([(k, y + 1), (k, y + h - 1)], "wd2" if k % 2 else "wd0")
        for hy in (y + 4, y + h - 5):
            cv.line([(x + 1, hy), (x + w - 1, hy)], "st3")
        cv.line([(x + 2, y + 1), (x + w - 2, y + 1)], "wd3")
    barrel(x0, y1 - 20)
    barrel(x0 + 17, y1 - 20)
    barrel(x0 + 8, y1 - 40)
    # crate
    cv.rect(x0 + 30, y1 - 14, x0 + 44, y1, "wd2")
    cv.rect(x0 + 31, y1 - 13, x0 + 43, y1 - 1, "wd1")
    cv.line([(x0 + 31, y1 - 13), (x0 + 43, y1 - 1)], "wd0")
    cv.line([(x0 + 43, y1 - 13), (x0 + 31, y1 - 1)], "wd0")


def cobweb(cv, x, y, flip=False):
    s = -1 if flip else 1
    for i in range(12):
        cv.px(x + s * i, y + i // 3, "st4")
        cv.px(x + s * (i // 3), y + i, "st4")
    for r in (4, 8):
        for i in range(r + 1):
            cv.px(x + s * i, y + r - i, "st3")


def small_window(cv, x0, y0):
    inside = arched_window(cv, x0, y0, x0 + 18, y0 + 26, moon=False, seed=9)
    return inside


def fireplace(cv, x0, y1):
    # stone mantel
    cv.rect(x0, y1 - 44, x0 + 42, y1, "st3")
    cv.rect(x0 - 3, y1 - 48, x0 + 45, y1 - 44, "st4")
    cv.line([(x0 - 3, y1 - 48), (x0 + 45, y1 - 48)], "pa0")
    for y in range(y1 - 42, y1, 6):
        cv.line([(x0, y), (x0 + 42, y)], "st2")
    # opening
    cv.rect(x0 + 6, y1 - 30, x0 + 36, y1, "void")
    cv.ellipse(x0 + 6, y1 - 38, x0 + 36, y1 - 22, "void")
    # logs
    cv.rect(x0 + 10, y1 - 4, x0 + 32, y1 - 1, "wd1")
    cv.line([(x0 + 10, y1 - 4), (x0 + 32, y1 - 4)], "wd3")


def fire(cv, x0, y1, frame=0):
    """Animated flames inside the fireplace opening."""
    import math
    for i in range(22):
        x = x0 + 11 + i
        hgt = 8 + int(6 * abs(math.sin((i + frame * 3) * 0.7))) + (3 if 6 < i < 16 else 0)
        for k in range(hgt):
            c = "fl2" if k < hgt * 0.3 else ("fl1" if k < hgt * 0.7 else "fl0")
            cv.px(x, y1 - 5 - k, c)


def banner(cv, x0, y0, w=24, h=40):
    cv.line([(x0 - 2, y0), (x0 + w + 2, y0)], "wd2")
    cv.rect(x0, y0 + 1, x0 + w, y0 + h, "bl1")
    cv.line([(x0, y0 + 1), (x0, y0 + h)], "bl2")
    cv.line([(x0 + w, y0 + 1), (x0 + w, y0 + h)], "bl0")
    # swallowtail
    for i in range(w + 1):
        cut = abs(i - w / 2) / (w / 2)
        for y in range(y0 + h - 6 + int(6 * (1 - cut)), y0 + h + 1):
            cv.px(x0 + i, y, "st1")
    # gold emblem: a book with a star
    cx, cy = x0 + w // 2, y0 + 14
    cv.rect(cx - 6, cy - 4, cx + 6, cy + 4, "gd1")
    cv.line([(cx, cy - 4), (cx, cy + 4)], "gd0")
    cv.rect(cx - 5, cy - 3, cx - 1, cy + 3, "gd2")
    cv.rect(cx + 1, cy - 3, cx + 5, cy + 3, "gd2")
    cv.px(cx, cy - 9, "gd2"); cv.px(cx - 1, cy - 8, "gd1"); cv.px(cx + 1, cy - 8, "gd1"); cv.px(cx, cy - 7, "gd1")
    cv.line([(x0 + 2, y0 + 26), (x0 + w - 2, y0 + 26)], "gd0")


def telescope(cv, x0, y1):
    # tripod
    cv.line([(x0 + 14, y1 - 30), (x0 + 4, y1)], "wd1", 2)
    cv.line([(x0 + 14, y1 - 30), (x0 + 24, y1)], "wd1", 2)
    cv.line([(x0 + 14, y1 - 30), (x0 + 14, y1)], "wd0", 1)
    # tube (brass), angled up-right
    for i in range(34):
        x = x0 + 2 + i
        y = y1 - 26 - i // 2
        r = 3 if i < 24 else 4
        cv.line([(x, y - r), (x, y + r)], "gd1")
        cv.px(x, y - r, "gd2")
        cv.px(x, y + r, "gd0")
    cv.line([(x0 + 26, y1 - 43), (x0 + 26, y1 - 31)], "gd0")


def summit_sky(cv, seed=4):
    rnd = random.Random(seed)
    # open sky above the parapet
    for y in range(0, 62):
        t = y / 62
        c = "sk0" if t < 0.4 else ("sk1" if t < 0.8 else "sk2")
        cv.line([(0, y), (W - 1, y)], c)
    cv.dither(0, 22, W - 1, 28, "sk1", 0.5)
    cv.dither(0, 46, W - 1, 52, "sk2", 0.5)
    for _ in range(130):
        x, y = rnd.randint(0, W - 1), rnd.randint(0, 58)
        cv.px(x, y, "star" if rnd.random() < 0.8 else "bone")
    # big moon
    mx, my = 150, 20
    light(cv, mx, my, 30, "ic2", 0.25)
    cv.ellipse(mx - 9, my - 9, mx + 9, my + 9, "bone")
    for (x, y, c) in [(mx - 3, my - 2, "pa1"), (mx + 2, my + 3, "pa1"), (mx + 4, my - 4, "pa1"), (mx - 4, my + 4, "pa1")]:
        cv.rect(x, y, x + 1, y + 1, c)
    # parapet with crenellations
    cv.rect(0, 62, W - 1, 92, "st2")
    stone_wall(cv, 0, 62, W - 1, 92, seed=seed + 5)
    for x in range(0, W, 24):
        cv.rect(x, 54, x + 13, 62, "st3")
        cv.line([(x, 54), (x + 13, 54)], "st4")
        cv.line([(x + 13, 54), (x + 13, 62)], "st1")


def make_room(kind):
    cv = Canvas(bg="st1")
    if kind == "cellar":
        room_base(cv, wall="stone", floor="straw", seed=11)
        small_window(cv, 150, 10)
        barrels(cv, 4, 93)
        cobweb(cv, 0, 0)
        cobweb(cv, W - 1, 0, flip=True)
    elif kind == "hall":
        room_base(cv, wall="stone", floor="wood", seed=12)
        rug(cv)
        arched_window(cv, 140, 14, 176, 70)
        fireplace(cv, 4, 93)
        banner(cv, 104, 6)
    elif kind == "library":
        room_base(cv, wall="stone", floor="wood", seed=1)
        rug(cv)
        arched_window(cv, 140, 14, 176, 70)
        bookshelf(cv, 6, 30, 46, 92)
    elif kind == "summit":
        summit_sky(cv)
        cv.rect(0, 92, W - 1, 94, "st0")
        cv.line([(0, 92), (W - 1, 92)], "st3")
        straw_floor(cv, 93, seed=21)
        telescope(cv, 150, 92)
    elif kind == "dungeon":
        room_base(cv, wall="dungeon", floor="straw", seed=7)
        barred_window(cv, 80, 10, 108, 28)
    if kind != "summit" and kind != "dungeon":
        pass
    wall_shelf(cv, 8, 58, 22)
    lectern_x = 104
    if kind != "dungeon":
        lectern(cv, lectern_x, 52)
    return cv


def room_lighting(cv, kind, lit):
    for i in range(lit):
        light(cv, 14 + i * 12, 6, 22, "fl1", 0.35)
    if kind != "dungeon":
        light(cv, 121, 44, 34, "gd2", 0.4 if kind != "cellar" else 0.3)
    if kind in ("library", "hall"):
        light(cv, 158, 40, 30, "ic1", 0.18)
    if kind == "hall":
        light(cv, 25, 80, 40, "fl1", 0.45)
    if kind == "dungeon":
        light_shaft(cv, 80, 108, 29, 93)
    vignette(cv, 0.6 if kind != "dungeon" else 0.7)


# ------------------------------------------------------------------ items for learned words

def item_cauldron(frame=0):
    cv = Canvas(30, 24)
    cv.ellipse(2, 6, 28, 24, "st0", outline="st2")
    cv.ellipse(4, 6, 26, 12, "mo1")
    cv.ellipse(6, 7, 24, 11, "mo2")
    cv.line([(2, 9), (28, 9)], "st3")
    for (x, y) in [(10, 4 - frame % 2), (16, 2 + frame % 2), (21, 5 - frame % 2)]:
        cv.ellipse(x, y, x + 2, y + 2, "mo2")
    cv.rect(6, 22, 8, 24, "st2"); cv.rect(22, 22, 24, 24, "st2")
    cv.px(5, 12, "st4"); cv.px(4, 15, "st3")
    return cv


def item_raven(frame=0):
    rows = [
        "......###....",
        ".....#####...",
        "....###o###..",
        "....#######>>",
        "...#########.",
        "..##########.",
        ".###########.",
        "############.",
        ".##########..",
        "..########...",
        "...######....",
        "....#..#.....",
        "...##..##....",
    ]
    cv = Canvas(14, 13)
    cv.sprite(rows, 0, 0, {"#": "rb0", "o": "eye", ">": "gd1"})
    # moonlit rim on the back and head
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == "#" and (y == 0 or rows[y - 1][x] == "."):
                cv.px(x, y, "rb3")
    cv.px(5, 5, "rb2"); cv.px(6, 6, "rb2"); cv.px(4, 8, "rb2"); cv.px(3, 9, "rb2")
    if frame % 4 == 1:
        cv.px(7, 2, "rb0")  # blink
    return cv


def item_crystal_ball(frame=0):
    cv = Canvas(18, 24)
    cv.ellipse(1, 0, 17, 16, "ic0", outline="ic1")
    cv.ellipse(3, 2, 15, 14, "ic1")
    cv.ellipse(5 + frame % 2, 4, 11 + frame % 2, 10, "ic2")
    cv.px(5, 3, "pa2"); cv.px(6, 3, "pa2"); cv.px(5, 4, "pa2")
    # stand
    cv.poly([(4, 16), (14, 16), (12, 19), (6, 19)], "gd1")
    cv.rect(7, 19, 11, 22, "wd1")
    cv.rect(3, 22, 15, 23, "wd2")
    return cv


def item_star_map():
    cv = Canvas(30, 18)
    cv.rect(0, 0, 29, 17, "pa1")
    cv.rect(1, 1, 28, 16, "pa2")
    cv.line([(0, 0), (29, 0)], "wd2"); cv.line([(0, 17), (29, 17)], "wd2")
    for (x, y) in [(5, 4), (9, 7), (14, 5), (20, 9), (24, 4), (17, 12), (7, 12)]:
        cv.px(x, y, "rb2")
    cv.line([(5, 4), (9, 7)], "pa0"); cv.line([(9, 7), (14, 5)], "pa0"); cv.line([(14, 5), (20, 9)], "pa0")
    cv.line([(20, 9), (24, 4)], "pa0"); cv.line([(17, 12), (20, 9)], "pa0")
    cv.ellipse(3, 9, 9, 15, None, outline="bl1")
    return cv


def item_hourglass(frame=0):
    cv = Canvas(9, 13)
    cv.rect(0, 0, 8, 1, "wd2"); cv.rect(0, 11, 8, 12, "wd2")
    for y in range(2, 11):
        w = abs(6.5 - y) * 0.6 + 0.6
        cv.line([(4 - w, y), (4 + w, y)], "ic2")
    cv.line([(1, 2), (1, 10)], "wd1"); cv.line([(7, 2), (7, 10)], "wd1")
    sand = 3 + frame % 3
    for y in range(11 - sand, 11):
        cv.line([(3, y), (5, y)], "gd1")
    cv.px(4, 6, "gd1"); cv.px(4, 8, "gd1")
    return cv


def item_cat(frame=0):
    rows = [
        ".#.#..........",
        ".###..........",
        "#o#o#.........",
        "#####.........",
        ".###########..",
        ".############.",
        ".############.",
        "..##..#..##..#",
        "..##..#..##.#.",
    ]
    cv = Canvas(14, 9)
    cv.sprite(rows, 0, 0, {"#": "rb0", "o": "mo2" if frame % 5 else "rb0"})
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == "#" and (y == 0 or rows[y - 1][x] == "."):
                cv.px(x, y, "rb3")
    cv.px(2, 4, "rb2"); cv.px(5, 5, "rb2")
    return cv


def item_staff():
    cv = Canvas(7, 52)
    cv.line([(3, 8), (3, 51)], "wd2")
    cv.line([(4, 8), (4, 51)], "wd1")
    cv.ellipse(0, 0, 6, 7, "ic1", outline="ic0")
    cv.px(2, 2, "ic2"); cv.px(3, 2, "pa2")
    cv.line([(1, 8), (5, 8)], "gd1")
    return cv


def item_armor():
    cv = Canvas(22, 40)
    # stand
    cv.line([(11, 30), (11, 39)], "wd1")
    cv.line([(5, 39), (17, 39)], "wd1")
    # helmet
    cv.ellipse(6, 0, 16, 10, "st4", outline="st2")
    cv.line([(8, 5), (14, 5)], "void")
    cv.px(11, 0, "bl1"); cv.px(11, -1, "bl2")
    # cuirass
    cv.poly([(2, 12), (20, 12), (17, 30), (5, 30)], "st3", outline="st1")
    cv.line([(11, 12), (11, 30)], "st4")
    cv.line([(4, 14), (8, 14)], "pa1")
    cv.rect(2, 11, 7, 15, "st4"); cv.rect(15, 11, 20, 15, "st4")
    return cv


def item_magic_circle(frame=0):
    cv = Canvas(64, 14)
    cv.ellipse(0, 0, 63, 13, None, outline="ic1" if frame % 2 else "ic2")
    cv.ellipse(6, 2, 57, 11, None, outline="ic0")
    for i, x in enumerate(range(8, 56, 8)):
        cv.px(x, 6 + (i % 2), "ic2")
    return cv


ITEMS = [
    # (threshold, key, title, slot x, slot y)
    (50, "cauldron", "Котёл с зельем", 12, 90),
    (100, "raven", "Ворон", 172, 61),
    (150, "crystal", "Хрустальный шар", 172, 76),
    (200, "starmap", "Карта звёзд", 66, 4),
    (250, "hourglass", "Песочные часы", 50, 9),
    (300, "cat", "Чёрный кот", 44, 102),
    (350, "staff", "Посох", 50, 41),
    (400, "banner", "Знамя", 104, 6),
    (450, "armor", "Доспехи", 146, 54),
    (500, "circle", "Магический круг", 64, 104),
]


def skeleton_hi(frame=0):
    import dark
    rows = scale2x(dark.skeleton(frame))
    cv = recolor_grey(rows, {"3": "bone", "2": "pa0", "1": "rb1", "0": "void"})
    return cv


def rat_hi(frame=0):
    import dark
    rows = scale2x(dark.RAT_A if frame % 2 == 0 else dark.RAT_B)
    cv = recolor_grey(rows, {"2": "st3", "3": "bl2"})
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == "2" and (y == 0 or rows[y - 1][x] == "."):
                cv.px(x, y, "st4")
    return cv


def drop_hi():
    cv = Canvas(2, 4)
    cv.rect(0, 1, 1, 3, "ic1"); cv.px(0, 0, "ic2"); cv.px(1, 3, "ic2")
    return cv


def splash_hi():
    cv = Canvas(7, 3)
    for (x, y) in [(0, 2), (1, 1), (3, 0), (5, 1), (6, 2)]:
        cv.px(x, y, "ic1")
    return cv


def sparks_hi(frame=0):
    """Glowing motes rising from the book (3 frames), 40x30."""
    cv = Canvas(40, 30)
    rnd = random.Random(31)
    pts = [(rnd.randint(2, 37), rnd.randint(0, 29)) for _ in range(14)]
    for i, (x, y) in enumerate(pts):
        yy = (y - frame * 4) % 30
        c = "gd2" if (i + frame) % 3 else "pa2"
        cv.px(x + (frame + i) % 2, yy, c)
        if i % 4 == 0:
            cv.px(x, yy + 1, "gd1")
    return cv


def page_turn_hi():
    cv = Canvas(14, 10)
    for i in range(12):
        yy = 6 - (5 - abs(i - 5))
        cv.line([(i + 1, yy), (i + 1, yy + 5)], "pa2")
        cv.px(i + 1, yy, "pa1")
    return cv


RUNE_GLYPHS = None


def rune_bubble_hi(idxs):
    import dark
    glyphs = [scale2x([r.replace("#", "3") for r in dark.RUNES[i]]) for i in idxs]
    tw = sum(len(g[0]) + 3 for g in glyphs) - 3
    w, h = tw + 14, 14 + 10
    cv = Canvas(w, h + 6)
    cv.rect(1, 0, w - 2, h - 1, "pa2")
    cv.rect(0, 1, w - 1, h - 2, "pa2")
    cv.rect(2, 2, w - 3, h - 3, "void")
    cv.rect(3, 1, w - 4, 1, "pa0")
    # tail
    for k in range(5):
        cv.px(6 - k, h + k, "pa2")
        cv.px(7 - k, h + k, "pa2")
    cv.rect(6, h - 2, 8, h - 1, "void")
    x = 7
    for g in glyphs:
        for yy, row in enumerate(g):
            for xx, ch in enumerate(row):
                if ch == "3":
                    cv.px(x + xx, 5 + yy, "bl2")
        x += len(g[0]) + 3
    return cv
