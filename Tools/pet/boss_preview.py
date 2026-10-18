import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from hires import *
from PIL import Image
out = sys.argv[1]
s = 3
big = Image.new("RGB", (W * s * 2 + 20, (H * s + 20) * 2), (255, 255, 255))
for i, (key, title, fn) in enumerate(BOSSES):
    cv = arena_bg()
    for tx in (14, 176):
        cv.paste(torch_flame(i), tx - 2, 20)
    m = mage_battle()
    cv.paste(m, 18, 30)
    b = fn(0)
    cv.paste(b, 186 - b.w - 14, 86 - b.h + 4)
    cv.paste(fire_bolt(0), 84, 54)
    big.paste(cv.img.resize((W * s, H * s), Image.NEAREST), ((i % 2) * (W * s + 20), (i // 2) * (H * s + 20)))
big.save(out); print(out)
