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
import phrasebank  # noqa: E402
from content_en import topics as en_topics  # noqa: E402


def english_notes():
    """Пояснения к словам по-английски: Tools/content_en/notes_*.py («слово|часть речи» → текст)."""
    import importlib
    notes = {}
    for path in sorted(glob.glob(os.path.join(HERE, "content_en", "notes_*.py"))):
        mod = importlib.import_module("content_en." + os.path.basename(path)[:-3])
        for k, v in mod.NOTES.items():
            if k in notes:
                raise SystemExit("Английское пояснение задано дважды: " + k)
            notes[k] = v
    return notes

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
                # Делим по «|» без учёта пробелов: «ru | | note» — пустое поле br, а не br = «| note».
                parts = [p.strip() for p in line.split("|")]
                where = "%s:%d" % (os.path.basename(path), lineno)
                if len(parts) < 4:
                    raise SystemExit("Слишком мало полей: %s: %s" % (where, line))
                pt, posfield, en, ru = parts[:4]
                br = parts[4] if len(parts) > 4 else ""
                note = parts[-1] if len(parts) > 5 else ""
                if len(parts) > 7 or (len(parts) == 7 and parts[5]):
                    raise SystemExit("Лишние поля: %s: %s" % (where, line))
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

    # Английские пояснения: у каждого русского должна быть пара, лишних (с опечаткой в ключе) быть не должно
    notes_en = english_notes()
    missing = [e["pt"] + "|" + e["pos"] for e in entries if e.get("note") and (e["pt"] + "|" + e["pos"]) not in notes_en]
    extra = sorted(set(notes_en) - {e["pt"] + "|" + e["pos"] for e in entries if e.get("note")})
    if missing or extra:
        raise SystemExit("Английские пояснения: нет для %d слов %s; лишние ключи: %s" % (len(missing), missing[:20], extra[:20]))
    for e in entries:
        if e.get("note"):
            e["_note_en"] = notes_en[e["pt"] + "|" + e["pos"]]
    missing_topics = [t["id"] for t in topics if t["id"] not in en_topics.TOPICS]
    if missing_topics:
        raise SystemExit("Нет английских названий тем: %s" % missing_topics)
    topics = [dict(t, nameEn=en_topics.TOPICS[t["id"]]) for t in topics]

    # Банк фраз; выражения из него («estar com fome») попадают и в словарь — их узнаёт «Слова из фото»
    phrases, phrase_entries, phrase_count = phrasebank.build(conj)
    keys = {e["pt"].lower() + "|" + e["pos"] for e in entries}
    added = 0
    for pe in phrase_entries:
        key = pe["pt"].lower() + "|phrase"
        if key in keys:
            continue
        keys.add(key)
        e = {"pt": pe["pt"], "pos": "phrase", "topic": "expressions", "lv": pe["lv"],
             "_en": [x.strip() for x in pe["en"].split(";") if x.strip()],
             "_ru": [x.strip() for x in pe["ru"].split(",") if x.strip()]}
        if pe["note"]:
            e["note"] = pe["note"]
            e["_note_en"] = pe["note_en"]
        entries.append(e)
        added += 1
    path = os.path.join(OUT, "phrases.json")
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(phrases, fh, ensure_ascii=False, separators=(",", ":"))
    print("%-22s %5d фраз, %6.1f КБ (в словарь добавлено выражений: %d)"
          % ("phrases.json", phrase_count, os.path.getsize(path) / 1024, added))

    for pack in PACKS:
        items = []
        for e in entries:
            item = {k: v for k, v in e.items() if not k.startswith("_")}
            item["tr"] = e["_en"] if pack["tr_index"] == 0 else e["_ru"]
            if pack["lang"] == "en":
                item.pop("note", None)
                if e.get("_note_en"):
                    item["note"] = e["_note_en"]
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
    tenses = conj.tenses_meta()
    for t in tenses:
        if t["id"] not in en_topics.TENSES or t["group"] not in en_topics.TENSE_GROUPS:
            raise SystemExit("Нет английского описания времени: " + t["id"])
        t["en"] = en_topics.TENSES[t["id"]]
        t["groupEn"] = en_topics.TENSE_GROUPS[t["group"]]
    doc = {"format": 1, "tenses": tenses, "verbs": verbs}
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
