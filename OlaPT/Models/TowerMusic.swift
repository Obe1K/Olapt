import Foundation

/// Музыка башни для вкладки «Сегодня»: арпеджио ля минор (Am – F – Dm – E), тёплый бас,
/// 8-битный колокольчик во 2-м и 4-м проходе и мягкое эхо; 25,6 секунды по кругу.
///
/// Без шума. Мелодия звучит в диапазоне, который воспроизводит динамик телефона;
/// у каждой ноты плавная атака и уход в ноль (без щелчков); эхо считается по кругу — петля бесшовная.
/// Эталон того же алгоритма на Python: Tools/music/tower_music.py; сборка на GitHub сверяет их.
enum TowerMusic {
    static let sampleRate = 22050.0
    static let noteLength = 0.4
    /// Итоговый пик (громкость плеера в приложении 0.35)
    static let peak = 0.30
    private static let tableSize = 2048
    private static let passes = 4

    private static let hz: [String: Double] = [
        "D2": 73.42, "E2": 82.41, "F2": 87.31, "A2": 110.00,
        "D3": 146.83, "E3": 164.81, "F3": 174.61, "A3": 220.00, "B3": 246.94,
        "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G#4": 415.30, "A4": 440.00, "B4": 493.88,
        "C5": 523.25, "D5": 587.33, "E5": 659.26, "F5": 698.46, "A5": 880.00,
    ]
    /// Арпеджио восьмыми и бас на весь такт; аккорды Am – F – Dm – E (гармонический минор)
    private static let arp = [["A3", "E4", "C4", "E4"], ["F3", "C4", "A3", "C4"], ["D4", "F4", "A3", "F4"], ["E4", "G#4", "B3", "G#4"]]
    private static let bass = ["A2", "F2", "D3", "E2"]
    /// Колокольчик: (нота или «-» — пауза, длина в восьмых), 16 восьмых на проход
    private static let bell: [Int: [(String, Int)]] = [
        1: [("E5", 4), ("F5", 2), ("E5", 2), ("D5", 4), ("B4", 2), ("G#4", 2)],
        3: [("C5", 2), ("E5", 2), ("A5", 4), ("F5", 2), ("D5", 2), ("E5", 3), ("-", 1)],
    ]

    private struct Voice {
        let harm: [(Int, Double)]
        let attack, decay, release, gain: Double
    }
    /// Треугольник с ограниченной полосой (нечётные гармоники 1/n², знак чередуется)
    private static let arpVoice = Voice(harm: [(1, 1.0), (3, -1.0 / 9), (5, 1.0 / 25), (7, -1.0 / 49)],
                                        attack: 0.006, decay: 3.2, release: 0.03, gain: 1.0)
    /// Тёплый бас: основной тон и гармоники 2–4, чтобы его было слышно и в маленьком динамике
    private static let bassVoice = Voice(harm: [(1, 1.0), (2, 0.5), (3, 0.25), (4, 0.12)],
                                         attack: 0.06, decay: 0.8, release: 0.08, gain: 0.55)
    /// 8-битный колокольчик: импульс со скважностью 25 % (8 гармоник)
    private static let bellVoice = Voice(harm: (1...8).map { n in (n, sin(Double(n) * Double.pi * 0.25) / Double(n)) },
                                         attack: 0.01, decay: 1.6, release: 0.06, gain: 0.45)
    private static let echoDelay = 0.6
    private static let echoTaps: [Double] = [0.32, 0.10, 0.03]

    /// Один период формы волны, нормированный к пику 1.
    private static func table(_ harm: [(Int, Double)]) -> [Double] {
        let t = (0..<tableSize).map { i -> Double in
            var s = 0.0
            for (n, a) in harm {
                s += a * sin(2 * Double.pi * Double(n) * Double(i) / Double(tableSize))
            }
            return s
        }
        let m = t.map { abs($0) }.max() ?? 1
        return t.map { $0 / m }
    }

    /// Нота с атакой, экспоненциальным спадом и плавным уходом в ноль в конце.
    private static func addNote(_ out: inout [Double], start: Int, length: Int, freq: Double, table tab: [Double], voice v: Voice) {
        let nAtt = v.attack * sampleRate
        let nRel = v.release * sampleRate
        let size = Double(tableSize)
        let step = freq * size / sampleRate
        var phase = 0.0
        for i in 0..<length {
            let att = min(1.0, Double(i) / nAtt)
            let r = min(1.0, Double(length - i) / nRel)
            let rel = 0.5 - 0.5 * cos(Double.pi * r)
            let env = att * exp(-v.decay * Double(i) / sampleRate) * rel
            let k = Int(phase)
            let frac = phase - Double(k)
            let s = tab[k % tableSize] * (1 - frac) + tab[(k + 1) % tableSize] * frac
            out[start + i] += s * env * v.gain
            phase += step
            if phase >= size { phase -= size }
        }
    }

    /// Отсчёты (моно, `sampleRate` Гц). Около 0,1 с на iPhone — вызывать не на главном потоке.
    static func render() -> [Float] {
        let note = Int((noteLength * sampleRate).rounded())
        let bar = 4 * note
        let total = passes * 4 * bar
        let arpTab = table(arpVoice.harm), bassTab = table(bassVoice.harm), bellTab = table(bellVoice.harm)
        var dry = [Double](repeating: 0, count: total)        // арпеджио и колокольчик (с эхом)
        var bassTrack = [Double](repeating: 0, count: total)  // бас (без эха)
        for p in 0..<passes {
            for b in 0..<4 {
                let start = (p * 4 + b) * bar
                for (j, name) in arp[b].enumerated() {
                    addNote(&dry, start: start + j * note, length: note, freq: hz[name]!, table: arpTab, voice: arpVoice)
                }
                addNote(&bassTrack, start: start, length: bar, freq: hz[bass[b]]!, table: bassTab, voice: bassVoice)
            }
            if let line = bell[p] {
                var pos = p * 4 * bar
                for (name, eighths) in line {
                    if name != "-" {
                        addNote(&dry, start: pos, length: eighths * note, freq: hz[name]!, table: bellTab, voice: bellVoice)
                    }
                    pos += eighths * note
                }
            }
        }
        let d = Int((echoDelay * sampleRate).rounded())
        var out = [Double](repeating: 0, count: total)
        for i in 0..<total {
            var s = dry[i] + bassTrack[i]
            for (k, g) in echoTaps.enumerated() {
                let j = ((i - (k + 1) * d) % total + total) % total
                s += g * dry[j]
            }
            out[i] = s
        }
        let m = out.map { abs($0) }.max() ?? 1
        return out.map { Float($0 * peak / m) }
    }
}
