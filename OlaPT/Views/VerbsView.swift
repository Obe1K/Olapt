import SwiftUI

// MARK: - Вкладка «Глаголы»

struct VerbsView: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""

    private var filtered: [Verb] {
        let q = TextUtil.fold(query)
        if q.isEmpty { return model.verbs.verbs }
        return model.verbs.verbs.filter { matches($0, q) }
    }

    private func matches(_ v: Verb, _ q: String) -> Bool {
        if TextUtil.fold(v.inf).contains(q) { return true }
        if let w = model.index.word(v.wordID) {
            for (_, list) in w.translations {
                for t in list {
                    if TextUtil.fold(t).contains(q) { return true }
                }
            }
        }
        return false
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

            Section(header: GothicHeader("Глаголы (\(filtered.count))")) {
                ForEach(filtered) { v in
                    NavigationLink {
                        ConjugationView(verb: v)
                    } label: {
                        VerbRow(verb: v)
                    }
                }
            }
        }
        .navigationTitle("Глаголы")
        .searchable(text: $query, prompt: "Глагол или его перевод")
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
    }
}

struct VerbRow: View {
    @EnvironmentObject var model: AppModel
    let verb: Verb

    private var translationLine: String {
        guard let w = model.index.word(verb.wordID) else { return "" }
        var parts: [String] = []
        for lang in model.index.languages {
            let text = w.translationText(lang: lang, limit: 2)
            if !text.isEmpty { parts.append(text) }
        }
        return parts.joined(separator: "  ·  ")
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
