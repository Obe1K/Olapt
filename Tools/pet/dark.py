"""Dark-fantasy pixel art for the pet: tower (fed) and dungeon (hungry).

Palette indices: 0 black, 1 dark grey, 2 mid grey, 3 bone white. '.' = transparent in sprites.
Screen: 96 x 60.
"""
import random

SW, SH = 96, 60

PALETTE = {
    0: (11, 11, 15),
    1: (52, 52, 62),
    2: (112, 110, 118),
    3: (226, 220, 204),
}


def grid(w=SW, h=SH, v=0):
    return [[v] * w for _ in range(h)]


def put(g, sprite, x, y):
    for r, row in enumerate(sprite):
        for c, ch in enumerate(row):
            if ch != '.':
                rr, cc = y + r, x + c
                if 0 <= rr < len(g) and 0 <= cc < len(g[0]):
                    g[rr][cc] = int(ch)


def hline(g, x0, x1, y, v):
    for x in range(x0, x1 + 1):
        if 0 <= y < len(g) and 0 <= x < len(g[0]):
            g[y][x] = v


def vline(g, x, y0, y1, v):
    for y in range(y0, y1 + 1):
        if 0 <= y < len(g) and 0 <= x < len(g[0]):
            g[y][x] = v


def rect(g, x0, y0, x1, y1, v):
    for y in range(y0, y1 + 1):
        hline(g, x0, x1, y, v)


# ---------------------------------------------------------------- backgrounds

def bricks(g, x0, y0, x1, y1, seed=1, bw=10, bh=5):
    """Stone wall: mortar lines dark grey, a few chipped highlights."""
    rnd = random.Random(seed)
    for y in range(y0, y1 + 1):
        row = (y - y0) // bh
        if (y - y0) % bh == 0:
            hline(g, x0, x1, y, 1)
            continue
        off = (bw // 2) if row % 2 else 0
        for x in range(x0, x1 + 1):
            if (x - x0 + off) % bw == 0:
                g[y][x] = 1
    # highlights on some bricks (top-left corner pixel) and cracks
    for _ in range((x1 - x0) * (y1 - y0) // 60):
        x = rnd.randint(x0, x1)
        y = rnd.randint(y0, y1)
        if g[y][x] == 0:
            g[y][x] = 1


def tower_background():
    g = grid()
    bricks(g, 0, 0, SW - 1, 47, seed=3)
    # window: arched opening, frame mid grey
    wx0, wx1, wy0, wy1 = 58, 81, 8, 36
    cx = (wx0 + wx1) / 2
    r = (wx1 - wx0) / 2
    for y in range(wy0 - 2, wy1 + 1):
        for x in range(wx0 - 2, wx1 + 3):
            # arch: circle top
            top = wy0 + r
            inside = False
            if y >= top:
                inside = wx0 <= x <= wx1
            else:
                inside = (x - cx) ** 2 + (y - top) ** 2 <= r ** 2
            frame_out = False
            if y >= top:
                frame_out = wx0 - 2 <= x <= wx1 + 2
            else:
                frame_out = (x - cx) ** 2 + (y - top) ** 2 <= (r + 2) ** 2
            if inside:
                g[y][x] = 0
            elif frame_out:
                g[y][x] = 2
    # sill
    hline(g, wx0 - 4, wx1 + 4, wy1 + 1, 2)
    hline(g, wx0 - 4, wx1 + 4, wy1 + 2, 1)
    # mullion & transom
    vline(g, int(cx), wy0 + 2, wy1, 1)
    hline(g, wx0, wx1, wy0 + 16, 1)
    # moon (crescent) and stars
    moon_c, moon_r = (75, 17), 4
    for y in range(moon_c[1] - moon_r, moon_c[1] + moon_r + 1):
        for x in range(moon_c[0] - moon_r, moon_c[0] + moon_r + 1):
            d1 = (x - moon_c[0]) ** 2 + (y - moon_c[1]) ** 2
            d2 = (x - moon_c[0] + 2) ** 2 + (y - moon_c[1] + 1) ** 2
            if d1 <= moon_r ** 2 and d2 > (moon_r - 0.5) ** 2:
                if g[y][x] == 0:
                    g[y][x] = 3
    for (x, y) in [(62, 13), (66, 22), (63, 30), (78, 29), (73, 33), (61, 20)]:
        if g[y][x] == 0:
            g[y][x] = 2
    # floor: planks
    rect(g, 0, 48, SW - 1, SH - 1, 0)
    hline(g, 0, SW - 1, 48, 2)
    for y in (52, 56):
        hline(g, 0, SW - 1, y, 1)
    for i, y in enumerate((49, 53, 57)):
        for x in range(3 + i * 7, SW, 23):
            vline(g, x, y, y + 2, 1)
    # shelf with candles area (top-left): a stone ledge
    hline(g, 2, 32, 10, 2)
    hline(g, 2, 32, 11, 1)
    # rug under the mage
    return g


def dungeon_background():
    g = grid()
    # irregular big stones
    rnd = random.Random(7)
    y = 0
    while y < 46:
        h = rnd.choice([6, 7, 8])
        x = -rnd.randint(0, 8)
        while x < SW:
            w = rnd.choice([9, 11, 13, 15])
            # stone outline
            for xx in range(x, x + w):
                if 0 <= xx < SW and y < 46:
                    g[y][xx] = 1
            for yy in range(y, min(46, y + h)):
                if 0 <= x < SW:
                    g[yy][x] = 1
            # damp highlight dots
            if rnd.random() < 0.5:
                px, py = x + rnd.randint(2, w - 2), y + rnd.randint(2, h - 2)
                if 0 <= px < SW and py < 46:
                    g[py][px] = 1
            x += w
        y += h
    # small barred window high on the wall
    rect(g, 40, 4, 55, 13, 0)
    rect(g, 39, 3, 56, 3, 2)
    rect(g, 39, 14, 56, 14, 2)
    vline(g, 39, 3, 14, 2)
    vline(g, 56, 3, 14, 2)
    for x in (43, 47, 51):
        vline(g, x, 4, 13, 2)
    # a faint light beam below the window (dither)
    for yy in range(15, 46):
        for xx in range(40 + (yy - 15) // 3, 56 + (yy - 15) // 3):
            if 0 <= xx < SW and (xx + yy) % 4 == 0 and g[yy][xx] == 0:
                g[yy][xx] = 1
    # floor with straw
    rect(g, 0, 46, SW - 1, SH - 1, 0)
    hline(g, 0, SW - 1, 46, 2)
    rnd = random.Random(11)
    for _ in range(60):
        x, y = rnd.randint(0, SW - 3), rnd.randint(48, SH - 2)
        g[y][x] = 1
        if rnd.random() < 0.5:
            g[y][x + 1] = 2 if rnd.random() < 0.3 else 1
    # cell bars on the right side (front)
    for x in range(80, 96, 5):
        vline(g, x, 0, 59, 2)
        vline(g, x + 1, 0, 59, 1)
    hline(g, 78, 95, 8, 2)
    hline(g, 78, 95, 40, 2)
    return g


# ---------------------------------------------------------------- sprites

# Hooded scholar, 20 x 30. Eyes glow in the dark hood.
MAGE_HAPPY = [
    "..........3.........",
    ".........32.........",
    "........321.........",
    ".......3211.........",
    "......321112........",
    ".....32111112.......",
    "....3211111112......",
    "....3210000012......",
    "...321000000012.....",
    "...321033003012.....",
    "...321300300312.....",
    "...321000000012.....",
    "...322100000122.....",
    "..32221111111222....",
    "..32211111111122....",
    ".3221133333331122...",
    ".3221323232323122...",
    ".3213323232323312...",
    ".3213333333333312...",
    ".3211111111111112...",
    ".3211111111111112...",
    "32211111111111112...",
    "32211111111111112...",
    "322111111111111122..",
    "322111111111111122..",
    "3221111111111111122.",
    "32221111111111111222",
    "22222222222222222222",
]

# Mug of potion — food
POTION = [
    "..33..",
    "..22..",
    ".2112.",
    "213312",
    "233332",
    ".2222.",
]

CANDLE_LIT_A = [
    ".3.",
    "333",
    ".3.",
    ".0.",
    "232",
    "222",
    "222",
    "222",
    "111",
]
CANDLE_LIT_B = [
    "3..",
    ".33",
    ".3.",
    ".0.",
    "232",
    "222",
    "222",
    "222",
    "111",
]
CANDLE_OUT = [
    "..2",
    ".2.",
    "2..",
    ".0.",
    "222",
    "222",
    "222",
    "222",
    "111",
]

RAT_A = [
    "....22.....",
    "..222222...",
    ".2222222232",
    "222222222..",
    ".2.2..2.2..",
]
RAT_B = [
    "....22.....",
    "..222222...",
    ".2222222232",
    "222222222..",
    "..2.22.2...",
]

DROP = ["3", "3"]
SPLASH = ["2.2", ".2."]

# Rune glyphs 5x7 for cursing
RUNES = [
    ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],   # ᚾ-like
    ["#....", "##...", "#.#..", "#..#.", "#.#..", "##...", "#...."],   # ᚦ
    ["..#..", "#.#.#", ".###.", "..#..", "..#..", "..#..", "..#.."],   # ᛉ
    ["..#..", ".#.#.", "#...#", ".#.#.", "..#..", ".#.#.", "#...#"],   # ᛟ
    ["#...#", "##.##", "#.#.#", "##.##", "#...#", "#...#", "#...#"],   # ᛗ
    ["#....", "##...", "#.#..", "#..#.", "#....", "#....", "#...."],   # ᚠ-ish
    ["#..#.", "#.#..", "##...", "#.#..", "#..#.", "#....", "#...."],   # ᚲ/ᚴ
    ["#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#", "#...#"],   # ᛞ-ish
    ["..#..", "..#..", "#####", "..#..", "..#..", "..#..", "..#.."],   # ✝/ᛏ
    ["#", "#", "#", "#", "#", ".", "#"],                                # !
    [".....", ".....", ".....", ".....", ".....", ".....", "#.#.#"],    # …
]

BOOKS = [  # shelf of books, 22 wide x 30 tall (tower, left wall)
]

# ---------------------------------------------------------------- procedural figure

T = -1  # transparent


def blank_sprite(w, h):
    return [[T] * w for _ in range(h)]


def shade(mask, light_from_right=True):
    """mask: set of (x, y). Returns dict (x, y) -> colour with outline and rim light."""
    out = {}
    for (x, y) in mask:
        edge_r = (x + 1, y) not in mask
        edge_l = (x - 1, y) not in mask
        edge_u = (x, y - 1) not in mask
        edge_d = (x, y + 1) not in mask
        if edge_r and light_from_right:
            out[(x, y)] = 3
        elif edge_l or edge_u or edge_d or edge_r:
            out[(x, y)] = 2
        else:
            out[(x, y)] = 1
    return out


def to_rows(px, w, h):
    rows = []
    for y in range(h):
        s = ""
        for x in range(w):
            v = px.get((x, y), T)
            s += "." if v == T else str(v)
        rows.append(s)
    return rows


def ellipse(cx, cy, rx, ry):
    pts = set()
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                pts.add((x, y))
    return pts


def trapezoid(y0, y1, l0, r0, l1, r1, bulge=0.0):
    pts = set()
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, y1 - y0)
        b = bulge * (1 - (2 * t - 1) ** 2)
        l = round(l0 + (l1 - l0) * t - b)
        r = round(r0 + (r1 - r0) * t + b)
        for x in range(l, r + 1):
            pts.add((x, y))
    return pts


def hood_tip(x0, y0, x1, y1, w0=3.0):
    """Tapered cone from (x0,y0) (wide) to (x1,y1) (point)."""
    pts = set()
    steps = 40
    for i in range(steps + 1):
        t = i / steps
        cx = x0 + (x1 - x0) * t
        cy = y0 + (y1 - y0) * t
        w = w0 * (1 - t) + 0.5
        for y in range(int(cy - w) - 1, int(cy + w) + 2):
            for x in range(int(cx - w) - 1, int(cx + w) + 2):
                if (x - cx) ** 2 + (y - cy) ** 2 <= w * w:
                    pts.add((x, y))
    return pts


def mage(pose="read", W=28, H=37, phase=0):
    """pose: read (happy), sit (ok), drink (eating), angry (thin, dungeon)."""
    thin = pose == "angry"
    hood_cx, hood_cy = 13, 11
    mask = set()
    mask |= ellipse(hood_cx, hood_cy, 7.6 if not thin else 6.6, 7.2 if not thin else 6.6)
    mask |= hood_tip(hood_cx + 1, hood_cy - 4, hood_cx + 6, 0, 3.4)
    if thin:
        mask |= trapezoid(17, H - 2, 9, 17, 7, 19, bulge=0.0)
    else:
        mask |= trapezoid(16, H - 2, 6, 20, 2, 24, bulge=1.5)
    # ragged hem
    for x in range(0, W):
        if x % 3 == 0:
            mask.discard((x, H - 2))
    if thin:
        for x in range(0, W):
            if x % 2 == 0:
                mask.discard((x, H - 3))
    px = shade(mask)
    # face opening
    face = ellipse(hood_cx - 0.5, hood_cy + 1.5, 4.6 if not thin else 4.0, 4.2 if not thin else 3.8)
    for p in face:
        if p in px:
            px[p] = 0
    ey = hood_cy + 1
    lx, rx_ = hood_cx - 3, hood_cx + 1
    if pose in ("read", "drink"):
        # happy arcs ^ ^
        for (x, y) in [(lx, ey + 1), (lx + 1, ey), (lx + 2, ey + 1), (rx_, ey + 1), (rx_ + 1, ey), (rx_ + 2, ey + 1)]:
            px[(x, y)] = 3
    elif pose == "sit":
        for (x, y) in [(lx + 1, ey), (lx + 1, ey + 1), (rx_ + 1, ey), (rx_ + 1, ey + 1)]:
            px[(x, y)] = 3
    elif pose == "blink":
        for (x, y) in [(lx, ey + 1), (lx + 1, ey + 1), (rx_ + 1, ey + 1), (rx_ + 2, ey + 1)]:
            px[(x, y)] = 2
        for (x, y) in [(10, 23), (11, 23), (12, 23), (13, 23), (14, 23), (15, 23), (16, 23)]:
            px[(x, y)] = 2
    elif pose == "angry":
        for (x, y) in [(lx, ey - 1), (lx + 1, ey), (lx + 2, ey), (rx_, ey), (rx_ + 1, ey), (rx_ + 2, ey - 1),
                       (lx + 1, ey + 1), (rx_ + 1, ey + 1)]:
            px[(x, y)] = 3
        # open shouting mouth
        for (x, y) in [(hood_cx - 1, ey + 3), (hood_cx, ey + 3)]:
            px[(x, y)] = 2
    # robe folds
    if not thin:
        for (x, y0) in [(9, 27), (13, 25), (17, 27)]:
            for y in range(y0, H - 2):
                if (x, y) in px and px[(x, y)] == 1:
                    px[(x, y)] = 0
    else:
        for y in range(24, H - 3):
            px[(13, y)] = 0 if (13, y) in px else T
        # ribs showing through torn robe
        for y in (19, 21, 23):
            for x in range(11, 16):
                if (x, y) in px:
                    px[(x, y)] = 2
    # book in hands
    if pose == "read":
        bx, by = 7, 19
        book = [
            ".33333333333.",
            "3232323.3232.",
            "3323233.3233.",
            "3232323.3232.",
            "3333333.3333.",
            ".2222222222..",
        ]
        for r, row in enumerate(book):
            for c, ch in enumerate(row):
                if ch != ".":
                    px[(bx + c, by + r)] = int(ch)
        # hands
        for (x, y) in [(6, 21), (6, 22), (19, 21), (19, 22)]:
            px[(x, y)] = 2
        # glow from the book (dither)
        glow = [(8, 17), (10, 16), (12, 17), (14, 16), (16, 17), (18, 16), (11, 15), (15, 15)]
        if phase:
            glow = [(9, 17), (11, 16), (13, 17), (15, 16), (17, 17), (13, 15)]
        for (x, y) in glow:
            if px.get((x, y), T) in (T, 1, 0):
                px[(x, y)] = 2 if (x + y + phase) % 2 else 1
    if pose == "sit":
        # hands folded on lap
        for (x, y) in [(10, 23), (11, 23), (12, 23), (13, 23), (14, 23), (15, 23), (16, 23)]:
            px[(x, y)] = 2
    if pose == "drink":
        # potion raised to the face, sleeve lifted
        vial = [".22..", ".33..", "2332.", "23332", "23332", ".222."]
        for r, row in enumerate(vial):
            for c, ch in enumerate(row):
                if ch != ".":
                    px[(13 + c, 12 + r)] = int(ch)
        for (x, y) in [(16, 18), (17, 18), (18, 19), (19, 20), (20, 21), (17, 19), (18, 20), (19, 21)]:
            px[(x, y)] = 2
    if pose == "angry":
        # bony fists raised (both); phase 1 — fists shaken lower/outward
        d = 1 if phase else 0
        fists = [(5 - d, 14 + d), (6 - d, 14 + d), (5 - d, 15 + d), (6 - d, 15 + d),
                 (21 + d, 14 + d), (22 + d, 14 + d), (21 + d, 15 + d), (22 + d, 15 + d)]
        arms = [(7 - d, 16 + d), (7, 17), (8, 18), (20 + d, 16 + d), (20, 17), (19, 18)]
        for p in arms:
            px[p] = 2
        for p in fists:
            px[p] = 3
    return to_rows(px, W, H)


def skeleton(frame=0, W=30, H=30):
    """Seated skeleton in a tattered hood, wrists chained up to the wall."""
    px = {}
    hood_cx, hood_cy = 14, 9
    mask = ellipse(hood_cx, hood_cy, 6.6, 6.4) | hood_tip(hood_cx + 1, hood_cy - 4, hood_cx + 4, 1, 2.6)
    # tattered: holes
    for p in [(9, 13), (19, 12), (18, 14), (10, 15)]:
        mask.discard(p)
    px.update(shade(mask, light_from_right=False))
    # skull
    skull = ellipse(hood_cx - 0.5, hood_cy + 2 + (1 if frame else 0), 3.8, 3.6)
    for p in skull:
        px[p] = 3
    sy = hood_cy + 1 + (1 if frame else 0)
    for (x, y) in [(11, sy), (12, sy), (11, sy + 1), (12, sy + 1), (15, sy), (16, sy), (15, sy + 1), (16, sy + 1)]:
        px[(x, y)] = 0
    px[(13, sy + 3)] = 0
    px[(14, sy + 3)] = 0
    for x in range(11, 17):
        px[(x, sy + 5)] = 0 if x % 2 else 3
    # spine & ribs
    for y in range(17, 25):
        px[(13, y)] = 3
        px[(14, y)] = 2
    for y in (18, 20, 22):
        for x in range(9, 13):
            px[(x, y)] = 3 if x > 9 else 2
        for x in range(15, 19):
            px[(x, y)] = 3 if x < 18 else 2
    # pelvis
    for x in range(10, 18):
        px[(x, 25)] = 3
    px[(10, 26)] = 2
    px[(17, 26)] = 2
    # legs bent (sitting): thighs forward, shins down
    for i in range(6):
        px[(9 - i, 26)] = 3
        px[(18 + i, 26)] = 3
    for y in range(27, 30):
        px[(3, y)] = 3
        px[(24, y)] = 3
    px[(2, 29)] = 3
    px[(25, 29)] = 3
    # arms raised to shackles
    for i in range(6):
        px[(8 - i, 17 - i)] = 3
        px[(19 + i, 17 - i)] = 3
    for (x, y) in [(1, 10), (2, 10), (1, 11), (2, 11), (25, 10), (26, 10), (25, 11), (26, 11)]:
        px[(x, y)] = 2
    # tear when frame 1
    if frame:
        px[(12, sy + 2)] = 2
    return to_rows(px, W, H)


SPRITES = {
    "mage_read": mage("read"),
    "mage_read2": mage("read", phase=1),
    "mage_angry2": mage("angry", phase=1),
    "mage_sit": mage("sit"),
    "mage_blink": mage("blink"),
    "mage_drink": mage("drink"),
    "mage_angry": mage("angry"),
    "skeleton1": skeleton(0),
    "skeleton2": skeleton(1),
}


def bookshelf(g, x0=2, y0=14, x1=22, y1=47):
    rect(g, x0, y0, x1, y1, 0)
    vline(g, x0, y0, y1, 2)
    vline(g, x1, y0, y1, 2)
    hline(g, x0, x1, y0, 2)
    rnd = random.Random(5)
    shelf_y = [y0 + 10, y0 + 21, y1]
    top = y0 + 1
    for sy in shelf_y:
        hline(g, x0, x1, sy, 2)
        x = x0 + 2
        while x < x1 - 1:
            w = rnd.choice([1, 2, 2])
            h = rnd.randint(max(4, sy - top - 4), sy - top - 1)
            c = rnd.choice([1, 2, 1, 2, 2, 3])
            if x + w > x1 - 1:
                break
            if rnd.random() < 0.08:
                x += 2  # gap
                continue
            rect(g, x, sy - h, x + w - 1, sy - 1, c)
            if h > 4:
                hline(g, x, x + w - 1, sy - h + 2, 3 if c == 1 else (1 if c == 3 else 0))
            x += w + (1 if rnd.random() < 0.6 else 0)
        top = sy + 1
    # small skull on the top shelf
    skull = [".333.", "30303", "33333", ".3.3."]
    put(g, skull, x1 - 7, y0 + 5)


def chains(g, x, y0, y1):
    for y in range(y0, y1):
        g[y][x] = 2 if (y - y0) % 3 != 2 else 1
        if (y - y0) % 3 == 1:
            g[y][x - 1] = 1
            g[y][x + 1] = 1


def tower_scene():
    g = tower_background()
    bookshelf(g)
    return g


def dungeon_scene(shackles=True):
    g = dungeon_background()
    # candle ledge (same HUD place as in the tower)
    hline(g, 2, 32, 10, 2)
    hline(g, 2, 32, 11, 1)
    if shackles:
        # wall rings with chains for the skeleton's wrists
        for (x, y) in [(20, 27), (44, 27)]:
            put(g, [".2.", "2.2", ".2."], x - 1, y)
            chains(g, x, y + 3, y + 7)
    return g


def candles(g, n, frame=0):
    for i in range(4):
        spr = (CANDLE_LIT_A if (i + frame) % 2 == 0 else CANDLE_LIT_B) if i < n else CANDLE_OUT
        put(g, spr, 5 + i * 7, 1)


def text_runes(g, x, y, idxs, color=3):
    cx = x
    for i in idxs:
        glyph = RUNES[i]
        for r, row in enumerate(glyph):
            for c, ch in enumerate(row):
                if ch == '#':
                    g[y + r][cx + c] = color
        cx += len(glyph[0]) + 2


def runes_width(idxs):
    return sum(len(RUNES[i][0]) + 2 for i in idxs) - 2


def bubble(g, x, y, idxs):
    w = runes_width(idxs) + 8
    h = 7 + 6
    rect(g, x, y, x + w - 1, y + h - 1, 0)
    hline(g, x + 1, x + w - 2, y, 3)
    hline(g, x + 1, x + w - 2, y + h - 1, 3)
    vline(g, x, y + 1, y + h - 2, 3)
    vline(g, x + w - 1, y + 1, y + h - 2, 3)
    # tail down-left
    tx, by = x + 5, y + h - 1
    g[by][tx - 1] = 0
    g[by][tx - 2] = 0
    g[by + 1][tx - 2] = 3
    g[by + 2][tx - 3] = 3
    g[by][tx] = 3
    g[by + 1][tx - 1] = 3 if False else g[by + 1][tx - 1]
    text_runes(g, x + 4, y + 3, idxs)
