import Foundation

// MARK: - Империя слов, Акт 1: числа баланса и карта
//
// Правила — вкладка «Правила Акта 1» в документе игры; числа — из симулятора Tools/game/act1_sim.py.
// Файл без зависимостей от интерфейса: его собирает и проверка на CI (Tools/game/swift_check).

enum Act1 {
    // Авра за упражнения
    static let avraChoice = 1.0          // верный ответ «выбрать из 4»
    static let avraTyped = 2.0           // верный ответ, где надо написать
    static let avraPhrase = 2.0          // верный ответ во фразах
    static let perfectBonus = 0.25       // упражнение без единой ошибки: +25%
    static let a2Multiplier = 1.5        // слова уровня A2 и выше
    static let planBonus = 20.0          // весь план «Сегодня» пройден
    static let patrolBonus = 20.0        // отбитая стража
    static let bossBonus = 50.0          // победа над боссом поселения
    /// Повтор того же режима за день: 100%, 50%, 25%, дальше ничего
    static let repeatShares: [Double] = [1.0, 0.5, 0.25]

    // Цены
    static let assaultCost = 15.0        // за каждую марионетку в бою
    static let agentFeed = 3.0           // в день за агента
    static let sortieCost = 15.0
    static let bindCost = 10.0
    static let obelisk = 200.0
    static let obeliskUpgrade = 300.0
    static let obeliskRestore = 100.0
    static let decreeCost: [Double] = [150, 250, 400]
    static let zoneDiscount = 0.75       // в зоне обелиска
    static let outOfZone = 1.5           // вне всех зон

    // Обелиски и сон кукол
    static let chargeUp = 20.0           // день, когда план пройден
    static let chargeDown = 25.0         // день совсем без занятий
    static let wakeLow = 0.08            // заряд ниже половины
    static let wakeZero = 0.15           // заряд ноль или нет зоны
    static let armyWakeFactor = 0.5      // войско просыпается вдвое медленнее
    static let graceDays = 7             // поселение после захвата держится само
    static let loseShare = 0.5           // кукол меньше этой доли — поселение потеряно
    static let curfewLoseShare = 0.4     // указ «Комендантский час»

    // Марионетки
    static let startArmy = 20
    static let cemeteryPerDay = 2
    static let bodyDays = 3              // павшие лежат на поле
    static let captiveDays = 7           // похищенные ждут в подвале
    static let takeShare = 0.5           // из поселения в войско — не больше половины исходных жителей
    static let maxAgents = 10
    static let squadSize = 3             // отряд вылазки

    // Настороженность
    static let alertDecay = 5.0
    static let alertFlee = 2.0           // за каждого беглеца после штурма — соседям
    static let alertAbduct = 5.0
    static let alertKey = 25.0
    static let alertExposed = 15.0
    static let alertFailedSortie = 10.0
    static let alertFailedAssault = 10.0
    static let reinforceAt = 50.0
    static let patrolAt = 100.0
    static let exposePerCultist = 0.01

    // Бои
    static let bossQuestions = 20
    static let bossPass = 13
    static let patrolQuestions = 10
    static let patrolPass = 7
    static let patrolFrees = 10          // столько кукол освобождает прорвавшаяся стража
    static let sortieQuestions = 5
    static let keyQuestions = 10
    static let keyNeed = 15
    static let guardPenaltyCap = 5
    static let regarrison = 0.5          // феодал ставит в отбитое поселение половину прежней стражи

    /// Вопросов в бою штурма: 10 + стража, но не больше 30.
    static func assaultQuestions(guards: Int) -> Int {
        return min(10 + guards, 30)
    }

    /// Бонус перевеса: во сколько раз марионеток больше силы обороны.
    static func ratioBonus(_ ratio: Double) -> Int {
        if ratio < 1.0 { return -4 }
        if ratio < 1.5 { return 0 }
        if ratio < 2.0 { return 2 }
        if ratio < 3.0 { return 4 }
        if ratio < 5.0 { return 6 }
        return 10
    }

    /// Обелиск вне поселения: шанс в день, что его найдут и разобьют.
    static func fieldBreakChance(_ terrain: SpotTerrain) -> Double {
        switch terrain {
        case .road: return 0.15
        case .field: return 0.07
        case .forest: return 0.03
        }
    }

    /// Доля набожных по вере (0 — нет, 1 — слабая, 2 — средняя, 3 — сильная).
    static let devout: [Double] = [0.0, 0.10, 0.33, 0.55]

    // MARK: Карта

    static let towns: [TownDef] = [
        TownDef(id: 0, pt: "Vila Calada", pop: 20, guards: 0, walls: 1.0, cultists: 0, faith: 0,
                boss: nil, keys: [], wallsKind: .none),
        TownDef(id: 1, pt: "Aldeia das Redes", pop: 60, guards: 2, walls: 1.0, cultists: 2, faith: 1,
                boss: .pastor, keys: [.elder, .pastor], wallsKind: .none),
        TownDef(id: 2, pt: "Vale do Trigo", pop: 80, guards: 5, walls: 1.25, cultists: 6, faith: 2,
                boss: .captain, keys: [.headman, .pastor, .captain], wallsKind: .fence),
        TownDef(id: 3, pt: "Souto das Sombras", pop: 100, guards: 6, walls: 1.5, cultists: 10, faith: 3,
                boss: .crimsonPriest, keys: [.forester], wallsKind: .palisade),
        TownDef(id: 4, pt: "Monte Sombrio", pop: 140, guards: 24, walls: 3.0, cultists: 6, faith: 2,
                boss: .lord, keys: [.pastor, .captain], wallsKind: .walls),
    ]

    static let roads: [Int: [Int]] = [0: [1], 1: [0, 2], 2: [1, 3, 4], 3: [2, 4], 4: [2, 3]]

    /// Места для обелисков в поле и лесу: по 2–3 между соседними поселениями.
    static let spots: [SpotDef] = [
        SpotDef(id: 0, between: (0, 1), terrain: .road),
        SpotDef(id: 1, between: (0, 1), terrain: .field),
        SpotDef(id: 2, between: (1, 2), terrain: .road),
        SpotDef(id: 3, between: (1, 2), terrain: .field),
        SpotDef(id: 4, between: (2, 3), terrain: .field),
        SpotDef(id: 5, between: (2, 3), terrain: .forest),
        SpotDef(id: 6, between: (2, 4), terrain: .road),
        SpotDef(id: 7, between: (2, 4), terrain: .field),
        SpotDef(id: 8, between: (3, 4), terrain: .forest),
        SpotDef(id: 9, between: (3, 4), terrain: .road),
    ]

    /// Соседи по дорогам.
    static func neighbors(_ town: Int) -> [Int] {
        return roads[town] ?? []
    }
}

/// Ключевые люди поселения.
enum KeyPerson: String, Codable, CaseIterable {
    case pastor        // поп: культисты слабеют вдвое, вера падает на ступень
    case headman       // староста: весть о нападении не уходит к соседям
    case captain       // капитан: стража вдвое слабее
    case elder         // старейшина рыбаков
    case forester      // лесничий
    case crimsonPriest // Багровый Поп: похитить нельзя
    case lord          // Dom Álvaro: похитить нельзя

    /// Можно ли похитить на вылазке.
    var abductable: Bool {
        return self != .crimsonPriest && self != .lord
    }
}

enum WallsKind: String, Codable {
    case none, fence, palisade, walls
}

enum SpotTerrain: String, Codable {
    case road, field, forest
}

struct TownDef {
    let id: Int
    let pt: String
    let pop: Int
    let guards: Int
    let walls: Double
    let cultists: Int
    let faith: Int
    /// Босс поселения: бой с ним перед штурмом
    let boss: KeyPerson?
    let keys: [KeyPerson]
    let wallsKind: WallsKind
}

struct SpotDef {
    let id: Int
    let between: (Int, Int)
    let terrain: SpotTerrain
}
