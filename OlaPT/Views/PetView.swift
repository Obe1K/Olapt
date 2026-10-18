import SwiftUI
import UIKit

// MARK: - Маг на экране «Сегодня»

/// Сцена в стиле тёмного пиксельного фэнтези: маг в башне (или в темнице, если голодает).
/// Без рамки: картинка во всю ширину и снизу растворяется в фоне страницы.
struct PetView: View {
    @EnvironmentObject var model: AppModel
    /// false, пока поверх открыта тренировка: анимацию еды показываем, когда экран снова виден
    let isVisible: Bool

    @State private var eatingStart: Date?
    @State private var reactionStart: Date?

    static let tickSeconds = 0.5
    static let eatingFrames = 10
    static let reactionFrames = 6

    /// Для UI-тестов: -uitest-pet happy|ok|angry|skeleton|eating — застывший кадр.
    private static let testOverride: String? = UserDefaults.standard.string(forKey: "uitest-pet")
    /// Для UI-тестов: -uitest-room cellar|hall|library|summit и -uitest-items N.
    private static let testRoom: PetRoom? = {
        switch UserDefaults.standard.string(forKey: "uitest-room") {
        case "cellar": return .cellar
        case "hall": return .hall
        case "library": return .library
        case "summit": return .summit
        default: return nil
        }
    }()
    private static let testItems: Int? = UserDefaults.standard.object(forKey: "uitest-items") != nil
        ? UserDefaults.standard.integer(forKey: "uitest-items") : nil
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
        let room = PetView.testRoom ?? model.towerRoom
        let items = PetView.testItems ?? model.towerItems
        let lit = PetRules.hearts(food: food)
        Group {
            if PetView.isStatic {
                let eating: Int? = PetView.testOverride == "eating" ? 3 : nil
                stage(room: room, mood: mood, lit: lit, items: items, tick: 2, eating: eating, reaction: nil)
            } else {
                TimelineView(.periodic(from: Date(), by: PetView.tickSeconds)) { context in
                    stage(room: room, mood: mood, lit: lit, items: items, tick: tick(context.date),
                          eating: frame(since: eatingStart, at: context.date, length: PetView.eatingFrames),
                          reaction: frame(since: reactionStart, at: context.date, length: PetView.reactionFrames))
                }
            }
        }
        .onAppear { startMealIfNeeded(mood: mood) }
        .onChange(of: isVisible) { _ in startMealIfNeeded(mood: PetRules.mood(food: model.petFood())) }
    }

    private func stage(room: PetRoom, mood: PetMood, lit: Int, items: Int, tick: Int,
                       eating: Int?, reaction: Int?) -> some View {
        let caption = eating != nil ? PetRules.eatingCaption : PetRules.caption(mood)
        let layers = PetComposer.compose(room: room, mood: mood, lit: lit, items: items, tick: tick,
                                         eating: eating, reaction: reaction)
        // Подписи нет: сцена должна читаться без слов. Текст — только для VoiceOver.
        return PixelStage(layers: layers)
            .contentShape(Rectangle())
            .onTapGesture {
                reactionStart = Date()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(caption)
            .accessibilityIdentifier("pet-screen")
    }

    /// Покормили — показываем, как пьёт зелье (только если он уже не голодный и не скелет).
    private func startMealIfNeeded(mood: PetMood) {
        guard isVisible, !PetView.isStatic, model.user.pet.pendingMeal else { return }
        model.consumePendingMeal()
        if mood == .happy || mood == .ok {
            eatingStart = Date()
        }
    }
}

/// Рисует слои сцены 192×120 без сглаживания, во всю ширину; низ плавно уходит в фон страницы.
struct PixelStage: View {
    let layers: [PlacedLayer]

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / CGFloat(PetAtlas.width)
            ZStack(alignment: .topLeading) {
                ForEach(layers) { l in
                    Image(l.name)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: CGFloat(l.w) * s, height: CGFloat(l.h) * s)
                        .offset(x: CGFloat(l.x) * s, y: CGFloat(l.y) * s)
                }
            }
            .frame(width: geo.size.width, height: CGFloat(PetAtlas.height) * s, alignment: .topLeading)
            .clipped()
        }
        .aspectRatio(CGFloat(PetAtlas.width) / CGFloat(PetAtlas.height), contentMode: .fit)
        .mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.06),
                .init(color: .black, location: 0.72),
                .init(color: .clear, location: 1),
            ], startPoint: .top, endPoint: .bottom)
        )
    }
}
