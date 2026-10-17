import SwiftUI

// MARK: - Тамагочи на экране «Сегодня»

/// Тамагочи в стиле тёмного пиксельного фэнтези: маг в башне или в темнице.
struct PetView: View {
    @EnvironmentObject var model: AppModel
    /// false, пока поверх открыта тренировка: анимацию еды показываем, когда экран снова виден
    let isVisible: Bool

    @State private var eatingStart: Date?
    @State private var reactionStart: Date?

    static let tickSeconds = 0.5

    /// Для UI-тестов: -uitest-pet happy|ok|angry|skeleton|eating — застывший кадр нужного состояния.
    private static let testOverride: String? = UserDefaults.standard.string(forKey: "uitest-pet")
    /// Для UI-тестов: без анимации, чтобы не мешать ожиданию «приложение простаивает».
    private static let isStatic: Bool = testOverride != nil || ProcessInfo.processInfo.arguments.contains("-uitest-static")

    private func tick(_ date: Date) -> Int {
        return Int(date.timeIntervalSinceReferenceDate / PetView.tickSeconds)
    }

    private func frame(since start: Date?, at date: Date, length: Int) -> Int? {
        guard let start = start else { return nil }
        let f = Int(date.timeIntervalSince(start) / PetView.tickSeconds)
        return (f >= 0 && f < length) ? f : nil
    }

    private var food: Double {
        if let o = PetView.testOverride {
            switch o {
            case "happy", "eating": return 100
            case "ok": return 60
            case "angry": return 25
            case "skeleton": return 0
            default: break
            }
        }
        return model.petFood()
    }

    var body: some View {
        let food = self.food
        let mood = PetRules.mood(food: food)
        Group {
            if PetView.isStatic {
                let eating: Int? = PetView.testOverride == "eating" ? 3 : nil
                screen(mood: mood, food: food, tick: 2, eating: eating, reaction: nil)
            } else {
                TimelineView(.periodic(from: Date(), by: PetView.tickSeconds)) { context in
                    screen(mood: mood, food: food, tick: tick(context.date),
                           eating: frame(since: eatingStart, at: context.date, length: PetScene.eatingFrames),
                           reaction: frame(since: reactionStart, at: context.date, length: PetScene.reactionFrames))
                }
            }
        }
        .onAppear { startMealIfNeeded(mood: mood) }
        .onChange(of: isVisible) { _ in startMealIfNeeded(mood: PetRules.mood(food: model.petFood())) }
    }

    private func screen(mood: PetMood, food: Double, tick: Int, eating: Int?, reaction: Int?) -> some View {
        let caption = eating != nil ? PetRules.eatingCaption : PetRules.caption(mood)
        return VStack(spacing: 8) {
            PixelScreen(buffer: PetScene.compose(mood: mood, food: food, tick: tick,
                                                 eatingFrame: eating, reactionFrame: reaction))
                .contentShape(Rectangle())
                .onTapGesture {
                    reactionStart = Date()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(caption)
                .accessibilityIdentifier("pet-screen")
            Text(caption)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("pet-caption")
        }
    }

    /// Покормили — показываем, как ест (только если он уже не голодный и не скелет).
    private func startMealIfNeeded(mood: PetMood) {
        guard isVisible, !PetView.isStatic, model.user.pet.pendingMeal else { return }
        model.consumePendingMeal()
        if mood == .happy || mood == .ok {
            eatingStart = Date()
        }
    }
}

/// Рисует буфер: чёрный фон и три оттенка серого, пиксели без зазоров.
struct PixelScreen: View {
    let buffer: PixelBuffer

    static let palette: [Color] = [
        Color(red: 11 / 255, green: 11 / 255, blue: 15 / 255),
        Color(red: 52 / 255, green: 52 / 255, blue: 62 / 255),
        Color(red: 112 / 255, green: 110 / 255, blue: 118 / 255),
        Color(red: 226 / 255, green: 220 / 255, blue: 204 / 255),
    ]

    var body: some View {
        Canvas { context, size in
            let p = size.width / CGFloat(buffer.width)
            var paths = [Path(), Path(), Path()]
            for y in 0..<buffer.height {
                // соседние пиксели одного цвета в строке — одним прямоугольником
                var x = 0
                while x < buffer.width {
                    let v = buffer.value(x, y)
                    var run = 1
                    while x + run < buffer.width && buffer.value(x + run, y) == v {
                        run += 1
                    }
                    if v > 0 && v <= 3 {
                        // +0.5 pt перекрытия, чтобы между пикселями не было швов
                        paths[Int(v) - 1].addRect(CGRect(x: CGFloat(x) * p, y: CGFloat(y) * p,
                                                         width: CGFloat(run) * p + 0.5, height: p + 0.5))
                    }
                    x += run
                }
            }
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(PixelScreen.palette[0]))
            for i in 0..<3 {
                context.fill(paths[i], with: .color(PixelScreen.palette[i + 1]))
            }
        }
        .aspectRatio(CGFloat(buffer.width) / CGFloat(buffer.height), contentMode: .fit)
        .padding(6)
        .background(PixelFrame(fill: .black))
    }
}
