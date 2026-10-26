import SwiftUI

// MARK: - Бои Империи слов: упражнение, потом кубик

/// Бой внутри тренировки: противник на арене (босс поселения) или обычный бой без арены.
struct BattleSpec {
    var arena: BossConfig?
    var onFinish: (BattleScore) -> Void
}

/// Итог боя-упражнения.
struct BattleScore {
    /// Верно с первого раза и сколько вопросов было задано с первого раза
    var correct: Int
    var total: Int
    /// Все верные и неверные, включая повторы (для арены)
    var hits: Int
    var misses: Int
    /// Противник на арене повержен
    var won: Bool
}

/// Этап боя, который сейчас идёт в тренировке.
struct BattleStage: Identifiable {
    enum Kind {
        case boss       // бой с боссом поселения перед штурмом
        case assault    // основной бой штурма
        case sortie     // вылазка
        case defense    // оборона от отряда стражи
    }

    let id = UUID()
    let kind: Kind
    let town: Int
    var squad: Int = 0
    var key: KeyPerson?
    /// Вопросов в бою
    var questions: Int
}

/// Что показать после броска.
struct BattleReport: Identifiable {
    let id = UUID()
    var title: String
    var lines: [String]
    var roll: Int?
    var bonus: Int
    var good: Bool
}

// MARK: - Кубик d20

/// Бросок кубика: цифры мелькают, потом встают на выпавшее значение.
struct DiceRollView: View {
    let roll: Int
    let bonus: Int
    @State private var shown: Int = 1
    @State private var settled = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                D20Shape()
                    .fill(settled ? Theme.bloodBright : Theme.panelRaised)
                D20Shape()
                    .stroke(Theme.goldBright, lineWidth: 3)
                Text("\(shown)")
                    .font(Theme.pixel(40, relativeTo: .largeTitle))
                    .foregroundColor(Theme.text)
            }
            .frame(width: 110, height: 110)
            .rotationEffect(.degrees(settled ? 0 : Double(shown * 37 % 360)))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("Бросок кубика: %d", roll))
            .accessibilityIdentifier("dice")

            if settled {
                Text(totalText)
                    .font(Theme.pixel(18, relativeTo: .headline))
                    .foregroundColor(Theme.goldBright)
                    .transition(.opacity)
            }
        }
        .task {
            // 14 быстрых смен цифр, потом выпавшее значение
            for i in 0..<14 {
                shown = Int.random(in: 1...20)
                try? await Task.sleep(nanoseconds: UInt64(40_000_000 + i * 9_000_000))
            }
            shown = roll
            withAnimation(.easeOut(duration: 0.25)) { settled = true }
            SoundFX.shared.play(roll == 1 ? .wrong : .correct)
        }
    }

    private var totalText: String {
        if roll == 20 { return L("Чистая 20 — всегда удача") }
        if roll == 1 { return L("Чистая 1 — всегда провал") }
        let sign = bonus >= 0 ? "+" : "−"
        return "\(roll) \(sign) \(abs(bonus)) = \(roll + bonus)"
    }
}

/// Двадцатигранник в профиль: шестиугольник с треугольником внутри.
struct D20Shape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for i in 0..<6 {
            let a = Double(i) * .pi / 3 - .pi / 2
            let pt = CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Итог боя

struct BattleReportView: View {
    let report: BattleReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            if let roll = report.roll {
                DiceRollView(roll: roll, bonus: report.bonus)
                    .padding(.top, 24)
            }
            Text(report.title)
                .font(Theme.pixel(26, relativeTo: .title))
                .foregroundColor(report.good ? Theme.goldBright : Theme.red)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("battle-report-title")
            VStack(alignment: .leading, spacing: 8) {
                ForEach(report.lines, id: \.self) { line in
                    Text(line)
                        .font(.body)
                        .foregroundColor(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .pixelPanel()
            Spacer(minLength: 0)
            Button(L("Понятно")) { dismiss() }
                .buttonStyle(GothicButtonStyle(.primary))
                .accessibilityIdentifier("battle-report-ok")
        }
        .padding(20)
        .background(StoneBackground().ignoresSafeArea())
    }
}

// MARK: - Карточка события, как в Frostpunk

struct EventCardView: View {
    let event: GameEvent
    let onClose: () -> Void

    var body: some View {
        let t = GameTexts.event(event)
        VStack(spacing: 14) {
            Group {
                if let art = art {
                    Image(art)
                        .interpolation(.high)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 34))
                        .foregroundColor(tint)
                }
            }
            .padding(.top, 6)
            Text(t.title)
                .font(Theme.pixel(22, relativeTo: .title2))
                .foregroundColor(Theme.goldBright)
                .multilineTextAlignment(.center)
            Text(t.text)
                .font(.body)
                .foregroundColor(Theme.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(L("Понятно"), action: onClose)
                .buttonStyle(GothicButtonStyle(.primary))
                .accessibilityIdentifier("event-ok")
        }
        .pixelPanel(fill: Theme.panelDeep, padding: 18)
        .padding(.horizontal, 28)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("event-card")
    }

    /// Значок автора, если он уже нарисован
    private var art: String? {
        switch event {
        case .captured: return "icon_st_control"
        case .agentExposed: return "icon_act_infiltrate"
        case .patrolComing, .patrolBrokeThrough: return "icon_st_guard"
        default: return nil
        }
    }

    private var icon: String {
        switch event {
        case .captured, .actComplete: return "flag.fill"
        case .lost, .sortieLost, .armyWoke: return "moon.zzz.fill"
        case .obeliskBroken: return "bolt.horizontal.fill"
        case .agentExposed: return "eye.fill"
        case .patrolComing, .patrolBrokeThrough: return "shield.lefthalf.filled"
        case .crimsonFled: return "figure.walk"
        }
    }

    private var tint: Color {
        switch event {
        case .captured, .actComplete, .crimsonFled: return Theme.goldBright
        default: return Theme.red
        }
    }
}
