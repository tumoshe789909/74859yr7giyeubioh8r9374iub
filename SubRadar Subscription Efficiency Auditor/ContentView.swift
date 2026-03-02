import SwiftUI

struct ContentView: View {
    @Environment(SubscriptionStore.self) private var store
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                RadarDashboardView()
            }
            .tabItem {
                Label("Radar", systemImage: "dot.radiowaves.left.and.right")
            }
            .tag(0)

            NavigationStack {
                ActivityLoggerView()
            }
            .tabItem {
                Label("Logger", systemImage: "hand.tap")
            }
            .tag(1)

            NavigationStack {
                ZombieAlertView()
            }
            .tabItem {
                Label("Zombies", systemImage: "exclamationmark.triangle")
            }
            .tag(2)

            NavigationStack {
                SavingsTabView()
            }
            .tabItem {
                Label("Savings", systemImage: "chart.line.downtrend.xyaxis")
            }
            .tag(3)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(4)
        }
        .tint(CyberTheme.neonGreen)
    }
}

struct SavingsTabView: View {
    @State private var selectedSegment = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $selectedSegment) {
                Text("Kill List").tag(0)
                Text("History").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            if selectedSegment == 0 {
                KillListPlannerView()
            } else {
                SavingsHistoryView()
            }
        }
        .background(CyberTheme.background)
        .navigationTitle("Savings")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    ContentView()
        .environment(SubscriptionStore(context: PersistenceController.preview.container.viewContext))
}
