import SwiftUI

// MARK: - Вкладка «Глаголы»

struct VerbsView: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""

    /// Результаты поиска: сначала совпадение инфинитива целиком, потом начало слова, потом вхождение,
    /// потом совпадение по переводу; внутри каждой группы — по алфавиту.
    private var searchResults: [Verb] {
        let q = TextUtil.fold(query)
        var exact: [Verb] = [], prefix: [Verb] = [], inside: [Verb] = [], byTranslation: [Verb] = []
        for v in model.verbs.alphabetical {
            let f = model.verbs.foldedInf[v.inf] ?? v.inf
            if f == q {
                exact.append(v)
            } else if f.hasPrefix(q) {
                prefix.append(v)
            } else if f.contains(q) {
                inside.append(v)
            } else if translationMatches(v, q) {
                byTranslation.append(v)
            }
        }
        return exact + prefix + inside + byTranslation
    }

    private func translationMatches(_ v: Verb, _ q: String) -> Bool {
        if let w = model.index.word(v.wordID) {
            for (_, list) in w.translations {
                for t in list {
                    if TextUtil.fold(t).contains(q) { return true }
                }
            }
        }
        return false
    }

    private func row(_ v: Verb) -> some View {
        NavigationLink {
            ConjugationView(verb: v)
        } label: {
            VerbRow(verb: v)
        }
    }

    var body: some View {
        GothicList {
            if let error = model.verbs.loadError {
                Section {
                    Text(error)
                        .foregroundColor(Theme.red)
                }
            }

            Section {
                NavigationLink {
                    VerbTrainerSetupView(initialCollectionID: nil)
                } label: {
                    Label("Тренировка спряжений", systemImage: "square.and.pencil")
                        .font(.headline)
                }
            } footer: {
                Text("Выберите времена и глаголы — приложение будет спрашивать формы по лицам. Для каждой пары «глагол + время» ведётся свой прогресс.")
            }

            if TextUtil.fold(query).isEmpty {
                // Весь список по алфавиту, с буквами
                ForEach(model.verbs.letterSections) { section in
                    Section(header: GothicHeader(section.letter)) {
                        ForEach(section.verbs) { v in row(v) }
                    }
                }
            } else {
                let results = searchResults
                Section(header: GothicHeader("Глаголы (\(results.count))")) {
                    ForEach(results) { v in row(v) }
                }
            }
        }
        .navigationTitle("Глаголы")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Глагол или его перевод")
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
    }
}

struct VerbRow: View {
    @EnvironmentObject var model: AppModel
    let verb: Verb

    private var translationLine: String {
        return model.verbTranslation(verb)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(verb.inf)
                    .font(.headline)
                if verb.irregular {
                    Text("неправильный")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.ember.opacity(0.18))
                        .foregroundColor(Theme.ember)
                        .clipShape(Capsule())
                }
                if verb.reflexive {
                    Text("возвратный")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.gold.opacity(0.15))
                        .foregroundColor(Theme.gold)
                        .clipShape(Capsule())
                }
            }
            Text(translationLine)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
            let overall = model.verbOverallFraction(verb)
            if overall > 0 {
                MasteryBar(fraction: overall)
            }
        }
        .padding(.vertical, 2)
    }
}

extension AppModel {
    /// Перевод глагола из словаря (1–2 значения на язык): «говорить, разговаривать  ·  to speak, to talk».
    func verbTranslation(_ verb: Verb, limit: Int = 2) -> String {
        guard let w = index.word(verb.wordID) else { return "" }
        var parts: [String] = []
        for lang in index.languages {
            let text = w.translationText(lang: lang, limit: limit)
            if !text.isEmpty { parts.append(text) }
        }
        return parts.joined(separator: "  ·  ")
    }

    /// Перевод глагола для задания: только на языке упражнений из настроек (обычно русский),
    /// если его нет — на первом доступном.
    func verbExerciseTranslation(_ verb: Verb, limit: Int = 2) -> String {
        guard let w = index.word(verb.wordID) else { return "" }
        let pref = settings.exerciseLanguage
        for lang in [pref, "ru"] + index.languages {
            let text = w.translationText(lang: lang, limit: limit)
            if !text.isEmpty { return text }
        }
        return ""
    }
}
