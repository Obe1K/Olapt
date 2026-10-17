import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from dark import *
from side import *
from PIL import Image, ImageDraw, ImageFont

def render(g, scale=5):
    img = Image.new("RGB", (len(g[0]) * scale, len(g) * scale))
    d = ImageDraw.Draw(img)
    for y, row in enumerate(g):
        for x, v in enumerate(row):
            d.rectangle([x * scale, y * scale, x * scale + scale - 1, y * scale + scale - 1], fill=PALETTE[v])
    return img

MX, MY = 30, 13
LX, LY = 52, 22

def tower(lit=4):
    t = tower_scene(); candles(t, lit); return t

def scenes():
    out = []
    t = tower(); put(t, LECTERN, LX, LY); put(t, SIDE_SPRITES["mage_side_read"], MX, MY); put(t, GLOW_A, LX + 3, LY - 1); out.append((t, "Сыт: читает книгу за кафедрой"))
    t = tower(); put(t, LECTERN, LX, LY); put(t, PAGE_TURN, LX + 2, LY - 1); put(t, SIDE_SPRITES["mage_side_read2"], MX, MY); out.append((t, "кадр 2: перелистывает"))
    t = tower(3); put(t, LECTERN, LX, LY); put(t, SIDE_SPRITES["mage_side_tired"], MX, MY); put(t, THOUGHT_POTION, MX + 12, MY - 13); out.append((t, "Проголодался: думает о зелье"))
    t = tower(); put(t, LECTERN, LX, LY); put(t, SIDE_SPRITES["mage_side_drink"], MX, MY); out.append((t, "Пьёт зелье"))
    t = tower(); put(t, LECTERN, LX, LY); put(t, SIDE_SPRITES["mage_side_wave"], MX, MY); put(t, HEART, MX + 22, MY - 6); out.append((t, "Касание: машет"))
    return out

if __name__ == "__main__":
    outp = sys.argv[1]
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 20)
    imgs = [(render(g), cap) for g, cap in scenes()]
    w = imgs[0][0].width; h = imgs[0][0].height
    pad = 16; cols = 2; rows = (len(imgs) + 1) // 2
    sheet = Image.new("RGB", (pad + cols * (w + pad), pad + rows * (h + 40 + pad)), (255, 255, 255))
    d = ImageDraw.Draw(sheet)
    for i, (im, cap) in enumerate(imgs):
        x = pad + (i % cols) * (w + pad); y = pad + (i // cols) * (h + 40 + pad)
        sheet.paste(im, (x, y)); d.text((x, y + h + 8), cap, fill=(0, 0, 0), font=font)
    sheet.save(outp); print(outp)
