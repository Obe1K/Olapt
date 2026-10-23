import Foundation

// MARK: - Этажи башни

/// Где живёт маг: этаж открывается, когда в памяти достаточно слов предыдущего уровня.
enum PetRoom: Int, CaseIterable {
    case cellar = 0   // подвал — A1
    case hall         // зал — A2
    case library      // библиотека — B1
    case summit       // вершина — B2

    var background: String {
        switch self {
        case .cellar: return "pet_bg_cellar"
        case .hall: return "pet_bg_hall"
        case .library: return "pet_bg_library"
        case .summit: return "pet_bg_summit"
        }
    }

    var title: String {
        switch self {
        case .cellar: return L("Подвал")
        case .hall: return L("Зал")
        case .library: return L("Библиотека")
        case .summit: return L("Вершина башни")
        }
    }

    /// Уровень слов, к которому относится этаж
    var level: String {
        switch self {
        case .cellar: return "A1"
        case .hall: return "A2"
        case .library: return "B1"
        case .summit: return "B2"
        }
    }

    /// Чтобы подняться на этот этаж: сколько слов какого уровня должно быть в памяти.
    var requirement: (level: String, count: Int)? {
        switch self {
        case .cellar: return nil
        case .hall: return ("A1", 100)
        case .library: return ("A2", 150)
        case .summit: return ("B1", 200)
        }
    }
}

// MARK: - Сборка кадра из слоёв

/// Слой, поставленный на сцену: картинка и её левый верхний угол в пикселях сцены 192×120.
struct PlacedLayer: Identifiable {
    let id: Int
    let name: String
    let x: Int
    let y: Int
    let w: Int
    let h: Int
}

enum PetComposer {
    /// Свечи-сытость стоят на полке: основание свечи i
    private static func candleBase(_ i: Int) -> (x: Int, y: Int) {
        return (12 + i * 12, 21)
    }

    /// Вещи, которые на вершине негде повесить (там нет стены)
    private static let wallItems: Set<String> = ["starmap", "banner"]

    /// Кадров у рун, которые маг выдувает из фонаря на посохе
    private static let runeFrames = 10

    private struct Builder {
        var list: [PlacedLayer] = []

        mutating func add(_ name: String, dx: Int = 0, dy: Int = 0) {
            guard let l = PetAtlas.layers[name] else { return }
            list.append(PlacedLayer(id: list.count, name: name, x: l.x + dx, y: l.y + dy, w: l.w, h: l.h))
        }

        /// Слой, у которого в атласе только размер, а место задаём сами
        mutating func addAt(_ name: String, x: Int, y: Int) {
            guard let l = PetAtlas.layers[name] else { return }
            list.append(PlacedLayer(id: list.count, name: name, x: x, y: y, w: l.w, h: l.h))
        }
    }

    /// Кадр сцены.
    /// - items: сколько вещей уже есть в башне (0…10)
    /// - tick: номер тика (каждые 0,5 с)
    /// - eating: кадр «пьёт зелье» или nil
    /// - reaction: кадр реакции на касание или nil
    static func compose(room: PetRoom, mood: PetMood, lit: Int, items: Int, tick: Int,
                        eating: Int?, reaction: Int?) -> [PlacedLayer] {
        var b = Builder()
        let inTower = eating != nil || mood == .happy || mood == .ok
        let shake = reaction.map { $0 < 3 ? ($0 % 2 == 0 ? 1 : -1) : 0 } ?? 0

        // фон
        if inTower {
            b.add(room.background)
        } else {
            b.add(mood == .skeleton ? "pet_bg_dungeon_chained" : "pet_bg_dungeon")
        }

        // свечи: горят по числу «сердечек» сытости
        for i in 0..<4 {
            let base = candleBase(i)
            let tall = i % 2
            if i < lit {
                b.add("pet_candle_light", dx: base.x + 1, dy: base.y - 15)
                b.add("pet_candle\(tall)_lit\((tick + i) % 4)", dx: base.x, dy: base.y)
            } else {
                b.add("pet_candle\(tall)_out\((tick + i) % 2)", dx: base.x, dy: base.y)
            }
        }

        if inTower {
            if room == .hall {
                b.add("pet_fire\(tick % 3)")
            }
            // вещи за выученные слова
            for item in PetAtlas.items.prefix(max(0, min(items, PetAtlas.items.count))) {
                if room == .summit && wallItems.contains(item.key) { continue }
                let frames = (0..<4).map { "pet_item_\(item.key)\($0)" }.filter { PetAtlas.layers[$0] != nil }
                if frames.isEmpty { continue }
                b.add(frames[(tick + item.threshold / 100) % frames.count])
            }
            b.add("pet_book")

            if let f = eating {
                if f < 6 {
                    b.add("pet_mage_drink", dy: f % 2 == 0 ? 0 : -1)
                } else {
                    b.add("pet_sparks\(tick % 3)")
                    b.add("pet_mage_wave", dy: -(f % 2))
                    b.add("pet_heart", dy: -(f - 6) * 3)
                }
                return b.list
            }

            if let r = reaction {
                // касание: машет рукой, над головой поднимается сердечко
                b.add("pet_sparks\(tick % 3)")
                b.add("pet_mage_wave", dy: -(r % 2))
                b.add("pet_heart", dy: -r * 3)
            } else if mood == .happy {
                let turning = tick % 8 == 7
                b.add("pet_sparks\(tick % 3)")
                if turning { b.add("pet_page_turn") }
                b.add(turning ? "pet_mage_read2" : "pet_mage_read")
                // из фонаря на посохе, как дым, поднимаются руны
                b.add("pet_runes\(tick % runeFrames)")
            } else {
                // проголодался: книга заброшена, мечтает о зелье
                b.add("pet_mage_tired")
                if tick % 6 < 4 {
                    b.add("pet_thought", dy: tick % 2)
                }
            }
            return b.list
        }

        // темница: капает вода
        let t = tick % 10
        if t < 8 {
            b.add("pet_drop", dy: 15 + t * 10)
        } else {
            b.add("pet_splash")
        }

        if mood == .angry {
            b.add("pet_mage_angry\(tick % 2)", dx: shake)
            if reaction != nil {
                b.add("pet_curse_shout")
            } else if tick % 6 < 4 {
                b.add("pet_curse\((tick / 6) % 6)")
            }
        } else {
            let rattle = reaction.map { $0 % 2 == 0 ? -3 : 0 } ?? 0
            b.add("pet_skeleton\(reaction != nil ? 0 : (tick / 2) % 2)", dx: shake, dy: rattle)
            // крыса пробегает по полу; при касании удирает
            let ratX = reaction.map { 120 - $0 * 30 } ?? (200 - (tick * 5) % 260)
            b.addAt("pet_rat\(tick % 2)", x: ratX, y: 104)
            if reaction != nil || tick % 12 >= 9 {
                b.add("pet_sigh")
            }
        }
        return b.list
    }
}
