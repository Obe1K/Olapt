import SwiftUI
import UIKit

// MARK: - Маг на экране «Сегодня»

/// Зал башни по картинкам автора: маг читает, скучает, пьёт зелье, колдует или, голодая, сидит в темнеющем зале.
/// Без рамки: картинка во всю ширину и сверху и снизу растворяется в фоне страницы.
struct PetView: View {
    @EnvironmentObject var model: AppModel
    /// false, пока поверх открыта тренировка: как пьёт зелье, показываем, когда экран снова виден
    let isVisible: Bool

    @State private var eatingStart: Date?
    @State private var reactionStart: Date?

    static let tickSeconds = 0.5
    /// Сколько тиков пьёт зелье после занятий и колдует после касания
    static let eatingFrames = 8
    static let reactionFrames = 6

    /// Для UI-тестов: -uitest-pet happy|ok|angry|skeleton|eating|cast — застывший кадр.
    private static let testOverride: String? = UserDefaults.standard.string(forKey: "uitest-pet")
    /// Для UI-тестов: без анимации, чтобы не мешать ожиданию «приложение простаивает».
    private static let isStatic: Bool = testOverride != nil || ProcessInfo.processInfo.arguments.contains("-uitest-static")

    private func tick(_ date: Date) -> Int {
        return Int(date.timeIntervalSinceReferenceDate / PetView.tickSeconds)
    }

    private func running(since start: Date?, at date: Date, length: Int) -> Bool {
        guard let start = start else { return false }
        let f = Int(date.timeIntervalSince(start) / PetView.tickSeconds)
        return f >= 0 && f < length
    }

    private var food: Double {
        if let o = PetView.testOverride {
            switch o {
            case "happy", "eating", "cast": return 100
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
                stage(mood: mood, tick: 2,
                      eating: PetView.testOverride == "eating", reacting: PetView.testOverride == "cast")
            } else {
                TimelineView(.periodic(from: Date(), by: PetView.tickSeconds)) { context in
                    stage(mood: mood, tick: tick(context.date),
                          eating: running(since: eatingStart, at: context.date, length: PetView.eatingFrames),
                          reacting: running(since: reactionStart, at: context.date, length: PetView.reactionFrames))
                }
            }
        }
        .onAppear { startMealIfNeeded(mood: mood) }
        .onChange(of: isVisible) { _ in startMealIfNeeded(mood: PetRules.mood(food: model.petFood())) }
    }

    private func stage(mood: PetMood, tick: Int, eating: Bool, reacting: Bool) -> some View {
        let hungry = mood == .angry || mood == .skeleton
        let pose: TowerPose
        if reacting && !hungry {
            pose = .cast
        } else if eating {
            pose = .drink
        } else {
            pose = TowerPose.resting(mood)
        }
        let caption = eating ? PetRules.eatingCaption : PetRules.caption(mood)
        let layers = TowerScene.compose(pose: pose, tick: tick, hungry: hungry, flash: reacting && hungry)
        // Подписи нет: сцена должна читаться без слов. Текст — только для VoiceOver.
        return PixelStage(layers: layers, width: TowerAtlas.width, height: TowerAtlas.height,
                          darkness: TowerScene.darkness(mood))
            .contentShape(Rectangle())
            .onTapGesture {
                reactionStart = Date()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                SoundFX.shared.play(.tap)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(caption)
            .accessibilityIdentifier("pet-screen")
    }

    /// Покормили — показываем, как пьёт зелье (только если он не голодает).
    private func startMealIfNeeded(mood: PetMood) {
        guard isVisible, !PetView.isStatic, model.user.pet.pendingMeal else { return }
        model.consumePendingMeal()
        if mood == .happy || mood == .ok {
            eatingStart = Date()
        }
    }
}

/// Рисует слои пиксельной сцены без сглаживания, во всю ширину; верх и низ плавно уходят в фон страницы.
struct PixelStage: View {
    let layers: [PlacedLayer]
    /// Размер сцены в пикселях: старая сцена 192×120, зал башни 320×200
    var width: Int = PetAtlas.width
    var height: Int = PetAtlas.height
    /// Затемнение всей сцены (0…1): голодный маг — зал погружается во тьму
    var darkness: Double = 0
    /// Плавно растворять верх и низ в фоне страницы
    var fade: Bool = true

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / CGFloat(width)
            ZStack(alignment: .topLeading) {
                ForEach(layers) { l in
                    Image(l.name)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: CGFloat(l.w) * s, height: CGFloat(l.h) * s)
                        .offset(x: CGFloat(l.x) * s, y: CGFloat(l.y) * s)
                }
                if darkness > 0 {
                    Color.black.opacity(darkness)
                        .frame(width: geo.size.width, height: CGFloat(height) * s)
                        .animation(.easeInOut(duration: 1.5), value: darkness)
                }
            }
            .frame(width: geo.size.width, height: CGFloat(height) * s, alignment: .topLeading)
            .clipped()
        }
        .aspectRatio(CGFloat(width) / CGFloat(height), contentMode: .fit)
        .mask(
            LinearGradient(stops: fade ? [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.06),
                .init(color: .black, location: 0.72),
                .init(color: .clear, location: 1),
            ] : [
                .init(color: .black, location: 0),
                .init(color: .black, location: 1),
            ], startPoint: .top, endPoint: .bottom)
        )
    }
}
