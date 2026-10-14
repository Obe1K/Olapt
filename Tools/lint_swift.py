# -*- coding: utf-8 -*-
"""
Лёгкая проверка Swift-исходников без компилятора:
  1) баланс скобок (с учётом строк, комментариев и интерполяции);
  2) обращения к членам основных типов (model.xxx, session.xxx, ...) — есть ли такой член;
  3) неизвестные имена типов.
Не заменяет сборку в Xcode, но ловит опечатки и забытые определения.
"""
import glob
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "OlaPT")
files = sorted(glob.glob(os.path.join(ROOT, "**", "*.swift"), recursive=True))
sources = {f: open(f, encoding="utf-8").read() for f in files}
problems = 0


def report(msg):
    global problems
    problems += 1
    print("  ! " + msg)


# ---------------------------------------------------------------- 1. скобки
PAIRS = {")": "(", "]": "[", "}": "{"}


def check_balance(path, text):
    stack = []  # (char, line)
    i, n, line = 0, len(text), 1
    # контексты: 'code', ('str', multiline), ('interp', depth)
    ctx = ["code"]
    while i < n:
        c = text[i]
        top = ctx[-1]
        if c == "\n":
            line += 1
        if top == "code" or (isinstance(top, tuple) and top[0] == "interp"):
            if text.startswith("//", i):
                j = text.find("\n", i)
                i = n if j < 0 else j
                continue
            if text.startswith("/*", i):
                j = text.find("*/", i + 2)
                line += text.count("\n", i, j if j >= 0 else n)
                i = n if j < 0 else j + 2
                continue
            if text.startswith('"""', i):
                ctx.append(("str", True))
                i += 3
                continue
            if c == '"':
                ctx.append(("str", False))
                i += 1
                continue
            if c in "([{":
                stack.append((c, line))
                if isinstance(top, tuple) and top[0] == "interp":
                    ctx[-1] = ("interp", top[1] + 1)
            elif c in ")]}":
                if not stack or stack[-1][0] != PAIRS[c]:
                    report("%s:%d: лишняя или несовпавшая скобка '%s'" % (os.path.basename(path), line, c))
                    return
                stack.pop()
                if isinstance(top, tuple) and top[0] == "interp":
                    depth = top[1] - 1
                    if depth == 0:
                        ctx.pop()
                    else:
                        ctx[-1] = ("interp", depth)
            i += 1
            continue
        # внутри строки
        if isinstance(top, tuple) and top[0] == "str":
            multiline = top[1]
            if c == "\\":
                if text.startswith("\\(", i):
                    stack.append(("(", line))
                    ctx.append(("interp", 1))
                    i += 2
                    continue
                i += 2
                continue
            if multiline and text.startswith('"""', i):
                ctx.pop()
                i += 3
                continue
            if not multiline and c == '"':
                ctx.pop()
                i += 1
                continue
            if not multiline and c == "\n":
                report("%s:%d: строка не закрыта" % (os.path.basename(path), line))
                return
            i += 1
            continue
        i += 1
    if stack:
        report("%s: не закрыта скобка '%s' (строка %d)" % (os.path.basename(path), stack[-1][0], stack[-1][1]))
    if len(ctx) != 1:
        report("%s: не закрыта строка или интерполяция" % os.path.basename(path))


print("1) Баланс скобок")
for f, t in sources.items():
    check_balance(f, t)

# ---------------------------------------------------------------- 2. члены типов
def members_of(type_name):
    """Имена членов типа (по всем файлам, включая extension)."""
    names = set()
    for text in sources.values():
        for m in re.finditer(r"\b(?:final\s+)?(?:class|struct|enum|extension)\s+" + type_name + r"\b[^{]*\{", text):
            # найдём тело по балансу фигурных скобок
            start = m.end()
            depth, j = 1, start
            while j < len(text) and depth > 0:
                if text[j] == "{":
                    depth += 1
                elif text[j] == "}":
                    depth -= 1
                j += 1
            body = text[start:j - 1]
            for mm in re.finditer(r"\b(?:func|var|let|case)\s+([A-Za-z_][A-Za-z0-9_]*)", body):
                names.add(mm.group(1))
            for mm in re.finditer(r"\bcase\s+([A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*)", body):
                for part in mm.group(1).split(","):
                    names.add(part.strip())
    return names


CHECKS = [
    # (регулярка префикса, тип)
    (r"\bmodel\.index\.", "DictionaryIndex"),
    (r"\bmodel\.verbs\.", "VerbLibrary"),
    (r"\bmodel\.settings\.", "AppSettings"),
    (r"\bmodel\.user\.", "UserData"),
    (r"\bsession\.", None),  # проверяем отдельно по двум классам
    (r"\bSpeaker\.shared\.", "Speaker"),
    (r"\bTextUtil\.", "TextUtil"),
    (r"\bLanguages\.", "Languages"),
    (r"\bPartOfSpeech\.", "PartOfSpeech"),
    (r"\bPersistence\.", "Persistence"),
    (r"\bPackImporter\.", "PackImporter"),
    (r"\bVerbLibrary\.", "VerbLibrary"),
    (r"\bWord\.", "Word"),
]

# model.<член> — только прямые обращения (не model.index.xxx и т.п.)
model_members = members_of("AppModel")
print("2) Обращения к членам типов")
for f, t in sources.items():
    base = os.path.basename(f)
    for m in re.finditer(r"\bmodel\.([A-Za-z_][A-Za-z0-9_]*)", t):
        name = m.group(1)
        if name in ("index", "verbs", "user", "settings", "$user"):
            if name not in model_members:
                report("%s: model.%s не найден в AppModel" % (base, name))
            continue
        if name not in model_members:
            report("%s: model.%s не найден в AppModel" % (base, name))
    for pattern, tname in CHECKS:
        if tname is None:
            names = members_of("WordStudySession") | members_of("VerbStudySession")
        else:
            names = members_of(tname)
        for m in re.finditer(pattern + r"([A-Za-z_][A-Za-z0-9_]*)", t):
            name = m.group(1)
            if name not in names:
                report("%s: %s%s — нет такого члена (%s)" % (base, pattern.replace("\\b", "").replace("\\", ""), name, tname or "Session"))

# ---------------------------------------------------------------- 3. неизвестные типы
declared = set()
for t in sources.values():
    for m in re.finditer(r"\b(?:class|struct|enum|protocol|typealias)\s+([A-Z][A-Za-z0-9_]*)", t):
        declared.add(m.group(1))

KNOWN = set("""
String Int Double Bool Date UUID Data URL Character Set Array Dictionary Optional Result Error Void Any
Bundle FileManager JSONDecoder JSONEncoder CharacterSet DispatchQueue DispatchWorkItem NSString
View Text Button List Section Form Group VStack HStack ZStack ScrollView ForEach NavigationStack NavigationLink
TabView Label Image Spacer Picker Toggle Stepper TextField ProgressView Menu DisclosureGroup Color Font Capsule
RoundedRectangle Rectangle Binding State StateObject EnvironmentObject Environment FocusState ObservableObject
Published App Scene WindowGroup ToolbarItem LocalizedError Codable Hashable Identifiable CodingKey CaseIterable
Equatable Decoder Encoder AVSpeechSynthesizer AVSpeechSynthesisVoice AVSpeechUtterance AVAudioSession
UTType UIColor Optional Sequence Collection Range ClosedRange IndexSet WritableKeyPath KeyPath Self Type
CFBundleShortVersionString CFBundleVersion JSON CSV PT UI ID OK TXT AO Acordo
""".split())
print("3) Неизвестные имена типов")
for f, t in sources.items():
    base = os.path.basename(f)
    # убираем строки и комментарии грубо
    clean = re.sub(r'"(?:\\.|[^"\\])*"', '""', t)
    clean = re.sub(r"//.*", "", clean)
    for m in re.finditer(r"(?<![\.\w])([A-Z][A-Za-z0-9_]+)\s*[\(\{<:]", clean):
        name = m.group(1)
        if name in declared or name in KNOWN:
            continue
        # метки аргументов и case-имена пропускаем
        report("%s: неизвестный идентификатор '%s'" % (base, name))

print("\nНайдено замечаний: %d" % problems)
sys.exit(1 if problems else 0)
