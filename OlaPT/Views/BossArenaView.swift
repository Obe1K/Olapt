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
        if boss.portrait != nil {
            // босс-портрет рисуется поверх сцены (portraitLayer)
        } else if defeated {
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

    /// Портрет босса справа, лицом к магу: дышит, от удара вздрагивает и краснеет, побеждённый — гаснет и оседает.
    @ViewBuilder
    private func portraitLayer(tick: Int) -> some View {
        if let p = boss.portrait {
            GeometryReader { geo in
                let s = geo.size.width / CGFloat(PetAtlas.width)
                let justHit = answered && lastCorrect && !defeated
                let dx: CGFloat = justHit ? 3 : 0
                let dy: CGFloat = defeated ? 10 : (tick % 2 == 0 ? 0 : 1)
                Image(p)
                    .interpolation(.high)
                    .resizable()
                    .scaleEffect(x: -1, y: 1)
                    .frame(width: 92 * s, height: 92 * s)
                    .colorMultiply(justHit ? Color(red: 1, green: 0.55, blue: 0.55) : .white)
                    .saturation(defeated ? 0 : 1)
                    .brightness(defeated ? -0.35 : 0)
                    .opacity(defeated ? 0.75 : 1)
                    .offset(x: (102 + dx) * s, y: (26 + dy) * s)
            }
            .clipped()
            .allowsHitTesting(false)
        }
    }

    private func stage(tick: Int) -> some View {
        let bossHP = max(0, boss.hp - hits)
        let hearts = max(0, boss.hearts - misses)
        return PixelStage(layers: layers(tick: tick), fade: false)
            .overlay { portraitLayer(tick: tick) }
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
                        // здоровье босса: полная красная полоска, с каждым верным ответом короче
                        PixelProgressBar(fraction: Double(bossHP) / Double(max(1, boss.hp)), fill: Theme.bloodBright,
                                         doneFill: nil, height: 12)
                            .frame(width: 120)
                        Text("\(bossHP) / \(boss.hp)")
                            .font(Theme.pixel(11, relativeTo: .caption2))
                            .foregroundColor(Theme.textDim)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("%@: осталось %d из %d. Сердец у мага: %d", boss.title, bossHP, boss.hp, hearts))
            .accessibilityIdentifier("boss-arena")
    }
}
