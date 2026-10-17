import SwiftUI

@main
struct OlaPTApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Theme.registerFonts()
        Theme.configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
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

    var body: some View {
        TabView {
            NavigationStack {
                TodayView()
            }
            .tabItem {
                Label { Text("Сегодня") } icon: { Image("tab-candle") }
            }
            .badge(model.dailyPlan().total)

            NavigationStack {
                SearchView()
            }
            .tabItem {
                Label { Text("Словарь") } icon: { Image("tab-book") }
            }

            NavigationStack {
                CollectionsView()
            }
            .tabItem {
                Label { Text("Коллекции") } icon: { Image("tab-chest") }
            }

            NavigationStack {
                VerbsView()
            }
            .tabItem {
                Label { Text("Глаголы") } icon: { Image("tab-quill") }
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label { Text("Настройки") } icon: { Image("tab-gear") }
            }
        }
    }
}
