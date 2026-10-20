#!/usr/bin/env python3
"""Музыка башни — эталон на Python для OlaPT/Models/TowerMusic.swift (тот же алгоритм, шаг в шаг).

    python3 Tools/music/tower_music.py out.wav          — записать WAV (послушать) и напечатать замеры
    python3 Tools/music/tower_music.py --check FILE.f32 — сверить вывод Swift (float32, little-endian)
                                                          с эталоном и проверить шум, щелчки и стык петли

Что важно для звука на iPhone:
  * никакого шума: в прошлой версии под мелодию был подмешан белый «ветер», а сама мелодия звучала
    в басах 110–196 Гц, которые динамик телефона почти не воспроизводит, — шум был громче мелодии;
  * арпеджио на октаву выше (A3–G#4) и с обертонами, бас — с гармониками 2–4, чтобы его было слышно;
  * у каждой ноты плавная атака и спад к нулю — без щелчков на стыках нот;
  * эхо считается по кругу, поэтому петля бесшовная.
Только стандартная библиотека.
"""
import math
import struct
import sys
import wave

SR = 22050.0
NOTE = 0.4          # восьмая, с
TABLE = 2048        # точек в таблице формы волны

HZ = {
    "D2": 73.42, "E2": 82.41, "F2": 87.31, "A2": 110.00,
    "D3": 146.83, "E3": 164.81, "F3": 174.61, "A3": 220.00, "B3": 246.94,
    "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G#4": 415.30, "A4": 440.00, "B4": 493.88,
    "C5": 523.25, "D5": 587.33, "E5": 659.26, "F5": 698.46, "A5": 880.00,
}

# Аккорды Am – F – Dm – E (гармонический минор): арпеджио восьмыми и бас на весь такт
ARP = [["A3", "E4", "C4", "E4"], ["F3", "C4", "A3", "C4"], ["D4", "F4", "A3", "F4"], ["E4", "G#4", "B3", "G#4"]]
BASS = ["A2", "F2", "D3", "E2"]
# Колокольчик во 2-м и 4-м проходе: (нота или "-" — пауза, длина в восьмых); 16 восьмых на проход
BELL = {
    1: [("E5", 4), ("F5", 2), ("E5", 2), ("D5", 4), ("B4", 2), ("G#4", 2)],
    3: [("C5", 2), ("E5", 2), ("A5", 4), ("F5", 2), ("D5", 2), ("E5", 3), ("-", 1)],
}
PASSES = 4

# Голоса: гармоники (номер, амплитуда), атака / спад / затухание в конце (с), громкость
VOICES = {
    # треугольник с ограниченной полосой (нечётные гармоники, 1/n², знак чередуется)
    "arp": dict(harm=[(1, 1.0), (3, -1 / 9), (5, 1 / 25), (7, -1 / 49)], attack=0.006, decay=3.2, release=0.03, gain=1.0),
    # тёплый бас: основной тон и гармоники 2–4, чтобы его было слышно и в маленьком динамике
    "bass": dict(harm=[(1, 1.0), (2, 0.5), (3, 0.25), (4, 0.12)], attack=0.06, decay=0.8, release=0.08, gain=0.55),
    # 8-битный колокольчик: импульс со скважностью 25 % (8 гармоник)
    "bell": dict(harm=[(n, math.sin(n * math.pi * 0.25) / n) for n in range(1, 9)], attack=0.01, decay=1.6, release=0.06, gain=0.45),
}
ECHO_DELAY = 0.6                     # с
ECHO_TAPS = [0.32, 0.10, 0.03]       # громкость повторов
PEAK = 0.30                          # итоговый пик (громкость плеера в приложении 0.35)


def table(harm):
    t = [sum(a * math.sin(2 * math.pi * n * i / TABLE) for n, a in harm) for i in range(TABLE)]
    m = max(abs(x) for x in t)
    return [x / m for x in t]


def add_note(out, start, length, freq, tab, v):
    """Нота с атакой, экспоненциальным спадом и плавным уходом в ноль в конце."""
    n_att = v["attack"] * SR
    n_rel = v["release"] * SR
    step = freq * TABLE / SR
    phase = 0.0
    for i in range(length):
        att = min(1.0, i / n_att)
        r = min(1.0, (length - i) / n_rel)
        rel = 0.5 - 0.5 * math.cos(math.pi * r)
        env = att * math.exp(-v["decay"] * i / SR) * rel
        k = int(phase)
        frac = phase - k
        s = tab[k % TABLE] * (1 - frac) + tab[(k + 1) % TABLE] * frac
        out[start + i] += s * env * v["gain"]
        phase += step
        if phase >= TABLE:
            phase -= TABLE


def render(sr=SR):
    assert sr == SR
    note = int(round(NOTE * SR))
    bar = 4 * note
    total = PASSES * 4 * bar
    tabs = {k: table(v["harm"]) for k, v in VOICES.items()}
    dry = [0.0] * total   # арпеджио и колокольчик (с эхом)
    bass = [0.0] * total  # бас (без эха)
    for p in range(PASSES):
        for b in range(4):
            start = (p * 4 + b) * bar
            for j, name in enumerate(ARP[b]):
                add_note(dry, start + j * note, note, HZ[name], tabs["arp"], VOICES["arp"])
            add_note(bass, start, bar, HZ[BASS[b]], tabs["bass"], VOICES["bass"])
        if p in BELL:
            pos = p * 4 * bar
            for name, eighths in BELL[p]:
                if name != "-":
                    add_note(dry, pos, eighths * note, HZ[name], tabs["bell"], VOICES["bell"])
                pos += eighths * note
    d = int(round(ECHO_DELAY * SR))
    out = [0.0] * total
    for i in range(total):
        s = dry[i] + bass[i]
        for k, g in enumerate(ECHO_TAPS, start=1):
            s += g * dry[(i - k * d) % total]
        out[i] = s
    m = max(abs(x) for x in out)
    return [x * PEAK / m for x in out]


# --- Замеры ---------------------------------------------------------------------------------

def highpass(x, fc=350.0):
    """Динамик iPhone: почти ничего ниже ~350 Гц (два звена Баттерворта 2-го порядка)."""
    w = math.tan(math.pi * fc / SR)
    out = x
    for q in (0.5412, 1.3066):  # 4-й порядок
        n = 1 / (1 + w / q + w * w)
        b0, b1, b2 = n, -2 * n, n
        a1, a2 = 2 * (w * w - 1) * n, (1 - w / q + w * w) * n
        y = [0.0] * len(out)
        x1 = x2 = y1 = y2 = 0.0
        for i, s in enumerate(out):
            r = b0 * s + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2, x1, y2, y1 = x1, s, y1, r
            y[i] = r
        out = y
    return out


def db(x):
    return 10 * math.log10(sum(s * s for s in x) / len(x) + 1e-24)


def measure(x):
    steps = [abs(x[i + 1] - x[i]) for i in range(len(x) - 1)]
    return {
        "длина, с": round(len(x) / SR, 2),
        "пик": round(max(abs(s) for s in x), 4),
        "RMS, дБ": round(db(x), 1),
        "через динамик, дБ": round(db(highpass(x)), 1),
        "макс. скачок": round(max(steps), 4),
        "стык петли": round(abs(x[0] - x[-1]), 4),
    }


def write_wav(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(int(SR))
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s / PEAK * 0.9)) * 32767)) for s in x))


def main():
    ref = render()
    if len(sys.argv) == 3 and sys.argv[1] == "--check":
        raw = open(sys.argv[2], "rb").read()
        got = list(struct.unpack("<%df" % (len(raw) // 4), raw))
        ok = len(got) == len(ref)
        diff = max(abs(a - b) for a, b in zip(got, ref)) if ok else float("inf")
        m = measure(got)
        print("Swift: %s" % m)
        print("Отличие от эталона: длина %d / %d, макс. разница %.2e" % (len(got), len(ref), diff))
        bad = []
        if diff > 1e-3:
            bad.append("не совпадает с эталоном")
        if m["макс. скачок"] > measure(ref)["макс. скачок"] * 1.05:
            bad.append("скачки больше, чем у эталона (щелчки)")
        if m["стык петли"] > 0.01:
            bad.append("стык петли слышен")
        print("ИТОГ: " + ("ок" if not bad else "ошибка — " + ", ".join(bad)))
        return 1 if bad else 0
    m = measure(ref)
    print("Эталон: %s" % m)
    if len(sys.argv) == 2:
        write_wav(sys.argv[1], ref)
        print("WAV: %s (громкость поднята для прослушивания)" % sys.argv[1])
    return 0


if __name__ == "__main__":
    sys.exit(main())
