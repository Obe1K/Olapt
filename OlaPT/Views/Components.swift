import SwiftUI

// MARK: - Бейдж статуса

struct StatusBadge: View {
    let status: MasteryStatus

    private var color: Color {
        switch status {
        case .new: return .gray
        case .learning: return .orange
        case .learned: return .green
        }
    }

    var body: some View {
        Text(status.title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.18))
            .foregroundColor(color)
            .clipShape(Capsule())
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
                    StatusBadge(status: status)
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
        ProgressView(value: min(1.0, max(0.0, fraction)))
            .tint(fraction >= 1.0 ? Color.green : Color.accentColor)
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
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(level.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let best = best {
                Text("\(best)%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(best >= 80 ? Color.green : Color.orange)
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
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
