# -*- coding: utf-8 -*-
"""
Банк фраз для упражнения «Фразы»: Tools/phrases/*.txt → OlaPT/Resources/phrases.json.

Выражения в лицах («~») спрягаются автоматически (conj.py), прилагательные со «*» согласуются
по роду и числу. Для каждой строки упражнения сохраняются:
    ru      — подсказка по-русски
    show    — правильный ответ, как его показать (с заглавной буквы и точкой)
    also    — другие правильные варианты (показываются как «Можно и так»)
    accept  — все принимаемые ответы в нормализованном виде (без регистра и знаков препинания)
    tiles   — слова ответа для упражнения «Собери фразу»
    extra   — лишние слова-ловушки
"""
import glob
import itertools
import os
import random
import re

HERE = os.path.dirname(os.path.abspath(__file__))

PERSONS = [  # (pronoun, index in conj tables, gender, plural)
    ("eu", 0, "x", False),
    ("tu", 1, "x", False),
    ("ele", 2, "m", False),
    ("ela", 2, "f", False),
    ("nós", 3, "x", True),
    ("eles", 4, "m", True),
]
PUNCT = re.compile(r"[.,!?¿¡;:«»\"“”()…]")


def norm(text):
    t = PUNCT.sub(" ", text.lower())
    return " ".join(t.split())


def agree(adj, gender, plural):
    """cansado → cansada / cansados / cansadas; feliz → felizes; triste → tristes."""
    base = adj
    if gender == "f" and base.endswith("o"):
        base = base[:-1] + "a"
    if not plural:
        return base
    if base.endswith(("a", "o", "e")):
        return base + "s"
    if base.endswith("z") or base.endswith("r") or base.endswith("s"):
        return base + "es"
    if base.endswith("l"):
        return base[:-1] + "is"
    return base + "s"


def gender_options(gender, plural, pronoun):
    """Какие формы прилагательного принимаем: для «eu», «tu», «nós» — обе, для «eles» — и «elas»."""
    if gender == "x":
        return ["m", "f"]
    if pronoun == "eles":
        return ["m", "f"]
    return [gender]


def subject_for(pronoun, g):
    if pronoun == "eles" and g == "f":
        return "elas"
    return pronoun


def sentence_case(text, question):
    t = text[0].upper() + text[1:]
    return t + ("?" if question else ".")


def parse(conj):
    sets = []
    current = None
    dict_entries = []
    for path in sorted(glob.glob(os.path.join(HERE, "phrases", "*.txt"))):
        with open(path, encoding="utf-8") as fh:
            for lineno, raw in enumerate(fh, 1):
                line = raw.strip()
                where = "%s:%d" % (os.path.basename(path), lineno)
                if not line or (line.startswith("#") and not line.startswith("## ")):
                    continue
                if line.startswith("## "):
                    sid, name, level = [x.strip() for x in line[3:].split("|")]
                    current = {"id": sid, "name": name, "level": level, "items": []}
                    sets.append(current)
                    continue
                if current is None:
                    raise SystemExit("Фраза вне набора: " + where)
                note = ""
                if "||" in line:
                    line, note = [x.strip() for x in line.split("||", 1)]
                kind, body = line[0], line[1:].strip()
                parts = [p.strip() for p in body.split(" | ")]
                if kind == "~":
                    if len(parts) != 9:
                        raise SystemExit("Нужно 9 полей (варианты, en, ru, 6 лиц): " + where)
                    alts = [a.strip() for a in parts[0].split(" / ")]
                    item = person_item(conj, current, alts, parts[1], parts[2], parts[3:], note, where)
                    for a in alts:
                        dict_entries.append({"pt": a.replace("*", ""), "en": parts[1], "ru": parts[2],
                                             "lv": current["level"],
                                             "note": ("То же: " + ", ".join(x.replace("*", "") for x in alts if x != a) + ".")
                                             if len(alts) > 1 else ""})
                elif kind == "=":
                    if len(parts) != 3:
                        raise SystemExit("Нужно 3 поля (фраза, en, ru): " + where)
                    alts = [a.strip() for a in parts[0].split(" / ")]
                    item = fixed_item(current, alts, parts[1], parts[2], note)
                else:
                    raise SystemExit("Строка должна начинаться с «~», «=» или «##»: " + where)
                current["items"].append(item)
    for s in sets:
        add_traps(s)
    return sets, dict_entries


def person_item(conj, set_, alts, en, ru, ru_lines, note, where):
    tables = []
    for a in alts:
        words = a.split()
        verb = words[0]
        try:
            c = conj.conjugate(verb)
        except Exception as exc:  # noqa: BLE001
            raise SystemExit("Не удалось проспрягать «%s»: %s (%s)" % (verb, where, exc))
        tables.append((a, words[1:], c["forms"]["presente"]))
    lines = []
    for k, (pronoun, idx, gender, plural) in enumerate(PERSONS):
        ru_line = ru_lines[k]
        question = ru_line.endswith("?")
        shows, accept = [], set()
        for (a, rest, pres) in tables:
            verb = pres[idx]
            variants = []
            for g in gender_options(gender, plural, pronoun):
                tail = [agree(w[:-1], g, plural) if w.endswith("*") else w for w in rest]
                variants.append((g, " ".join([verb] + tail)))
            for g, core in variants:
                subj = subject_for(pronoun, g)
                accept.add(norm(core))
                accept.add(norm(subj + " " + core))
            # как показывать: в 1–2 лице и «nós» без местоимения, в 3 лице — с местоимением
            g0, core0 = variants[0]
            if pronoun in ("ele", "ela", "eles"):
                g_show = "f" if pronoun == "ela" else "m"
                core_show = next(c for g, c in variants if g == g_show or len(variants) == 1)
                shows.append(sentence_case(pronoun + " " + core_show, question))
            else:
                shows.append(sentence_case(core0, question))
        lines.append({
            "p": pronoun, "ru": ru_line, "show": shows[0], "also": shows[1:],
            "accept": sorted(accept), "tiles": tiles_of(shows[0]),
            "verbs": [t[2] for t in tables],   # for traps
        })
    return {"id": set_["id"] + ":" + alts[0].replace("*", ""), "kind": "person",
            "pt": [a.replace("*", "") for a in alts], "en": en, "ru": ru, "note": note, "lines": lines}


def fixed_item(set_, alts, en, ru, note):
    show = alts[0]
    accept = sorted({norm(a) for a in alts})
    return {"id": set_["id"] + ":" + norm(alts[0]), "kind": "fixed", "pt": alts, "en": en, "ru": ru, "note": note,
            "lines": [{"p": "", "ru": ru, "show": show, "also": alts[1:], "accept": accept, "tiles": tiles_of(show)}]}


def tiles_of(sentence):
    """Слова ответа для плиток: без знаков препинания; с маленькой буквы только первое слово
    (имена и названия — «Lisboa», «Porto» — остаются с заглавной)."""
    words = [w for w in PUNCT.sub(" ", sentence).split()]
    if words:
        words[0] = words[0][0].lower() + words[0][1:]
    return words


def add_traps(set_):
    """Лишние слова: та же форма глагола в другом лице, слово из соседней фразы."""
    rnd = random.Random(set_["id"])
    all_words = sorted({w.lower() for it in set_["items"] for ln in it["lines"] for w in ln["tiles"]
                        if w[0].islower()})
    for it in set_["items"]:
        for ln in it["lines"]:
            traps = []
            own = {w.lower() for w in ln["tiles"]}
            accept_words = {w for a in ln["accept"] for w in a.split()}
            for pres in ln.pop("verbs", []):
                wrong = [f for f in pres if f.lower() not in accept_words]
                rnd.shuffle(wrong)
                traps += [w.lower() for w in wrong[:1]]
            pool = [w for w in all_words if w not in own and w not in accept_words and w not in traps]
            rnd.shuffle(pool)
            traps += pool[:3 - len(traps) if len(traps) < 3 else 0]
            ln["extra"] = traps[:3]


def build(conj):
    sets, dict_entries = parse(conj)
    count = sum(len(s["items"]) for s in sets)
    return {"format": 1, "sets": sets}, dict_entries, count
