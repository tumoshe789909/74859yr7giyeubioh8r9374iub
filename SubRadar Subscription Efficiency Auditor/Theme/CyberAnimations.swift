import SwiftUI

struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false
    let color: Color

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: CyberTheme.cornerRadius)
                    .stroke(color, lineWidth: 2)
                    .scaleEffect(isPulsing ? 1.05 : 1.0)
                    .opacity(isPulsing ? 0 : 0.6)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
    }
}

struct NeonFlashModifier: ViewModifier {
    @State private var flash = false
    let color: Color

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: CyberTheme.cornerRadius)
                    .fill(color.opacity(flash ? 0.3 : 0))
            )
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) { flash = true }
                withAnimation(.easeOut(duration: 1.0).delay(0.4)) { flash = false }
            }
    }
}

struct ParticleExplosionView: View {
    let color: Color
    let particleCount: Int
    @State private var particles: [ParticleState] = []

    struct ParticleState: Identifiable {
        let id = UUID()
        var offset: CGSize
        var opacity: Double
        var scale: Double
    }

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .offset(p.offset)
                    .opacity(p.opacity)
                    .scaleEffect(p.scale)
            }
        }
        .onAppear { explode() }
    }

    private func explode() {
        particles = (0..<particleCount).map { _ in
            ParticleState(offset: .zero, opacity: 1, scale: 1)
        }
        withAnimation(.easeOut(duration: 1.2)) {
            particles = particles.map { _ in
                let angle = Double.random(in: 0...(2 * .pi))
                let distance = Double.random(in: 30...120)
                return ParticleState(
                    offset: CGSize(
                        width: cos(angle) * distance,
                        height: sin(angle) * distance
                    ),
                    opacity: 0,
                    scale: Double.random(in: 0.2...0.8)
                )
            }
        }
    }
}

struct FloatingBubble: ViewModifier {
    @State private var offset: CGSize = .zero
    let amplitude: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(offset)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: Double.random(in: 2.0...4.0))
                    .repeatForever(autoreverses: true)
                ) {
                    offset = CGSize(
                        width: CGFloat.random(in: -amplitude...amplitude),
                        height: CGFloat.random(in: -amplitude...amplitude)
                    )
                }
            }
    }
}

extension View {
    func neonPulse(color: Color) -> some View {
        modifier(PulseAnimation(color: color))
    }

    func neonFlash(color: Color) -> some View {
        modifier(NeonFlashModifier(color: color))
    }

    func floatingBubble(amplitude: CGFloat = 8) -> some View {
        modifier(FloatingBubble(amplitude: amplitude))
    }
}
