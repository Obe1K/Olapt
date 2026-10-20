import Foundation
import AVFoundation

// MARK: - 8-битные звуки

/// Звуки синтезируются прямо в приложении (квадратная и треугольная волна), без файлов;
/// музыка башни — TowerMusic.
/// Категория «ambient»: не прерывает чужую музыку и молчит, когда включён беззвучный режим.
final class SoundFX {
    static let shared = SoundFX()

    enum Effect: CaseIterable {
        case correct, wrong, victory, unlock, tap
    }

    /// Звуки ответов и событий
    var effectsOn = true
    /// Музыка башни на вкладке «Сегодня» (TowerMusic)
    var musicOn = false {
        didSet { if !musicOn { stopMusic() } }
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let musicPlayer = AVAudioPlayerNode()
    private let sampleRate = TowerMusic.sampleRate
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]
    private var musicBuffer: AVAudioPCMBuffer?
    private var configured = false
    /// Вкладка «Сегодня» на экране и хочет музыку
    private var musicWanted = false
    private var musicRendering = false
    /// В UI-тестах молчим
    private let disabledForTests = ProcessInfo.processInfo.arguments.contains("-uitest-static")
        || UserDefaults.standard.string(forKey: "uitest-pet") != nil

    private init() {}

    /// Готовит движок и запускает его, если он остановлен (после звонка, Siri, смены наушников
    /// система его останавливает, а play() на остановленном движке роняет приложение).
    private func startIfNeeded() -> Bool {
        if disabledForTests { return false }
        if !configured {
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            } catch {
                return false
            }
            engine.attach(player)
            engine.attach(musicPlayer)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            engine.connect(musicPlayer, to: engine.mainMixerNode, format: format)
            let center = NotificationCenter.default
            center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
                self?.resumeMusic()
            }
            center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
                let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                if raw == AVAudioSession.InterruptionType.ended.rawValue { self?.resumeMusic() }
            }
            configured = true
        }
        if !engine.isRunning {
            // плееры остановленного движка тоже сбрасываем, иначе isPlaying врёт и звук не пойдёт
            player.stop()
            musicPlayer.stop()
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                try engine.start()
            } catch {
                return false
            }
        }
        return true
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

    /// Включить музыку (вкладка «Сегодня» появилась). Первый раз синтез идёт в фоне, ~0,1 с.
    func startMusic() {
        musicWanted = true
        guard musicOn, !disabledForTests else { return }
        if let b = musicBuffer {
            playMusic(b)
            return
        }
        guard !musicRendering else { return }
        musicRendering = true
        DispatchQueue.global(qos: .utility).async {
            let samples = TowerMusic.render()
            DispatchQueue.main.async {
                self.musicRendering = false
                self.musicBuffer = self.buffer(from: samples)
                if self.musicWanted, let b = self.musicBuffer { self.playMusic(b) }
            }
        }
    }

    /// Вернуть музыку после паузы системы или возврата в приложение — только если вкладка её хотела.
    func resumeMusic() {
        if musicWanted { startMusic() }
    }

    func stopMusic() {
        musicWanted = false
        if musicPlayer.isPlaying { musicPlayer.stop() }
    }

    private func playMusic(_ b: AVAudioPCMBuffer) {
        guard musicOn, musicWanted, startIfNeeded(), !musicPlayer.isPlaying else { return }
        musicPlayer.volume = 0.35
        musicPlayer.scheduleBuffer(b, at: nil, options: .loops, completionHandler: nil)
        musicPlayer.play()
    }

    // MARK: Синтез

    private enum Wave { case square, triangle }

    /// Ноты: (частота Гц, длительность с). Частота 0 — пауза.
    private func synth(_ notes: [(Double, Double)], wave: Wave, volume: Float, decay: Double = 6) -> [Float] {
        var out: [Float] = []
        var phase = 0.0
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

}
