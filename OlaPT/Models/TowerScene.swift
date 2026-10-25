import Foundation

// MARK: - Зал башни на экране «Сегодня» (картинки автора, 320×200)

/// Поза мага. Каждая поза — целый кадр зала (Tools/tower/build_tower.py).
enum TowerPose: String, CaseIterable {
    case read    // сыт: читает книгу за кафедрой
    case bored   // проголодался: книга закрыта, смотрит на пустой флакон
    case drink   // после занятий: пьёт зелье
    case cast    // касание: поднимает посох, фонарь вспыхивает
    case weak    // голодает: сидит у кафедры, ссутулившись

    /// Поза по сытости, когда ничего не происходит.
    static func resting(_ mood: PetMood) -> TowerPose {
        switch mood {
        case .happy: return .read
        case .ok: return .bored
        case .angry, .skeleton: return .weak
        }
    }
}

enum TowerScene {
    /// Насколько темнеет зал от голода: свет рун почти гаснет, и атмосфера гнетущая.
    static func darkness(_ mood: PetMood) -> Double {
        switch mood {
        case .happy, .ok: return 0
        case .angry: return 0.3
        case .skeleton: return 0.5
        }
    }

    /// Кадр сцены.
    /// - pose: поза мага
    /// - tick: номер тика (каждые 0,5 с)
    /// - hungry: голодает — фонарь тлеет и не мерцает; на касание он лишь вспыхивает
    /// - flash: вспышка фонаря на касание, когда маг слишком слаб, чтобы колдовать
    static func compose(pose: TowerPose, tick: Int, hungry: Bool = false, flash: Bool = false) -> [PlacedLayer] {
        var list: [PlacedLayer] = []
        func add(_ name: String) {
            guard let l = TowerAtlas.layers[name] else { return }
            list.append(PlacedLayer(id: list.count, name: name, x: l.x, y: l.y, w: l.w, h: l.h))
        }
        // Второй кадр позы — тот же зал, но фиолетовый свет (фонарь, руны) другой яркости.
        let glow: Int
        if pose == .cast || flash {
            glow = tick % 2
        } else if hungry {
            glow = 1
        } else {
            glow = (tick / 3) % 2
        }
        add("tower_\(pose.rawValue)\(glow)")
        add("tower_candles_\(pose.rawValue)\(tick % TowerAtlas.candleFrames)")
        add("tower_dust\(tick % TowerAtlas.dustFrames)")
        return list
    }
}
