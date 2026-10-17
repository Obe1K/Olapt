import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from dark import *
from PIL import Image, ImageDraw, ImageFont

def render(g, scale=5):
    img = Image.new("RGB", (len(g[0]) * scale, len(g) * scale))
    d = ImageDraw.Draw(img)
    for y, row in enumerate(g):
        for x, v in enumerate(row):
            d.rectangle([x * scale, y * scale, x * scale + scale - 1, y * scale + scale - 1], fill=PALETTE[v])
    return img

def scenes():
    out = []
    t = tower_scene(); candles(t, 4); put(t, SPRITES["mage_read"], 34, 12); out.append((t, "Сыт: башня, читает книгу заклинаний"))
    t = tower_scene(); candles(t, 3, 1); put(t, SPRITES["mage_sit"], 34, 12); out.append((t, "Немного голоден: свечей меньше"))
    t = tower_scene(); candles(t, 4); put(t, SPRITES["mage_drink"], 34, 12); out.append((t, "После занятий: пьёт зелье"))
    d = dungeon_scene(False); candles(d, 1); put(d, SPRITES["mage_angry"], 20, 10); bubble(d, 46, 16, [0, 2, 4, 9]); out.append((d, "Голодает: темница, проклинает рунами"))
    d = dungeon_scene(True); candles(d, 0); put(d, SPRITES["skeleton1"], 18, 24); put(d, RAT_A, 60, 53); put(d, DROP, 70, 20); out.append((d, "3+ дня без еды: скелет в кандалах, крыса"))
    return out

if __name__ == "__main__":
    outp = sys.argv[1]
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 20)
    imgs = [(render(g), cap) for g, cap in scenes()]
    w = imgs[0][0].width; h = imgs[0][0].height
    pad = 16
    cols = 2
    rows = (len(imgs) + 1) // 2
    sheet = Image.new("RGB", (pad + cols * (w + pad), pad + rows * (h + 40 + pad)), (255, 255, 255))
    d = ImageDraw.Draw(sheet)
    for i, (im, cap) in enumerate(imgs):
        x = pad + (i % cols) * (w + pad); y = pad + (i // cols) * (h + 40 + pad)
        sheet.paste(im, (x, y)); d.text((x, y + h + 8), cap, fill=(0, 0, 0), font=font)
    sheet.save(outp); print(outp)
