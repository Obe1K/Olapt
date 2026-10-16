# -*- coding: utf-8 -*-
"""
Сборка данных приложения из текстового лексикона.

    python3 build_data.py

Читает Tools/lexicon/*.txt и создаёт в OlaPT/Resources:
    dict-en-pt-eu.json   — англо-португальский (европейский) словарь
    dict-ru-pt-eu.json   — русско-португальский (европейский) словарь
    verbs.json           — таблицы спряжений для всех глаголов (15 времён)

Формат строки лексикона описан в начале lexicon/01_basics.txt.
"""
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import conj  # noqa: E402

OUT = os.path.join(HERE, "..", "OlaPT", "Resources")

PACKS = [
    {"id": "en-pt-eu", "file": "dict-en-pt-eu.json", "lang": "en", "langName": "Английский",
     "name": "Английский ↔ Португальский (Европа)", "tr_index": 0},
    {"id": "ru-pt-eu", "file": "dict-ru-pt-eu.json", "lang": "ru", "langName": "Русский",
     "name": "Русский ↔ Португальский (Европа)", "tr_index": 1},
]


DUPES = []


def parse_lexicon():
    entries = []
    topics = []
    topic = None
    seen = {}
    for path in sorted(glob.glob(os.path.join(HERE, "lexicon", "*.txt"))):
        with open(path, encoding="utf-8") as fh:
            for lineno, raw in enumerate(fh, 1):
                line = raw.strip()
                if not line:
                    continue
                if line.startswith("## "):
                    tid, tname = [x.strip() for x in line[3:].split("|", 1)]
                    topic = tid
                    # Тема может продолжаться в другом файле: добавляем её один раз.
                    if not any(t["id"] == tid for t in topics):
                        topics.append({"id": tid, "name": tname})
                    continue
                if line.startswith("#"):
                    continue
                parts = [p.strip() for p in line.split(" | ")]
                where = "%s:%d" % (os.path.basename(path), lineno)
                if len(parts) < 4:
                    raise SystemExit("Слишком мало полей: %s: %s" % (where, line))
                pt, posfield, en, ru = parts[:4]
                br = parts[4] if len(parts) > 4 else ""
                note = parts[5] if len(parts) > 5 else ""
                toks = posfield.split()
                pos = toks[0]
                e = {"pt": pt, "pos": pos, "topic": topic}
                for t in toks[1:]:
                    if t in ("m", "f", "mf"):
                        e["g"] = t
                    elif t.startswith("f="):
                        e["f"] = t[2:]
                    elif t.startswith("pl="):
                        e["pl"] = t[3:]
                    elif t in ("A1", "A2", "B1", "B2"):
                        e["lv"] = t
                    else:
                        raise SystemExit("Неизвестный признак '%s' в %s" % (t, where))
                if pos == "adj" and "f" not in e and pt.endswith("o"):
                    e["f"] = pt[:-1] + "a"
                if pos == "n" and "g" not in e:
                    raise SystemExit("Не указан род у существительного: %s: %s" % (where, pt))
                e["_en"] = [x.strip() for x in en.split(",") if x.strip()]
                e["_ru"] = [x.strip() for x in ru.split(",") if x.strip()]
                if not e["_en"] or not e["_ru"]:
                    raise SystemExit("Нет перевода: %s: %s" % (where, pt))
                if br:
                    e["br"] = br
                if note:
                    e["note"] = note
                key = pt.lower() + "|" + pos
                if key in seen:
                    DUPES.append("Дубликат %s: %s (уже был в %s)" % (key, where, seen[key]))
                    continue
                seen[key] = where
                entries.append(e)
    return topics, entries


def main():
    topics, entries = parse_lexicon()
    if DUPES:
        raise SystemExit("\n".join(DUPES))
    os.makedirs(OUT, exist_ok=True)

    for pack in PACKS:
        items = []
        for e in entries:
            item = {k: v for k, v in e.items() if not k.startswith("_")}
            item["tr"] = e["_en"] if pack["tr_index"] == 0 else e["_ru"]
            if pack["lang"] != "ru":
                item.pop("note", None)  # пояснения написаны по-русски
            items.append(item)
        doc = {
            "format": 1,
            "id": pack["id"],
            "name": pack["name"],
            "lang": pack["lang"],
            "langName": pack["langName"],
            "variant": "pt-PT",
            "version": 1,
            "topics": topics,
            "entries": items,
        }
        path = os.path.join(OUT, pack["file"])
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(doc, fh, ensure_ascii=False, separators=(",", ":"))
        print("%-22s %5d слов, %6.1f КБ" % (pack["file"], len(items), os.path.getsize(path) / 1024))

    verbs = []
    for e in entries:
        if e["pos"] != "v":
            continue
        c = conj.conjugate(e["pt"])
        verbs.append(c)
    doc = {"format": 1, "tenses": conj.tenses_meta(), "verbs": verbs}
    path = os.path.join(OUT, "verbs.json")
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(doc, fh, ensure_ascii=False, separators=(",", ":"))
    print("%-22s %5d глаголов, %6.1f КБ" % ("verbs.json", len(verbs), os.path.getsize(path) / 1024))

    by_topic = {}
    for e in entries:
        by_topic[e["topic"]] = by_topic.get(e["topic"], 0) + 1
    print("Темы:", ", ".join("%s=%d" % (t["id"], by_topic.get(t["id"], 0)) for t in topics))


if __name__ == "__main__":
    main()
