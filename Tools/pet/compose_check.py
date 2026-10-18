"""Compose exported layers like the app does (for checking positions)."""
import os, sys, re
from PIL import Image
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
A = os.path.join(ROOT, "OlaPT", "Assets.xcassets", "Pet")
src = open(os.path.join(ROOT, "OlaPT", "Models", "PetAtlas.swift")).read()
L = {m[0]: tuple(map(int, m[1:])) for m in re.findall(r'"(\w+)": PetLayer\(name: "\w+", x: (-?\d+), y: (-?\d+), w: (\d+), h: (\d+)\)', src)}

def img(name):
    return Image.open(os.path.join(A, name + ".imageset", name + ".png")).convert("RGBA")

def put(canvas, name, dx=0, dy=0):
    x, y, w, h = L[name]
    canvas.alpha_composite(img(name), (x + dx, y + dy)) if x + dx >= 0 and y + dy >= 0 else canvas.paste(img(name), (x + dx, y + dy), img(name))

def scene(room="library", mood="happy", lit=4, items=10, tick=0):
    c = img("pet_bg_" + room).copy()
    for i in range(4):
        tall = i % 2
        bx, by = 12 + i * 12, 21
        if i < lit:
            put(c, f"pet_candle_light", bx + 1, by - 15)
            put(c, f"pet_candle{tall}_lit{(tick + i) % 4}", bx, by)
        else:
            put(c, f"pet_candle{tall}_out{(tick + i) % 2}", bx, by)
    if mood in ("happy", "ok"):
        if room == "hall":
            put(c, f"pet_fire{tick % 3}")
        keys = ["cauldron", "raven", "crystal", "starmap", "hourglass", "cat", "bats", "banner", "armor", "circle"][:items]
        for k in keys:
            if room == "summit" and k in ("starmap", "banner"):
                continue
            names = sorted(n for n in L if n.startswith(f"pet_item_{k}"))
            put(c, names[tick % len(names)])
        put(c, "pet_book")
        if mood == "happy":
            put(c, f"pet_sparks{tick % 3}")
            put(c, "pet_mage_read")
            put(c, f"pet_runes{tick % 10}")
        else:
            put(c, "pet_mage_tired")
            put(c, "pet_thought")
    elif mood == "angry":
        put(c, f"pet_mage_angry{tick % 2}")
        put(c, f"pet_curse{tick % 6}")
    else:
        put(c, f"pet_skeleton{tick % 2}")
        x = 150 - tick * 6
        put(c, f"pet_rat{tick % 2}", x, 0)
        put(c, "pet_sigh")
    return c

if __name__ == "__main__":
    out = sys.argv[1]
    sc = [scene("library", "happy"), scene("hall", "ok", 3, 8), scene("cellar", "happy", 4, 1), scene("summit", "happy", 4, 10),
          scene("dungeon", "angry", 1), scene("dungeon_chained", "skeleton", 0)]
    s = 3
    big = Image.new("RGB", (192 * s * 2 + 20, (120 * s + 20) * 3), (255, 255, 255))
    for i, im in enumerate(sc):
        big.paste(im.resize((192 * s, 120 * s), Image.NEAREST), ((i % 2) * (192 * s + 20), (i // 2) * (120 * s + 20)))
    big.save(out); print(out)
