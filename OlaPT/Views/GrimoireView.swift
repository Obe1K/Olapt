import SwiftUI

// MARK: - Гримуар

/// Книга заклинаний: слова, которые вы помните хотя бы неделю.
/// Страницы — пергамент, буквицы — готическим шрифтом на алом поле.
struct GrimoireView: View {
    @EnvironmentObject var model: AppModel

    static let parchment = Color(red: 236 / 255, green: 224 / 255, blue: 196 / 255)
    static let parchmentDark = Color(red: 206 / 255, green: 188 / 255, blue: 150 / 255)
    static let ink = Color(red: 58 / 255, green: 38 / 255, blue: 22 / 255)
    static let inkLight = Color(red: 112 / 255, green: 84 / 255, blue: 56 / 255)

    struct Spell: Identifiable {
        let word: Word
        let stability: Double
        var id: String { return word.id }
    }

    /// Сила заклинания: 1–5 по тому, как долго слово держится в памяти.
    static func power(_ stability: Double) -> Int {
        if stability >= 120 { return 5 }
        if stability >= 60 { return 4 }
        if stability >= 21 { return 3 }
        if stability >= 14 { return 2 }
        return 1
    }

    private var groups: [(letter: String, spells: [Spell])] {
        var list: [Spell] = []
        for (id, s) in model.user.srs where s.stability >= AppModel.memoryStability {
            if let w = model.index.word(id) {
                list.append(Spell(word: w, stability: s.stability))
            }
        }
        list.sort { TextUtil.fold($0.word.pt) < TextUtil.fold($1.word.pt) }
        var result: [(String, [Spell])] = []
        for sp in list {
            let letter = String(TextUtil.fold(sp.word.pt).prefix(1)).uppercased()
            if let last = result.last, last.0 == letter {
                result[result.count - 1].1.append(sp)
            } else {
                result.append((letter, [sp]))
            }
        }
        return result
    }

    var body: some View {
        let g = groups
        let total = g.reduce(0) { $0 + $1.spells.count }
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Grimorium")
                        .font(Theme.gothic(42))
                        .foregroundColor(Theme.goldBright)
                        .shadow(color: Theme.blood, radius: 0, x: 2, y: 2)
                    Text(total > 0 ? "\(total) \(Plural.spells(total))" : "Пока пусто")
                        .font(Theme.pixel(15, relativeTo: .subheadline))
                        .foregroundColor(Theme.textDim)
                }
                .padding(.top, 8)

                if total == 0 {
                    Text("Слово становится заклинанием, когда вы помните его хотя бы неделю. Занимайтесь по плану «Сегодня» — и книга начнёт заполняться.")
                        .font(.subheadline)
                        .foregroundColor(GrimoireView.ink)
                        .multilineTextAlignment(.center)
                        .padding(18)
                        .background(PixelFrame(fill: GrimoireView.parchment, border: Theme.goldDark,
                                               highlight: Theme.gold, shadow: Theme.goldDark))
                        .accessibilityIdentifier("grimoire-empty")
                }

                ForEach(g, id: \.letter) { group in
                    page(letter: group.letter, spells: group.spells)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(StoneBackground().ignoresSafeArea())
        .navigationTitle("Гримуар")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func page(letter: String, spells: [Spell]) -> some View {
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                // буквица
                Text(letter)
                    .font(Theme.gothic(40))
                    .foregroundColor(Theme.goldBright)
                    .frame(width: 52, height: 52)
                    .background(PixelFrame(fill: Theme.blood, border: Theme.gold))
                Rectangle()
                    .fill(GrimoireView.parchmentDark)
                    .frame(height: 2)
            }
            .padding(.bottom, 8)
            ForEach(spells) { sp in
                NavigationLink {
                    WordCardView(word: sp.word)
                } label: {
                    spellRow(sp)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(PixelFrame(fill: GrimoireView.parchment, border: Theme.goldDark,
                               highlight: Theme.gold, shadow: Theme.goldDark))
    }

    private func spellRow(_ sp: Spell) -> some View {
        let p = GrimoireView.power(sp.stability)
        let ru = sp.word.translationText(lang: "ru", limit: 2)
        let tr = ru.isEmpty ? sp.word.translationText(lang: model.index.languages.first ?? "en", limit: 2) : ru
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sp.word.titleWithArticle)
                    .font(.system(.headline, design: .serif))
                    .foregroundColor(GrimoireView.ink)
                Text(tr)
                    .font(.system(.subheadline, design: .serif).italic())
                    .foregroundColor(GrimoireView.inkLight)
                    .lineLimit(2)
            }
            Spacer(minLength: 6)
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    Diamond()
                        .fill(i < p ? Theme.blood : GrimoireView.parchmentDark)
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityLabel("Сила \(p) из 5")
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
