import SwiftUI
import CoreData

// MARK: - Main Tab View

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WardrobeHubView()
                .tabItem {
                    Label("Wardrobe", systemImage: "hanger")
                }
                .tag(0)

            OOTDTrackerView()
                .tabItem {
                    Label("OOTD", systemImage: "tshirt")
                }
                .tag(1)

            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar.xaxis.ascending")
                }
                .tag(2)

            WearCalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .tint(CPWTheme.accent)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
