import Foundation
import AVFoundation

// MARK: - 8-битные звуки

/// Звуки синтезируются прямо в приложении (квадратная и треугольная волна), без файлов.
/// Категория «ambient»: не прерывает чужую музыку и молчит, когда включён беззвучный режим.
final class SoundFX {
    static let shared = SoundFX()

    enum Effect: CaseIterable {
        case correct, wrong, victory, unlock, tap
    }

    /// Звуки ответов и событий
    var effectsOn = true
    /// Тихая музыка башни на вкладке «Сегодня»
    var musicOn = false {
        didSet { if !musicOn { stopMusic() } }
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let musicPlayer = AVAudioPlayerNode()
    private let sampleRate = 22050.0
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]
    private var musicBuffer: AVAudioPCMBuffer?
    private var started = false
    private var musicPlaying = false
    /// В UI-тестах молчим
    private let disabledForTests = ProcessInfo.processInfo.arguments.contains("-uitest-static")
        || UserDefaults.standard.string(forKey: "uitest-pet") != nil

    private init() {}

    private func startIfNeeded() -> Bool {
        if disabledForTests { return false }
        if started { return true }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            engine.attach(player)
            engine.attach(musicPlayer)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            engine.connect(musicPlayer, to: engine.mainMixerNode, format: format)
            try engine.start()
            player.play()
            started = true
        } catch {
            started = false
        }
        return started
    }

    func play(_ effect: Effect) {
        guard effectsOn, startIfNeeded() else { return }
        let buffer: AVAudioPCMBuffer
        if let b = buffers[effect] {
            buffer = b
        } else {
            guard let b = render(effect) else { return }
            buffers[effect] = b
            buffer = b
        }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    func startMusic() {
        guard musicOn, !musicPlaying, startIfNeeded() else { return }
        if musicBuffer == nil { musicBuffer = renderMusic() }
        guard let b = musicBuffer else { return }
        musicPlayer.volume = 0.35
        musicPlayer.scheduleBuffer(b, at: nil, options: .loops, completionHandler: nil)
        musicPlayer.play()
        musicPlaying = true
    }

    func stopMusic() {
        guard musicPlaying else { return }
        musicPlayer.stop()
        musicPlaying = false
    }

    // MARK: Синтез

    private enum Wave { case square, triangle, noise }

    /// Ноты: (частота Гц, длительность с). Частота 0 — пауза.
    private func synth(_ notes: [(Double, Double)], wave: Wave, volume: Float, decay: Double = 6) -> [Float] {
        var out: [Float] = []
        var phase = 0.0
        var noiseState: UInt32 = 0x1234_5678
        for (freq, dur) in notes {
            let n = Int(dur * sampleRate)
            for i in 0..<n {
                let t = Double(i) / sampleRate
                let env = Float(exp(-t * decay)) * min(1, Float(i) / 40)   // быстрая атака, плавный спад
                var v: Float = 0
                if freq > 0 {
                    phase += freq / sampleRate
                    phase -= floor(phase)
                    switch wave {
                    case .square: v = phase < 0.5 ? 1 : -1
                    case .triangle: v = Float(4 * abs(phase - 0.5) - 1)
                    case .noise:
                        noiseState ^= noiseState << 13
                        noiseState ^= noiseState >> 17
                        noiseState ^= noiseState << 5
                        v = Float(noiseState & 0xFFFF) / 32768 - 1
                    }
                }
                out.append(v * env * volume)
            }
        }
        return out
    }

    private func buffer(from samples: [Float]) -> AVAudioPCMBuffer? {
        guard let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return nil }
        b.frameLength = AVAudioFrameCount(samples.count)
        if let ch = b.floatChannelData?[0] {
            for (i, s) in samples.enumerated() { ch[i] = s }
        }
        return b
    }

    private func render(_ effect: Effect) -> AVAudioPCMBuffer? {
        // ноты: C5 = 523, E5 = 659, G5 = 784, C6 = 1047
        switch effect {
        case .correct:
            return buffer(from: synth([(784, 0.06), (1047, 0.12)], wave: .square, volume: 0.12, decay: 9))
        case .wrong:
            return buffer(from: synth([(196, 0.09), (147, 0.18)], wave: .square, volume: 0.12, decay: 5))
        case .victory:
            return buffer(from: synth([(523, 0.1), (659, 0.1), (784, 0.1), (1047, 0.35)], wave: .square, volume: 0.12, decay: 3))
        case .unlock:
            return buffer(from: synth([(784, 0.07), (988, 0.07), (1175, 0.07), (1568, 0.25)], wave: .triangle, volume: 0.25, decay: 4))
        case .tap:
            return buffer(from: synth([(880, 0.05)], wave: .triangle, volume: 0.18, decay: 18))
        }
    }

    /// Тихая мрачная мелодия башни (ля минор), ~13 секунд, по кругу.
    private func renderMusic() -> AVAudioPCMBuffer? {
        let a2 = 110.0, c3 = 130.8, e3 = 164.8, g3 = 196.0, f3 = 174.6, d3 = 146.8
        let pattern: [(Double, Double)] = [
            (a2, 0.4), (e3, 0.4), (c3, 0.4), (e3, 0.4),
            (f3, 0.4), (c3, 0.4), (a2, 0.4), (c3, 0.4),
            (d3, 0.4), (f3, 0.4), (a2, 0.4), (f3, 0.4),
            (e3, 0.4), (g3, 0.4), (e3, 0.4), (0, 0.4),
        ]
        var samples = synth(pattern + pattern, wave: .triangle, volume: 0.10, decay: 2.5)
        // лёгкий «ветер»
        let wind = synth([(1, Double(samples.count) / sampleRate)], wave: .noise, volume: 0.006, decay: 0)
        for i in 0..<min(samples.count, wind.count) { samples[i] += wind[i] }
        return buffer(from: samples)
    }
}
