import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from hires import *
from PIL import Image

def library(lit=4, frame=0, pose="read", turn=0):
    cv = Canvas(bg="st1")
    stone_wall(cv, 0, 0, W - 1, 92)
    # baseboard
    cv.rect(0, 92, W - 1, 94, "st0")
    cv.line([(0, 92), (W - 1, 92)], "st3")
    wood_floor(cv, 95)
    # rug
    cv.rect(52, 100, 140, 114, "bl0")
    cv.rect(54, 101, 138, 113, "bl1")
    cv.rect(56, 102, 136, 112, "bl0")
    for x in range(58, 136, 6):
        cv.px(x, 104, "gd1"); cv.px(x + 3, 110, "gd1")
    cv.line([(54, 101), (138, 101)], "gd0")
    inside = arched_window(cv, 140, 14, 176, 70)
    bookshelf(cv, 6, 30, 46, 92)
    wall_shelf(cv, 8, 58, 22)
    for i in range(4):
        candle(cv, 12 + i * 12, 21, lit=i < lit, frame=frame + i, h=10 + (i % 2) * 3)

    lectern(cv, 104, 52)
    open_book(cv, 103, 52, glow=False, turn=turn)
    m = mage_hi(pose, frame % 2)
    cv.paste(m, 58, 24)
    # lighting: candles, book, moon
    for i in range(lit):
        light(cv, 14 + i * 12, 6, 22, "fl1", 0.35)
    light(cv, 121, 44, 34, "gd2", 0.45)
    light(cv, 158, 40, 30, "ic1", 0.18)
    vignette(cv, 0.6)
    return cv

if __name__ == "__main__":
    out = sys.argv[1]
    a = library().img
    b = library(lit=3, pose="tired").img
    big = Image.new("RGB", (W * 4 * 2 + 20, H * 4), (255, 255, 255))
    big.paste(a.resize((W * 4, H * 4), Image.NEAREST), (0, 0))
    big.paste(b.resize((W * 4, H * 4), Image.NEAREST), (W * 4 + 20, 0))
    big.save(out)
    print(out)


def dungeon(pose="angry"):
    import dark
    cv = Canvas(bg="st0")
    dungeon_wall(cv, 0, 0, W - 1, 92)
    barred_window(cv, 80, 10, 108, 28)
    straw_floor(cv, 93)
    wall_shelf(cv, 8, 58, 22)
    for i in range(4):
        candle(cv, 12 + i * 12, 21, lit=i < (1 if pose == "angry" else 0), frame=i, h=10 + (i % 2) * 3)
    if pose == "skeleton":
        for x in (40, 90):
            cv.ellipse(x - 3, 46, x + 3, 52, None, outline="st4")
            chain(cv, x, 53, 64)
        sk = recolor_grey(scale2x(dark.skeleton(0)), {"3": "bone", "2": "pa0", "1": "st2", "0": "void"})
        cv.paste(sk, 36, 54)
        rat = recolor_grey(scale2x(dark.RAT_A), {"2": "st3", "3": "bl2"})
        cv.paste(rat, 130, 106)
    else:
        m = recolor_grey(scale2x(dark.mage("angry")), {"1": "rb1", "2": "rb2", "3": "pa1", "0": "void"})
        cv.paste(m, 44, 22)
    light_shaft(cv, 80, 108, 29, 93)
    for i in range(1 if pose == "angry" else 0):
        light(cv, 14 + i * 12, 6, 22, "fl1", 0.35)
    front_bars(cv, 150, W)
    vignette(cv, 0.7)
    return cv


if __name__ == "__main__" and len(sys.argv) > 2:
    out = sys.argv[2]
    a = dungeon("angry").img
    b = dungeon("skeleton").img
    big = Image.new("RGB", (W * 4 * 2 + 20, H * 4), (255, 255, 255))
    big.paste(a.resize((W * 4, H * 4), Image.NEAREST), (0, 0))
    big.paste(b.resize((W * 4, H * 4), Image.NEAREST), (W * 4 + 20, 0))
    big.save(out)
