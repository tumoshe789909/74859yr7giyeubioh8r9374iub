import Foundation

struct SubscriptionPreset: Identifiable {
    let id = UUID()
    let name: String
    let suggestedCost: Double
    let category: String
    let iconName: String
}

enum SubscriptionPresets {
    static let all: [SubscriptionPreset] = [
        SubscriptionPreset(name: "Streaming Service", suggestedCost: 14.99, category: "Entertainment", iconName: "tv"),
        SubscriptionPreset(name: "Music Platform", suggestedCost: 10.99, category: "Music", iconName: "music.note"),
        SubscriptionPreset(name: "Cloud Storage", suggestedCost: 2.99, category: "Cloud Storage", iconName: "cloud"),
        SubscriptionPreset(name: "News Subscription", suggestedCost: 9.99, category: "News", iconName: "newspaper"),
        SubscriptionPreset(name: "Fitness App", suggestedCost: 12.99, category: "Health", iconName: "heart"),
        SubscriptionPreset(name: "Productivity Suite", suggestedCost: 6.99, category: "Productivity", iconName: "hammer"),
        SubscriptionPreset(name: "Learning Platform", suggestedCost: 19.99, category: "Education", iconName: "book"),
        SubscriptionPreset(name: "Social Premium", suggestedCost: 8.99, category: "Social", iconName: "person.2"),
        SubscriptionPreset(name: "Gaming Service", suggestedCost: 14.99, category: "Gaming", iconName: "gamecontroller"),
        SubscriptionPreset(name: "VPN Service", suggestedCost: 5.99, category: "Productivity", iconName: "lock.shield"),
        SubscriptionPreset(name: "Email Service", suggestedCost: 3.99, category: "Productivity", iconName: "envelope"),
        SubscriptionPreset(name: "Design Tool", suggestedCost: 12.99, category: "Productivity", iconName: "paintbrush"),
        SubscriptionPreset(name: "Finance Tracker", suggestedCost: 4.99, category: "Finance", iconName: "dollarsign.circle"),
        SubscriptionPreset(name: "Meditation App", suggestedCost: 7.99, category: "Health", iconName: "leaf"),
        SubscriptionPreset(name: "Password Manager", suggestedCost: 2.99, category: "Productivity", iconName: "key"),
    ]

    static let categories: [String] = [
        "Entertainment", "Music", "Education", "Productivity",
        "Health", "News", "Cloud Storage", "Social", "Finance", "Gaming", "Other"
    ]
}
