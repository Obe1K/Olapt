import SwiftUI

/// Запрос на запуск тренировки глаголов (используется для fullScreenCover).
struct VerbSessionRequest: Identifiable {
    let id = UUID()
    let verbs: [Verb]
    let tenses: [TenseInfo]
    let mode: VerbMode
    let count: Int
}

// MARK: - Таблицы спряжения одного глагола

struct ConjugationView: View {
    @EnvironmentObject var model: AppModel
    let verb: Verb

    @State private var expanded: Set<String> = ["presente"]
    @State private var showPicker = false
    @State private var request: VerbSessionRequest?

    private var word: Word? {
        return model.index.word(verb.wordID)
    }

    var body: some View {
        GothicList {
            headerSection

            ForEach(model.verbs.tenseGroups) { group in
                Section(header: GothicHeader(group.name)) {
                    ForEach(group.tenses) { tense in
                        tenseBlock(tense)
                    }
                }
            }

            Section(footer: Text("Форма vós в современном португальском почти не используется, поэтому здесь не показана. В Португалии настоящее продолженное строится как «estar a + инфинитив» (estou a falar), а не герундием.")) {
                Button {
                    showPicker = true
                } label: {
                    Label("Сохранить в коллекцию", systemImage: "plus.rectangle.on.folder")
                }
            }
        }
        .navigationTitle(verb.inf)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            CollectionPickerSheet(wordIDs: [verb.wordID])
        }
        .fullScreenCover(item: $request) { req in
            VerbSessionView(request: req)
        }
    }

    // MARK: Шапка

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(verb.inf)
                        .font(.largeTitle.weight(.bold))
                    Spacer()
                    SpeakButton(text: verb.base)
                }
                if let w = word {
                    ForEach(model.index.languages, id: \.self) { lang in
                        let text = w.translationText(lang: lang, limit: 4)
                        if !text.isEmpty {
                            Text(text)
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                HStack(spacing: 6) {
                    Text(verb.group)
                    if verb.irregular { Text("· неправильный") }
                    if verb.reflexive { Text("· возвратный") }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)

                Text("Герундий: \(verb.gerund)  ·  Причастие: \(verb.participle)")
                    .font(.subheadline)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: Одно время

    private func binding(_ id: String) -> Binding<Bool> {
        return Binding(
            get: { expanded.contains(id) },
            set: { isOn in
                if isOn {
                    expanded.insert(id)
                } else {
                    expanded.remove(id)
                }
            }
        )
    }

    @ViewBuilder
    private func tenseBlock(_ tense: TenseInfo) -> some View {
        DisclosureGroup(isExpanded: binding(tense.id)) {
            ForEach(model.verbs.activePersons(tense), id: \.self) { p in
                HStack {
                    Text(lead(tense, p))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(verb.form(tense.id, p))
                        .font(.body.weight(.semibold))
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    Speaker.shared.speak(verb.form(tense.id, p))
                }
            }
            HStack(spacing: 10) {
                Button {
                    request = VerbSessionRequest(verbs: [verb], tenses: [tense], mode: .choice, count: 0)
                } label: {
                    Text("Выбрать форму")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GothicButtonStyle(.secondary))
                Button {
                    request = VerbSessionRequest(verbs: [verb], tenses: [tense], mode: .typing, count: 0)
                } label: {
                    Text("Написать форму")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GothicButtonStyle(.primary))
            }
            .padding(.vertical, 4)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(tense.name)
                        .font(.headline)
                    Spacer()
                    let status = model.verbStatus(verb: verb, tense: tense)
                    if status != .new {
                        StatusBadge(status: status)
                    }
                }
                Text(tense.ru)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func lead(_ tense: TenseInfo, _ person: Int) -> String {
        let label = person < tense.labels.count ? tense.labels[person] : ""
        if tense.prefix.isEmpty { return label }
        return tense.prefix + " " + label
    }
}
