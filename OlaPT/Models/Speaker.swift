import Foundation
import AVFoundation

/// Озвучка португальских слов системным голосом (европейский португальский, pt-PT).
final class Speaker {
    static let shared = Speaker()

    private let synthesizer = AVSpeechSynthesizer()

    /// Голос европейского португальского, если он установлен на устройстве.
    private var europeanVoice: AVSpeechSynthesisVoice? {
        if let v = AVSpeechSynthesisVoice(language: "pt-PT") { return v }
        return AVSpeechSynthesisVoice.speechVoices().first { $0.language == "pt-PT" }
    }

    /// Запасной вариант: любой португальский голос.
    private var anyPortugueseVoice: AVSpeechSynthesisVoice? {
        return AVSpeechSynthesisVoice.speechVoices().first { $0.language.hasPrefix("pt") }
    }

    var hasEuropeanVoice: Bool {
        return europeanVoice != nil
    }

    func speak(_ text: String) {
        let cleaned = Speaker.clean(text)
        if cleaned.isEmpty { return }

        let session = AVAudioSession.sharedInstance()
        // mixWithOthers: не прерываем и не «глушим» музыку из других приложений насовсем.
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
        try? session.setActive(true)

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.voice = europeanVoice ?? anyPortugueseVoice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        synthesizer.speak(utterance)
    }

    /// «bonito / bonita» → «bonito»; лишние пробелы убираются.
    static func clean(_ text: String) -> String {
        var t = text
        if let slash = t.firstIndex(of: "/") {
            t = String(t[t.startIndex..<slash])
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
