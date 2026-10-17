"""Three-quarter / profile mage at a lectern (tower scenes)."""
from dark import shade, to_rows, T, ellipse

# Silhouette of the mage in profile, facing right ('#' = robe/hood)
MAGE_SIDE_MASK = [
    "....##......................",
    "...####.....................",
    "...#####....................",
    "....######..................",
    ".....#######................",
    ".....#########..............",
    "....###########.............",
    "...#############............",
    "...##############...........",
    "..###############...........",
    "..################..........",
    "..################..........",
    "..################..........",
    "..###############...........",
    "...#############............",
    "...##############...........",
    "..#################.........",
    "..###################.......",
    "..######################....",
    "..#######################...",
    "..#################.######..",
    "..################....##....",
    "..################..........",
    "..#################.........",
    "..#################.........",
    "..#################.........",
    "..##################........",
    "..##################........",
    "..##################........",
    ".###################........",
    ".####################.......",
    ".####################.......",
    ".#####################......",
    ".#####################......",
    "#.#.#.#.#.#.#.#.#.#.#.......",
]


def mask_from(rows):
    m = set()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == "#":
                m.add((x, y))
    return m


def mage_side(pose="read", phase=0):
    """pose: read | tired | drink | wave"""
    rows = list(MAGE_SIDE_MASK)
    if pose in ("tired",):
        # arm hangs down, head lowered by 1 px
        rows = rows[:17] + [
            "..#################.........",
            "..##################........",
            "..##################........",
            "..##################........",
            "..##################........",
        ] + rows[22:]
        rows = ["." * 28] + rows[:-1]
    if pose == "drink":
        # forearm raised to the face
        rows = rows[:16] + [
            "..#################..##.....",
            "..##################.###....",
            "..###################.##....",
            "..##################.##.....",
            "..#################.##......",
            "..################..........",
        ] + rows[22:]
    if pose == "wave":
        rows = rows[:16] + [
            "..#################.....##..",
            "..##################...###..",
            "..###################.##....",
            "..##################.##.....",
            "..#################.........",
            "..################..........",
        ] + rows[22:]
    mask = mask_from(rows)
    px = shade(mask)
    dy = 1 if pose == "tired" else 0
    # face opening: dark oval at the front of the hood
    for p in ellipse(13.0, 10.5 + dy, 3.2, 3.0):
        if p in px:
            px[p] = 0
    # glowing eye
    if pose == "tired":
        px[(14, 11 + dy)] = 2
        px[(15, 11 + dy)] = 2
    elif pose == "wave":
        px[(13, 10)] = 3
        px[(15, 10)] = 3
        px[(14, 12)] = 2
    else:
        ey = 10 if phase == 0 else 11
        px[(14, ey)] = 3
        px[(15, ey)] = 3
    # robe folds
    for (x, y0) in [(6, 22), (10, 24), (14, 26)]:
        for y in range(y0, 33):
            if px.get((x, y)) == 1:
                px[(x, y)] = 0
    # belt
    for x in range(3, 19):
        if px.get((x, 22 + dy)) == 1:
            px[(x, 22 + dy)] = 2
    # hands
    if pose == "read":
        hx, hy = (22, 20) if phase == 0 else (23, 19)
        for p in [(hx, hy), (hx + 1, hy), (hx, hy + 1), (hx + 1, hy + 1)]:
            px[p] = 3
    if pose == "drink":
        # flask held at the mouth: bright potion
        flask = [".2..", ".3..", "232.", "3332", "3332", ".22."]
        for r, row in enumerate(flask):
            for c, ch in enumerate(row):
                if ch != ".":
                    px[(17 + c, 9 + r)] = int(ch)
        px[(21, 16)] = 3
        px[(22, 16)] = 3
    if pose == "wave":
        for p in [(24, 15), (25, 15), (24, 16), (25, 16), (26, 14)]:
            px[p] = 3
    return to_rows(px, 28, 35)


def make_lectern():
    """Lectern with a big open book; pages dip toward the spine, text lines, ribbon."""
    W, H = 24, 26
    g = [["."] * W for _ in range(H)]
    def setp(x, y, c):
        if 0 <= x < W and 0 <= y < H:
            g[y][x] = c
    spine = 11
    top0 = 3
    for x in range(1, W - 1):
        d = abs(x - spine - 0.5) / (spine)
        top = top0 + round(2 * (1 - d))   # pages higher at the outer edges
        bottom = top + 8
        for y in range(top, bottom + 1):
            setp(x, y, "3")
        # text lines
        if x not in (1, W - 2, spine, spine + 1):
            for k, y in enumerate(range(top + 2, bottom - 1, 2)):
                if (x + k * 3) % 7 != 0:
                    setp(x, y, "2")
        setp(x, top - 1, "2")
        setp(x, bottom + 1, "2")
        setp(x, bottom + 2, "1")
    for y in range(top0 + 1, top0 + 12):
        setp(0, y, "2")
        setp(W - 1, y, "2")
    for y in range(top0 + 2, top0 + 11):
        setp(spine, y, "2")
        setp(spine + 1, y, "1")
    # ribbon bookmark hanging from the spine
    for y in range(top0 + 12, top0 + 16):
        setp(spine + 1, y, "2")
    # stand: slanted top board and a post
    for x in range(2, W - 2):
        setp(x, top0 + 12, "2")
    for y in range(top0 + 13, H - 2):
        for x in range(spine - 2, spine + 3):
            setp(x, y, "1" if spine - 2 < x < spine + 2 else "2")
    for x in range(spine - 5, spine + 6):
        setp(x, H - 2, "2")
    for x in range(spine - 6, spine + 7):
        setp(x, H - 1, "2")
    return ["".join(r) for r in g]


LECTERN = make_lectern()

# page being turned (drawn over the left page)
PAGE_TURN = [
    "......3.....",
    ".....323....",
    "....32223...",
    "...3222223..",
    "..3333333333",
]

# glowing runes rising from the book (frames)
GLOW_A = [
    "....3.......3....",
    ".......2.........",
    "..2.........2....",
]
GLOW_B = [
    "......2....3.....",
    "...3.............",
    ".........2....2..",
]

# Empty flask on the lectern (ok/hungry state)
FLASK_EMPTY = [
    ".22.",
    ".22.",
    "2..2",
    "2..2",
    ".22.",
]

# Thought bubble with a potion inside: "I want a potion"
THOUGHT_POTION = [
    ".....222222222.....",
    "...22.........22...",
    "..2.....222.....2..",
    ".2......232......2.",
    "2.......232.......2",
    "2......23332......2",
    "2.....2333332.....2",
    "2.....2333332.....2",
    ".2.....22222.....2.",
    "..2.............2..",
    "...22.........22...",
    ".....222222222.....",
    "....22.............",
    "....22.............",
    "..22...............",
    "..22...............",
]

HEART = [
    ".33.33.",
    "3333333",
    "3333333",
    ".33333.",
    "..333..",
    "...3...",
]

SIDE_SPRITES = {
    "mage_side_read": mage_side("read", 0),
    "mage_side_read2": mage_side("read", 1),
    "mage_side_tired": mage_side("tired"),
    "mage_side_drink": mage_side("drink"),
    "mage_side_wave": mage_side("wave"),
}
