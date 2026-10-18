import SwiftUI

// MARK: - Арена боя с боссом

/// Пиксельная арена: маг слева, босс справа, полоски здоровья сверху.
struct BossArenaView: View {
    let boss: BossConfig
    let hits: Int
    let misses: Int
    let answered: Bool
    let lastCorrect: Bool
    var defeated: Bool = false

    private static let isStatic = ProcessInfo.processInfo.arguments.contains("-uitest-static")
        || UserDefaults.standard.string(forKey: "uitest-pet") != nil

    private func layers(tick: Int) -> [PlacedLayer] {
        var list: [PlacedLayer] = []
        func add(_ name: String, dx: Int = 0, dy: Int = 0) {
            guard let l = PetAtlas.layers[name] else { return }
            list.append(PlacedLayer(id: list.count, name: name, x: l.x + dx, y: l.y + dy, w: l.w, h: l.h))
        }
        add("pet_bg_arena")
        add("pet_torch0_\(tick % 4)")
        add("pet_torch1_\((tick + 1) % 4)")
        let justHit = answered && lastCorrect
        let justHurt = answered && !lastCorrect
        add(justHurt ? "pet_battle_mage_hurt" : "pet_battle_mage", dx: justHurt ? -2 : 0)
        if defeated {
            // поверженный босс: вспышка и лежит ниже
            add("pet_boss_\(boss.key)_hit", dy: 8)
        } else if justHit {
            add("pet_boss_\(boss.key)_hit", dx: 3)
        } else {
            add("pet_boss_\(boss.key)\(tick % 2)")
        }
        if justHit {
            // огненный шар летит в босса
            if let l = PetAtlas.layers["pet_bolt\(tick % 2)"] {
                list.append(PlacedLayer(id: list.count, name: l.name, x: 96, y: l.y, w: l.w, h: l.h))
            }
        }
        return list
    }

    var body: some View {
        Group {
            if BossArenaView.isStatic {
                stage(tick: 1)
            } else {
                TimelineView(.periodic(from: Date(), by: 0.25)) { context in
                    stage(tick: Int(context.date.timeIntervalSinceReferenceDate / 0.25))
                }
            }
        }
    }

    private func stage(tick: Int) -> some View {
        let bossHP = max(0, boss.hp - hits)
        let hearts = max(0, boss.hearts - misses)
        return PixelStage(layers: layers(tick: tick), fade: false)
            .overlay(alignment: .top) {
                HStack(alignment: .center) {
                    HStack(spacing: 3) {
                        ForEach(0..<boss.hearts, id: \.self) { i in
                            Image(systemName: i < hearts ? "heart.fill" : "heart")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(i < hearts ? Theme.bloodBright : Theme.textDim)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(boss.title)
                            .font(Theme.pixel(12, relativeTo: .caption))
                            .foregroundColor(Theme.goldBright)
                        PixelProgressBar(fraction: Double(bossHP) / Double(max(1, boss.hp)), fill: Theme.bloodBright)
                            .frame(width: 120)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(boss.title): осталось \(bossHP) из \(boss.hp). Сердец у мага: \(hearts)")
            .accessibilityIdentifier("boss-arena")
    }
}
