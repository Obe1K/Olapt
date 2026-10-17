"""Generate OlaPT/Models/PetSprites.swift from Tools/pet/dark.py.

Run: python3 Tools/pet/gen_swift.py
Preview: python3 Tools/pet/dark_preview.py out.png
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import dark as D

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "OlaPT", "Models", "PetSprites.swift")


def grid_rows(g):
    return ["".join(str(v) for v in row) for row in g]


def trim_bottom(rows):
    while rows and set(rows[-1]) == {"."}:
        rows = rows[:-1]
    return rows


def font_rows(glyph):
    return [r.replace("#", "3") for r in glyph]


def emit(name, rows, out):
    out.append(f"    static let {name} = PetSprite(rows: [")
    out.append(",\n".join('        "' + r + '"' for r in rows))
    out.append("    ])")


def camel(name):
    parts = name.lower().split("_")
    return parts[0] + "".join(p.capitalize() for p in parts[1:])


out = [
    "// Сгенерировано Tools/pet/gen_swift.py из Tools/pet/dark.py — не редактировать вручную.",
    "",
    "enum PetSprites {",
]
emit("tower", grid_rows(D.tower_scene()), out)
emit("dungeon", grid_rows(D.dungeon_scene(False)), out)
emit("dungeonChained", grid_rows(D.dungeon_scene(True)), out)
for name, rows in D.SPRITES.items():
    emit(camel(name), trim_bottom(rows), out)
for name in ["CANDLE_LIT_A", "CANDLE_LIT_B", "CANDLE_OUT", "RAT_A", "RAT_B", "DROP", "SPLASH"]:
    emit(camel(name), getattr(D, name), out)
out.append("")
out.append("    /// Руны для ругательств (5×7, «!» и «…»).")
out.append("    static let runes: [PetSprite] = [")
out.append(",\n".join("        PetSprite(rows: [" + ", ".join('"' + r + '"' for r in font_rows(g)) + "])" for g in D.RUNES))
out.append("    ]")
out.append("}")
open(OUT, "w", encoding="utf-8").write("\n".join(out) + "\n")
print(OUT, sum(1 for _ in open(OUT)), "lines")
