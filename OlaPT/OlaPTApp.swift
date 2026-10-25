import SwiftUI

@main
struct OlaPTApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    /// Выбранная вкладка живёт выше RootView, чтобы пережить смену языка
    @State private var tab = 0

    init() {
        Theme.registerFonts()
        Theme.configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            // При смене языка интерфейса весь экран собирается заново — все надписи берутся на новом языке
            RootView(tab: $tab)
                .id(model.settings.uiLanguage)
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .tint(Theme.gold)
                .onChange(of: scenePhase) { phase in
                    if phase != .active {
                        model.saveNow()
                    }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @Binding var tab: Int

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                TodayView(openEmpire: { tab = 4 })
            }
            .tabItem {
                Label { Text(L("Сегодня")) } icon: { Image("tab-candle") }
            }
            .badge(model.dailyPlan().total)
            .tag(0)

            NavigationStack {
                SearchView()
            }
            .tabItem {
                Label { Text(L("Словарь")) } icon: { Image("tab-book") }
            }
            .tag(1)

            NavigationStack {
                CollectionsView()
            }
            .tabItem {
                Label { Text(L("Коллекции")) } icon: { Image("tab-chest") }
            }
            .tag(2)

            NavigationStack {
                VerbsView()
            }
            .tabItem {
                Label { Text(L("Глаголы")) } icon: { Image("tab-quill") }
            }
            .tag(3)

            NavigationStack {
                EmpireView()
            }
            .tabItem {
                Label { Text(L("Империя")) } icon: { Image("tab-mask") }
            }
            .badge(model.user.game.events.count)
            .tag(4)
        }
    }
}
