"""The dark mage (chosen design «Маска», 19.10.2026).

Thin noir figure in a black hooded robe with a monk's rope belt, a red lacquer mask deep in the hood
and a staff with a caged violet flame that puffs runes like smoke.

Local sprite canvas: SW x SH, feet on the last row, facing right (toward the lectern).
Poses: read, read2 (turning a page), tired, drink, wave; angry(phase) is a separate front view for the dungeon.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from hires import Canvas, P  # noqa: E402

SW, SH = 60, 68
CX = 26          # body axis
WAIST = 39       # rope belt row
STAFF_X = CX - 12

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

P.update({
    "nr0": (8, 8, 11), "nr1": (16, 16, 22), "nr2": (27, 26, 35), "nr3": (44, 42, 56), "nr4": (70, 68, 88),
    "vi0": (14, 9, 20), "vi1": (26, 16, 36), "vi2": (42, 28, 58), "vi3": (70, 50, 96), "vi4": (150, 110, 220),
    "vi5": (210, 180, 255),
    "rp0": (92, 76, 52), "rp1": (150, 128, 90), "rp2": (196, 176, 132),
    "rd0": (70, 10, 12), "rd1": (130, 20, 22), "rd2": (200, 40, 36), "rd3": (255, 110, 80),
    "mk0": (96, 12, 14), "mk1": (160, 24, 24), "mk2": (214, 58, 46), "mk3": (255, 140, 110),
})

ROBE = ("nr0", "nr1", "nr2", "nr3")
RIM_WARM = "vi3"      # violet light from the lantern and the book
RIM_COLD = "nr4"      # cold moonlight on top
LINING = "vi1"
ROPE = ("rp0", "rp1", "rp2")
RUNE = ("vi3", "vi4", "vi5")


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


# ------------------------------------------------------------------ geometry

def silhouette(pose):
    """Robe mask, face opening, front sleeve and hand, back sleeve and hand, head centre."""
    slump = 2 if pose == "tired" else 0
    hx, hy = CX + 1 - (1 if slump else 0), 15 + slump
    body = set()
    head = ellipse(hx, hy, 6.6, 7.6)
    body |= head
    # liripipe: long hood tail drooping back over the shoulder
    for i, (x, y) in enumerate(bezier((hx - 2, hy - 6), (hx - 10, hy - 13), (hx - 13, hy - 1), 28)):
        body |= disc(x, y, max(0.8, 3.8 - i * 0.11))
    # sloping shoulders
    for y in range(21, 28):
        t = ((y - 21) / 6) ** 0.6
        for x in range(round(CX - 3 - 4 * t), round(CX + 3 + 3 * t) + 1):
            body.add((x, y))
    # capelet over the shoulders, rounded edge
    cape = set()
    for y in range(21, 33):
        t = ((y - 21) / 11) ** 0.7
        for x in range(round(CX - 4 - 5 * t), round(CX + 4 + 4 * t) + 1):
            bottom = 32 - round(((x - (CX - 2)) / 4.2) ** 2)
            if y <= max(27, bottom):
                cape.add((x, y))
    body |= cape
    # thin torso
    for y in range(28, WAIST + 1):
        t = (y - 28) / (WAIST - 28)
        for x in range(round(CX - 6 + 1.5 * t), round(CX + 5 - 1 * t) + 1):
            body.add((x, y))
    # skirt to the floor, trailing back
    for y in range(WAIST + 1, SH):
        t = (y - WAIST) / (SH - 1 - WAIST)
        for x in range(round(CX - 4 - 8 * t ** 1.2), round(CX + 4 + 5 * t ** 1.3) + 1):
            body.add((x, y))
    # ragged hem
    for x in range(SW):
        for k in range(((x * 5 + 3) % 7) // 2):
            body.discard((x, SH - 1 - k))
    face = {(x, y) for (x, y) in ellipse(hx + 4, hy + 1, 3.8, 5.4) if (x, y) in head and x >= hx}

    sleeve, hand, prop = set(), [], []
    sh = (CX + 2, 24)
    if pose in ("read", "read2"):
        wr = (CX + 11, 35)
        pts = bezier(sh, (CX + 5, 32), wr, 22)
        for i, (x, y) in enumerate(pts):
            sleeve |= disc(x, y, 2.2 + (i / len(pts)) ** 2 * 2.0)
        sleeve |= {(x, y + 1) for (x, y) in disc(wr[0] - 1, wr[1] + 1, 3.2)}
        px_, py_ = wr[0] + 3, wr[1] + 1
        hand = [(px_, py_), (px_ + 1, py_), (px_ + 2, py_), (px_ + 3, py_ + 1), (px_ + 1, py_ + 1), (px_ + 2, py_ + 1)]
        if pose == "read2":
            hand = [(px_, py_ - 1), (px_ + 1, py_ - 2), (px_ + 2, py_ - 3), (px_ + 1, py_ - 1), (px_ + 3, py_ - 4)]
    elif pose == "tired":
        # arm hangs down, the hand lost in the sleeve
        wr = (CX + 6, 42)
        for i, (x, y) in enumerate(bezier(sh, (CX + 6, 31), wr, 18)):
            sleeve |= disc(x, y, 2.2 + i * 0.07)
        hand = [(wr[0], wr[1] + 3), (wr[0] + 1, wr[1] + 3)]
    elif pose == "drink":
        # flask raised to the mask
        wr = (CX + 9, hy + 6)
        for i, (x, y) in enumerate(bezier(sh, (CX + 10, 30), wr, 20)):
            sleeve |= disc(x, y, 2.2 + i * 0.08)
        fx, fy = wr[0] + 1, wr[1] - 6
        prop = [("flask", fx, fy)]
        hand = [(wr[0] + 1, wr[1] - 1), (wr[0] + 2, wr[1] - 1), (wr[0] + 2, wr[1])]
    elif pose == "wave":
        wr = (CX + 10, 6)
        for i, (x, y) in enumerate(bezier(sh, (CX + 11, 20), wr, 22)):
            sleeve |= disc(x, y, 2.2 + i * 0.07)
        hand = [(wr[0], wr[1] - 3), (wr[0] + 1, wr[1] - 4), (wr[0] + 2, wr[1] - 3), (wr[0] + 1, wr[1] - 2),
                (wr[0] + 3, wr[1] - 2), (wr[0] - 1, wr[1] - 2)]
    back_hand = [(STAFF_X + 1, 31), (STAFF_X + 2, 31), (STAFF_X + 1, 32), (STAFF_X + 2, 32), (STAFF_X + 3, 31)]
    back_sleeve = set()
    for i, (x, y) in enumerate(bezier((CX - 5, 24), (CX - 9, 28), (STAFF_X + 4, 31), 16)):
        back_sleeve |= disc(x, y, 2.0 + i * 0.05)
    return body, cape, face, head, sleeve, hand, back_sleeve, back_hand, prop, (hx, hy)


def shade_mass(cv, mask, light_bias=0.0, warm=True):
    r0, r1, r2, r3 = ROBE
    for (x, y) in mask:
        if not (0 <= x < SW and 0 <= y < SH):
            continue
        out_r = (x + 1, y) not in mask
        out_l = (x - 1, y) not in mask
        out_u = (x, y - 1) not in mask
        out_d = (x, y + 1) not in mask
        if out_r and 22 <= y <= 54 and warm:
            c = RIM_WARM
        elif out_u or (out_r and y < 22):
            c = RIM_COLD
        elif out_l or out_d or out_r:
            c = r0
        else:
            t = (x - (CX - 12)) / 26 + light_bias - (y / SH) * 0.35
            if t > 0.75:
                c = r2
            elif t > 0.45:
                c = r1 if (BAYER[y % 4][x % 4] + 0.5) / 16 > (t - 0.45) * 2.5 else r2
            elif t > 0.15:
                c = r1
            else:
                c = r0 if (BAYER[y % 4][x % 4] + 0.5) / 16 < (0.15 - t) * 4 + 0.3 else r1
            if (x + 2, y) not in mask and 22 <= y <= 54 and warm:
                c = r2
        cv.px(x, y, c)


def draw_staff(cv, lit=True, top_y=10):
    """Dark wooden staff with a small caged lantern. Returns the point where the runes come out."""
    x = STAFF_X
    for y in range(top_y + 2, SH):
        cv.px(x, y, "wd2" if y % 7 else "wd1")
        cv.px(x + 1, y, "wd0")
    # hook
    for (px_, py_) in [(x, top_y + 1), (x + 1, top_y), (x + 2, top_y), (x + 3, top_y + 1)]:
        cv.px(px_, py_, "wd2")
    lx, ly = x + 2, top_y + 2
    for yy in range(ly, ly + 6):
        cv.px(lx, yy, "nr4")
        cv.px(lx + 4, yy, "nr4")
    cv.rect(lx, ly, lx + 4, ly, "nr4")
    cv.rect(lx, ly + 6, lx + 4, ly + 6, "nr4")
    cv.rect(lx + 1, ly + 1, lx + 3, ly + 5, "vi2" if lit else "vi0")
    if lit:
        cv.px(lx + 2, ly + 2, "vi5")
        cv.px(lx + 2, ly + 3, "vi4")
        cv.px(lx + 1, ly + 4, "vi4")
        cv.px(lx + 3, ly + 4, "vi3")
    else:
        cv.px(lx + 2, ly + 4, "vi3")
    return (lx + 2, ly - 1)


def draw_rope(cv, body):
    c0, c1, c2 = ROPE
    row = [x for x in range(SW) if (x, WAIST) in body]
    if not row:
        return
    l, r = min(row), max(row)
    for x in range(l, r + 1):
        cv.px(x, WAIST, c1 if x % 2 else c2)
        cv.px(x, WAIST + 1, c0 if x % 2 else c1)
    kx = CX + 2
    for (px_, py_) in [(kx, WAIST - 1), (kx + 1, WAIST - 1), (kx - 1, WAIST), (kx + 2, WAIST), (kx, WAIST + 2), (kx + 1, WAIST + 2)]:
        cv.px(px_, py_, c1)
    cv.px(kx, WAIST, c2)
    cv.px(kx + 1, WAIST + 1, c0)
    for (sx, length, sway) in ((kx, 17, -1), (kx + 2, 12, 1)):
        for k in range(length):
            x = sx + (sway if k > length * 0.6 else 0)
            y = WAIST + 2 + k
            cv.px(x, y, c1 if k % 2 else c0)
            if k in (4, 9, 14) and k < length - 1:
                cv.px(x - 1, y, c0)
                cv.px(x + 1, y, c2)
        cv.px(sx + sway, WAIST + 2 + length, c2)


def draw_mask(cv, face, head, hc, mood="calm"):
    hx, hy = hc
    for (x, y) in face:
        cv.px(x, y, "void")
    for (x, y) in face:
        for dx, dy in ((-1, 0), (0, -1), (-1, -1)):
            q = (x + dx, y + dy)
            if q in head and q not in face:
                cv.px(q[0], q[1], LINING)
    m = ellipse(hx + 5, hy + 2, 2.6, 4.2)
    for (x, y) in m:
        if (x, y) in face:
            cv.px(x, y, "mk1" if x > hx + 4 else "mk0")
    cv.px(hx + 6, hy, "mk2"); cv.px(hx + 7, hy, "mk2"); cv.px(hx + 7, hy + 1, "mk2")
    cv.px(hx + 6, hy - 2, "mk0")
    # eye slits; when tired they are dark, otherwise a faint glow behind them
    eye = "void" if mood == "tired" else "rd3"
    cv.px(hx + 4, hy + 1, "void"); cv.px(hx + 5, hy + 1, eye)
    cv.px(hx + 7, hy + 1, eye)
    # thin crack
    cv.px(hx + 6, hy + 4, "mk0"); cv.px(hx + 5, hy + 5, "mk0")


def draw_flask(cv, x, y):
    cv.rect(x + 1, y, x + 2, y + 1, "wd2")
    cv.rect(x + 1, y + 2, x + 2, y + 2, "ic2")
    for (px_, py_) in ellipse(x + 1.5, y + 5, 2.3, 2.6):
        cv.px(px_, py_, "vi3")
    cv.px(x + 1, y + 4, "vi5"); cv.px(x + 2, y + 6, "vi2")


def build(pose="read", phase=0):
    """Tower mage. Returns (canvas, rune origin in local coordinates)."""
    cv = Canvas(SW, SH)
    body, cape, face, head, sleeve, hand, back_sleeve, back_hand, prop, hc = silhouette(pose)
    shade_mass(cv, back_sleeve - body, light_bias=-0.25)
    lit = pose != "tired"
    top = draw_staff(cv, lit=lit)
    shade_mass(cv, body, warm=lit)
    for (x, y) in cape:
        if (x, y + 1) not in cape and (x, y + 1) in body:
            cv.px(x, y, LINING)
            cv.px(x, y + 1, ROBE[0])
    for fx, top_y in ((CX - 6, WAIST + 5), (CX - 1, WAIST + 3), (CX + 4, WAIST + 8)):
        for y in range(top_y, SH - 3):
            if (fx, y) in body and (fx + 1, y) in body and (fx - 1, y) in body:
                cv.px(fx, y, ROBE[0])
    draw_rope(cv, body)
    draw_mask(cv, face, head, hc, mood="tired" if pose == "tired" else "calm")
    for (x, y) in back_hand:
        cv.px(x, y, "pa1" if (x + y) % 2 else "pa0")
    shade_mass(cv, sleeve, light_bias=0.2, warm=lit)
    for i, (x, y) in enumerate(hand):
        cv.px(x, y, "pa1" if i % 2 else "pa2")
    for kind, x, y in prop:
        if kind == "flask":
            draw_flask(cv, x, y)
    return cv, top


# ------------------------------------------------------------------ runes puffed from the lantern

RUNE_FRAMES = 10


def rune_smoke(cv, origin, phase=0, count=3):
    """Runes rise from the lantern like smoke rings: drift along a lazy S, spread and fade."""
    import dark
    glyph_ids = [0, 2, 3, 5, 6, 7]
    c0, c1, c2 = RUNE
    ox, oy = origin
    span = 30
    for k in range(count):
        age = (k * span // count + phase * 3) % span
        f = age / span
        y = oy - 5 - round(age * 0.9)
        x = ox + 2 + round(4 * math.sin(age / 5 + k)) + round(age * 0.25)
        g = dark.RUNES[glyph_ids[(k + (phase * 3 + k * span // count) // span) % len(glyph_ids)]]
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
    cv.glow(ox, oy, 4, c1, 0.4)


# ------------------------------------------------------------------ starving mage in the dungeon (front view)

def angry(phase=0):
    """Thin starved mage facing us, fists raised, cracked red mask with burning eye slits. 60 x 66."""
    W_, H_ = 60, 66
    cv = Canvas(W_, H_)
    cx = 30
    d = 1 if phase else 0
    mask = set()
    head = ellipse(cx, 17, 7.5, 8.5)
    mask |= head
    for i, (x, y) in enumerate(bezier((cx + 3, 10), (cx + 9, 2), (cx + 14, 9), 22)):
        mask |= disc(x, y, max(0.8, 3.6 - i * 0.13))
    for y in range(25, 31):
        t = ((y - 25) / 5) ** 0.6
        for x in range(round(cx - 4 - 4 * t), round(cx + 4 + 4 * t) + 1):
            mask.add((x, y))
    for y in range(31, H_):
        t = (y - 31) / (H_ - 32)
        for x in range(round(cx - 7 - 4 * t), round(cx + 7 + 4 * t) + 1):
            mask.add((x, y))
    # torn hem
    for x in range(W_):
        for k in range(1, 6):
            if (x * 7 + k * 3) % 5 < (k + 1) // 2 + 1:
                mask.discard((x, H_ - k))
    # thin arms raised, shaking
    arms = set()
    for sx in (-1, 1):
        for i, (x, y) in enumerate(bezier((cx + sx * 7, 29), (cx + sx * 14, 26), (cx + sx * (16 + d), 13 - d), 16)):
            arms |= disc(x, y, 1.6)
    mask |= arms
    for (x, y) in mask:
        out_r = (x + 1, y) not in mask
        out_any = any((x + dx, y + dy) not in mask for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if out_r or (x, y - 1) not in mask:
            c = "nr4"
        elif out_any:
            c = "nr0"
        else:
            c = "nr1" if (BAYER[y % 4][x % 4] + 0.5) / 16 > 0.3 + y / H_ * 0.4 else "nr0"
        cv.px(x, y, c)
    # face opening and the mask, cracked
    face = {p for p in ellipse(cx, 19, 5.2, 6.2) if p in head}
    for (x, y) in face:
        cv.px(x, y, "void")
    for (x, y) in ellipse(cx, 19, 3.6, 5.0):
        if (x, y) in face:
            cv.px(x, y, "mk1" if x >= cx else "mk0")
    cv.px(cx + 1, 15, "mk2"); cv.px(cx + 2, 16, "mk2")
    # angry slanted slits burning
    for (x, y) in [(cx - 3, 17), (cx - 2, 18), (cx - 1, 18), (cx + 1, 18), (cx + 2, 18), (cx + 3, 17)]:
        cv.px(x, y, "fl1" if phase else "rd3")
    # crack across
    for (x, y) in [(cx - 1, 20), (cx, 21), (cx - 1, 22), (cx, 23)]:
        cv.px(x, y, "void")
    # rope belt, frayed
    for x in range(cx - 8, cx + 9):
        if (x, 38) in mask:
            cv.px(x, 38, "rp1" if x % 2 else "rp0")
    for k in range(9):
        cv.px(cx + 2 + (1 if k > 5 else 0), 39 + k, "rp0" if k % 2 else "rp1")
    # ribs through the torn robe
    for y in (31, 34):
        for x in range(cx - 4, cx + 5):
            if (x, y) in mask and abs(x - cx) > 1:
                cv.px(x, y, "pa0")
    # bony fists
    for sx in (-1, 1):
        fx = cx + sx * (16 + d) - 1
        fy = 10 - d
        cv.rect(fx, fy, fx + 2, fy + 2, "pa1")
        cv.px(fx, fy, "pa2"); cv.px(fx + 1, fy + 1, "pa0")
    return cv


def mask_on_floor():
    """The red mask lying in the straw next to the skeleton. 9 x 6."""
    cv = Canvas(9, 6)
    for (x, y) in ellipse(4, 3, 4.2, 2.6):
        cv.px(x, y, "mk1" if x > 3 else "mk0")
    cv.px(2, 2, "void"); cv.px(6, 2, "void")
    cv.px(5, 1, "mk2"); cv.px(4, 4, "void")
    return cv
