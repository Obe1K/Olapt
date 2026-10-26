import SwiftUI

// MARK: - Арена боя с боссом

/// Арена: маг слева, босс справа, полоски здоровья сверху. Боссы «Империи слов» — дуэль
/// с рисунками автора (duelScene), недельный босс — старая пиксельная сцена.
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

    /// Дуэль с боссом-портретом: фон автора, маг по пояс слева (стоит, бьёт, получает удар),
    /// босс справа лицом к нему, снаряд летит в босса при верном ответе.
    private func duelScene(portrait: String, tick: Int) -> some View {
        let justHit = answered && lastCorrect && !defeated
        let justHurt = answered && !lastCorrect
        let pose = justHit ? "duel_mage_cast" : (justHurt ? "duel_mage_hurt" : "duel_mage_idle")
        let breathe: CGFloat = tick % 2 == 0 ? 0 : 1
        return GeometryReader { geo in
            let s = geo.size.width / DuelLayout.width
            let side = DuelLayout.portrait
            ZStack(alignment: .topLeading) {
                Image("duel_bg")
                    .interpolation(.high)
                    .resizable()
                    .frame(width: DuelLayout.width * s, height: DuelLayout.height * s)
                Image(pose)
                    .interpolation(.high)
                    .resizable()
                    .frame(width: side * s, height: side * s)
                    .offset(x: (justHurt ? -16 : -12) * s, y: (44 + breathe) * s)
                Image(portrait)
                    .interpolation(.high)
                    .resizable()
                    .scaleEffect(x: -1, y: 1)
                    .frame(width: side * s, height: side * s)
                    .colorMultiply(justHit ? Color(red: 1, green: 0.55, blue: 0.55) : .white)
                    .saturation(defeated ? 0 : 1)
                    .brightness(defeated ? -0.35 : 0)
                    .opacity(defeated ? 0.75 : 1)
                    .offset(x: (justHit ? 159 : 156) * s, y: (defeated ? 54 : 45 - breathe) * s)
                if justHit {
                    Image("duel_bolt")
                        .interpolation(.high)
                        .resizable()
                        .frame(width: DuelLayout.bolt.width * s, height: DuelLayout.bolt.height * s)
                        .offset(x: (112 + CGFloat(tick % 2) * 8) * s, y: 96 * s)
                }
            }
            .frame(width: geo.size.width, height: DuelLayout.height * s, alignment: .topLeading)
            .clipped()
        }
        .aspectRatio(DuelLayout.width / DuelLayout.height, contentMode: .fit)
    }

    @ViewBuilder
    private func scene(tick: Int) -> some View {
        if let p = boss.portrait {
            duelScene(portrait: p, tick: tick)
        } else {
            PixelStage(layers: layers(tick: tick), fade: false)
        }
    }

    private func stage(tick: Int) -> some View {
        let bossHP = max(0, boss.hp - hits)
        let hearts = max(0, boss.hearts - misses)
        return scene(tick: tick)
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
