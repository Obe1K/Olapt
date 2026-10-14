# -*- coding: utf-8 -*-
"""Рисует иконку приложения 1024x1024 (без прозрачности, как требует App Store)."""
import os
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "OlaPT", "Assets.xcassets",
                   "AppIcon.appiconset", "AppIcon.png")
S = 2048  # рисуем вдвое крупнее и уменьшаем — гладкие края


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


img = Image.new("RGB", (S, S))
px = ImageDraw.Draw(img)
top, bottom = (36, 96, 170), (14, 44, 104)
for y in range(S):
    px.line([(0, y), (S, y)], fill=lerp(top, bottom, y / (S - 1)))

# лёгкий узор в духе азулежу: решётка четырёхлучевых звёзд
pattern = Image.new("RGBA", (S, S), (0, 0, 0, 0))
pd = ImageDraw.Draw(pattern)
step = 256
for gx in range(0, S + step, step):
    for gy in range(0, S + step, step):
        cx, cy, r = gx, gy, 54
        pts = [(cx, cy - r), (cx + r * 0.28, cy - r * 0.28), (cx + r, cy), (cx + r * 0.28, cy + r * 0.28),
               (cx, cy + r), (cx - r * 0.28, cy + r * 0.28), (cx - r, cy), (cx - r * 0.28, cy - r * 0.28)]
        pd.polygon(pts, fill=(255, 255, 255, 26))
img.paste(pattern, (0, 0), pattern)

d = ImageDraw.Draw(img)

# облачко речи
bx0, by0, bx1, by1 = 300, 520, 1748, 1360
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.rounded_rectangle((bx0 + 10, by0 + 28, bx1 + 10, by1 + 28), radius=300, fill=(0, 0, 0, 70))
sd.polygon([(520, by1 - 60), (470, 1640), (800, by1 - 40)], fill=(0, 0, 0, 70))
img.paste(shadow, (0, 0), shadow)
d = ImageDraw.Draw(img)
d.rounded_rectangle((bx0, by0, bx1, by1), radius=300, fill=(255, 255, 255))
d.polygon([(520, by1 - 70), (460, 1630), (800, by1 - 50)], fill=(255, 255, 255))

# текст «Olá»
font_path = "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf"
if not os.path.exists(font_path):
    font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
font = ImageFont.truetype(font_path, 560)
text = "Olá"
bbox = d.textbbox((0, 0), text, font=font)
tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
tx = (bx0 + bx1) // 2 - tw // 2 - bbox[0]
ty = (by0 + by1) // 2 - th // 2 - bbox[1] - 10
d.text((tx, ty), text, font=font, fill=(26, 78, 146))

# значок «PT»
cx, cy, r = 1650, 520, 230
d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(226, 62, 44))
f2 = ImageFont.truetype(font_path, 220)
b2 = d.textbbox((0, 0), "PT", font=f2)
d.text((cx - (b2[2] - b2[0]) // 2 - b2[0], cy - (b2[3] - b2[1]) // 2 - b2[1]), "PT", font=f2, fill=(255, 255, 255))

img = img.resize((1024, 1024), Image.LANCZOS).convert("RGB")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT, "PNG")
print("saved", os.path.abspath(OUT), img.size, img.mode)
