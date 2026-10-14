# -*- coding: utf-8 -*-
"""Печатает UDID симулятора iPhone: сначала «Pro Max» (для скриншотов App Store 6.9"), затем любой «Pro», затем любой iPhone."""
import json
import subprocess

out = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"])
data = json.loads(out)["devices"]

candidates = []  # (runtime, name, udid)
for runtime in sorted(data.keys()):
    if "iOS" not in runtime:
        continue
    for d in data[runtime]:
        if d["name"].startswith("iPhone"):
            candidates.append((runtime, d["name"], d["udid"]))


def pick(predicate):
    found = [c for c in candidates if predicate(c[1])]
    return found[-1] if found else None  # самый новый runtime


choice = (pick(lambda n: "Pro Max" in n)
          or pick(lambda n: "Pro" in n)
          or (candidates[-1] if candidates else None))
if choice:
    import sys
    print("Выбран симулятор: %s (%s)" % (choice[1], choice[0]), file=sys.stderr)
    print(choice[2])
