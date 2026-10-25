import SwiftUI

// MARK: - Тексты Империи слов (на языке интерфейса)

enum GameTexts {
    static func townName(_ id: Int) -> String {
        switch id {
        case 0: return L("Молчаливая деревня")
        case 1: return L("Деревня сетей")
        case 2: return L("Пшеничная долина")
        case 3: return L("Тенистая роща")
        default: return L("Сумрачный холм")
        }
    }

    static func townKind(_ id: Int) -> String {
        switch id {
        case 0: return L("Деревня у башни. Уцелевшие — уже ваши куклы.")
        case 1: return L("Рыбацкая деревня на побережье.")
        case 2: return L("Фермерский городок: огороды и поля.")
        case 3: return L("Городок у леса, гнездо Церкви Эссеш.")
        default: return L("Райцентр-крепость, поместье сеньора.")
        }
    }

    static func keyName(_ k: KeyPerson) -> String {
        switch k {
        case .pastor: return L("поп")
        case .headman: return L("староста")
        case .captain: return L("капитан")
        case .elder: return L("старейшина рыбаков")
        case .forester: return L("лесничий")
        case .crimsonPriest: return L("Багровый Поп")
        case .lord: return L("Dom Álvaro")
        }
    }

    /// Что даст похищение ключевого человека.
    static func keyEffect(_ k: KeyPerson) -> String {
        switch k {
        case .pastor: return L("культисты слабеют вдвое, вера падает на ступень")
        case .headman: return L("весть о нападении не уйдёт к соседям")
        case .captain: return L("стража вдвое слабее")
        default: return L("ещё один пленник в подвале")
        }
    }

    static func bossTitle(_ k: KeyPerson) -> String {
        switch k {
        case .pastor: return L("Поп деревни")
        case .captain: return L("Капитан стражи")
        case .crimsonPriest: return L("Багровый Поп")
        case .lord: return L("Dom Álvaro")
        default: return keyName(k)
        }
    }

    static func faith(_ f: Int) -> String {
        switch f {
        case 0: return L("нет")
        case 1: return L("слабая")
        case 2: return L("средняя")
        default: return L("сильная")
        }
    }

    static func walls(_ w: WallsKind) -> String {
        switch w {
        case .none: return L("нет")
        case .fence: return L("плетни")
        case .palisade: return L("частокол")
        case .walls: return L("стены")
        }
    }

    static func terrain(_ t: SpotTerrain) -> String {
        switch t {
        case .road: return L("у дороги")
        case .field: return L("в поле")
        case .forest: return L("в лесу")
        }
    }

    static func outcome(_ o: AssaultOutcome) -> String {
        switch o {
        case .bossLost: return L("Бой с боссом проигран")
        case .fail: return L("Штурм отбит")
        case .hard: return L("Тяжёлая победа")
        case .sure: return L("Уверенная победа")
        case .rout: return L("Разгром")
        }
    }

    /// Карточка события: заголовок и одна-две строки, как в Frostpunk.
    static func event(_ e: GameEvent) -> (title: String, text: String) {
        switch e {
        case .captured(let t, let how):
            return (L("%@ — ваша", townName(t)),
                    how == .infiltration ? L("Куклы внутри взяли верх. Тихо: соседи ничего не узнали.")
                                         : L("Кто остался — уже куклы. Поставьте обелиск, иначе через неделю они начнут просыпаться."))
        case .lost(let t):
            return (L("%@ больше не ваша", townName(t)),
                    L("Люди проснулись и ничего не помнят. Феодал снова поставил там стражу."))
        case .obeliskBroken(let t, let spot):
            if let t = t {
                return (L("Обелиск разбит"), L("%@: куклы в его зоне начнут просыпаться. Восстановить — 100 Авры.", townName(t)))
            }
            let where_ = spot.map { terrain(Act1.spots[$0].terrain) } ?? ""
            return (L("Обелиск разбит"), L("Обелиск %@ нашли и разбили.", where_))
        case .agentExposed(let t, let n):
            return (L("Агенты раскрыты"), L("%@: потеряно агентов — %d. Настороженность растёт.", townName(t), n))
        case .patrolComing(let from, let target):
            return (L("Отряд стражи вышел"), L("Из поселения «%@» идёт отряд на «%@». Подойдёт этой ночью — отбейте его.", townName(from), townName(target)))
        case .patrolBrokeThrough(let t, let freed):
            return (L("Стража прорвалась"), L("%@: освобождено кукол — %d, обелиск разбит.", townName(t), freed))
        case .crimsonFled:
            return (L("Багровый Поп бежал на юг"), L("Церковь потеряла гнездо: вера по всей области слабеет на ступень."))
        case .sortieLost(let t):
            return (L("Из вылазки никто не вернулся"), L("%@: отряд из трёх марионеток пропал.", townName(t)))
        case .armyWoke(let n):
            return (L("Марионетки просыпаются"), L("Башня слабеет: ушло марионеток — %d. Занимайтесь, чтобы заряд вернулся.", n))
        case .actComplete:
            return (L("Сеньор стал куклой"), L("Dom Álvaro в вашей власти. Акт 1 пройден — его руками Маска войдёт во второй акт."))
        }
    }

    static func decreeTier(_ tier: Int) -> String {
        switch tier {
        case 0: return L("I. Presente: 10 глаголов в памяти")
        case 1: return L("II. Неправильные в Presente: 6 из 8")
        default: return L("III. Pretérito Perfeito: 10 глаголов")
        }
    }

    static func decree(_ tier: Int, _ path: DecreePath) -> (title: String, text: String) {
        switch (tier, path) {
        case (0, .fear): return (L("Комендантский час"), L("Поселение теряется, только когда кукол меньше 40%, а не 50%."))
        case (0, .word): return (L("Глашатаи"), L("+10% Авры за новые слова."))
        case (1, .fear): return (L("Железная рука"), L("Марионетки гарнизона против стражи и культистов считаются за двоих."))
        case (1, .word): return (L("Лжепророки"), L("В поселении под инфильтрацией вера слабеет на ступень."))
        case (_, .fear): return (L("Маска на воротах"), L("+2 к броску кубика при каждом штурме."))
        case (_, .word): return (L("Шёпот"), L("Раскрытый агент не поднимает настороженность."))
        }
    }

    static func percent(_ x: Double) -> String {
        return "\(Int((x * 100).rounded()))%"
    }

    static func avra(_ x: Double) -> String {
        return "\(Int(x.rounded(.down)))"
    }
}
