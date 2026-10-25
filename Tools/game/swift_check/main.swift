// Проверка движка Акта 1 на CI: правила по отдельности и бот, который играет 90 дней,
// как в симуляторе Tools/game/act1_sim.py. Сборка:
//   swiftc -O OlaPT/Models/Game/*.swift Tools/game/swift_check/main.swift -o game_check && ./game_check
import Foundation

var failures: [String] = []
func check(_ ok: Bool, _ what: String) {
    print((ok ? "ok    " : "FAIL  ") + what)
    if !ok { failures.append(what) }
}

// MARK: - Правила по отдельности

do {
    var g = GameState(seed: 1)
    check(g.army == 20 && g.avra == 0, "старт: 20 марионеток, 0 Авры")
    check(g.coverCharge(0) != nil && g.coverCharge(1) != nil && g.coverCharge(2) == nil,
          "башня накрывает Молчаливую деревню и Деревню сетей, но не долину")
    check(g.priceFactor(1) == Act1.zoneDiscount && g.priceFactor(2) == Act1.outOfZone, "в зоне дешевле, вне зон дороже")

    let a = g.reward(base: 100, mode: "verbs", perfect: false)
    let b = g.reward(base: 100, mode: "verbs", perfect: false)
    let c = g.reward(base: 100, mode: "verbs", perfect: false)
    let d = g.reward(base: 100, mode: "verbs", perfect: false)
    let e = g.reward(base: 100, mode: "phrases", perfect: true)
    check(a == 100 && b == 50 && c == 25 && d == 0, "повтор режима за день: 100%, 50%, 25%, потом ничего")
    check(e == 125, "другой режим снова 100%, без ошибок +25%")

    g.planDone = false; g.studied = false
    g.advance(to: 2)
    check(g.towerCharge == 50, "два дня без занятий: заряд башни 100 → 50")
    g.completePlan()
    g.advance(to: 3)
    check(g.towerCharge == 70, "день с планом: +20")
    check(g.repeats.isEmpty && !g.planDone, "в полночь счёт повторов и план обнуляются")
}

do {
    // Похищенного попа можно вернуть домой куклой: он обращает двоих в день
    var g = GameState(seed: 7)
    g.avra = 1000
    g.captives = [Captive(until: 5, town: 1, key: .pastor)]
    try? g.bind(.captive(index: 0))
    check(g.towns[1].keyAgents == 1 && g.army == 20, "поп-кукла вернулся домой агентом, а не в войско")

    // Кладбище: два в день
    try? g.bind(.cemetery); try? g.bind(.cemetery)
    var third = false
    do { try g.bind(.cemetery) } catch { third = true }
    check(third && g.army == 22, "кладбище — не больше двух в день")
}

do {
    // Шансы штурма видны до боя и складываются в единицу
    let g = GameState(seed: 3)
    let o = g.assaultOdds(1, squad: 30)
    check(abs(o.fail + o.hard + o.sure + o.rout - 1) < 1e-9, "шансы штурма складываются в 100%")
    check(o.bossFight && o.questions == 12, "Деревня сетей: сначала бой с попом, в бою 10 + 2 вопроса")
}

do {
    // Потеря поселения: кукол меньше половины
    var g = GameState(seed: 11)
    g.capture(1, way: .infiltration)
    g.towns[1].dolls = 20
    g.towns[1].grace = 0
    g.advance(to: 1)
    check(g.towns[1].owner == .lord && g.towns[1].guards == 1, "кукол меньше половины — поселение снова у феодала, стража — половина")
    check(g.events.contains(.lost(town: 1)), "карточка «поселение потеряно»")
}

// MARK: - Бот: 90 дней, как в симуляторе

struct Profile {
    let name: String
    let active: (Int) -> Bool
    let decreePace: Double
}

let profiles = [
    Profile(name: "daily", active: { _ in true }, decreePace: 1.0),
    Profile(name: "weekends", active: { $0 % 7 != 5 && $0 % 7 != 6 }, decreePace: 1.4),
    Profile(name: "away_week", active: { !(30...36).contains($0) }, decreePace: 1.1),
    Profile(name: "quit_2w", active: { !(40...53).contains($0) }, decreePace: 1.2),
]

let accuracy = 0.85
let avraPerCorrect = 1.5

struct Bot {
    var g: GameState
    var rng: GameRNG
    let profile: Profile

    init(profile: Profile, seed: UInt64) {
        self.profile = profile
        g = GameState(seed: seed &* 2654435761 &+ 1)
        rng = GameRNG(seed: seed &+ 99)
    }

    mutating func ok(_ n: Int) -> Int { return rng.binomial(n, accuracy) }

    mutating func fight(_ n: Int) -> Int {
        let right = ok(n)
        g.reward(base: Double(right) * avraPerCorrect, mode: nil, perfect: false)
        return right
    }

    mutating func sortie(_ i: Int, key: KeyPerson?) {
        guard (try? g.beginSortie(i, key: key)) != nil else { return }
        let right = fight(key == nil ? Act1.sortieQuestions : Act1.keyQuestions)
        _ = g.resolveSortie(i, key: key, correct: right)
    }

    mutating func bindUpTo(_ want: Int) -> Int {
        var got = 0
        while got < want, !g.captives.isEmpty, (try? g.bind(.captive(index: g.captives.count - 1))) != nil { got += 1 }
        while got < want, !g.bodies.isEmpty, (try? g.bind(.body)) != nil { got += 1 }
        while got < want, g.cemetery > 0, (try? g.bind(.cemetery)) != nil { got += 1 }
        for t in g.owned.sorted(by: { $0.dolls > $1.dolls }) {
            while got < want, (try? g.bind(.town(t.id))) != nil { got += 1 }
        }
        return got
    }

    func keyChance(_ i: Int) -> Double {
        let need = Double(Act1.keyNeed) - (10 * accuracy - Double(g.sortiePenalty(i)))
        return max(0.05, min(1, (21 - ceil(need)) / 20))
    }

    func sortieFailChance(_ i: Int) -> Double {
        let bonus = 5 * accuracy - Double(g.sortiePenalty(i))
        return min(1, max(0.05, (6 - bonus) / 20))
    }

    mutating func act() {
        for t in g.owned {
            if g.coverCharge(t.id) == nil {
                if t.obelisk?.state == .broken { try? g.restoreObelisk(town: t.id) }
                else if t.obelisk == nil { try? g.buildObelisk(town: t.id) }
            }
            let tt = g.towns[t.id]
            if tt.cultists > 0 && g.army > tt.cultists + 2 && tt.garrison <= tt.cultists {
                try? g.garrison(t.id, tt.cultists + 1 - tt.garrison)
            }
        }
        let days: [Double] = [20, 40, 60]
        if g.decrees.count < 3 && Double(g.day) >= days[g.decrees.count] * profile.decreePace
            && g.avra >= Act1.decreeCost[g.decrees.count] + 100 {
            try? g.decree(.fear)
        }
        _ = bindUpTo(g.captives.count + g.bodies.count)
        for t in g.owned where t.cultists > 0 && g.avra >= 60 {
            sortie(t.id, key: nil)
            break
        }
        guard let target = g.towns.first(where: { $0.owner == .lord }) else { return }
        let i = target.id
        if i == 4 {
            for key in [KeyPerson.pastor, .captain] where g.towns[4].has(key) && g.avra >= 80 && g.army >= 6
                && g.towns[4].alert < Act1.reinforceAt && keyChance(4) >= 0.25 {
                sortie(4, key: key)
                break
            }
            let expose = Act1.exposePerCultist * Double(g.towns[4].cultists)
            if g.towns[4].agents < Act1.maxAgents && g.army > 30 && expose <= 0.05 && g.towns[4].alert < Act1.reinforceAt {
                try? g.sendAgents(4, min(Act1.maxAgents - g.towns[4].agents, g.army - 30))
            }
        }
        let t = g.towns[i]
        let squad = max(3, Int(ceil(2 * t.defense - 2 * Double(t.dolls))))
        var lack = max(0, squad - g.army)
        let cost = Double(lack) * Act1.bindCost + Double(squad) * Act1.assaultCost * g.priceFactor(i)
        if i == 4 && t.agents >= 5 && Double(t.dolls) < 0.5 * Double(t.pop) { return }
        if g.avra >= cost {
            _ = bindUpTo(lack)
            if g.army >= squad, (try? g.beginAssault(i, squad: squad)) != nil {
                let boss: Int? = g.towns[i].bossDefeated ? nil : fight(Act1.bossQuestions)
                let q = Act1.assaultQuestions(guards: Int(g.towns[i].effectiveGuards))
                let right = boss.map { $0 >= Act1.bossPass } ?? true ? fight(q) : 0
                _ = g.resolveAssault(i, squad: squad, bossCorrect: boss, correct: right, questions: q)
                return
            }
        }
        lack = max(0, squad - g.army)
        let pool = g.owned.reduce(0) { $0 + g.room($1) } + g.cemetery
        if lack > pool + g.captives.count {
            for _ in 0..<2 {
                let tt = g.towns[i]
                if g.army >= 6 && g.avra >= Act1.sortieCost * 2 + 30 && tt.free >= 5
                    && tt.alert < 40 && sortieFailChance(i) <= 0.2 {
                    sortie(i, key: nil)
                }
            }
        }
    }

    /// Отряд стражи: ученик, который занимается, отбивает его в тот же день.
    mutating func defend() {
        guard g.patrol != nil else { return }
        let right = fight(Act1.patrolQuestions)
        g.resolveDefense(correct: right)
    }

    mutating func run(days: Int) -> (finish: Int?, owned: [Int]) {
        var finish: Int?
        var owned: [Int] = []
        for d in 0..<days {
            if profile.active(d) {
                g.reward(base: (150 - Act1.planBonus) * accuracy / 0.85, mode: nil, perfect: false)
                g.completePlan()
                defend()
                act()
            }
            if g.finished && finish == nil { finish = d }
            owned.append(g.owned.count)
            g.advance(to: d + 1)
            g.events.removeAll()
        }
        return (finish, owned)
    }
}

func median(_ xs: [Int]) -> Int? {
    let s = xs.sorted()
    return s.isEmpty ? nil : s[s.count / 2]
}

let runs = 200
var dailyMedian: Int?
var dailyShare = 0.0
for p in profiles {
    var finishes: [Int] = []
    var lostInGap: [Int] = []
    for seed in 0..<runs {
        var bot = Bot(profile: p, seed: UInt64(seed))
        let r = bot.run(days: 90)
        if let f = r.finish { finishes.append(f) }
        if p.name == "away_week" { lostInGap.append(r.owned[29] - (r.owned[29...37].min() ?? 0)) }
        if p.name == "quit_2w" { lostInGap.append(r.owned[39] - (r.owned[39...54].min() ?? 0)) }
    }
    let share = Double(finishes.count) / Double(runs)
    let lost = lostInGap.isEmpty ? "" : String(format: "  за перерыв теряет в среднем %.2f", Double(lostInGap.reduce(0, +)) / Double(runs))
    let name = p.name.padding(toLength: 10, withPad: " ", startingAt: 0)
    let med = median(finishes).map { String($0) } ?? "—"
    print(name + String(format: " финиш %3.0f%%", share * 100) + "  медиана " + med + lost)
    if p.name == "daily" { dailyMedian = median(finishes); dailyShare = share }
}
check(dailyShare >= 0.9, "ежедневный ученик проходит Акт 1 (≥ 90% прогонов)")
check((dailyMedian ?? 0) >= 30 && (dailyMedian ?? 999) <= 63, "ежедневный ученик — за 4–9 недель (симулятор на Python: 44 дня)")

if failures.isEmpty {
    print("Все проверки пройдены")
} else {
    print("Не прошло: \(failures.count)")
    exit(1)
}
