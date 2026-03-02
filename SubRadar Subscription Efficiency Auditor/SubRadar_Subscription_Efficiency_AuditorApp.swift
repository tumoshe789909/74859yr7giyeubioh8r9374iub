import SwiftUI
import CoreData

@main
struct SubRadar_Subscription_Efficiency_AuditorApp: App {
    let persistence = PersistenceController.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var store: SubscriptionStore?

    var body: some Scene {
        WindowGroup {
            Group {
                if let store {
                    if hasCompletedOnboarding {
                        ContentView()
                            .environment(store)
                    } else {
                        OnboardingView {
                            withAnimation(.easeInOut(duration: 0.6)) {
                                hasCompletedOnboarding = true
                            }
                        }
                        .environment(store)
                    }
                } else {
                    ZStack {
                        CyberTheme.background.ignoresSafeArea()
                        ProgressView()
                            .tint(CyberTheme.neonGreen)
                    }
                }
            }
            .onAppear {
                if store == nil {
                    store = SubscriptionStore(context: persistence.container.viewContext)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
