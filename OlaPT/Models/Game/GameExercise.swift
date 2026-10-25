import Foundation

/// Текущее упражнение для Авры: доля с учётом повторов, сколько набрано, были ли ошибки.
struct GameExercise {
    var mode: String?
    var share: Double
    /// Авра за верные ответы до умножения на долю (для бонуса «без ошибок»)
    var base: Double = 0
    var errors: Int = 0
    var answers: Int = 0
    var newWords: Bool = false

    /// Авра за верный ответ: 1 за выбор из 4, 2 — где надо написать и во фразах; A2 и выше — ×1,5.
    static func value(typed: Bool, level: String?) -> Double {
        let v = typed ? Act1.avraTyped : Act1.avraChoice
        if let lv = level, lv != "A1" { return v * Act1.a2Multiplier }
        return v
    }
}
