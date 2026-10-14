# -*- coding: utf-8 -*-
"""Раскладывает экспортированные из .xcresult вложения по понятным именам: shots_named/01_dictionary_home.png и т. д."""
import json
import os
import re
import shutil
import sys

SRC = sys.argv[1] if len(sys.argv) > 1 else "shots"
DST = sys.argv[2] if len(sys.argv) > 2 else "shots_named"

manifest_path = os.path.join(SRC, "manifest.json")
if not os.path.exists(manifest_path):
    print("manifest.json не найден в", SRC)
    sys.exit(0)

manifest = json.load(open(manifest_path, encoding="utf-8"))
if isinstance(manifest, dict):
    manifest = manifest.get("tests") or manifest.get("items") or [manifest]

os.makedirs(DST, exist_ok=True)
count = 0
for item in manifest:
    for att in item.get("attachments", []):
        exported = att.get("exportedFileName")
        if not exported:
            continue
        src = os.path.join(SRC, exported)
        if not os.path.exists(src):
            continue
        human = att.get("suggestedHumanReadableName") or exported
        # убираем технический хвост вида «_0_8F3A1C2B-....»
        human = re.sub(r"_\d+_[0-9A-Fa-f\-]{36}(?=\.)", "", human)
        shutil.copyfile(src, os.path.join(DST, human))
        count += 1
print("Скопировано файлов:", count)
