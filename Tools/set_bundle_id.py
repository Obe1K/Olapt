#!/usr/bin/env python3
"""Заменяет Bundle ID во всём проекте.

Использование:  python3 Tools/set_bundle_id.py com.ваше.имя.olapt

Меняет com.example.olapt (и com.example.olapt.uitesthost / .uitests) в:
  - OlaPT.xcodeproj/project.pbxproj
  - .github/workflows/build.yml   (запуск приложения в симуляторе)
  - UITests/Tests/ScreenshotTests.swift
  - UITests/project.yml
Bundle ID: латинские буквы, цифры, точки и дефисы; не меньше двух сегментов.
"""
import re
import sys
from pathlib import Path

OLD = "com.example.olapt"
FILES = [
    "OlaPT.xcodeproj/project.pbxproj",
    ".github/workflows/build.yml",
    "UITests/Tests/ScreenshotTests.swift",
    "UITests/project.yml",
]

def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    new = sys.argv[1].strip()
    if not re.fullmatch(r"[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+", new):
        print("Некорректный Bundle ID:", new)
        return 2
    root = Path(__file__).resolve().parent.parent
    total = 0
    for rel in FILES:
        p = root / rel
        text = p.read_text(encoding="utf-8")
        n = text.count(OLD)
        if n:
            p.write_text(text.replace(OLD, new), encoding="utf-8")
        print(f"{rel}: {n} замен")
        total += n
    print("Всего замен:", total)
    return 0 if total else 1

if __name__ == "__main__":
    sys.exit(main())
