import SwiftUI

enum CyberTheme {
    static let background = Color(hex: "1A1A1A")
    static let surface = Color(hex: "242424")
    static let surfaceLight = Color(hex: "2E2E2E")
    static let neonGreen = Color(hex: "00E676")
    static let neonRed = Color(hex: "FF5252")
    static let neonBlue = Color(hex: "00D4FF")
    static let neonPurple = Color(hex: "B388FF")
    static let neonYellow = Color(hex: "FFD740")
    static let neonOrange = Color(hex: "FF9100")
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.35)

    static let neonGreenGradient = LinearGradient(
        colors: [neonGreen, neonGreen.opacity(0.5)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let neonRedGradient = LinearGradient(
        colors: [neonRed, neonOrange],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let neonBlueGradient = LinearGradient(
        colors: [neonBlue, neonPurple],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let backgroundGradient = LinearGradient(
        colors: [background, Color(hex: "0D0D0D")],
        startPoint: .top, endPoint: .bottom
    )

    static let cornerRadius: CGFloat = 16
    static let cornerRadiusLarge: CGFloat = 24
    static let cornerRadiusXL: CGFloat = 28

    static func displayFont(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func headlineFont(_ size: CGFloat = 18) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    static func bodyFont(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .medium)
    }
    static func captionFont(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .regular)
    }

    static let categoryIcons: [String: String] = [
        "Entertainment": "tv",
        "Music": "music.note",
        "Education": "book",
        "Productivity": "hammer",
        "Health": "heart",
        "News": "newspaper",
        "Cloud Storage": "cloud",
        "Social": "person.2",
        "Finance": "dollarsign.circle",
        "Gaming": "gamecontroller",
        "Other": "square.grid.2x2"
    ]

    static let categoryColors: [String: Color] = [
        "Entertainment": neonPurple,
        "Music": neonBlue,
        "Education": neonGreen,
        "Productivity": neonYellow,
        "Health": neonRed,
        "News": neonOrange,
        "Cloud Storage": neonBlue.opacity(0.7),
        "Social": neonPurple.opacity(0.7),
        "Finance": neonGreen.opacity(0.7),
        "Gaming": neonRed.opacity(0.7),
        "Other": textSecondary
    ]

    static func colorForCategory(_ category: String) -> Color {
        categoryColors[category] ?? textSecondary
    }

    static func iconForCategory(_ category: String) -> String {
        categoryIcons[category] ?? "square.grid.2x2"
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct CyberCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: CyberTheme.cornerRadius)
                    .fill(CyberTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: CyberTheme.cornerRadius)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
    }
}
