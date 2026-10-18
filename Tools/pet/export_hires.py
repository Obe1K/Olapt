"""Export hi-res pet layers as PNG imagesets + OlaPT/Models/PetAtlas.swift.

Run: python3 Tools/pet/export_hires.py
"""
import os, sys, json, shutil
sys.path.insert(0, os.path.dirname(__file__))
from hires import *
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSETS = os.path.join(ROOT, "OlaPT", "Assets.xcassets", "Pet")
SWIFT = os.path.join(ROOT, "OlaPT", "Models", "PetAtlas.swift")

layers = {}   # name -> (x, y, w, h)


def save_png(name, img):
    folder = os.path.join(ASSETS, name + ".imageset")
    os.makedirs(folder, exist_ok=True)
    img.save(os.path.join(folder, name + ".png"))
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({"images": [{"filename": name + ".png", "idiom": "universal", "scale": "1x"}],
                   "info": {"author": "xcode", "version": 1}}, f, indent=2)


def export_full(name, cv, x0=0, y0=0):
    """Crop to the non-transparent bounding box and remember the offset."""
    img = cv.img
    bbox = img.getbbox()
    if bbox is None:
        return
    crop = img.crop(bbox)
    save_png(name, crop)
    layers[name] = (x0 + bbox[0], y0 + bbox[1], crop.width, crop.height)


def at(draw_fn):
    cv = Canvas()
    draw_fn(cv)
    return cv


def sprite_at(sprite_cv, x, y):
    cv = Canvas()
    cv.paste(sprite_cv, x, y) if x >= 0 and y >= 0 else None
    if x < 0 or y < 0:
        cv.img.alpha_composite(sprite_cv.img, (max(0, x), max(0, y)))
    return cv


def main():
    if os.path.isdir(ASSETS):
        shutil.rmtree(ASSETS)
    os.makedirs(ASSETS)
    with open(os.path.join(ASSETS, "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)

    # backgrounds (static lighting baked in, without candles)
    for kind in ["cellar", "hall", "library", "summit", "dungeon", "dungeon_chained"]:
        k = "dungeon" if kind.startswith("dungeon") else kind
        cv = make_room(k)
        if kind == "dungeon_chained":
            for (rx, hx) in ((40, 40), (88, 88)):
                cv.ellipse(rx - 3, 56, rx + 3, 62, None, outline="st4")
                chain(cv, rx, 63, 76)
        room_lighting(cv, k, 0)
        img = cv.img.copy()
        # the vignette is applied in room_lighting; keep opaque
        save_png("pet_bg_" + kind, img)
        layers["pet_bg_" + kind] = (0, 0, W, H)

    # candles: two heights, lit (4 frames) and out (2 frames)
    for tall in (0, 1):
        h = 10 + tall * 3
        for f in range(4):
            export_full(f"pet_candle{tall}_lit{f}", at(lambda cv: candle(cv, 20, 40, True, f, h)), -20 + 0, -40 + 0)
        for f in range(2):
            export_full(f"pet_candle{tall}_out{f}", at(lambda cv: candle(cv, 20, 40, False, f, h)), -20, -40)
    # warm light pool for a lit candle (alpha overlay), centred
    lc = Canvas(48, 48)
    px = lc.img.load()
    for y in range(48):
        for x in range(48):
            d = ((x - 24) ** 2 + (y - 24) ** 2) ** 0.5 / 24
            if d < 1:
                a = int(255 * 0.30 * (1 - d) ** 2)
                px[x, y] = P["fl1"] + (a,)
    save_png("pet_candle_light", lc.img)
    layers["pet_candle_light"] = (-24, -24, 48, 48)

    # book and page turn, sparks
    export_full("pet_book", at(lambda cv: open_book(cv, 103, 52, glow=False)))
    export_full("pet_page_turn", sprite_at(page_turn_hi(), 104, 41))
    for f in range(3):
        export_full(f"pet_sparks{f}", sprite_at(sparks_hi(f), 103, 18))

    # mage poses (tower)
    for pose, ph, name in [("read", 0, "pet_mage_read"), ("read", 1, "pet_mage_read2"), ("tired", 0, "pet_mage_tired"),
                           ("drink", 0, "pet_mage_drink"), ("wave", 0, "pet_mage_wave")]:
        export_full(name, sprite_at(mage_hi(pose, ph), 58, 24))
    # dungeon
    for f in range(2):
        export_full(f"pet_mage_angry{f}", sprite_at(mage_angry_hi(f), 40, 20))
        export_full(f"pet_skeleton{f}", sprite_at(skeleton_hi(f), 36, 54))
        rat = rat_hi(f)
        save_png(f"pet_rat{f}", rat.img)
        layers[f"pet_rat{f}"] = (0, 104, rat.w, rat.h)
    save_png("pet_drop", drop_hi().img); layers["pet_drop"] = (70, 0, 2, 4)
    save_png("pet_splash", splash_hi().img); layers["pet_splash"] = (67, 92, 7, 3)
    tb = thought_bubble_potion()
    export_full("pet_thought", sprite_at(tb, 92, 0))
    hb = heart_hi()
    save_png("pet_heart", hb.img); layers["pet_heart"] = (102, 14, hb.w, hb.h)
    # rune bubbles: curses + "!!!!" + "…"
    curses = [[0, 2, 4, 9], [3, 1, 6, 9], [5, 7, 2, 9, 9], [4, 8, 0, 9], [6, 3, 5, 1], [2, 2, 7, 9]]
    for i, c in enumerate(curses):
        export_full(f"pet_curse{i}", sprite_at(rune_bubble_hi(c), 80, 10))
    export_full("pet_curse_shout", sprite_at(rune_bubble_hi([9, 9, 9, 9]), 80, 10))
    export_full("pet_sigh", sprite_at(rune_bubble_hi([10]), 96, 40))
    # fire (hall)
    for f in range(3):
        export_full(f"pet_fire{f}", at(lambda cv: fire(cv, 4, 93, f)))

    # items
    item_frames = {
        "cauldron": [item_cauldron(0), item_cauldron(1)],
        "raven": [item_raven(0), item_raven(1)],
        "crystal": [item_crystal_ball(0), item_crystal_ball(1)],
        "starmap": [item_star_map()],
        "hourglass": [item_hourglass(0), item_hourglass(1), item_hourglass(2)],
        "cat": [item_cat(1), item_cat(0)],
        "staff": [item_staff()],
        "banner": None,
        "armor": [item_armor()],
        "circle": [item_magic_circle(0), item_magic_circle(1)],
    }
    for (th, key, title, x, y) in ITEMS:
        if key == "banner":
            export_full("pet_item_banner0", at(lambda cv: banner(cv, x, y, 22, 34)))
            continue
        for f, spr in enumerate(item_frames[key]):
            export_full(f"pet_item_{key}{f}", sprite_at(spr, x, y))

    # boss arena
    save_png("pet_bg_arena", arena_bg().img)
    layers["pet_bg_arena"] = (0, 0, W, H)
    for f in range(4):
        for i, tx in enumerate((14, 176)):
            export_full(f"pet_torch{i}_{f}", sprite_at(torch_flame(f + i), tx - 2, 20))
    export_full("pet_battle_mage", sprite_at(mage_hi("wave", 0), 18, 30))
    export_full("pet_battle_mage_hurt", sprite_at(mage_hi("tired", 0), 18, 30))
    for f in range(2):
        bolt = fire_bolt(f)
        save_png(f"pet_bolt{f}", bolt.img)
        layers[f"pet_bolt{f}"] = (0, 52, bolt.w, bolt.h)
    for key, title, fn in BOSSES:
        for f in range(2):
            b = fn(f)
            export_full(f"pet_boss_{key}{f}", sprite_at(b, 186 - b.w - 14, 90 - b.h))
        b = fn(0, hit=True)
        export_full(f"pet_boss_{key}_hit", sprite_at(b, 186 - b.w - 14, 90 - b.h))

    # Swift atlas
    out = ["// Сгенерировано Tools/pet/export_hires.py — не редактировать вручную.", "",
           "/// Слой сцены: картинка из Assets/Pet и её место на экране 192×120.",
           "struct PetLayer {", "    let name: String", "    let x: Int", "    let y: Int", "    let w: Int", "    let h: Int", "}", "",
           "enum PetAtlas {", "    static let width = 192", "    static let height = 120", "",
           "    static let layers: [String: PetLayer] = ["]
    items = []
    for name in sorted(layers):
        x, y, w, h = layers[name]
        items.append(f'        "{name}": PetLayer(name: "{name}", x: {x}, y: {y}, w: {w}, h: {h})')
    out.append(",\n".join(items))
    out.append("    ]")
    out.append("")
    out.append("    /// Вещи в башне за выученные слова: порог, ключ, название.")
    out.append("    static let items: [(threshold: Int, key: String, title: String)] = [")
    out.append(",\n".join(f'        ({th}, "{key}", "{title}")' for (th, key, title, x, y) in ITEMS))
    out.append("    ]")
    out.append("")
    out.append("    /// Боссы недели по кругу: ключ и название.")
    out.append("    static let bosses: [(key: String, title: String)] = [")
    out.append(",\n".join(f'        ("{k}", "{t}")' for k, t, fn in BOSSES))
    out.append("    ]")
    out.append("}")
    open(SWIFT, "w", encoding="utf-8").write("\n".join(out) + "\n")
    print(len(layers), "layers →", SWIFT)


if __name__ == "__main__":
    main()
