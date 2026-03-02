import SwiftUI

struct BubbleRadarView: View {
    let subscriptions: [CDSubscription]
    let onTap: (CDSubscription) -> Void

    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let maxRadius = min(geo.size.width, geo.size.height) / 2 - 30

            ZStack {
                radarGrid(center: center, maxRadius: maxRadius)

                ForEach(Array(subscriptions.enumerated()), id: \.element.id) { index, sub in
                    let position = bubblePosition(
                        for: sub, index: index, total: subscriptions.count,
                        center: center, maxRadius: maxRadius
                    )
                    let size = bubbleSize(for: sub)

                    BubbleNode(subscription: sub, size: size)
                        .position(position)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.3)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.7)
                            .delay(Double(index) * 0.08),
                            value: appeared
                        )
                        .onTapGesture { onTap(sub) }
                }
            }
        }
        .onAppear { appeared = true }
    }

    private func radarGrid(center: CGPoint, maxRadius: CGFloat) -> some View {
        ZStack {
            ForEach(1...4, id: \.self) { ring in
                let r = maxRadius * CGFloat(ring) / 4
                Circle()
                    .stroke(CyberTheme.neonGreen.opacity(0.08), lineWidth: 1)
                    .frame(width: r * 2, height: r * 2)
                    .position(center)
            }

            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * .pi / 4
                Path { path in
                    path.move(to: center)
                    path.addLine(to: CGPoint(
                        x: center.x + cos(angle) * maxRadius,
                        y: center.y + sin(angle) * maxRadius
                    ))
                }
                .stroke(CyberTheme.neonGreen.opacity(0.05), lineWidth: 0.5)
            }

            Text("HIGH USAGE")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(CyberTheme.neonGreen.opacity(0.4))
                .position(x: center.x, y: center.y - maxRadius * 0.15)

            Text("LOW USAGE")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(CyberTheme.neonRed.opacity(0.4))
                .position(x: center.x, y: center.y + maxRadius * 0.85)
        }
    }

    private func bubblePosition(
        for sub: CDSubscription, index: Int, total: Int,
        center: CGPoint, maxRadius: CGFloat
    ) -> CGPoint {
        let maxUsage = max(1, subscriptions.map(\.usageCount).max() ?? 1)
        let usageRatio = Double(sub.usageCount) / Double(maxUsage)
        let distance = maxRadius * (1.0 - usageRatio * 0.7) * 0.7

        let goldenAngle = 2.399963 // ~137.508 degrees
        let angle = Double(index) * goldenAngle

        return CGPoint(
            x: center.x + cos(angle) * distance,
            y: center.y + sin(angle) * distance
        )
    }

    private func bubbleSize(for sub: CDSubscription) -> CGFloat {
        let maxCost = subscriptions.map(\.effectiveMonthlyCost).max() ?? 1
        let minSize: CGFloat = 36
        let maxSize: CGFloat = 80
        let ratio = sub.effectiveMonthlyCost / max(maxCost, 1)
        return minSize + (maxSize - minSize) * ratio
    }
}

struct BubbleNode: View {
    let subscription: CDSubscription
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [subscription.statusColor.opacity(0.5), subscription.statusColor.opacity(0.15)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(subscription.statusColor.opacity(0.6), lineWidth: 1.5)
                )
                .neonGlow(subscription.statusColor, radius: 6, active: subscription.wrappedStatus == .zombie)

            VStack(spacing: 1) {
                Text(String(subscription.wrappedName.prefix(6)))
                    .font(.system(size: max(8, size * 0.14), weight: .semibold))
                    .foregroundStyle(CyberTheme.textPrimary)
                    .lineLimit(1)

                Text(subscription.cpuFormatted)
                    .font(.system(size: max(7, size * 0.12), weight: .bold))
                    .foregroundStyle(subscription.statusColor)
            }
        }
        .floatingBubble(amplitude: 4)
    }
}

#Preview {
    ZStack {
        CyberTheme.background.ignoresSafeArea()
        BubbleRadarView(
            subscriptions: {
                let ctx = PersistenceController.preview.container.viewContext
                let req = CDSubscription.fetchRequest()
                return (try? ctx.fetch(req)) ?? []
            }(),
            onTap: { _ in }
        )
        .frame(height: 350)
        .padding()
    }
}
