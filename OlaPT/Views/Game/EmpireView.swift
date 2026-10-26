import SwiftUI

// MARK: - Вкладка «Империя»: карта Акта 1, войско, указы

/// Места на карте 320×480. Карта автора — Tools/game/art/map_act1_base.png: поселения, дороги
/// и большие города юга нарисованы на ней; здесь — где они стоят, куда нажимать и где обелиски.
enum MapLayout {
    static let width: CGFloat = 320
    static let height: CGFloat = 480

    /// Центры поселений на карте
    static let towns: [CGPoint] = [
        CGPoint(x: 96, y: 62), CGPoint(x: 46, y: 242), CGPoint(x: 181, y: 235),
        CGPoint(x: 256, y: 132), CGPoint(x: 244, y: 350),
    ]
    /// Сколько места поселение занимает на карте: сюда нажимают, под ним — подпись
    static let area: [CGSize] = [
        CGSize(width: 80, height: 88), CGSize(width: 96, height: 96), CGSize(width: 78, height: 70),
        CGSize(width: 92, height: 96), CGSize(width: 104, height: 108),
    ]
    /// Картинки поселений для шапки карточки (втрое подробнее, Tools/game/build_game_assets.py)
    static let sprites = ["settle_0_calada", "settle_1_redes", "settle_2_trigo", "settle_3_souto", "settle_4_monte"]
    static let spriteSize: [CGSize] = [
        CGSize(width: 96, height: 112), CGSize(width: 96, height: 96), CGSize(width: 96, height: 96),
        CGSize(width: 96, height: 96), CGSize(width: 112, height: 112),
    ]
    /// Большие города юга в тумане
    static let south = CGPoint(x: 105, y: 422)
    /// Где у поселения стоит его обелиск и флажок владельца (точка на земле; картинки — MapMarks)
    static let townObelisk: [CGPoint] = [
        CGPoint(x: 142, y: 94), CGPoint(x: 96, y: 228), CGPoint(x: 146, y: 262),
        CGPoint(x: 212, y: 156), CGPoint(x: 188, y: 344),
    ]
    static let townBanner: [CGPoint] = [
        CGPoint(x: 118, y: 32), CGPoint(x: 66, y: 212), CGPoint(x: 212, y: 212),
        CGPoint(x: 284, y: 108), CGPoint(x: 278, y: 316),
    ]
    /// Огонь над крышами поселения, где стража подняла тревогу (основание пламени)
    static let townFire: [CGPoint] = [
        CGPoint(x: 96, y: 58), CGPoint(x: 52, y: 232), CGPoint(x: 186, y: 228),
        CGPoint(x: 258, y: 122), CGPoint(x: 240, y: 334),
    ]
    /// Войско Маски ждёт у башни
    static let legion = CGPoint(x: 128, y: 140)

    /// Места для обелисков: «дорога» — на нарисованной дороге, «поле» и «лес» — рядом с ней.
    static let spots: [CGPoint] = [
        CGPoint(x: 93, y: 145),  CGPoint(x: 110, y: 185),   // башня — сети
        CGPoint(x: 115, y: 244), CGPoint(x: 110, y: 278),   // сети — долина
        CGPoint(x: 190, y: 186), CGPoint(x: 222, y: 196),   // долина — роща
        CGPoint(x: 202, y: 293), CGPoint(x: 218, y: 280),   // долина — крепость
        CGPoint(x: 276, y: 196), CGPoint(x: 252, y: 265),   // роща — крепость
    ]

    static func spot(_ id: Int) -> CGPoint {
        return spots[id]
    }
}

struct TownRef: Identifiable { let id: Int }
struct SpotRef: Identifiable { let id: Int }

struct EmpireView: View {
    @EnvironmentObject var model: AppModel
    @State private var town: TownRef?
    @State private var spot: SpotRef?
    @State private var stage: BattleStage?
    @State private var score: BattleScore?
    /// Верных в бою с боссом (если он был) — нужно для итога штурма
    @State private var bossCorrect: Int?
    @State private var report: BattleReport?
    @State private var showDecrees = false

    private var game: GameState { return model.user.game }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                resourceBar
                if let p = game.patrol, !p.defended {
                    patrolBanner(p)
                }
                if game.finished {
                    Text(L("Акт 1 пройден: Dom Álvaro — ваша кукла."))
                        .font(Theme.pixel(17, relativeTo: .headline))
                        .foregroundColor(Theme.goldBright)
                        .frame(maxWidth: .infinity)
                        .pixelPanel()
                }
                map
                armyCard
                decreesCard
                rulesHint
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(StoneBackground().ignoresSafeArea())
        .navigationTitle(L("Империя"))
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if let e = game.events.first {
                ZStack {
                    Color.black.opacity(0.55).ignoresSafeArea()
                    EventCardView(event: e) {
                        withAnimation { _ = model.user.game.events.removeFirst() }
                    }
                }
                .transition(.opacity)
            }
        }
        .onAppear { model.gameTick() }
        .sheet(item: $town) { ref in
            TownSheet(townID: ref.id, onBattle: { st in
                town = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { startStage(st) }
            })
            .environmentObject(model)
        }
        .sheet(item: $spot) { ref in
            SpotSheet(spotID: ref.id)
                .environmentObject(model)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showDecrees) {
            DecreesSheet().environmentObject(model)
        }
        .fullScreenCover(item: $stage, onDismiss: stageEnded) { st in
            StudySessionView(level: nil, title: stageTitle(st), collectionID: nil,
                             battle: BattleSpec(arena: arena(for: st), onFinish: { score = $0 }),
                             generator: { model.battleQuestions(count: st.questions) })
                .environmentObject(model)
        }
        .sheet(item: $report) { r in
            BattleReportView(report: r)
        }
    }

    // MARK: Ресурсы

    private var resourceBar: some View {
        HStack(spacing: 14) {
            resource(image: "icon_aura", value: GameTexts.avra(game.avra), title: L("Авра"))
            resource(image: "icon_puppets", value: "\(game.army)", title: L("Марионетки"))
            resource(image: "icon_st_charge", value: GameTexts.percent(game.towerCharge / 100), title: L("Башня"))
        }
        .frame(maxWidth: .infinity)
        .pixelPanel(padding: 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("empire-resources")
    }

    /// Ресурс со значком автора (картинка) вместо системного.
    private func resource(image: String, value: String, title: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(image)
                    .interpolation(.high)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                Text(value)
                    .font(Theme.pixel(20, relativeTo: .title3))
                    .foregroundColor(Theme.text)
            }
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textDim)
        }
        .frame(maxWidth: .infinity)
    }

    private func patrolBanner(_ p: Patrol) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Отряд стражи идёт на «%@»", GameTexts.townName(p.target)))
                .font(Theme.pixel(17, relativeTo: .headline))
                .foregroundColor(Theme.red)
            Text(L("Подойдёт этой ночью. Оборона — %d слов, которые вы помните хуже всего; нужно %d верных. Отбили — +20 Авры.",
                   Act1.patrolQuestions, Act1.patrolPass))
                .font(.subheadline)
                .foregroundColor(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Button(L("Отбить")) {
                startStage(BattleStage(kind: .defense, town: p.target, questions: Act1.patrolQuestions))
            }
            .buttonStyle(GothicButtonStyle(.primary))
            .disabled(!model.canFight)
            .accessibilityIdentifier("defend-patrol")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(border: Theme.red)
    }

    // MARK: Карта

    private var map: some View {
        GeometryReader { geo in
            let s = geo.size.width / MapLayout.width
            ZStack(alignment: .topLeading) {
                Image("map_act1")
                    .interpolation(.high)
                    .resizable()
                    .frame(width: MapLayout.width * s, height: MapLayout.height * s)
                // зоны обелисков: подсветка поселений, до которых дотягиваются горящие обелиски
                ForEach(0..<Act1.towns.count, id: \.self) { i in
                    if game.coverCharge(i) != nil {
                        // только тонкий размытый ободок, чтобы не закрывать карту
                        Circle()
                            .stroke(Color(red: 0.69, green: 0.47, blue: 1).opacity(0.6), lineWidth: 2 * s)
                            .blur(radius: 1.3 * s)
                            .frame(width: 104 * s, height: 104 * s)
                            .allowsHitTesting(false)
                            .position(x: MapLayout.towns[i].x * s, y: MapLayout.towns[i].y * s)
                    }
                }
                // места для обелисков — под поселениями, чтобы не закрывать названия
                ForEach(Act1.spots.map { $0.id }, id: \.self) { id in
                    spotMarker(id, scale: s)
                }
                // обелиски и флажки поселений
                ForEach(0..<Act1.towns.count, id: \.self) { i in
                    if let o = game.towns[i].obelisk {
                        obeliskMark(o, scale: s)
                            .position(x: MapLayout.townObelisk[i].x * s, y: MapLayout.townObelisk[i].y * s)
                        Button { town = TownRef(id: i) } label: {
                            obeliskTapArea(scale: s)
                        }
                        .buttonStyle(.plain)
                        .position(x: MapLayout.townObelisk[i].x * s, y: (MapLayout.townObelisk[i].y - 14) * s)
                        .accessibilityIdentifier("town-obelisk-\(i)")
                    }
                    markImage(game.towns[i].owner == .mask ? "banner_mask" : "banner_lord", scale: s)
                        .allowsHitTesting(false)
                        .position(x: MapLayout.townBanner[i].x * s, y: MapLayout.townBanner[i].y * s)
                }
                // тревога у феодала: над крышами огонь
                ForEach(0..<Act1.towns.count, id: \.self) { i in
                    if game.towns[i].owner == .lord && game.towns[i].alert >= Act1.reinforceAt {
                        fireMark(scale: s)
                            .position(x: MapLayout.townFire[i].x * s, y: MapLayout.townFire[i].y * s)
                    }
                }
                if game.army > 0 {
                    markImage("map_legion", scale: s)
                        .allowsHitTesting(false)
                        .position(x: MapLayout.legion.x * s, y: MapLayout.legion.y * s)
                }
                ForEach(0..<Act1.towns.count, id: \.self) { i in
                    townMarker(i, scale: s)
                }
                if let p = game.patrol, !p.defended {
                    // стража нарисована идущей влево — вправо отражаем
                    markImage("map_patrol", scale: s)
                        .scaleEffect(x: MapLayout.towns[p.target].x > MapLayout.towns[p.from].x ? -1 : 1, y: 1)
                        .allowsHitTesting(false)
                        .position(x: (MapLayout.towns[p.from].x + MapLayout.towns[p.target].x) / 2 * s,
                                  y: (MapLayout.towns[p.from].y + MapLayout.towns[p.target].y) / 2 * s)
                        .accessibilityIdentifier("map-patrol")
                }
                Text(L("Большие города юга"))
                    .font(Theme.pixel(10, relativeTo: .caption2))
                    .foregroundColor(Theme.textDim)
                    .padding(.horizontal, 4)
                    .background(Theme.panelDeep.opacity(0.75))
                    .fixedSize()
                    .position(x: MapLayout.south.x * s, y: (MapLayout.south.y + 44) * s)
            }
        }
        .aspectRatio(MapLayout.width / MapLayout.height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.goldDark, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("empire-map")
    }

    @ViewBuilder
    private func townMarker(_ i: Int, scale s: CGFloat) -> some View {
        let t = game.towns[i]
        let size = MapLayout.area[i]
        let p = MapLayout.towns[i]
        Button {
            town = TownRef(id: i)
        } label: {
            ZStack(alignment: .top) {
                // само поселение нарисовано на карте — здесь только место для нажатия
                Color.clear
                    .frame(width: size.width * s, height: size.height * s)
                    .contentShape(Rectangle())
                VStack(spacing: 1) {
                    Text(GameTexts.townName(i))
                        .font(Theme.pixel(10, relativeTo: .caption2))
                        .foregroundColor(t.owner == .mask ? Color(red: 0.85, green: 0.7, blue: 1) : Theme.text)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 4)
                        .background(Theme.panelDeep.opacity(0.75))
                    if i != 0 {
                        dollBar(t)
                            .frame(width: 44 * s, height: 4 * s)
                    }
                }
                .offset(y: size.height * s - 6 * s)
            }
        }
        .buttonStyle(.plain)
        .position(x: p.x * s, y: p.y * s)
        .accessibilityLabel(GameTexts.townName(i))
        .accessibilityIdentifier("town-\(i)")
    }

    private func dollBar(_ t: TownState) -> some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.panelDeep)
                Rectangle()
                    .fill(Color(red: 0.6, green: 0.35, blue: 0.95))
                    .frame(width: g.size.width * CGFloat(t.pop > 0 ? Double(t.dolls) / Double(t.pop) : 0))
            }
        }
    }

    /// Метка на карте: картинка из MapMarks, точка «на земле» — в центре кадра.
    private func markImage(_ name: String, scale s: CGFloat) -> some View {
        let size = MapMarks.size(name)
        return Image(name)
            .interpolation(.high)
            .resizable()
            .frame(width: size.width * s, height: size.height * s)
    }

    /// Обелиск: горящий светится тем ярче, чем больше заряд; строящийся — бледный; сломанный — обломки.
    @ViewBuilder
    private func obeliskMark(_ o: Obelisk, scale s: CGFloat) -> some View {
        switch o.state {
        case .lit:
            ZStack {
                markImage("obelisk_dark", scale: s)
                markImage("obelisk_lit", scale: s)
                    .opacity(0.35 + 0.65 * min(1, max(0, o.charge / 100)))
            }
            .allowsHitTesting(false)
        case .building:
            markImage("obelisk_dark", scale: s)
                .opacity(0.55)
                .allowsHitTesting(false)
        case .broken:
            markImage("obelisk_broken", scale: s)
                .allowsHitTesting(false)
        }
    }

    /// Огонь над крышами: три кадра по кругу.
    private func fireMark(scale s: CGFloat) -> some View {
        let size = MapMarks.size("fx_fire")
        return TimelineView(.periodic(from: .now, by: 0.16)) { context in
            let frame = Int(context.date.timeIntervalSinceReferenceDate / 0.16) % 3
            Image("fx_fire\(frame)")
                .interpolation(.high)
                .resizable()
                .frame(width: size.width * s, height: size.height * s)
        }
        .allowsHitTesting(false)
    }

    /// Куда нажимать на обелиск: сам обелиск над точкой на земле, а не весь прозрачный кадр.
    private func obeliskTapArea(scale s: CGFloat) -> some View {
        return Color.clear
            .frame(width: 16 * s, height: 32 * s)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private func spotMarker(_ id: Int, scale s: CGFloat) -> some View {
        let p = MapLayout.spot(id)
        if let o = game.spots[id] {
            obeliskMark(o, scale: s)
                .position(x: p.x * s, y: p.y * s)
            Button { spot = SpotRef(id: id) } label: {
                obeliskTapArea(scale: s)
            }
            .buttonStyle(.plain)
            .position(x: p.x * s, y: (p.y - 14) * s)
            .accessibilityIdentifier("spot-\(id)")
        } else if game.spotAvailable(id) {
            Button { spot = SpotRef(id: id) } label: {
                Diamond()
                    .stroke(Color(red: 0.7, green: 0.5, blue: 1).opacity(0.8), lineWidth: 1)
                    .frame(width: 9 * s, height: 9 * s)
                    .padding(6 * s)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: p.x * s, y: p.y * s)
            .accessibilityIdentifier("spot-\(id)")
        }
    }

    // MARK: Войско

    private var armyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            GothicHeader(L("Войско"))
            Text(L("Марионеток в войске: %d. Взять под контроль — 10 Авры за каждую.", game.army))
                .font(.subheadline)
                .foregroundColor(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            bindRow(title: L("Кладбище Молчаливой деревни"),
                    detail: L("сегодня можно поднять: %d", game.cemetery),
                    enabled: game.cemetery > 0, id: "bind-cemetery") {
                try? model.user.game.bind(.cemetery)
            }
            if !game.bodies.isEmpty {
                bindRow(title: L("Павшие на поле"),
                        detail: L("%d — лежат до трёх дней", game.bodies.count),
                        enabled: true, id: "bind-body") {
                    try? model.user.game.bind(.body)
                }
            }
            ForEach(Array(game.captives.enumerated()), id: \.offset) { pair in
                let c = pair.element
                let left = max(0, c.until - game.day)
                let who: String = {
                    if let k = c.key, let t = c.town {
                        return L("%@ из «%@»", GameTexts.keyName(k), GameTexts.townName(t))
                    }
                    return L("Пленник в подвале")
                }()
                let home = (c.key == .pastor || c.key == .headman) && c.town.map { game.towns[$0].owner == .lord } == true
                bindRow(title: who,
                        detail: home ? L("вернётся домой куклой и будет обращать по двое в день · ещё %d дн.", left)
                                     : L("в подвале ещё %d дн.", left),
                        enabled: true, id: "bind-captive-\(pair.offset)") {
                    try? model.user.game.bind(.captive(index: pair.offset))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel()
    }

    private func bindRow(title: String, detail: String, enabled: Bool, id: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(Theme.text)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(Theme.textDim)
            }
            Spacer()
            Button(L("Взять · 10")) {
                action()
                SoundFX.shared.play(.tap)
            }
            .buttonStyle(GothicButtonStyle(.secondary))
            .disabled(!enabled || game.avra < Act1.bindCost)
            .accessibilityIdentifier(id)
        }
    }

    // MARK: Указы

    private var decreesCard: some View {
        Button {
            showDecrees = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    GothicHeader(L("Указы"))
                    Text(game.decrees.isEmpty ? L("Пока ни одного. Ступени открывает грамматика.")
                                              : game.decrees.enumerated().map { GameTexts.decree($0.offset, $0.element).title }.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundColor(Theme.text)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(Theme.textDim)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel()
        .accessibilityIdentifier("open-decrees")
    }

    private var rulesHint: some View {
        Text(L("Авру дают любые упражнения. Пока вы занимаетесь, обелиски заряжены и куклы спят; забросите — куклы проснутся, и поселения уйдут к феодалу."))
            .font(.caption)
            .foregroundColor(Theme.textDim)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Бои

    private func arena(for st: BattleStage) -> BossConfig? {
        guard st.kind == .boss, let boss = Act1.towns[st.town].boss else { return nil }
        // Пока нет портретов боссов поселений, на арене — противники из старого боя с боссом недели
        let sprite: String
        switch boss {
        case .pastor: sprite = "lich"
        case .captain: sprite = "goblin"
        case .crimsonPriest: sprite = "spider"
        default: sprite = "dragon"
        }
        return BossConfig(key: sprite, title: GameTexts.bossTitle(boss), hp: Act1.bossPass,
                          hearts: Act1.bossQuestions - Act1.bossPass + 1)
    }

    private func stageTitle(_ st: BattleStage) -> String {
        switch st.kind {
        case .boss: return L("Бой с боссом")
        case .assault: return L("Штурм")
        case .sortie: return L("Вылазка")
        case .defense: return L("Оборона")
        }
    }

    private func startStage(_ st: BattleStage) {
        score = nil
        if st.kind != .assault { bossCorrect = nil }
        var st = st
        st.questions = min(st.questions, max(1, model.battleWords(limit: st.questions).count))
        lastStage = st
        stage = st
    }

    /// Тренировка закрылась: считаем итог этапа и, если надо, начинаем следующий.
    private func stageEnded() {
        guard let st = lastStage else { return }
        let sc = score ?? BattleScore(correct: 0, total: 0, hits: 0, misses: 0, won: false)
        switch st.kind {
        case .boss:
            if sc.won {
                bossCorrect = Act1.bossPass
                let q = Act1.assaultQuestions(guards: Int(game.towns[st.town].effectiveGuards))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    startStage(BattleStage(kind: .assault, town: st.town, squad: st.squad, questions: q))
                }
            } else {
                let r = model.user.game.resolveAssault(st.town, squad: st.squad, bossCorrect: sc.hits,
                                                       correct: 0, questions: 0)
                report = assaultReport(r, town: st.town)
            }
        case .assault:
            let r = model.user.game.resolveAssault(st.town, squad: st.squad, bossCorrect: bossCorrect,
                                                   correct: sc.correct, questions: st.questions)
            bossCorrect = nil
            report = assaultReport(r, town: st.town)
        case .sortie:
            let r = model.user.game.resolveSortie(st.town, key: st.key, correct: sc.correct)
            report = sortieReport(r, town: st.town, key: st.key)
        case .defense:
            let ok = model.user.game.resolveDefense(correct: sc.correct)
            report = BattleReport(title: ok ? L("Стража отбита") : L("Не отбили"),
                                  lines: ok ? [L("+20 Авры. Отряд повернул назад.")]
                                            : [L("Верных: %d из %d, нужно %d. Можно попробовать ещё раз до ночи.", sc.correct, st.questions, Act1.patrolPass)],
                                  roll: nil, bonus: 0, good: ok)
        }
        model.saveNow()
    }

    /// Этап, который только что закончился (fullScreenCover уже обнулил stage).
    @State private var lastStage: BattleStage?

    private func assaultReport(_ r: AssaultResult, town: Int) -> BattleReport {
        var lines: [String] = []
        switch r.outcome {
        case .bossLost:
            lines.append(L("Штурм отбит. Половина отряда пала — их можно поднять марионетками три дня."))
        case .fail:
            lines.append(L("Поселение не взято. Потеряно марионеток: %d.", r.lost))
        default:
            lines.append(L("%@ — ваша. Потеряно марионеток: %d.", GameTexts.townName(town), r.lost))
            lines.append(L("Жителей погибло: %d, бежало: %d, стали куклами: %d.", r.killed, r.fled, r.dolls))
            lines.append(L("Павших можно поднять марионетками в течение трёх дней."))
        }
        let good = r.outcome != .fail && r.outcome != .bossLost
        return BattleReport(title: GameTexts.outcome(r.outcome), lines: lines,
                            roll: r.outcome == .bossLost ? nil : r.roll, bonus: r.bonus, good: good)
    }

    private func sortieReport(_ r: SortieResult, town: Int, key: KeyPerson?) -> BattleReport {
        if r.taken < 0 {
            return BattleReport(title: L("Вылазка провалена"),
                                lines: [L("Из отряда не вернулся никто. Настороженность +10.")],
                                roll: r.roll, bonus: r.bonus, good: false)
        }
        if let k = r.keyTaken {
            return BattleReport(title: L("Похищен: %@", GameTexts.keyName(k)),
                                lines: [L("Ждёт в подвале башни 7 дней: %@.", GameTexts.keyEffect(k))],
                                roll: r.roll, bonus: r.bonus, good: true)
        }
        if key != nil {
            return BattleReport(title: L("Не вышло"), lines: [L("Для ключевого человека нужен итог 15 и выше. Отряд вернулся.")],
                                roll: r.roll, bonus: r.bonus, good: false)
        }
        return BattleReport(title: r.taken > 0 ? L("Увели: %d", r.taken) : L("Вернулись ни с чем"),
                            lines: r.taken > 0 ? [L("Пленники ждут в подвале башни 7 дней — возьмите их под контроль.")] : [],
                            roll: r.roll, bonus: r.bonus, good: r.taken > 0)
    }
}
