"""Redesigned dark mage (thin, noir, rope belt, staff that breathes runes).

Four variants for the author to choose from:
  hermit  — «Отшельник»: чёрная ряса, верёвка с узлами, посох с лунным камнем
  warlock — «Чернокнижник»: красная подкладка и пояс, руны по подолу, посох с углём
  shade   — «Тень»: подол растворяется в дыму, ледяные глаза, костяной посох с черепом
  masked  — «Маска»: фарфоровая маска в глубине капюшона, фиолетовое пламя в фонаре

Local sprite canvas: 60 x 80, feet on the last row. Facing right (toward the lectern).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from hires import Canvas, P  # noqa: E402

SW, SH = 60, 80
CX = 26          # body axis
WAIST = 46       # rope belt row
STAFF_X = CX - 12

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

# extra colours (added to the shared palette)
P.update({
    "nr0": (8, 8, 11), "nr1": (16, 16, 22), "nr2": (27, 26, 35), "nr3": (44, 42, 56), "nr4": (70, 68, 88),
    "vi0": (14, 9, 20), "vi1": (26, 16, 36), "vi2": (42, 28, 58), "vi3": (70, 50, 96), "vi4": (150, 110, 220),
    "vi5": (210, 180, 255),
    "rp0": (92, 76, 52), "rp1": (150, 128, 90), "rp2": (196, 176, 132),
    "rd0": (70, 10, 12), "rd1": (130, 20, 22), "rd2": (200, 40, 36), "rd3": (255, 110, 80),
    "cy0": (30, 80, 96), "cy1": (80, 190, 210), "cy2": (190, 245, 255),
    "mk0": (150, 146, 140), "mk1": (206, 202, 194), "mk2": (240, 238, 232),
    "wd4": (60, 40, 26),
})

VARIANTS = {
    "hermit": dict(title="Отшельник", robe=("nr0", "nr1", "nr2", "nr3"), rim_warm="gd0", rim_cold="nr4",
                   lining="nr2", rope=("rp0", "rp1", "rp2"), eyes="eye", eye_glow="gd2",
                   hood="liripipe", hem="plain", cape=False, trim=None, face="void",
                   staff="moonstone", rune=("gd1", "gd2", "pa2")),
    "warlock": dict(title="Чернокнижник", robe=("nr0", "nr1", "nr2", "nr3"), rim_warm="rd1", rim_cold="nr4",
                    lining="rd1", rope=("rd0", "rd1", "rd2"), eyes="rd3", eye_glow="rd2",
                    hood="tall", hem="plain", cape=True, trim="gd1", face="void",
                    staff="ember", rune=("rd1", "rd2", "rd3")),
    "shade": dict(title="Тень", robe=("vi0", "nr1", "vi1", "vi2"), rim_warm="vi3", rim_cold="cy0",
                  lining="vi1", rope=("nr3", "nr4", "mk0"), eyes="cy2", eye_glow="cy1",
                  hood="tall", hem="smoke", cape=False, trim=None, face="void",
                  staff="skull", rune=("cy0", "cy1", "cy2")),
    "masked": dict(title="Маска", robe=("nr0", "nr1", "nr2", "nr3"), rim_warm="gd0", rim_cold="vi3",
                   lining="vi1", rope=("rp0", "rp1", "rp2"), eyes="void", eye_glow=None,
                   hood="liripipe", hem="ragged", cape=True, trim=None, face="mask",
                   staff="lantern", rune=("vi3", "vi4", "vi5")),
}


def disc(cx, cy, r):
    out = set()
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                out.add((x, y))
    return out


def ellipse(cx, cy, rx, ry):
    out = set()
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1:
                out.add((x, y))
    return out


def bezier(p0, p1, p2, n=24):
    pts = []
    for i in range(n + 1):
        t = i / n
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1]
        pts.append((x, y))
    return pts


def silhouette(v, pose):
    """Robe mask, sleeve mask, face opening."""
    body = set()
    head_c = (CX + 1, 17)
    head = ellipse(head_c[0], head_c[1], 7.2, 8.6)
    body |= head
    # hood tip
    if v["hood"] == "liripipe":
        # long tail drooping back over the shoulder
        for i, (x, y) in enumerate(bezier((CX - 1, 10), (CX - 10, 2), (CX - 14, 14), 30)):
            body |= disc(x, y, max(0.8, 4.2 - i * 0.12))
    else:
        # tall point, slightly bent back
        for i, (x, y) in enumerate(bezier((CX + 1, 11), (CX - 1, 2), (CX - 6, -1), 24)):
            body |= disc(x, y, max(0.6, 4.4 - i * 0.17))
    # neck / shoulders
    for y in range(23, 31):
        t = ((y - 23) / 7) ** 0.6
        l = round(CX - 3 - 4 * t)
        r = round(CX + 3 + 3 * t)
        for x in range(l, r + 1):
            body.add((x, y))
    # thin torso down to the waist
    for y in range(31, WAIST + 1):
        t = (y - 31) / (WAIST - 31)
        l = round(CX - 7 + 2 * t)
        r = round(CX + 6 - 1.5 * t)
        for x in range(l, r + 1):
            body.add((x, y))
    # skirt flaring to the floor, trailing a little backwards
    for y in range(WAIST + 1, SH):
        t = (y - WAIST) / (SH - 1 - WAIST)
        l = round(CX - 5 - 9 * t ** 1.2)
        r = round(CX + 5 + 6 * t ** 1.3)
        for x in range(l, r + 1):
            body.add((x, y))
    # capelet over the shoulders
    cape = set()
    if v["cape"]:
        for y in range(23, 38):
            t = ((y - 23) / 14) ** 0.7
            l = round(CX - 4 - 6 * t)
            r = round(CX + 4 + 4 * t)
            for x in range(l, r + 1):
                # rounded lower edge: longer in the middle and at the back
                bottom = 37 - round(((x - (CX - 2)) / 4.5) ** 2)
                if y <= max(30, bottom):
                    cape.add((x, y))
        body |= cape
    # hem
    if v["hem"] == "ragged":
        for x in range(0, SW):
            cut = (x * 5 + 3) % 7
            for k in range(cut // 2):
                body.discard((x, SH - 1 - k))
    face = {(x, y) for (x, y) in ellipse(CX + 5, 18, 4.2, 6.2) if (x, y) in head and x >= CX + 1}

    # front sleeve: pose dependent
    sleeve = set()
    hand = []
    if pose in ("read", "read2"):
        sh = (CX + 2, 28)
        wr = (CX + 11, 41)
        pts = bezier(sh, (CX + 5, 37), wr, 24)
        for i, (x, y) in enumerate(pts):
            sleeve |= disc(x, y, 2.4 + (i / len(pts)) ** 2 * 2.2)   # widens into a bell cuff
        # the cuff hangs down a little
        sleeve |= {(x, y + 1) for (x, y) in disc(wr[0] - 1, wr[1] + 1, 3.6)}
        hx, hy = wr[0] + 3, wr[1] + 1
        hand = [(hx, hy), (hx + 1, hy), (hx + 2, hy), (hx + 3, hy + 1), (hx + 1, hy + 1), (hx + 2, hy + 1)]
        if pose == "read2":
            hand = [(hx, hy - 1), (hx + 1, hy - 2), (hx + 2, hy - 2), (hx + 1, hy - 1), (hx + 3, hy - 3)]
    elif pose == "blow":
        # hand raised to the mouth? no — hand rests on the belt, staff raised
        sh = (CX + 3, 28)
        wr = (CX + 9, 40)
        for i, (x, y) in enumerate(bezier(sh, (CX + 9, 31), wr, 20)):
            sleeve |= disc(x, y, 2.5 + i * 0.06)
        hand = [(wr[0] + 1, wr[1] + 2), (wr[0] + 2, wr[1] + 2), (wr[0] + 1, wr[1] + 3)]
    # back hand on the staff
    back_hand = [(STAFF_X + 1, 37), (STAFF_X + 2, 37), (STAFF_X + 1, 38), (STAFF_X + 2, 38), (STAFF_X + 3, 37)]
    back_sleeve = set()
    for i, (x, y) in enumerate(bezier((CX - 5, 28), (CX - 9, 33), (STAFF_X + 4, 37), 16)):
        back_sleeve |= disc(x, y, 2.2 + i * 0.05)
    return body, cape, face, sleeve, hand, back_sleeve, back_hand


def shade_mass(cv, mask, v, light_bias=0.0, ox=0, oy=0):
    r0, r1, r2, r3 = v["robe"]
    for (x, y) in mask:
        if not (0 <= x < SW and 0 <= y < SH):
            continue
        out_r = (x + 1, y) not in mask
        out_l = (x - 1, y) not in mask
        out_u = (x, y - 1) not in mask
        out_d = (x, y + 1) not in mask
        if out_r and 26 <= y <= 64:
            c = v["rim_warm"]                       # warm light from the book
        elif out_u or (out_r and y < 26):
            c = v["rim_cold"]                       # cold moonlight on top of the hood
        elif out_l or out_d or out_r:
            c = r0
        else:
            # noir: mostly black, a soft gradient toward the lit front
            t = (x - (CX - 12)) / 26 + light_bias - (y / SH) * 0.35
            if t > 0.75:
                c = r2
            elif t > 0.45:
                c = r1 if (BAYER[y % 4][x % 4] + 0.5) / 16 > (t - 0.45) * 2.5 else r2
            elif t > 0.15:
                c = r1
            else:
                c = r0 if (BAYER[y % 4][x % 4] + 0.5) / 16 < (0.15 - t) * 4 + 0.3 else r1
            if (x + 2, y) not in mask and 26 <= y <= 64:
                c = r2
        cv.px(x + ox, y + oy, c)


def draw_staff(cv, v, top_y=12):
    x = STAFF_X
    kind = v["staff"]
    shaft = {"moonstone": ("wd1", "wd2", "wd0"), "ember": ("nr0", "nr3", "nr0"),
             "skull": ("rp0", "pa0", "rp0"), "lantern": ("wd0", "wd2", "wd0")}[kind]
    for y in range(top_y, SH):
        # gnarled: wobble one pixel now and then
        dx = 1 if kind == "moonstone" and (y // 9) % 2 == 1 else 0
        cv.px(x + dx, y, shaft[1])
        cv.px(x + dx + 1, y, shaft[0])
        if kind == "moonstone" and y % 9 == 0:
            cv.px(x + dx - 1, y, shaft[2])
    top = (x, top_y)
    if kind == "moonstone":
        # curl holding a pale stone
        for (px, py) in [(x, top_y - 1), (x - 1, top_y - 2), (x - 1, top_y - 3), (x, top_y - 4), (x + 1, top_y - 5),
                         (x + 2, top_y - 5), (x + 3, top_y - 4), (x + 4, top_y - 3), (x + 4, top_y - 2)]:
            cv.px(px, py, "wd2")
        for (px, py) in disc(x + 2, top_y - 2, 1.6):
            cv.px(px, py, "ic2")
        cv.px(x + 2, top_y - 3, "pa2")
        top = (x + 2, top_y - 3)
    elif kind == "ember":
        # iron crescent fork with a glowing coal
        for (px, py) in [(x - 2, top_y - 5), (x - 2, top_y - 4), (x - 1, top_y - 3), (x, top_y - 2), (x, top_y - 1),
                         (x + 3, top_y - 5), (x + 3, top_y - 4), (x + 2, top_y - 3), (x + 1, top_y - 2), (x + 1, top_y - 1)]:
            cv.px(px, py, "nr4")
        for (px, py) in disc(x + 0.5, top_y - 4, 1.4):
            cv.px(px, py, "rd2")
        cv.px(x, top_y - 4, "rd3")
        cv.px(x + 1, top_y - 5, "fl1")
        top = (x + 1, top_y - 5)
    elif kind == "skull":
        sx, sy = x - 2, top_y - 7
        skull = [".###.", "#####", "#.#.#", "#####", ".#.#."]
        for r, row in enumerate(skull):
            for c, ch in enumerate(row):
                if ch == "#":
                    cv.px(sx + c, sy + r, "bone" if r < 2 else "pa1")
        cv.px(sx + 1, sy + 2, "cy2")
        cv.px(sx + 3, sy + 2, "cy2")
        top = (x, sy)
    elif kind == "lantern":
        # small caged lantern hanging from a hook
        for (px, py) in [(x, top_y - 1), (x + 1, top_y - 2), (x + 2, top_y - 2), (x + 3, top_y - 1)]:
            cv.px(px, py, "wd2")
        lx, ly = x + 2, top_y
        for yy in range(ly, ly + 6):
            cv.px(lx, yy, "nr4")
            cv.px(lx + 4, yy, "nr4")
        cv.rect(lx, ly, lx + 4, ly, "nr4")
        cv.rect(lx, ly + 6, lx + 4, ly + 6, "nr4")
        cv.rect(lx + 1, ly + 1, lx + 3, ly + 5, "vi2")
        cv.px(lx + 2, ly + 2, "vi5")
        cv.px(lx + 2, ly + 3, "vi4")
        cv.px(lx + 1, ly + 4, "vi4")
        cv.px(lx + 3, ly + 4, "vi3")
        top = (lx + 2, ly - 1)
    return top


def draw_rope(cv, body, v):
    c0, c1, c2 = v["rope"]
    row = [x for x in range(SW) if (x, WAIST) in body]
    if not row:
        return
    l, r = min(row), max(row)
    for x in range(l, r + 1):
        cv.px(x, WAIST, c1 if x % 2 else c2)
        cv.px(x, WAIST + 1, c0 if x % 2 else c1)
    # knot at the front
    kx = CX + 3
    for (px, py) in [(kx, WAIST - 1), (kx + 1, WAIST - 1), (kx - 1, WAIST), (kx + 2, WAIST), (kx, WAIST + 2), (kx + 1, WAIST + 2)]:
        cv.px(px, py, c1)
    cv.px(kx, WAIST, c2)
    cv.px(kx + 1, WAIST + 1, c0)
    # two hanging cord ends with monk's knots
    for (sx, length, sway) in ((kx, 20, -1), (kx + 2, 14, 1)):
        for k in range(length):
            x = sx + (sway if k > length * 0.6 else 0)
            y = WAIST + 2 + k
            cv.px(x, y, c1 if k % 2 else c0)
            if k in (5, 10, 15) and k < length - 1:
                cv.px(x - 1, y, c0)
                cv.px(x + 1, y, c2)
        cv.px(sx + sway, WAIST + 2 + length, c2)


def draw_face(cv, face, head_mask, v):
    for (x, y) in face:
        cv.px(x, y, "void")
    # hood lining: thin edge around the opening on the far side
    for (x, y) in face:
        for dx, dy in ((-1, 0), (0, -1), (-1, -1)):
            q = (x + dx, y + dy)
            if q in head_mask and q not in face:
                cv.px(q[0], q[1], v["lining"])
    if v["face"] == "mask":
        # porcelain mask, three-quarter, deep in the hood
        m = ellipse(CX + 6, 19, 2.8, 4.4)
        for (x, y) in m:
            if (x, y) in face:
                cv.px(x, y, "mk1" if x > CX + 5 else "mk0")
        for (x, y) in [(CX + 7, 17), (CX + 8, 17)]:
            cv.px(x, y, "mk2")
        # eye slits and a thin crack
        cv.px(CX + 5, 18, "void"); cv.px(CX + 6, 18, "void")
        cv.px(CX + 8, 18, "void")
        cv.px(CX + 7, 21, "mk0"); cv.px(CX + 6, 22, "mk0")
        cv.px(CX + 7, 15, "mk0")
        return
    ec = v["eyes"]
    for (x, y) in [(CX + 5, 18), (CX + 6, 18), (CX + 8, 18)]:
        cv.px(x, y, ec)
    if v["eye_glow"]:
        for (x, y) in [(CX + 5, 17), (CX + 9, 18), (CX + 7, 19)]:
            if (x, y) in face:
                cv.px(x, y, v["eye_glow"]) if (x + y) % 2 else None


def draw_trim(cv, body, v):
    if not v["trim"]:
        return
    # runic dots along the hem and the front opening
    for x in range(SW):
        if (x, SH - 2) in body and (x, SH - 1) in body:
            if x % 3 == 0:
                cv.px(x, SH - 3, v["trim"])
            elif x % 3 == 1:
                cv.px(x, SH - 4, "gd0")
    for y in range(WAIST + 3, SH - 4):
        x = CX + 2 + (y - WAIST) // 7
        if (x, y) in body and y % 2 == 0:
            cv.px(x, y, "gd0")


def smoke_hem(cv, body, v):
    """Robe dissolves into dark smoke near the floor."""
    r0, r1, r2, _ = v["robe"]
    for (x, y) in list(body):
        if y >= SH - 12:
            t = (y - (SH - 12)) / 12
            if (BAYER[y % 4][x % 4] + 0.5) / 16 < t * 1.15:
                cv.px(x, y, (0, 0, 0, 0))
    # wisps
    for x in range(CX - 15, CX + 13, 4):
        for k in range(4):
            y = SH - 10 + k * 2
            xx = x + (k % 2)
            if (xx, y - 3) in body:
                cv.px(xx, y, r1 if k < 2 else r0)


def build(variant, pose="read", phase=0):
    v = VARIANTS[variant]
    cv = Canvas(SW, SH)
    body, cape, face, sleeve, hand, back_sleeve, back_hand = silhouette(v, pose)
    head_mask = body.copy()
    # back sleeve behind the body
    shade_mass(cv, back_sleeve - body, v, light_bias=-0.25)
    staff_top = draw_staff(cv, v, top_y=14 if pose != "blow" else 8)
    shade_mass(cv, body, v)
    if cape:
        # capelet edge: a darker line where it overlaps the robe, lining color at the bottom
        for (x, y) in cape:
            if (x, y + 1) not in cape and (x, y + 1) in body:
                cv.px(x, y, v["lining"])
                cv.px(x, y + 1, v["robe"][0])
    if v["hem"] == "smoke":
        smoke_hem(cv, body, v)
    # folds
    for fx, top in ((CX - 7, WAIST + 6), (CX - 1, WAIST + 4), (CX + 5, WAIST + 10)):
        for y in range(top, SH - 3):
            if (fx, y) in body and (fx + 1, y) in body and (fx - 1, y) in body:
                cv.px(fx, y, v["robe"][0])
    draw_trim(cv, body, v)
    draw_rope(cv, body, v)
    draw_face(cv, face, head_mask, v)
    # hand on the staff over it
    for (x, y) in back_hand:
        cv.px(x, y, "pa1" if (x + y) % 2 else "pa0")
    # front sleeve over everything
    shade_mass(cv, sleeve, v, light_bias=0.2)
    for i, (x, y) in enumerate(hand):
        cv.px(x, y, "pa1" if i % 2 else "pa2")
    return cv, staff_top


def rune_smoke(cv, origin, v, phase=0, count=3):
    """Runes puffed from the staff like smoke rings: rise along a lazy S, spread out and fade."""
    import dark
    import math
    glyph_ids = [0, 2, 3, 5, 6, 7]
    c0, c1, c2 = v["rune"]
    ox, oy = origin
    span = 30
    for k in range(count):
        age = (k * span // count + phase * 2) % span     # 0..span-1
        f = age / span
        y = oy - 6 - round(age * 0.9)
        x = ox + 2 + round(5 * math.sin(age / 5 + k)) + round(age * 0.25)
        g = dark.RUNES[glyph_ids[(k + phase // 6) % len(glyph_ids)]]
        col = c2 if f < 0.3 else (c1 if f < 0.65 else c0)
        for r, row in enumerate(g):
            for c, ch in enumerate(row):
                if ch != "#":
                    continue
                if f > 0.7 and (BAYER[(y + r) % 4][(x + c) % 4] + 0.5) / 16 < (f - 0.7) * 3.3:
                    continue
                cv.px(x + c - 2, y + r - 3, col)
        if f < 0.45:
            cv.glow(x, y, 6, c1, 0.2 * (1 - f * 2))
    # wisp right at the tip
    cv.glow(ox, oy - 1, 4, c1, 0.4)
