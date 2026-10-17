import Foundation

// MARK: - Тамагочи: маг в башне

/// Состояние питомца. Сытость падает со временем и растёт от упражнений.
/// Сыт — читает книгу заклинаний в башне; голодает — сидит в темнице.
struct PetData: Codable {
    /// Сытость 0…100 на момент `updated`
    var food: Double
    var updated: Date
    /// Питомца покормили, а он ещё не показал, как ест
    var pendingMeal: Bool

    enum CodingKeys: String, CodingKey {
        case food, updated, pendingMeal
    }

    init(food: Double = 100, updated: Date = Date(), pendingMeal: Bool = false) {
        self.food = food
        self.updated = updated
        self.pendingMeal = pendingMeal
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        food = try c.decodeIfPresent(Double.self, forKey: .food) ?? 100
        updated = try c.decodeIfPresent(Date.self, forKey: .updated) ?? Date()
        pendingMeal = try c.decodeIfPresent(Bool.self, forKey: .pendingMeal) ?? false
    }
}

enum PetMood: String, CaseIterable {
    case happy      // сыт: башня, читает книгу заклинаний
    case ok         // немного проголодался: башня, сидит
    case angry      // голодает: темница, проклинает рунами
    case skeleton   // совсем зачах: скелет в кандалах
}

enum PetRules {
    /// Сытость падает на 36 в сутки: пропущенный день — ещё «нормально»,
    /// два дня — злой и худой, три — скелет.
    static let decayPerHour = 1.5
    static let foodPerCorrect = 4.0
    static let foodPerWrong = 2.0

    static func food(_ pet: PetData, at now: Date = Date()) -> Double {
        let hours = max(0, now.timeIntervalSince(pet.updated) / 3600)
        return min(100, max(0, pet.food - hours * decayPerHour))
    }

    static func mood(food: Double) -> PetMood {
        if food >= 70 { return .happy }
        if food >= 40 { return .ok }
        if food >= 5 { return .angry }
        return .skeleton
    }

    /// Горящие свечи — сытость, 0…4
    static func hearts(food: Double) -> Int {
        return min(4, max(0, Int((food / 25).rounded(.up))))
    }

    static func caption(_ mood: PetMood) -> String {
        switch mood {
        case .happy: return "Сыт и доволен — читает книгу заклинаний за кафедрой в своей башне"
        case .ok: return "Проголодался: забросил книгу и мечтает о зелье"
        case .angry: return "Голодает в темнице и проклинает вас. Пройдите план на сегодня — и он вернётся в башню"
        case .skeleton: return "Совсем зачах в темнице… Пара упражнений — и он оживёт"
        }
    }

    static let eatingCaption = "Пьёт зелье — спасибо за занятия!"

    /// Проклятия рунами: номера знаков из PetSprites.runes (9 — «!»).
    static let curses: [[Int]] = [
        [0, 2, 4, 9],
        [3, 1, 6, 9],
        [5, 7, 2, 9, 9],
        [4, 8, 0, 9],
        [6, 3, 5, 1],
        [2, 2, 7, 9],
    ]
}
