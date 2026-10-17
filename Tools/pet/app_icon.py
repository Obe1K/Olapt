"""App icon: pixel-art hooded mage over a glowing book (64x64 -> 1024x1024)."""
import os, sys, math
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "OlaPT", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")

N = 64
BG = (13, 11, 10)
MORTAR = (24, 21, 18)
BRICK = (17, 15, 13)
HOOD = (46, 44, 54)
HOOD_D = (30, 29, 36)
HOOD_L = (98, 96, 106)
GOLD = (201, 163, 90)
GOLD_B = (240, 206, 130)
GOLD_D = (110, 84, 40)
PARCH = (236, 224, 196)
INK = (150, 120, 70)
BLACK = (6, 6, 8)
EYE = (250, 240, 214)


def make():
    px = [[BG] * N for _ in range(N)]

    def s(x, y, c):
        if 0 <= x < N and 0 <= y < N:
            px[y][x] = c

    # stone wall
    for y in range(N):
        for x in range(N):
            row = y // 8
            off = 8 if row % 2 else 0
            if y % 8 == 0 or (x + off) % 16 == 0:
                s(x, y, MORTAR)
            else:
                s(x, y, BRICK)
    # crescent moon (top right)
    for y in range(4, 20):
        for x in range(42, 60):
            d1 = (x - 51) ** 2 + (y - 11) ** 2
            d2 = (x - 48) ** 2 + (y - 9) ** 2
            if d1 <= 30 and d2 > 26:
                s(x, y, PARCH)

    # hood + shoulders mask
    hood = set()
    cx, cy = 31.5, 31
    for y in range(N):
        for x in range(N):
            if ((x - cx) / 16.5) ** 2 + ((y - cy) / 17.5) ** 2 <= 1:
                hood.add((x, y))
    # pointed tip bending to the right
    for i in range(60):
        t = i / 59
        tx = 31 + 10 * t * t
        ty = 16 - 13 * t
        w = 6.5 * (1 - t) + 0.6
        for y in range(int(ty - w) - 1, int(ty + w) + 2):
            for x in range(int(tx - w) - 1, int(tx + w) + 2):
                if (x - tx) ** 2 + (y - ty) ** 2 <= w * w:
                    hood.add((x, y))
    # shoulders / robe down to the bottom edge
    for y in range(40, N):
        t = (y - 40) / (N - 40)
        l = int(14 - 12 * t)
        r = int(49 + 12 * t)
        for x in range(l, r + 1):
            hood.add((x, y))
    for (x, y) in hood:
        edge = any((x + dx, y + dy) not in hood for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if edge:
            s(x, y, HOOD_L)
        else:
            # simple dithered shading: darker on the left
            s(x, y, HOOD_D if (x < 22 and (x + y) % 2 == 0) or x < 19 else HOOD)
    # folds on the robe
    for (fx, fy) in [(22, 46), (31, 48), (41, 46)]:
        for y in range(fy, N):
            s(fx, y, HOOD_D)

    # face opening
    for y in range(N):
        for x in range(N):
            if ((x - 31.5) / 10.5) ** 2 + ((y - 31.5) / 9.5) ** 2 <= 1:
                s(x, y, BLACK)
    # glowing eyes with halo
    for (ex, ey) in [(25, 30), (35, 30)]:
        for (hx, hy) in [(-1, 0), (4, 0), (0, -1), (1, -1), (2, -1), (0, 2), (1, 2), (2, 2)]:
            s(ex + hx, ey + hy, (60, 54, 40))
        for x in range(ex, ex + 3):
            for y in range(ey, ey + 2):
                s(x, y, EYE)

    # open book at the bottom, glowing
    spine = 32
    for x in range(12, 52):
        d = abs(x - spine + 0.5) / 20
        top = 47 + round(3 * (1 - d))
        for y in range(top, top + 11):
            s(x, y, PARCH)
        s(x, top - 1, GOLD_D)
        s(x, top + 11, GOLD_D)
        s(x, top + 12, (60, 46, 22))
        if x not in (12, 51, spine - 1, spine) and x % 9 != 0:
            for k, y in enumerate(range(top + 2, top + 10, 2)):
                if (x * 3 + k * 5) % 11 != 0:
                    s(x, y, INK)
    for y in range(48, 62):
        s(spine - 1, y, GOLD_D)
        s(spine, y, (60, 46, 22))
    # gold rim light on the robe near the book
    for (x, y) in list(hood):
        if 40 <= y < 47 and px[y][x] == HOOD_L:
            s(x, y, GOLD)
    # rising glow / runes from the book
    for (x, y, c) in [(20, 42, GOLD), (23, 39, GOLD_B), (28, 43, GOLD), (36, 41, GOLD_B),
                      (41, 43, GOLD), (44, 38, GOLD), (17, 36, GOLD_D), (47, 35, GOLD_D),
                      (31, 44, GOLD_B)]:
        s(x, y, c)
    return px


def save(px, path, scale=16):
    img = Image.new("RGB", (N * scale, N * scale))
    for y in range(N):
        for x in range(N):
            for dy in range(scale):
                for dx in range(scale):
                    img.putpixel((x * scale + dx, y * scale + dy), px[y][x])
    img.save(path)


if __name__ == "__main__":
    px = make()
    out = sys.argv[1] if len(sys.argv) > 1 else OUT
    save(px, out)
    print(out)
