import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Фокус", systemImage: "bolt.circle.fill") }

            RulesView()
                .tabItem { Label("Правила", systemImage: "list.bullet.rectangle") }

            StatsView()
                .tabItem { Label("Статистика", systemImage: "chart.bar.fill") }

            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape.fill") }
        }
    }
}
