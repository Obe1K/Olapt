import SwiftUI

// MARK: - Карточка поселения: условия и действия

struct TownSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let townID: Int
    let onBattle: (BattleStage) -> Void

    @State private var squad: Int = 10
    @State private var agents: Int = 1
    @State private var problem: String?

    private var game: GameState { return model.user.game }
    private var t: TownState { return game.towns[townID] }

    var body: some View {
        NavigationStack {
            GothicList {
                header
                stats
                if townID == 0 {
                    towerSection
                } else if t.owner == .mask {
                    ownedSections
                } else {
                    assaultSection
                    sortieSection
                    agentsSection
                }
                if let p = problem {
                    Section {
                        Text(p).foregroundColor(Theme.red)
                    }
                }
            }
            .navigationTitle(GameTexts.townName(townID))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Закрыть")) { dismiss() }
                }
            }
            .onAppear {
                let need = max(3, Int(ceil(2 * t.defense - 2 * Double(t.dolls))))
                squad = max(1, min(game.army, need))
            }
        }
    }

    // MARK: Шапка и условия

    private var header: some View {
        Section {
            HStack(spacing: 14) {
                Image(MapLayout.sprites[townID])
                    .interpolation(.high)
                    .resizable()
                    .frame(width: MapLayout.spriteSize[townID].width * 1.2, height: MapLayout.spriteSize[townID].height * 1.2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(Act1.towns[townID].pt)
                        .font(.subheadline.italic())
                        .foregroundColor(Theme.textDim)
                    Text(GameTexts.townKind(townID))
                        .font(.subheadline)
                        .foregroundColor(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(t.owner == .mask ? L("Под властью Маски") : L("Под властью сеньора"))
                        .font(Theme.pixel(15, relativeTo: .subheadline))
                        .foregroundColor(t.owner == .mask ? Color(red: 0.75, green: 0.55, blue: 1) : Theme.gold)
                }
            }
            .listRowBackground(Color.clear)
        }
    }

    private var stats: some View {
        Section(header: GothicHeader(L("Условия"))) {
            row(L("Жителей"), "\(t.pop)")
            if townID != 0 {
                row(L("Куклы"), icon: "icon_st_control", "\(t.dolls) · \(GameTexts.percent(t.pop > 0 ? Double(t.dolls) / Double(t.pop) : 0))")
            }
            if t.owner == .lord && townID != 0 {
                row(L("Стража"), icon: "icon_st_guard", String(format: "%.0f", t.effectiveGuards))
                row(L("Укрепления"), GameTexts.walls(t.def.wallsKind))
                row(L("Культисты"), "\(t.cultists)")
                row(L("Вера"), GameTexts.faith(t.faith))
                row(L("Сила обороны"), String(format: "%.0f", t.defense))
                VStack(alignment: .leading, spacing: 6) {
                    row(L("Настороженность"), "\(Int(t.alert))")
                    PixelProgressBar(fraction: min(1, t.alert / 100), fill: Theme.red)
                }
            } else if townID != 0 {
                row(L("Культисты"), "\(t.cultists)")
                row(L("Гарнизон"), "\(t.garrison)")
                if t.grace > 0 {
                    row(L("Держится само"), L("ещё %d дн.", t.grace))
                }
            }
            if !t.def.keys.isEmpty && townID != 0 {
                row(L("Ключевые люди"), t.def.keys.map { k in
                    t.gone.contains(k) ? "✕ " + GameTexts.keyName(k) : GameTexts.keyName(k)
                }.joined(separator: ", "))
            }
            if townID != 0 {
                Text(game.coverCharge(townID) != nil
                     ? L("В зоне обелиска: штурм, агенты и вылазки на четверть дешевле.")
                     : L("Вне зон обелисков: штурм, агенты и вылазки в полтора раза дороже."))
                    .font(.caption)
                    .foregroundColor(Theme.textDim)
            }
        }
    }

    private func row(_ title: String, icon: String? = nil, _ value: String) -> some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(icon)
                    .interpolation(.high)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
            }
            Text(title).foregroundColor(Theme.textDim)
            Spacer()
            Text(value)
                .foregroundColor(Theme.text)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    // MARK: Башня

    private var towerSection: some View {
        Section(header: GothicHeader(L("Башня"))) {
            Text(L("Башня — первый обелиск: её зона накрывает Молчаливую деревню и Деревню сетей. Заряд держит и марионеток войска: ниже половины они начинают просыпаться."))
                .font(.subheadline)
                .foregroundColor(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            row(L("Заряд башни"), GameTexts.percent(game.towerCharge / 100))
            PixelProgressBar(fraction: game.towerCharge / 100, fill: Color(red: 0.6, green: 0.35, blue: 0.95))
            Text(L("День, когда пройден план «Сегодня», — +20%. День совсем без занятий — −25%."))
                .font(.caption)
                .foregroundColor(Theme.textDim)
        }
    }

    // MARK: Своё поселение

    @ViewBuilder
    private var ownedSections: some View {
        Section(header: GothicHeader(L("Обелиск"))) {
            obeliskControls
        }
        Section(header: GothicHeader(L("Гарнизон"), icon: "icon_puppets")) {
            Text(L("Марионетки в поселении стерегут обелиск от культистов, а против стражи каждая спасает двух кукол."))
                .font(.caption)
                .foregroundColor(Theme.textDim)
            HStack {
                Button(L("Забрать")) { act { try model.user.game.garrison(townID, -1) } }
                    .buttonStyle(GothicButtonStyle(.secondary))
                    .disabled(t.garrison == 0)
                Spacer()
                Text("\(t.garrison)")
                    .font(Theme.pixel(22, relativeTo: .title3))
                    .foregroundColor(Theme.text)
                Spacer()
                Button(L("Оставить")) { act { try model.user.game.garrison(townID, 1) } }
                    .buttonStyle(GothicButtonStyle(.secondary))
                    .disabled(game.army == 0)
                    .accessibilityIdentifier("garrison-add")
            }
        }
        Section(header: GothicHeader(L("Куклы в войско"), icon: "icon_puppets")) {
            let room = game.room(t)
            Text(room > 0 ? L("Можно забрать ещё %d — не больше половины исходных жителей.", room)
                          : L("Больше забирать нельзя: иначе поселение опустеет."))
                .font(.subheadline)
                .foregroundColor(Theme.text)
            Button(L("Взять куклу в войско · 10")) { act { try model.user.game.bind(.town(townID)) } }
                .buttonStyle(GothicButtonStyle(.secondary))
                .disabled(room == 0 || game.avra < Act1.bindCost)
                .accessibilityIdentifier("bind-town")
        }
        if t.cultists > 0 {
            Section(header: GothicHeader(L("Культисты"))) {
                Text(L("Оставшиеся культисты по ночам рвут нити: каждые двое освобождают куклу в день. Их можно уводить на вылазках — похищенный культист станет марионеткой."))
                    .font(.caption)
                    .foregroundColor(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
                sortieButton(key: nil, title: L("Вылазка на культистов"))
            }
        }
    }

    @ViewBuilder
    private var obeliskControls: some View {
        if let o = t.obelisk {
            switch o.state {
            case .building:
                Text(L("Поставлен — загорится этой ночью.")).foregroundColor(Theme.text)
            case .lit:
                row(L("Заряд"), GameTexts.percent(o.charge / 100))
                PixelProgressBar(fraction: o.charge / 100, fill: Color(red: 0.6, green: 0.35, blue: 0.95))
                if !o.upgraded {
                    Button(L("Усилить · 300")) { act { try model.user.game.upgradeObelisk(town: townID) } }
                        .buttonStyle(GothicButtonStyle(.secondary))
                        .disabled(game.avra < Act1.obeliskUpgrade)
                    Text(L("Усиленный дотягивается на одну дорогу дальше."))
                        .font(.caption)
                        .foregroundColor(Theme.textDim)
                } else {
                    Text(L("Усилен: дотягивается на одну дорогу дальше.")).font(.caption).foregroundColor(Theme.textDim)
                }
            case .broken:
                Text(L("Разбит: куклы в его зоне просыпаются.")).foregroundColor(Theme.red)
                Button(L("Восстановить · 100")) { act { try model.user.game.restoreObelisk(town: townID) } }
                    .buttonStyle(GothicButtonStyle(.primary))
                    .disabled(game.avra < Act1.obeliskRestore)
            }
        } else {
            Text(game.coverCharge(townID) != nil
                 ? L("Поселение в зоне другого обелиска. Свой обелиск дотянется до соседей.")
                 : L("Ни один обелиск сюда не дотягивается: после семи дней куклы начнут просыпаться."))
                .font(.subheadline)
                .foregroundColor(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Button(L("Поставить обелиск · 200")) { act { try model.user.game.buildObelisk(town: townID) } }
                .buttonStyle(GothicButtonStyle(.primary))
                .disabled(game.avra < Act1.obelisk)
                .accessibilityIdentifier("build-obelisk")
        }
    }

    // MARK: Штурм

    private var assaultSection: some View {
        let odds = game.assaultOdds(townID, squad: squad)
        return Section(header: GothicHeader(L("Штурм"), icon: "icon_act_assault")) {
            Stepper(value: $squad, in: 1...max(1, game.army)) {
                Text(L("Марионеток в бой: %d", squad)).foregroundColor(Theme.text)
            }
            .accessibilityIdentifier("squad-stepper")
            row(L("Перевес"), String(format: "×%.1f", odds.ratio))
            row(L("Цена"), L("%d Авры", Int(odds.cost.rounded())))
            if odds.bossFight, let boss = t.def.boss {
                Text(L("Сначала бой с боссом: %@. 20 вопросов, для победы нужно 13 верных. Поражение — штурм отбит.", GameTexts.bossTitle(boss)))
                    .font(.caption)
                    .foregroundColor(Theme.ember)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(L("Бой — %d вопросов на слова, которые вы учите. Каждая ошибка стоит марионетки. Потом бросок d20: +%d к броску за перевес и бой.",
                   odds.questions, max(0, odds.bonus)))
                .font(.caption)
                .foregroundColor(Theme.textDim)
                .fixedSize(horizontal: false, vertical: true)
            oddsBar(odds)
            Button(L("Начать штурм")) {
                act {
                    try model.user.game.beginAssault(townID, squad: squad)
                    let kind: BattleStage.Kind = odds.bossFight ? .boss : .assault
                    let q = odds.bossFight ? Act1.bossQuestions : odds.questions
                    onBattle(BattleStage(kind: kind, town: townID, squad: squad, questions: q))
                }
            }
            .buttonStyle(GothicButtonStyle(.primary))
            .disabled(game.avra < odds.cost || game.army < squad || !model.canFight)
            .accessibilityIdentifier("start-assault")
            if !model.canFight {
                Text(L("Для боя нужно хотя бы 4 начатых слова.")).font(.caption).foregroundColor(Theme.red)
            }
        }
    }

    private func oddsBar(_ o: AssaultOdds) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { g in
                HStack(spacing: 0) {
                    Rectangle().fill(Theme.red).frame(width: g.size.width * o.fail)
                    Rectangle().fill(Theme.ember).frame(width: g.size.width * o.hard)
                    Rectangle().fill(Theme.gold).frame(width: g.size.width * o.sure)
                    Rectangle().fill(Theme.moss).frame(width: g.size.width * o.rout)
                }
            }
            .frame(height: 10)
            Text(L("Отбит %@ · тяжёлая %@ · уверенная %@ · разгром %@",
                   GameTexts.percent(o.fail), GameTexts.percent(o.hard), GameTexts.percent(o.sure), GameTexts.percent(o.rout)))
                .font(.caption)
                .foregroundColor(Theme.textDim)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("assault-odds")
    }

    // MARK: Вылазка

    private var sortieSection: some View {
        Section(header: GothicHeader(L("Вылазка"), icon: "icon_act_abduct")) {
            Text(L("Отряд из трёх марионеток. %d вопросов, каждый верный — +1 к броску d20; стража и настороженность дают −%d. Итог 1–5 — из отряда не вернётся никто.",
                   Act1.sortieQuestions, game.sortiePenalty(townID)))
                .font(.caption)
                .foregroundColor(Theme.textDim)
                .fixedSize(horizontal: false, vertical: true)
            sortieButton(key: nil, title: L("Увести жителей"))
            ForEach(t.def.keys.filter { $0.abductable && t.has($0) }, id: \.self) { k in
                VStack(alignment: .leading, spacing: 4) {
                    sortieButton(key: k, title: L("Похитить: %@", GameTexts.keyName(k)))
                    Text(L("10 вопросов, нужен итог 15. Даст: %@.", GameTexts.keyEffect(k)))
                        .font(.caption)
                        .foregroundColor(Theme.textDim)
                }
            }
        }
    }

    private func sortieButton(key: KeyPerson?, title: String) -> some View {
        let cost = game.sortieCost(townID)
        return Button("\(title) · \(Int(cost.rounded()))") {
            act {
                try model.user.game.beginSortie(townID, key: key)
                onBattle(BattleStage(kind: .sortie, town: townID, key: key,
                                     questions: key == nil ? Act1.sortieQuestions : Act1.keyQuestions))
            }
        }
        .buttonStyle(GothicButtonStyle(.secondary))
        .disabled(game.avra < cost || game.army < Act1.squadSize || !model.canFight)
    }

    // MARK: Агенты

    private var agentsSection: some View {
        let free = Act1.maxAgents - t.agents
        let feed = Act1.agentFeed * game.priceFactor(townID)
        return Section(header: GothicHeader(L("Инфильтрация"), icon: "icon_act_infiltrate")) {
            Text(L("Агенты обращают по жителю в день, набожных — за два дня. Подпитка — %@ Авры в день за агента; без неё через три дня агентов начнут раскрывать.",
                   String(format: "%.1f", feed)))
                .font(.caption)
                .foregroundColor(Theme.textDim)
                .fixedSize(horizontal: false, vertical: true)
            row(L("Агентов"), t.keyAgents > 0 ? "\(t.agents) + \(t.keyAgents)" : "\(t.agents)")
            if free > 0 {
                Stepper(value: $agents, in: 1...max(1, min(free, game.army))) {
                    Text(L("Заслать: %d", agents)).foregroundColor(Theme.text)
                }
                Button(L("Заслать агентов")) { act { try model.user.game.sendAgents(townID, agents) } }
                    .buttonStyle(GothicButtonStyle(.secondary))
                    .disabled(game.army < agents)
                    .accessibilityIdentifier("send-agents")
            }
            if let boss = t.def.boss, !boss.abductable {
                Text(L("Здесь инфильтрация одна не возьмёт поселение: нужен штурм. Но каждая кукла внутри сражается за двоих."))
                    .font(.caption)
                    .foregroundColor(Theme.ember)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Действие

    private func act(_ f: () throws -> Void) {
        do {
            try f()
            problem = nil
            SoundFX.shared.play(.tap)
        } catch GameError.notEnoughAvra {
            problem = L("Не хватает Авры.")
        } catch GameError.notEnoughArmy {
            problem = L("Не хватает марионеток.")
        } catch {
            problem = L("Сейчас это сделать нельзя.")
        }
    }
}

// MARK: - Место для обелиска в поле или лесу

struct SpotSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let spotID: Int

    var body: some View {
        let s = Act1.spots[spotID]
        let o = model.user.game.spots[spotID]
        VStack(alignment: .leading, spacing: 14) {
            GothicHeader(L("Место для обелиска"))
            Text(L("Между «%@» и «%@», %@. Зона накрывает оба поселения.",
                   GameTexts.townName(s.between.0), GameTexts.townName(s.between.1), GameTexts.terrain(s.terrain)))
                .foregroundColor(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(L("Вне поселения обелиск находят чаще: примерно %@ в день.", GameTexts.percent(Act1.fieldBreakChance(s.terrain))))
                .font(.caption)
                .foregroundColor(Theme.textDim)
            if let o = o {
                switch o.state {
                case .building: Text(L("Поставлен — загорится этой ночью.")).foregroundColor(Theme.text)
                case .lit: Text(L("Горит, заряд %@.", GameTexts.percent(o.charge / 100))).foregroundColor(Theme.text)
                case .broken:
                    Button(L("Восстановить · 100")) {
                        try? model.user.game.restoreObelisk(spot: spotID)
                        dismiss()
                    }
                    .buttonStyle(GothicButtonStyle(.primary))
                    .disabled(model.user.game.avra < Act1.obeliskRestore)
                }
            } else {
                Button(L("Поставить обелиск · 200")) {
                    try? model.user.game.buildObelisk(spot: spotID)
                    dismiss()
                }
                .buttonStyle(GothicButtonStyle(.primary))
                .disabled(model.user.game.avra < Act1.obelisk)
            }
            Spacer()
        }
        .padding(20)
        .background(StoneBackground().ignoresSafeArea())
    }
}

// MARK: - Указы

struct DecreesSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GothicList {
                Section {
                    Text(L("Три ступени. Каждую открывает грамматика, стоит Авры и предлагает выбор из двух указов — Страх или Слово. Выбор окончательный на весь акт."))
                        .font(.subheadline)
                        .foregroundColor(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(0..<3, id: \.self) { tier in
                    tierSection(tier)
                }
            }
            .navigationTitle(L("Указы"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Закрыть")) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func tierSection(_ tier: Int) -> some View {
        let game = model.user.game
        let progress = model.decreeProgress(tier: tier)
        let open = progress.have >= progress.need
        Section(header: GothicHeader(GameTexts.decreeTier(tier))) {
            if tier < game.decrees.count {
                let d = GameTexts.decree(tier, game.decrees[tier])
                Label(d.title, systemImage: "seal.fill").foregroundColor(Theme.goldBright)
                Text(d.text).font(.caption).foregroundColor(Theme.textDim)
            } else if tier > game.decrees.count {
                Text(L("Сначала — предыдущая ступень.")).foregroundColor(Theme.textDim)
            } else {
                Text(L("Глаголов в памяти: %d из %d", progress.have, progress.need))
                    .foregroundColor(open ? Theme.moss : Theme.text)
                ForEach([DecreePath.fear, DecreePath.word], id: \.self) { path in
                    let d = GameTexts.decree(tier, path)
                    VStack(alignment: .leading, spacing: 4) {
                        Button("\(d.title) · \(Int(Act1.decreeCost[tier]))") {
                            try? model.user.game.decree(path)
                        }
                        .buttonStyle(GothicButtonStyle(path == .fear ? .primary : .secondary))
                        .disabled(!open || game.avra < Act1.decreeCost[tier])
                        Text(d.text).font(.caption).foregroundColor(Theme.textDim)
                    }
                }
            }
        }
    }
}
