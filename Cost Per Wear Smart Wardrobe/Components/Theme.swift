import SwiftUI

// MARK: - Design System (Adaptive Dark Mode)

enum CPWTheme {

    // MARK: Colors — Adaptive

    static let background = Color("AppBackground")
    static let cardBackground = Color("CardBackground")
    static let primaryText = Color("PrimaryText")
    static let secondaryText = Color("SecondaryText")
    static let separator = Color("AppSeparator")

    // Accent stays the same — gold works in both modes
    static let accent = Color("GoldAccent")
    static let accentSecondary = Color("GoldAccentSecondary")
    static let success = Color("Success")
    static let destructive = Color("Destructive")
    static let inefficient = Color("Inefficient")

    // Calendar heat-map
    static let calendarLight = Color("CalendarLight")
    static let calendarMedium = Color("CalendarMedium")
    static let calendarDark = Color("CalendarDark")

    // Gradients
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.15), accent.opacity(0.0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: Layout

    static let cornerRadius: CGFloat = 18
    static let largeCornerRadius: CGFloat = 26
    static let smallCornerRadius: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let gridSpacing: CGFloat = 12
    static let sectionSpacing: CGFloat = 24

    // MARK: Typography

    static let largeTitleFont = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let titleFont = Font.system(.title2, design: .rounded, weight: .bold)
    static let title3Font = Font.system(.title3, design: .rounded, weight: .semibold)
    static let headlineFont = Font.system(.headline, design: .default, weight: .semibold)
    static let bodyFont = Font.system(.body, design: .default, weight: .regular)
    static let captionFont = Font.system(.caption, design: .default, weight: .regular)
    static let cpwDisplayFont = Font.system(size: 36, weight: .bold, design: .rounded)
    static let cpwCardFont = Font.system(size: 15, weight: .bold, design: .rounded)
    static let monoFont = Font.system(.caption2, design: .monospaced, weight: .medium)

    // MARK: Legal

    static let disclaimer = "This is a private personal wardrobe tracking tool for mindful consumption. Not financial or shopping advice."

    // MARK: Empty State Quotes

    static let emptyStateQuotes: [String] = [
        "Quality over quantity — start building your smart wardrobe.",
        "The best outfit is the one you wear the most.",
        "Invest in pieces you'll love wearing again and again.",
        "Mindful consumption starts with awareness.",
        "Your wardrobe, your data, your journey."
    ]

    // MARK: Categories

    static let categories: [String] = [
        "Tops", "Bottoms", "Dresses", "Outerwear",
        "Shoes", "Accessories", "Bags", "Activewear",
        "Formal", "Underwear", "Swimwear", "Other"
    ]

    static let categoryIcons: [String: String] = [
        "Tops": "tshirt",
        "Bottoms": "figure.walk",
        "Dresses": "tshirt.fill",
        "Outerwear": "cloud.snow",
        "Shoes": "shoe.fill",
        "Accessories": "watch",
        "Bags": "bag",
        "Activewear": "figure.run",
        "Formal": "sparkle",
        "Underwear": "tshirt",
        "Swimwear": "water.waves",
        "Other": "hanger"
    ]

    static let categoryColors: [String: Color] = [
        "Tops": .blue,
        "Bottoms": .indigo,
        "Dresses": .pink,
        "Outerwear": .orange,
        "Shoes": .brown,
        "Accessories": .purple,
        "Bags": .teal,
        "Activewear": .green,
        "Formal": .gray,
        "Underwear": .cyan,
        "Swimwear": .mint,
        "Other": .secondary
    ]
}

// MARK: - Color Hex Extension

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

// MARK: - Card Style Modifier

struct CPWCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(CPWTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CPWTheme.cornerRadius, style: .continuous))
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.06),
                radius: 8, x: 0, y: 2
            )
            .overlay(
                RoundedRectangle(cornerRadius: CPWTheme.cornerRadius, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.06) : .clear, lineWidth: 1)
            )
    }
}

extension View {
    func cpwCard() -> some View {
        modifier(CPWCardStyle())
    }
}

// MARK: - Glass Card Style

struct CPWGlassStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: CPWTheme.cornerRadius, style: .continuous))
    }
}

extension View {
    func cpwGlass() -> some View {
        modifier(CPWGlassStyle())
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let value: String
    let label: String
    let icon: String
    var color: Color = CPWTheme.accent

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(CPWTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(CPWTheme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .cpwCard()
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var icon: String? = nil
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CPWTheme.accent)
            }
            Text(title)
                .font(CPWTheme.headlineFont)
                .foregroundStyle(CPWTheme.primaryText)
            Spacer()
            if let trailing = trailing {
                Text(trailing)
                    .font(CPWTheme.captionFont)
                    .foregroundStyle(CPWTheme.secondaryText)
            }
        }
    }
}

// MARK: - Disclaimer Footer

struct DisclaimerFooter: View {
    var body: some View {
        Text(CPWTheme.disclaimer)
            .font(.system(size: 10))
            .foregroundStyle(CPWTheme.secondaryText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.vertical, 8)
    }
}

// MARK: - Animated Ring

struct AnimatedRing: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    var size: CGFloat = 80
    var color: Color = CPWTheme.accent

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.5), color],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * animatedProgress)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                animatedProgress = min(progress, 1.0)
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.6)) {
                animatedProgress = min(newValue, 1.0)
            }
        }
    }
}

// MARK: - Efficiency Score Badge

struct EfficiencyBadge: View {
    let score: Double // 0..100

    private var grade: (text: String, color: Color) {
        switch score {
        case 80...: return ("A+", CPWTheme.success)
        case 60..<80: return ("A", Color.green)
        case 40..<60: return ("B", CPWTheme.accent)
        case 20..<40: return ("C", .orange)
        default: return ("D", CPWTheme.destructive)
        }
    }

    var body: some View {
        Text(grade.text)
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(grade.color.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
