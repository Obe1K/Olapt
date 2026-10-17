import Foundation

// MARK: - Интервальные повторения (FSRS)

/// Оценка ответа для алгоритма повторений.
enum ReviewRating: Int {
    case again = 1   // ошибка
    case hard = 2    // верно, но с ошибкой в ударении
    case good = 3    // верно
}

/// Состояние слова в интервальных повторениях.
struct SRSState: Codable, Hashable {
    /// «Стабильность» памяти в днях: через столько дней вероятность вспомнить падает до 90 %.
    var stability: Double
    /// Сложность слова для вас: 1 (лёгкое) … 10 (трудное).
    var difficulty: Double
    /// Когда слово впервые попало в повторения.
    var firstSeen: Date
    /// Последний ответ.
    var lastReview: Date
    /// День следующего повторения (начало суток).
    var due: Date
    var reps: Int
    var lapses: Int

    enum CodingKeys: String, CodingKey {
        case stability, difficulty, firstSeen, lastReview, due, reps, lapses
    }

    init(stability: Double, difficulty: Double, firstSeen: Date, lastReview: Date, due: Date, reps: Int, lapses: Int) {
        self.stability = stability
        self.difficulty = difficulty
        self.firstSeen = firstSeen
        self.lastReview = lastReview
        self.due = due
        self.reps = reps
        self.lapses = lapses
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let now = Date()
        stability = try c.decodeIfPresent(Double.self, forKey: .stability) ?? 1
        difficulty = try c.decodeIfPresent(Double.self, forKey: .difficulty) ?? 5
        firstSeen = try c.decodeIfPresent(Date.self, forKey: .firstSeen) ?? now
        lastReview = try c.decodeIfPresent(Date.self, forKey: .lastReview) ?? now
        due = try c.decodeIfPresent(Date.self, forKey: .due) ?? now
        reps = try c.decodeIfPresent(Int.self, forKey: .reps) ?? 0
        lapses = try c.decodeIfPresent(Int.self, forKey: .lapses) ?? 0
    }
}

/// Алгоритм FSRS-4.5 (Free Spaced Repetition Scheduler) с параметрами по умолчанию.
/// Слово возвращается к повторению, когда вероятность его вспомнить падает примерно до 90 %.
/// Первые интервалы при верных ответах: ~4 дня, ~2 недели, ~1,5 месяца, ~4–5 месяцев.
enum FSRS {
    static let w: [Double] = [0.4872, 1.4003, 3.7145, 13.8206, 5.1618, 1.2298, 0.8975, 0.031,
                              1.6474, 0.1367, 1.0461, 2.1072, 0.0793, 0.3246, 1.587, 0.2272, 2.8755]
    static let decay = -0.5
    static let factor = 19.0 / 81.0
    /// Слово «выучено», когда держится в памяти не меньше трёх недель.
    static let learnedStability = 21.0
    static let maxInterval = 365

    static var calendar: Calendar {
        return Calendar.current
    }

    static func startOfDay(_ date: Date) -> Date {
        return calendar.startOfDay(for: date)
    }

    static func days(from a: Date, to b: Date) -> Int {
        return calendar.dateComponents([.day], from: startOfDay(a), to: startOfDay(b)).day ?? 0
    }

    /// Вероятность вспомнить через t дней.
    static func retrievability(elapsedDays t: Double, stability s: Double) -> Double {
        return pow(1 + factor * t / max(s, 0.01), decay)
    }

    private static func clampDifficulty(_ d: Double) -> Double {
        return min(10, max(1, d))
    }

    private static func initialDifficulty(_ r: ReviewRating) -> Double {
        return clampDifficulty(w[4] - Double(r.rawValue - 3) * w[5])
    }

    /// Интервал в днях до следующего повторения.
    static func intervalDays(stability s: Double) -> Int {
        // При желаемой вероятности 90 % интервал равен стабильности.
        return min(maxInterval, max(1, Int(s.rounded())))
    }

    /// Новое состояние после ответа.
    static func review(_ state: SRSState?, rating: ReviewRating, now: Date = Date()) -> SRSState {
        guard var s = state else {
            let stability = w[rating.rawValue - 1]
            let interval = intervalDays(stability: stability)
            let due = calendar.date(byAdding: .day, value: interval, to: startOfDay(now)) ?? now
            return SRSState(stability: stability, difficulty: initialDifficulty(rating),
                            firstSeen: now, lastReview: now, due: due,
                            reps: 1, lapses: rating == .again ? 1 : 0)
        }
        let elapsed = Double(max(0, days(from: s.lastReview, to: now)))
        let r = retrievability(elapsedDays: elapsed, stability: s.stability)
        let d = s.difficulty

        // Сложность: ошибка повышает, «хорошо» оставляет, с плавным возвратом к среднему.
        let changed = d - w[6] * Double(rating.rawValue - 3)
        s.difficulty = clampDifficulty(w[7] * initialDifficulty(.good) + (1 - w[7]) * changed)

        if rating == .again {
            let forget = w[11] * pow(d, -w[12]) * (pow(s.stability + 1, w[13]) - 1) * exp(w[14] * (1 - r))
            s.stability = max(0.1, min(forget, s.stability))
            s.lapses += 1
        } else {
            let hardPenalty = rating == .hard ? w[15] : 1
            let growth = exp(w[8]) * (11 - d) * pow(s.stability, -w[9]) * (exp(w[10] * (1 - r)) - 1) * hardPenalty
            s.stability = s.stability * (growth + 1)
        }
        s.reps += 1
        s.lastReview = now
        let interval = intervalDays(stability: s.stability)
        s.due = calendar.date(byAdding: .day, value: interval, to: startOfDay(now)) ?? now
        return s
    }
}
