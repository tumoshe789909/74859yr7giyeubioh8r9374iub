import SwiftUI

struct NeonGlow: ViewModifier {
    let color: Color
    let radius: CGFloat
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content
                .shadow(color: color.opacity(0.6), radius: radius / 2)
                .shadow(color: color.opacity(0.3), radius: radius)
                .shadow(color: color.opacity(0.1), radius: radius * 2)
        } else {
            content
        }
    }
}

struct NeonBorder: ViewModifier {
    let color: Color
    let cornerRadius: CGFloat
    let lineWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color.opacity(0.8), lineWidth: lineWidth)
                    .shadow(color: color.opacity(0.5), radius: 4)
                    .shadow(color: color.opacity(0.2), radius: 8)
            )
    }
}

struct NeonText: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.5), radius: 4)
            .shadow(color: color.opacity(0.2), radius: 8)
    }
}

extension View {
    func neonGlow(_ color: Color, radius: CGFloat = 8, active: Bool = true) -> some View {
        modifier(NeonGlow(color: color, radius: radius, active: active))
    }

    func neonBorder(_ color: Color, cornerRadius: CGFloat = CyberTheme.cornerRadius, lineWidth: CGFloat = 1.5) -> some View {
        modifier(NeonBorder(color: color, cornerRadius: cornerRadius, lineWidth: lineWidth))
    }

    func neonText(_ color: Color) -> some View {
        modifier(NeonText(color: color))
    }
}
