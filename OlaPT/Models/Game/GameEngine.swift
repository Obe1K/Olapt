import Foundation

// MARK: - Правила Акта 1: ночь (смена дня), действия, бои
//
// Всё, что решает кубик или случай, берёт числа из state.rng — история повторяется при перезапуске.
// Интерфейса здесь нет: карточки событий копятся в state.events, тексты к ним — в GameTexts.

enum GameError: Error, Equatable {
    case notEnoughAvra
    case notEnoughArmy
    case notAvailable
}

/// Шансы штурма, которые видны до начала боя.
struct AssaultOdds: Equatable {
    var cost: Double
    var questions: Int
    var bossFight: Bool
    var defense: Double
    var ratio: Double
    var bonus: Int
    /// Вероятности (при бое без ошибок): отбит, тяжёлая, уверенная, разгром
    var fail: Double
    var hard: Double
    var sure: Double
    var rout: Double
}

enum AssaultOutcome: String, Codable {
    case bossLost, fail, hard, sure, rout
}

struct AssaultResult: Equatable {
    var outcome: AssaultOutcome
    var roll: Int
    var bonus: Int
    /// Марионетки, погибшие в бою (ошибки + потери после броска)
    var lost: Int
    var killed: Int
    var fled: Int
    var dolls: Int
}

struct SortieResult: Equatable {
    var roll: Int
    var bonus: Int
    /// −1 — отряд не вернулся; иначе сколько увели
    var taken: Int
    var keyTaken: KeyPerson?
}

extension GameState {

    // MARK: Зоны обелисков

    /// Лучший заряд среди горящих обелисков, чья зона накрывает поселение; nil — вне всех зон.
    func coverCharge(_ town: Int) -> Double? {
        var best: Double?
        /// reach — на сколько дорог от центров дотягивается зона (усиленный обелиск — на одну дальше)
        func consider(_ o: Obelisk, _ centers: [Int], reach: Int) {
            guard o.state == .lit else { return }
            var area = Set(centers)
            let steps = reach + (o.upgraded ? 1 : 0)
            for _ in 0..<steps {
                for c in Array(area) { area.formUnion(Act1.neighbors(c)) }
            }
            if area.contains(town) { best = max(best ?? 0, o.charge) }
        }
        // обелиск поселения накрывает его и соседей; башня — Молчаливую деревню и Деревню сетей
        for t in towns where t.owner == .mask {
            if let o = t.obelisk { consider(o, [t.id], reach: 1) }
        }
        // обелиск в поле — оба поселения по краям; держится, пока хотя бы одно из них — Маски
        for (id, o) in spots {
            let s = Act1.spots[id]
            if towns[s.between.0].owner == .mask || towns[s.between.1].owner == .mask {
                consider(o, [s.between.0, s.between.1], reach: 0)
            }
        }
        return best
    }

    /// Множитель цены действий против поселения: в зоне дешевле, вне зон дороже.
    func priceFactor(_ town: Int) -> Double {
        return coverCharge(town) != nil ? Act1.zoneDiscount : Act1.outOfZone
    }

    /// Доля кукол, ниже которой поселение потеряно.
    var loseShare: Double {
        return has(.fear, tier: 0) ? Act1.curfewLoseShare : Act1.loseShare
    }

    /// Гарнизон против стражи и культистов (указ «Железная рука» — вдвое).
    func garrisonPower(_ t: TownState) -> Int {
        return t.garrison * (has(.fear, tier: 1) ? 2 : 1)
    }

    // MARK: Авра за упражнения

    /// Начислить Авру за упражнение и вернуть, сколько вышло.
    /// - base: Авра за верные ответы (1 за выбор, 2 за письмо и фразы; A2 и выше ×1,5 — считает вызывающий)
    /// - mode: режим для защиты от «фарма»; nil — бой, вылазка или оборона (каждый — отдельное упражнение)
    /// - perfect: без единой ошибки — +25%
    /// - newWords: в упражнении были новые слова (указ «Глашатаи» — +10%)
    @discardableResult
    mutating func reward(base: Double, mode: String?, perfect: Bool, newWords: Bool = false) -> Double {
        var amount = base * (perfect ? 1 + Act1.perfectBonus : 1)
        if newWords && has(.word, tier: 0) { amount *= 1.1 }
        if let m = mode {
            let n = repeats[m] ?? 0
            let share = n < Act1.repeatShares.count ? Act1.repeatShares[n] : 0
            repeats[m] = n + 1
            amount *= share
        }
        amount = (amount * 10).rounded() / 10
        avra += amount
        if base > 0 { studied = true }
        return amount
    }

    /// План «Сегодня» пройден целиком: +20 и обелиски на ночь заряжаются.
    mutating func completePlan() {
        guard !planDone else { return }
        planDone = true
        studied = true
        avra += Act1.planBonus
    }

    // MARK: Смена дня

    /// Прожить ночи до дня `target` (номер игрового дня). Пропущенные дни — без занятий.
    mutating func advance(to target: Int) {
        while day < target {
            night()
            day += 1
            planDone = false
            studied = false
            repeats = [:]
        }
    }

    /// Номер игрового дня для даты.
    func dayNumber(for date: Date, calendar: Calendar = .current) -> Int {
        let a = calendar.startOfDay(for: started)
        let b = calendar.startOfDay(for: date)
        return max(0, calendar.dateComponents([.day], from: a, to: b).day ?? 0)
    }

    mutating func night() {
        chargeObelisks()
        cemetery = Act1.cemeteryPerDay
        bodies = bodies.filter { $0 > day }
        captives = captives.filter { $0.until > day }
        wake()
        cultistsAct()
        fieldObelisksFound()
        checkLost()
        infiltration()
        patrolArrives()
        alerts()
    }

    private mutating func chargeObelisks() {
        func charged(_ o: Obelisk) -> Obelisk {
            var o = o
            switch o.state {
            case .building:
                o.state = .lit
                o.charge = 100
            case .lit:
                if planDone {
                    o.charge = min(100, o.charge + Act1.chargeUp)
                } else if !studied {
                    o.charge = max(0, o.charge - Act1.chargeDown)
                }
            case .broken:
                break
            }
            return o
        }
        for i in towns.indices where towns[i].owner == .mask {
            if let o = towns[i].obelisk { towns[i].obelisk = charged(o) }
        }
        for (id, o) in spots { spots[id] = charged(o) }
    }

    private func wakeRate(_ charge: Double?) -> Double {
        guard let c = charge, c > 0 else { return Act1.wakeZero }
        return c < 50 ? Act1.wakeLow : 0
    }

    private mutating func wake() {
        for i in towns.indices where towns[i].owner == .mask && towns[i].id != 0 {
            if towns[i].grace > 0 {
                towns[i].grace -= 1
                continue
            }
            let rate = wakeRate(coverCharge(i))
            if rate > 0 {
                towns[i].dolls -= rng.binomial(towns[i].dolls, rate)
            }
        }
        let tower = towns[0].obelisk.map { $0.state == .lit ? $0.charge : 0 }
        let rate = wakeRate(tower) * Act1.armyWakeFactor
        if rate > 0 {
            let woke = rng.binomial(army, rate)
            if woke > 0 {
                army -= woke
                events.append(.armyWoke(count: woke))
            }
        }
    }

    private mutating func cultistsAct() {
        for i in towns.indices where towns[i].owner == .mask && towns[i].id != 0 {
            let c = towns[i].cultists
            guard c > 0 else { continue }
            towns[i].dolls = max(0, towns[i].dolls - c / 2)
            if var o = towns[i].obelisk, o.state == .lit, c > garrisonPower(towns[i]) {
                if rng.unit() < 0.1 + towns[i].alert / 200 {
                    o.state = .broken
                    towns[i].obelisk = o
                    events.append(.obeliskBroken(town: i, spot: nil))
                }
            }
        }
    }

    private mutating func fieldObelisksFound() {
        for (id, o) in spots where o.state == .lit {
            let s = Act1.spots[id]
            let alert = max(towns[s.between.0].alert, towns[s.between.1].alert)
            let p = Act1.fieldBreakChance(s.terrain) * (1 + alert / 100)
            if rng.unit() < p {
                var b = o
                b.state = .broken
                spots[id] = b
                events.append(.obeliskBroken(town: nil, spot: id))
            }
        }
    }

    private mutating func checkLost() {
        for i in towns.indices where towns[i].owner == .mask && towns[i].id != 0 {
            let t = towns[i]
            if Double(t.dolls) < loseShare * Double(t.pop) {
                lose(i)
            }
        }
    }

    /// Поселение снова под феодалом: обелиск разбит, гарнизон пропал, стража — половина прежней.
    mutating func lose(_ i: Int) {
        let def = Act1.towns[i]
        towns[i].owner = .lord
        towns[i].obelisk = nil
        towns[i].garrison = 0
        towns[i].dolls = 0
        towns[i].grace = 0
        towns[i].cultists = max(towns[i].cultists, def.cultists / 2)
        towns[i].guards = Double(def.guards) * Act1.regarrison
        // капитан и поп снова на месте; побеждённый босс — тоже (кроме бежавшего Багрового Попа)
        towns[i].gone = towns[i].gone.filter { $0 == .crimsonPriest }
        if patrol?.target == i { patrol = nil }
        events.append(.lost(town: i))
    }

    private mutating func infiltration() {
        for i in towns.indices where towns[i].owner == .lord && (towns[i].agents > 0 || towns[i].keyAgents > 0) {
            let n = towns[i].agents + towns[i].keyAgents
            let cost = Act1.agentFeed * Double(n) * priceFactor(i)
            if avra >= cost {
                avra -= cost
                towns[i].unfedDays = 0
                let capacity = towns[i].agents + 2 * towns[i].keyAgents
                var faith = towns[i].faith
                if has(.word, tier: 1) { faith = max(0, faith - 1) }   // «Лжепророки»
                let devout = Act1.devout[min(3, faith)]
                let converted = rng.binomial(capacity, 1 - devout / 2)
                towns[i].dolls = min(towns[i].pop, towns[i].dolls + converted)
            } else {
                towns[i].unfedDays += 1
            }
            var p = Act1.exposePerCultist * Double(towns[i].cultists) * (towns[i].alert >= Act1.reinforceAt ? 1.5 : 1)
            if towns[i].unfedDays >= 3 { p += 0.2 }
            let lostAgents = rng.binomial(towns[i].agents, p)
            let lostKeys = rng.binomial(towns[i].keyAgents, p)
            if lostAgents + lostKeys > 0 {
                towns[i].agents -= lostAgents
                towns[i].keyAgents -= lostKeys
                if !has(.word, tier: 2) {   // «Шёпот»
                    towns[i].alert += Act1.alertExposed * Double(lostAgents + lostKeys)
                }
                events.append(.agentExposed(town: i, count: lostAgents + lostKeys))
            }
            let quiet = towns[i].def.boss.map { $0.abductable } ?? true
            if quiet && Double(towns[i].dolls) >= 2.0 / 3.0 * Double(towns[i].pop) {
                capture(i, way: .infiltration)
            }
        }
    }

    /// Ближайшее поселение Маски (кроме башни) по дорогам.
    func nearestOwned(from start: Int) -> Int? {
        var seen: Set<Int> = [start]
        var queue = [start]
        while !queue.isEmpty {
            let i = queue.removeFirst()
            for j in Act1.neighbors(i) where !seen.contains(j) {
                seen.insert(j)
                if towns[j].owner == .mask && j != 0 { return j }
                queue.append(j)
            }
        }
        return nil
    }

    private mutating func alerts() {
        for i in towns.indices where towns[i].owner == .lord {
            if towns[i].alert >= Act1.patrolAt && patrol == nil, let target = nearestOwned(from: i) {
                patrol = Patrol(from: i, target: target, arrives: day + 1, defended: false)
                events.append(.patrolComing(from: i, target: target))
                towns[i].alert = Act1.reinforceAt
            }
            towns[i].alert = max(0, towns[i].alert - Act1.alertDecay)
        }
    }

    private mutating func patrolArrives() {
        guard let p = patrol, p.arrives <= day else { return }
        patrol = nil
        guard !p.defended, towns[p.target].owner == .mask else { return }
        let freed = max(0, Act1.patrolFrees - 2 * garrisonPower(towns[p.target]))
        towns[p.target].dolls = max(0, towns[p.target].dolls - freed)
        if var o = towns[p.target].obelisk, o.state == .lit {
            o.state = .broken
            towns[p.target].obelisk = o
        }
        events.append(.patrolBrokeThrough(target: p.target, freed: freed))
    }

    // MARK: Захват

    mutating func capture(_ i: Int, way: CaptureWay) {
        towns[i].owner = .mask
        towns[i].grace = Act1.graceDays
        army += towns[i].agents
        towns[i].agents = 0
        towns[i].keyAgents = 0
        towns[i].unfedDays = 0
        if patrol?.from == i { patrol = nil }
        events.append(.captured(town: i, how: way))
        // роща пала — Багровый Поп сразу бежит на юг, вера по всей области слабеет на ступень
        if towns[i].def.boss == .crimsonPriest && !towns[i].gone.contains(.crimsonPriest) {
            towns[i].gone.append(.crimsonPriest)
            for j in towns.indices { towns[j].faith = max(0, towns[j].faith - 1) }
            events.append(.crimsonFled)
        }
        if towns[i].def.boss == .lord && !finished {
            finished = true
            events.append(.actComplete)
        }
    }

    // MARK: Марионетки

    /// Сколько кукол ещё можно забрать из поселения в войско.
    func room(_ t: TownState) -> Int {
        let limit = Int(Act1.takeShare * Double(t.def.pop))
        return max(0, min(limit - t.takenToArmy, t.pop - limit, t.dolls))
    }

    enum BindSource: Equatable {
        case captive(index: Int)
        case body
        case cemetery
        case town(Int)
    }

    /// Взять марионетку под контроль за 10 Авры.
    mutating func bind(_ source: BindSource) throws {
        guard avra >= Act1.bindCost else { throw GameError.notEnoughAvra }
        switch source {
        case .captive(let index):
            guard captives.indices.contains(index) else { throw GameError.notAvailable }
            let c = captives.remove(at: index)
            avra -= Act1.bindCost
            if let t = c.town, let key = c.key, key == .pastor || key == .headman, towns[t].owner == .lord {
                // поп или староста возвращается домой куклой: работает как агент, обращает двоих в день
                towns[t].keyAgents += 1
            } else {
                army += 1
            }
            return
        case .body:
            guard !bodies.isEmpty else { throw GameError.notAvailable }
            bodies.removeLast()
        case .cemetery:
            guard cemetery > 0 else { throw GameError.notAvailable }
            cemetery -= 1
        case .town(let i):
            guard towns[i].owner == .mask, room(towns[i]) > 0 else { throw GameError.notAvailable }
            towns[i].dolls -= 1
            towns[i].pop -= 1
            towns[i].takenToArmy += 1
        }
        avra -= Act1.bindCost
        army += 1
    }

    /// Оставить марионеток в поселении (отрицательное n — забрать обратно в войско).
    mutating func garrison(_ i: Int, _ n: Int) throws {
        guard towns[i].owner == .mask, i != 0 else { throw GameError.notAvailable }
        if n > 0 && army < n { throw GameError.notEnoughArmy }
        if n < 0 && towns[i].garrison < -n { throw GameError.notAvailable }
        army -= n
        towns[i].garrison += n
    }

    // MARK: Обелиски

    mutating func buildObelisk(town i: Int) throws {
        guard towns[i].owner == .mask, towns[i].obelisk == nil else { throw GameError.notAvailable }
        guard avra >= Act1.obelisk else { throw GameError.notEnoughAvra }
        avra -= Act1.obelisk
        towns[i].obelisk = Obelisk(state: .building)
    }

    /// Место в поле доступно, если одно из соседних поселений — Маски.
    func spotAvailable(_ id: Int) -> Bool {
        let s = Act1.spots[id]
        return towns[s.between.0].owner == .mask || towns[s.between.1].owner == .mask
    }

    mutating func buildObelisk(spot id: Int) throws {
        guard spotAvailable(id), spots[id] == nil else { throw GameError.notAvailable }
        guard avra >= Act1.obelisk else { throw GameError.notEnoughAvra }
        avra -= Act1.obelisk
        spots[id] = Obelisk(state: .building)
    }

    mutating func restoreObelisk(town i: Int) throws {
        guard var o = towns[i].obelisk, o.state == .broken else { throw GameError.notAvailable }
        guard avra >= Act1.obeliskRestore else { throw GameError.notEnoughAvra }
        avra -= Act1.obeliskRestore
        o.state = .building
        towns[i].obelisk = o
    }

    mutating func restoreObelisk(spot id: Int) throws {
        guard var o = spots[id], o.state == .broken else { throw GameError.notAvailable }
        guard avra >= Act1.obeliskRestore else { throw GameError.notEnoughAvra }
        avra -= Act1.obeliskRestore
        o.state = .building
        spots[id] = o
    }

    mutating func upgradeObelisk(town i: Int) throws {
        guard var o = towns[i].obelisk, o.state == .lit, !o.upgraded else { throw GameError.notAvailable }
        guard avra >= Act1.obeliskUpgrade else { throw GameError.notEnoughAvra }
        avra -= Act1.obeliskUpgrade
        o.upgraded = true
        towns[i].obelisk = o
    }

    // MARK: Инфильтрация

    mutating func sendAgents(_ i: Int, _ n: Int) throws {
        guard towns[i].owner == .lord, n > 0 else { throw GameError.notAvailable }
        guard towns[i].agents + n <= Act1.maxAgents else { throw GameError.notAvailable }
        guard army >= n else { throw GameError.notEnoughArmy }
        army -= n
        towns[i].agents += n
    }

    // MARK: Указы

    /// Ввести указ следующей ступени; открытость ступени (грамматика) проверяет вызывающий.
    mutating func decree(_ path: DecreePath) throws {
        let tier = decrees.count
        guard tier < Act1.decreeCost.count else { throw GameError.notAvailable }
        guard avra >= Act1.decreeCost[tier] else { throw GameError.notEnoughAvra }
        avra -= Act1.decreeCost[tier]
        decrees.append(path)
    }

    // MARK: Штурм

    func assaultOdds(_ i: Int, squad: Int) -> AssaultOdds {
        let t = towns[i]
        let d = t.defense
        let eff = Double(squad + 2 * t.dolls)
        let ratio = d > 0 ? eff / d : 99
        var bonus = Act1.ratioBonus(ratio)
        let boss = !t.bossDefeated
        if boss { bonus += 2 }                 // при победе над боссом
        if has(.fear, tier: 2) { bonus += 2 }  // «Маска на воротах»
        var counts = [0, 0, 0, 0]
        for roll in 1...20 {
            var total = roll + bonus
            if roll == 1 { total = 1 }
            if roll == 20 { total = 99 }
            let k = total <= 7 ? 0 : (total <= 12 ? 1 : (total <= 17 ? 2 : 3))
            counts[k] += 1
        }
        return AssaultOdds(cost: Act1.assaultCost * Double(squad) * priceFactor(i),
                           questions: Act1.assaultQuestions(guards: Int(t.effectiveGuards)),
                           bossFight: boss, defense: d, ratio: ratio, bonus: bonus,
                           fail: Double(counts[0]) / 20, hard: Double(counts[1]) / 20,
                           sure: Double(counts[2]) / 20, rout: Double(counts[3]) / 20)
    }

    /// Начать штурм: Авра и марионетки уходят в бой.
    mutating func beginAssault(_ i: Int, squad: Int) throws {
        guard towns[i].owner == .lord, squad > 0 else { throw GameError.notAvailable }
        guard army >= squad else { throw GameError.notEnoughArmy }
        let cost = assaultOdds(i, squad: squad).cost
        guard avra >= cost else { throw GameError.notEnoughAvra }
        avra -= cost
        army -= squad
    }

    /// Итог штурма после упражнений.
    /// - bossCorrect: верных в бою с боссом (nil — боя не было)
    /// - correct, questions: основной бой
    mutating func resolveAssault(_ i: Int, squad: Int, bossCorrect: Int?, correct: Int, questions: Int) -> AssaultResult {
        var squad = squad
        var bonus = 0
        if let b = bossCorrect, let boss = towns[i].def.boss, !towns[i].bossDefeated {
            if b >= Act1.bossPass {
                avra += Act1.bossBonus
                bonus += 2
                if boss != .crimsonPriest && boss != .lord { towns[i].gone.append(boss) }
            } else {
                let lost = squad / 2
                bodies += Array(repeating: day + Act1.bodyDays, count: lost)
                army += squad - lost
                towns[i].alert += Act1.alertFailedAssault
                return AssaultResult(outcome: .bossLost, roll: 0, bonus: 0, lost: lost, killed: 0, fled: 0, dolls: 0)
            }
        }
        let errors = max(0, questions - correct)
        let dead = min(errors, squad)
        squad -= dead
        bodies += Array(repeating: day + Act1.bodyDays, count: dead)
        let t = towns[i]
        let d = t.defense
        let eff = Double(squad + 2 * t.dolls)
        bonus += Act1.ratioBonus(d > 0 ? eff / d : 99)
        if errors == 0 { bonus += 2 }
        if has(.fear, tier: 2) { bonus += 2 }
        let roll = rng.roll(20)
        var total = roll + bonus
        if roll == 1 { total = 1 }
        if roll == 20 { total = 99 }
        if total <= 7 {
            let lost = squad / 2
            bodies += Array(repeating: day + Act1.bodyDays, count: lost)
            army += squad - lost
            towns[i].alert += Act1.alertFailedAssault
            return AssaultResult(outcome: .fail, roll: roll, bonus: bonus, lost: dead + lost, killed: 0, fled: 0, dolls: 0)
        }
        let outcome: AssaultOutcome
        let kill: Double, flee: Double, loss: Double
        if total <= 12 {
            outcome = .hard; kill = 0.30; flee = 0.30; loss = 1.0
        } else if total <= 17 {
            outcome = .sure; kill = 0.20; flee = 0.15; loss = 0.5
        } else {
            outcome = .rout; kill = 0.10; flee = 0.05; loss = 0.25
        }
        let extra = min(squad, Int((d * loss).rounded()))
        bodies += Array(repeating: day + Act1.bodyDays, count: extra)
        army += squad - extra
        let free = t.free
        let killed = Int((Double(free) * kill).rounded())
        let fled = Int((Double(free) * flee).rounded())
        bodies += Array(repeating: day + Act1.bodyDays, count: killed + Int(t.effectiveGuards) + t.cultists)
        towns[i].pop -= killed + fled
        towns[i].dolls = towns[i].pop
        towns[i].guards = 0
        towns[i].cultists = 0
        if !t.gone.contains(.headman) || !t.def.keys.contains(.headman) {
            for j in Act1.neighbors(i) where towns[j].owner == .lord {
                towns[j].alert += Act1.alertFlee * Double(fled)
            }
        }
        capture(i, way: .assault)
        return AssaultResult(outcome: outcome, roll: roll, bonus: bonus, lost: dead + extra,
                             killed: killed, fled: fled, dolls: towns[i].dolls)
    }

    // MARK: Вылазка

    /// Штраф вылазки: −1 за каждых двух стражников (не больше −5) и −1 за каждые 20 настороженности.
    func sortiePenalty(_ i: Int) -> Int {
        let t = towns[i]
        return min(Act1.guardPenaltyCap, Int(t.effectiveGuards) / 2) + Int(t.alert) / 20
    }

    func sortieCost(_ i: Int) -> Double {
        return Act1.sortieCost * priceFactor(i)
    }

    /// Начать вылазку: Авра за отряд из трёх марионеток.
    mutating func beginSortie(_ i: Int, key: KeyPerson?) throws {
        if let k = key {
            guard k.abductable, towns[i].has(k), towns[i].owner == .lord else { throw GameError.notAvailable }
        }
        guard army >= Act1.squadSize else { throw GameError.notEnoughArmy }
        let cost = sortieCost(i)
        guard avra >= cost else { throw GameError.notEnoughAvra }
        avra -= cost
    }

    mutating func resolveSortie(_ i: Int, key: KeyPerson?, correct: Int) -> SortieResult {
        let bonus = correct - sortiePenalty(i)
        let roll = rng.roll(20)
        let total = roll == 1 ? 1 : (roll == 20 ? 99 : roll + bonus)
        if total <= 5 {
            army = max(0, army - Act1.squadSize)
            towns[i].alert += Act1.alertFailedSortie
            events.append(.sortieLost(town: i))
            return SortieResult(roll: roll, bonus: bonus, taken: -1, keyTaken: nil)
        }
        if let k = key {
            guard total >= Act1.keyNeed else {
                return SortieResult(roll: roll, bonus: bonus, taken: 0, keyTaken: nil)
            }
            towns[i].alert += Act1.alertKey
            towns[i].gone.append(k)
            if k == .pastor {
                towns[i].cultists /= 2
                towns[i].faith = max(0, towns[i].faith - 1)
            }
            towns[i].pop -= 1
            captives.append(Captive(until: day + Act1.captiveDays, town: i, key: k))
            return SortieResult(roll: roll, bonus: bonus, taken: 1, keyTaken: k)
        }
        var n = total <= 10 ? 0 : (total <= 15 ? 1 : (total <= 19 ? 2 : 3))
        if towns[i].owner == .mask {
            // в своём поселении уводят культистов
            n = min(n, towns[i].cultists)
            towns[i].cultists -= n
        } else {
            n = min(n, towns[i].free)
            towns[i].pop -= n
        }
        if total < 99 { towns[i].alert += Act1.alertAbduct * Double(n) }
        for _ in 0..<n { captives.append(Captive(until: day + Act1.captiveDays, town: nil, key: nil)) }
        return SortieResult(roll: roll, bonus: bonus, taken: n, keyTaken: nil)
    }

    // MARK: Оборона

    /// Итог обороны от отряда стражи (10 вопросов, нужно 7).
    @discardableResult
    mutating func resolveDefense(correct: Int) -> Bool {
        guard var p = patrol, !p.defended else { return false }
        if correct >= Act1.patrolPass {
            p.defended = true
            patrol = p
            avra += Act1.patrolBonus
            return true
        }
        return false
    }
}
