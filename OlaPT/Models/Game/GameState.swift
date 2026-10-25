import Foundation

// MARK: - Состояние игры (сохраняется вместе с прогрессом учёбы)

enum Owner: String, Codable {
    case mask, lord
}

enum ObeliskState: String, Codable {
    case building   // поставлен, загорится на следующий день
    case lit
    case broken
}

/// Обелиск: в поселении или на месте в поле/лесу.
struct Obelisk: Codable, Equatable {
    var state: ObeliskState
    var charge: Double
    var upgraded: Bool

    init(state: ObeliskState = .building, charge: Double = 100, upgraded: Bool = false) {
        self.state = state
        self.charge = charge
        self.upgraded = upgraded
    }
}

struct TownState: Codable, Equatable {
    var id: Int
    var owner: Owner
    var pop: Int
    var dolls: Int
    var guards: Double
    var cultists: Int
    var faith: Int
    var alert: Double
    var obelisk: Obelisk?
    /// Дней, пока захваченное поселение держится само
    var grace: Int
    var agents: Int
    /// Вернувшиеся домой куклами поп или староста: обращают по двое в день
    var keyAgents: Int
    var unfedDays: Int
    /// Марионетки, оставленные в поселении: защищают от стражи, стерегут обелиск
    var garrison: Int
    /// Сколько кукол уже забрано в войско
    var takenToArmy: Int
    /// Ключевые люди, которых уже нет (похищены или босс побеждён)
    var gone: [KeyPerson]

    init(def: TownDef) {
        id = def.id
        owner = def.id == 0 ? .mask : .lord
        pop = def.pop
        dolls = def.id == 0 ? def.pop : 0
        guards = Double(def.guards)
        cultists = def.cultists
        faith = def.faith
        alert = 0
        obelisk = nil
        grace = 0
        agents = 0
        keyAgents = 0
        unfedDays = 0
        garrison = 0
        takenToArmy = 0
        gone = []
    }

    var def: TownDef { return Act1.towns[id] }

    func has(_ key: KeyPerson) -> Bool {
        return def.keys.contains(key) && !gone.contains(key)
    }

    var bossDefeated: Bool {
        guard let b = def.boss else { return true }
        return gone.contains(b)
    }

    /// Стража с учётом подкрепления и похищенного капитана.
    var effectiveGuards: Double {
        var g = guards * (alert >= Act1.reinforceAt ? 1.5 : 1.0)
        if def.keys.contains(.captain) && gone.contains(.captain) { g /= 2 }
        return g
    }

    /// Сила обороны = (стража × 3 + культисты) × укрепления.
    var defense: Double {
        return (effectiveGuards * 3 + Double(cultists)) * def.walls
    }

    /// Свободные жители (не куклы).
    var free: Int { return max(0, pop - dolls) }
}

/// Похищенный ждёт в подвале башни, пока его не возьмут под контроль.
struct Captive: Codable, Equatable {
    /// До какого дня ждёт (дольше в подвале не выдерживают)
    var until: Int
    /// Откуда и кто — если это ключевой человек (поп или староста может вернуться домой куклой)
    var town: Int?
    var key: KeyPerson?
}

/// Отряд стражи идёт на поселение Маски: виден на карте за день до подхода.
struct Patrol: Codable, Equatable {
    var from: Int
    var target: Int
    /// День (номер игрового дня), когда отряд подойдёт
    var arrives: Int
    var defended: Bool
}

/// Выбор указа на ступени.
enum DecreePath: String, Codable {
    case fear, word
}

/// Что игра объясняет карточкой, как в Frostpunk.
enum GameEvent: Codable, Equatable {
    case captured(town: Int, how: CaptureWay)
    case lost(town: Int)
    case obeliskBroken(town: Int?, spot: Int?)
    case agentExposed(town: Int, count: Int)
    case patrolComing(from: Int, target: Int)
    case patrolBrokeThrough(target: Int, freed: Int)
    case crimsonFled
    case sortieLost(town: Int)
    case armyWoke(count: Int)
    case actComplete
}

enum CaptureWay: String, Codable {
    case assault, infiltration
}

/// Генератор случайных чисел с сохраняемым состоянием (SplitMix64): одна и та же история при перезапуске.
struct GameRNG: Codable, Equatable {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    // В JSON — строкой: большие UInt64 числом теряют точность
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        state = UInt64(try c.decode(String.self)) ?? 0x5EED
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(String(state))
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0 ≤ x < 1
    mutating func unit() -> Double {
        return Double(next() >> 11) / Double(UInt64(1) << 53)
    }

    /// Кубик: 1…sides
    mutating func roll(_ sides: Int) -> Int {
        return Int(next() % UInt64(sides)) + 1
    }

    /// Сколько из n событий с вероятностью p случилось.
    mutating func binomial(_ n: Int, _ p: Double) -> Int {
        guard n > 0, p > 0 else { return 0 }
        var k = 0
        for _ in 0..<n where unit() < p { k += 1 }
        return k
    }
}

struct GameState: Codable, Equatable {
    var towns: [TownState]
    /// Обелиски на местах в поле и лесу: номер места → обелиск
    var spots: [Int: Obelisk]
    var avra: Double
    var army: Int
    /// Похищенные в подвале башни
    var captives: [Captive]
    /// Павшие на поле: до какого дня лежат
    var bodies: [Int]
    /// Сколько ещё можно поднять с кладбища сегодня
    var cemetery: Int
    var decrees: [DecreePath]
    var patrol: Patrol?
    /// Карточки, которые ещё не показали
    var events: [GameEvent]
    /// Номер игрового дня (0 — день начала игры)
    var day: Int
    /// Начало первого дня игры
    var started: Date
    /// Сколько раз сегодня пройден каждый режим (защита от «фарма»)
    var repeats: [String: Int]
    /// Пройден ли сегодня план, занимались ли вообще
    var planDone: Bool
    var studied: Bool
    var rng: GameRNG
    var finished: Bool

    init(started: Date = Date(), seed: UInt64 = UInt64(Date().timeIntervalSince1970)) {
        towns = Act1.towns.map { TownState(def: $0) }
        towns[0].obelisk = Obelisk(state: .lit)
        spots = [:]
        avra = 0
        army = Act1.startArmy
        captives = []
        bodies = []
        cemetery = Act1.cemeteryPerDay
        decrees = []
        patrol = nil
        events = []
        day = 0
        self.started = started
        repeats = [:]
        planDone = false
        studied = false
        rng = GameRNG(seed: seed)
        finished = false
    }

    func town(_ id: Int) -> TownState { return towns[id] }
    /// Заряд башни — первого обелиска
    var towerCharge: Double { return towns[0].obelisk?.charge ?? 0 }
    var owned: [TownState] { return towns.filter { $0.owner == .mask && $0.id != 0 } }

    func has(_ path: DecreePath, tier: Int) -> Bool {
        return decrees.count > tier && decrees[tier] == path
    }
}
