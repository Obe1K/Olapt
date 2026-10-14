import SwiftUI

// Пустое приложение-«хозяин»: Xcode требует его для UI-тестов. Само тестируемое приложение — Olá PT.
@main
struct HostApp: App {
    var body: some Scene {
        WindowGroup {
            Text("UI test host")
        }
    }
}
