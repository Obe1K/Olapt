import SwiftUI

// MARK: - Бейдж статуса

struct StatusBadge: View {
    let status: MasteryStatus
    /// Доля выученности 0…1: пока слово учится, вместо «Учу» показываем процент
    var fraction: Double? = nil

    private var text: String {
        if status == .learning, let f = fraction {
            return "\(min(99, max(1, Int((f * 100).rounded()))))%"
        }
        return status.title
    }

    private var color: Color {
        switch status {
        case .new: return Theme.textDim
        case .learning: return Theme.ember
        case .learned: return Theme.moss
        }
    }

    var body: some View {
        Text(text)
            .font(Theme.pixel(11, relativeTo: .caption2))
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundColor(color)
            .background(PixelFrame(fill: Theme.panelDeep, border: color.opacity(0.7),
                                   highlight: color.opacity(0.7), shadow: color.opacity(0.4)))
    }
}

// MARK: - Строка слова

struct WordRow: View {
    @EnvironmentObject var model: AppModel
    let word: Word
    var hint: String = ""
    var showStatus: Bool = true

    private var translationLine: String {
        var parts: [String] = []
        for lang in model.index.languages {
            let text = word.translationText(lang: lang, limit: 2)
            if !text.isEmpty { parts.append(text) }
        }
        return parts.joined(separator: "  ·  ")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(word.titleWithArticle)
                        .font(.headline)
                        .foregroundColor(Theme.text)
                    if !word.posLine.isEmpty {
                        Text(word.posLine)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Text(translationLine)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                if !hint.isEmpty {
                    Text(hint)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
            Spacer(minLength: 4)
            if showStatus {
                let status = model.status(for: word.id)
                if status != .new {
                    StatusBadge(status: status, fraction: model.fraction(for: word.id))
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Полоска прогресса

struct MasteryBar: View {
    let fraction: Double

    var body: some View {
        PixelProgressBar(fraction: fraction)
    }
}

// MARK: - Строка уровня упражнений

struct LevelRow: View {
    let level: ExerciseLevel
    let best: Int?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: level.symbol)
                .font(.title3)
                .frame(width: 32)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(level.title)
                    .font(Theme.pixel(15, relativeTo: .headline))
                    .foregroundColor(Theme.goldBright)
                Text(level.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let best = best {
                Text("\(best)%")
                    .font(Theme.pixel(15, relativeTo: .subheadline))
                    .foregroundColor(best >= 80 ? Theme.moss : Theme.ember)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Кнопка озвучки

struct SpeakButton: View {
    let text: String

    var body: some View {
        Button {
            Speaker.shared.speak(text)
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.title2)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Произнести")
    }
}

// MARK: - Пустое состояние

struct EmptyHint: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(Theme.pixel(15, relativeTo: .headline))
                .foregroundColor(Theme.goldBright)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Подсветка акцентов

/// «falámos» с подсвеченной «á», если пользователь написал «falamos».
enum AccentHighlight {
    /// - lead: начало без подсветки, например «nós »
    static func attributed(_ answer: String, typed: String, lead: String = "") -> AttributedString {
        let marks = AccentCheck.slips(typed: typed, answer: answer)
        var result = AttributedString(lead)
        for (i, ch) in answer.enumerated() {
            var piece = AttributedString(String(ch))
            if marks.contains(i) {
                piece.foregroundColor = Theme.goldBright
                piece.underlineStyle = .single
            }
            result += piece
        }
        return result
    }

    static func text(_ answer: String, typed: String, lead: String = "") -> Text {
        return Text(attributed(answer, typed: typed, lead: lead))
    }
}
