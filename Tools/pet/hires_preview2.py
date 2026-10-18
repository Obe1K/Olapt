import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from hires import *
from PIL import Image

def scene(kind, lit=4, items=10, pose="read"):
    cv = make_room(kind)
    funcs = {"cauldron": item_cauldron, "raven": item_raven, "crystal": item_crystal_ball, "starmap": lambda f=0: item_star_map(),
             "hourglass": item_hourglass, "cat": item_cat, "staff": lambda f=0: item_staff(), "banner": None,
             "armor": lambda f=0: item_armor(), "circle": item_magic_circle}
    for (th, key, title, x, y) in ITEMS[:items]:
        if key == "banner":
            if kind != "hall":
                banner(cv, x, y, 22, 34)
            continue
        if kind == "summit" and key in ("starmap", "staff", "banner"):
            continue
        cv.paste(funcs[key](0) if key not in ("starmap", "staff", "armor") else funcs[key](), x, y)
    if kind == "hall":
        fire(cv, 4, 93, 0)
    for i in range(4):
        candle(cv, 12 + i * 12, 21, lit=i < lit, frame=i, h=10 + (i % 2) * 3)
    if kind == "dungeon":
        m = mage_angry_hi(0)
        cv.paste(m, 40, 20)
    else:
        open_book(cv, 103, 52, glow=False)
        cv.paste(mage_hi(pose, 0), 58, 24)
    room_lighting(cv, kind, lit)
    return cv

if __name__ == "__main__":
    out = sys.argv[1]
    kinds = [("cellar", 0), ("hall", 4), ("library", 7), ("summit", 10), ("dungeon", 0)]
    imgs = [scene(k, items=n).img for k, n in kinds]
    s = 3
    big = Image.new("RGB", (W * s * 2 + 20, (H * s + 20) * 3), (255, 255, 255))
    for i, im in enumerate(imgs):
        big.paste(im.resize((W * s, H * s), Image.NEAREST), ((i % 2) * (W * s + 20), (i // 2) * (H * s + 20)))
    big.save(out)
    print(out)
