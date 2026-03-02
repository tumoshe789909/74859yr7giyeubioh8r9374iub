import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0

    private let pages: [(icon: String, title: String, description: String, color: Color)] = [
        ("plus.circle.fill", "Add Your Subscriptions",
         "Start by adding the services you pay for monthly. Use our neutral presets or create custom entries.",
         CyberTheme.neonGreen),
        ("hand.tap.fill", "Log Your Usage",
         "Tap to record each time you use a service. This builds your personal efficiency data over time.",
         CyberTheme.neonBlue),
        ("chart.bar.fill", "See Your CPU",
         "Cost Per Use reveals which subscriptions deliver real value and which are silently draining your budget.",
         CyberTheme.neonPurple)
    ]

    var body: some View {
        ZStack {
            CyberTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        onboardingPage(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 420)

                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? pages[currentPage].color : CyberTheme.textTertiary)
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentPage ? 1.3 : 1)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.top, 24)

                Spacer()

                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation(.spring(response: 0.4)) { currentPage += 1 }
                    } else {
                        onComplete()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Next" : "Start Auditing")
                        .font(CyberTheme.headlineFont())
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: CyberTheme.cornerRadiusLarge)
                                .fill(pages[currentPage].color)
                        )
                        .neonGlow(pages[currentPage].color, radius: 12)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 20)

                if currentPage < pages.count - 1 {
                    Button("Skip") { onComplete() }
                        .font(CyberTheme.bodyFont())
                        .foregroundStyle(CyberTheme.textSecondary)
                        .padding(.bottom, 32)
                } else {
                    Color.clear.frame(height: 52)
                }
            }
        }
    }

    private func onboardingPage(_ page: (icon: String, title: String, description: String, color: Color)) -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.15))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(page.color.opacity(0.08))
                    .frame(width: 160, height: 160)
                Image(systemName: page.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(page.color)
                    .neonGlow(page.color, radius: 10)
            }

            Text(page.title)
                .font(CyberTheme.displayFont(24))
                .foregroundStyle(CyberTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text(page.description)
                .font(CyberTheme.bodyFont())
                .foregroundStyle(CyberTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

#Preview {
    OnboardingView {}
}
