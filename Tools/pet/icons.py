"""Pixel tab-bar icons (12x12, template images) -> OlaPT/Assets.xcassets/tab-*.imageset."""
import os, json
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSETS = os.path.join(ROOT, "OlaPT", "Assets.xcassets")

ICONS = {
    # Сегодня — свеча
    "candle": [
        ".....#......",
        "....###.....",
        "....###.....",
        ".....#......",
        "...######...",
        "...#.####...",
        "...#.####...",
        "...#.####...",
        "...#.####...",
        "...######...",
        ".##########.",
        "############",
    ],
    # Словарь — раскрытая книга
    "book": [
        "............",
        ".####..####.",
        "#....##....#",
        "#.##.##.##.#",
        "#....##....#",
        "#.##.##.##.#",
        "#....##....#",
        "#.##.##.##.#",
        "#....##....#",
        "#####..#####",
        ".....##.....",
        "............",
    ],
    # Коллекции — сундук
    "chest": [
        "............",
        "..########..",
        ".#........#.",
        "#..........#",
        "############",
        "#....##....#",
        "#....##....#",
        "#..........#",
        "#..........#",
        "#..........#",
        "############",
        "............",
    ],
    # Глаголы — перо
    "quill": [
        "..........##",
        "........####",
        ".......####.",
        "......####..",
        ".....####...",
        "....###.#...",
        "...###.#....",
        "...##.#.....",
        "..#.##......",
        "..#.........",
        ".#..........",
        "#...........",
    ],
    # Настройки — шестерня
    "gear": [
        ".....##.....",
        "..#..##..#..",
        ".###.##.###.",
        "..########..",
        "...##..##...",
        "####....####",
        "####....####",
        "...##..##...",
        "..########..",
        ".###.##.###.",
        "..#..##..#..",
        ".....##.....",
    ],
}


def write(name, rows):
    folder = os.path.join(ASSETS, f"tab-{name}.imageset")
    os.makedirs(folder, exist_ok=True)
    images = []
    for scale in (1, 2, 3):
        px = 2 * scale
        img = Image.new("RGBA", (12 * px, 12 * px), (0, 0, 0, 0))
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == "#":
                    for dy in range(px):
                        for dx in range(px):
                            img.putpixel((x * px + dx, y * px + dy), (0, 0, 0, 255))
        fn = f"tab-{name}@{scale}x.png"
        img.save(os.path.join(folder, fn))
        images.append({"filename": fn, "idiom": "universal", "scale": f"{scale}x"})
    contents = {"images": images, "info": {"author": "xcode", "version": 1},
                "properties": {"template-rendering-intent": "template"}}
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)


for n, r in ICONS.items():
    assert all(len(x) == 12 for x in r) and len(r) == 12, n
    write(n, r)
print("ok")
