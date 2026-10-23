#!/usr/bin/env python3
"""Локализация интерфейса: строки пишутся в коде по-русски внутри L(...), переводы — OlaPT/Resources/ui-en.json.

    python3 Tools/l10n.py check            — ошибки: русский текст вне L(...), L(...) с подстановкой \\(...),
                                             ключи без перевода, разные %d/%@ в ключе и переводе; код выхода 1
    python3 Tools/l10n.py missing [FILE]   — ключи без перевода (JSON-объект «ключ: ""»), для заполнения
    python3 Tools/l10n.py unused           — переводы, ключей которых больше нет в коде
    python3 Tools/l10n.py build            — собрать ui-en.json из Tools/l10n_en/ui_*.py (исходники переводов)
    python3 Tools/l10n.py wrap FILE...     — обернуть простые русские строки в L(...) (без подстановок);
                                             строки в static let / case-шаблонах / многострочные — только отчёт

Исключения: OlaPT/Models/Localization.swift и строки с комментарием «// l10n-ok».
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
TABLE = os.path.join(ROOT, "OlaPT", "Resources", "ui-en.json")
CYR = re.compile("[А-Яа-яЁё]")
SPEC = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|@|\.\d+f|f|%)")
EXEMPT = {"Localization.swift"}


def swift_files():
    return sorted(glob.glob(os.path.join(ROOT, "OlaPT", "**", "*.swift"), recursive=True))


class Lit:
    def __init__(self, start, end, raw, interp, multiline, line):
        self.start, self.end, self.raw, self.interp, self.multiline, self.line = start, end, raw, interp, multiline, line

    @property
    def value(self):
        """Текст литерала с раскрытыми простыми escape-последовательностями (как ключ в JSON)."""
        out, i, s = [], 0, self.raw
        while i < len(s):
            c = s[i]
            if c == "\\" and i + 1 < len(s):
                n = s[i + 1]
                out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\", "'": "'", "0": "\0"}.get(n, "\\" + n))
                i += 2
            else:
                out.append(c)
                i += 1
        return "".join(out)


def lex(src):
    """Строковые литералы Swift (включая вложенные в интерполяцию); комментарии пропускаются."""
    lits = []
    i, n = 0, len(src)

    def line_of(pos):
        return src.count("\n", 0, pos) + 1

    def read_string(i):
        # src[i] == '"' (одинарный) или начало '"""'
        multiline = src.startswith('"""', i)
        q = '"""' if multiline else '"'
        j = i + len(q)
        start = j
        interp = False
        while j < n:
            if src.startswith(q, j):
                lits.append(Lit(i, j + len(q), src[start:j], interp, multiline, line_of(i)))
                return j + len(q)
            c = src[j]
            if c == "\\" and j + 1 < n and src[j + 1] == "(":
                interp = True
                depth = 1
                j += 2
                while j < n and depth:
                    if src[j] == '"':
                        j = read_string(j)
                        continue
                    if src[j] == "(":
                        depth += 1
                    elif src[j] == ")":
                        depth -= 1
                    j += 1
                continue
            if c == "\\":
                j += 2
                continue
            if c == "\n" and not multiline:
                break
            j += 1
        return j

    while i < n:
        if src.startswith("//", i):
            k = src.find("\n", i)
            i = n if k < 0 else k
        elif src.startswith("/*", i):
            k = src.find("*/", i + 2)
            i = n if k < 0 else k + 2
        elif src[i] == '"':
            i = read_string(i)
        else:
            i += 1
    return lits


def wrapped(src, lit):
    """Литерал — первый аргумент L(...)?"""
    k = lit.start - 1
    while k >= 0 and src[k] in " \t":
        k -= 1
    return k >= 1 and src[k] == "(" and src[k - 1] == "L" and (k < 2 or not (src[k - 2].isalnum() or src[k - 2] == "_"))


def line_text(src, lit):
    """Строка с началом литерала и строка перед ней (там может стоять «// l10n-ok»)."""
    a = src.rfind("\n", 0, lit.start) + 1
    b = src.find("\n", lit.start)
    prev = src.rfind("\n", 0, max(0, a - 1)) + 1
    return src[prev: b if b >= 0 else len(src)]


def analyze():
    problems, keys = [], {}
    for path in swift_files():
        name = os.path.basename(path)
        src = open(path, encoding="utf-8").read()
        rel = os.path.relpath(path, ROOT)
        for lit in lex(src):
            is_key = wrapped(src, lit)
            if is_key:
                if lit.interp:
                    problems.append("%s:%d: в L(...) подстановка \\(...) — нужен шаблон %%d/%%@: %s" % (rel, lit.line, lit.raw[:80]))
                else:
                    keys.setdefault(lit.value, []).append("%s:%d" % (rel, lit.line))
                continue
            if name in EXEMPT or not CYR.search(lit.raw):
                continue
            if "l10n-ok" in line_text(src, lit):
                continue
            problems.append("%s:%d: русский текст без L(...): %s" % (rel, lit.line, lit.raw[:90]))
    return problems, keys


def load_table():
    if not os.path.exists(TABLE):
        return {}
    return json.load(open(TABLE, encoding="utf-8"))


def specs(s):
    return [m for m in SPEC.findall(s) if m != "%%"]


def check():
    problems, keys = analyze()
    table = load_table()
    for k, where in sorted(keys.items()):
        if not CYR.search(k):
            continue  # ключ без русского текста (например, «%d / %d») переводить не нужно
        if k not in table or not table[k].strip():
            problems.append("%s: нет перевода: %s" % (where[0], k[:90]))
        elif specs(k) != specs(table[k]):
            problems.append("%s: разные подстановки %s / %s: %s" % (where[0], specs(k), specs(table[k]), k[:70]))
        elif CYR.search(table[k]):
            problems.append("%s: в переводе осталась кириллица: %s" % (where[0], table[k][:70]))
    for p in problems:
        print(p)
    print("Ключей в коде: %d, переводов: %d, ошибок: %d" % (len(keys), len(table), len(problems)))
    return 1 if problems else 0


def missing(out=None):
    _, keys = analyze()
    table = load_table()
    miss = {k: "" for k in sorted(keys) if CYR.search(k) and not table.get(k)}
    text = json.dumps(miss, ensure_ascii=False, indent=1)
    if out:
        open(out, "w", encoding="utf-8").write(text + "\n")
        print("%d ключей без перевода → %s" % (len(miss), out))
    else:
        print(text)
    return 0


def unused():
    _, keys = analyze()
    for k in sorted(set(load_table()) - set(keys)):
        print(k)
    return 0


def build():
    import importlib.util
    table = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "Tools", "l10n_en", "ui_*.py"))):
        spec = importlib.util.spec_from_file_location(os.path.basename(path)[:-3], path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        for k, v in mod.T.items():
            if k in table and table[k] != v:
                print("Разные переводы одного ключа (%s): %r / %r" % (os.path.basename(path), table[k], v))
            table[k] = v
    with open(TABLE, "w", encoding="utf-8") as fh:
        json.dump(dict(sorted(table.items())), fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    print("ui-en.json: %d переводов" % len(table))
    return 0


def wrap(paths):
    report = []
    for path in paths:
        src = open(path, encoding="utf-8").read()
        rel = os.path.relpath(path, ROOT)
        edits = []
        for lit in lex(src):
            if not CYR.search(lit.raw) or wrapped(src, lit):
                continue
            line = line_text(src, lit)
            if "l10n-ok" in line:
                continue
            why = None
            if lit.multiline:
                why = "многострочная"
            elif lit.interp:
                why = "подстановка"
            elif re.search(r"\b(static|let)\s+\w+\s*(:[^=]+)?=", line) and re.search(r"^\s*(private\s+|fileprivate\s+)?static\s+let\b", line):
                why = "static let"
            elif re.match(r"\s*case\s+\"", line):
                why = "case-шаблон"
            if why:
                report.append("%s:%d: %s: %s" % (rel, lit.line, why, lit.raw[:80]))
                continue
            edits.append(lit)
        # вложенные литералы (внутри интерполяции) не трогаем, если внешний будет переписан вручную
        for lit in sorted(edits, key=lambda l: -l.start):
            src = src[:lit.start] + "L(" + src[lit.start:lit.end] + ")" + src[lit.end:]
        open(path, "w", encoding="utf-8").write(src)
        print("%s: обёрнуто %d" % (rel, len(edits)))
    for r in report:
        print("ВРУЧНУЮ " + r)
    return 0


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    if cmd == "check":
        return check()
    if cmd == "missing":
        return missing(sys.argv[2] if len(sys.argv) > 2 else None)
    if cmd == "unused":
        return unused()
    if cmd == "build":
        return build()
    if cmd == "wrap":
        return wrap(sys.argv[2:])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
