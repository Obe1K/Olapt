import SwiftUI

@main
struct OlaPTApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .onChange(of: scenePhase) { phase in
                    if phase != .active {
                        model.saveNow()
                    }
                }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                SearchView()
            }
            .tabItem {
                Label("Словарь", systemImage: "magnifyingglass")
            }

            NavigationStack {
                CollectionsView()
            }
            .tabItem {
                Label("Коллекции", systemImage: "rectangle.stack")
            }

            NavigationStack {
                VerbsView()
            }
            .tabItem {
                Label("Глаголы", systemImage: "textformat.abc")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Настройки", systemImage: "gearshape")
            }
        }
    }
}
