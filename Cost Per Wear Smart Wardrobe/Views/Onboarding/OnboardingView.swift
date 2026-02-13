import SwiftUI

// MARK: - Onboarding (3-step wizard)

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @State private var currentPage = 0

    private let pages: [(icon: String, title: String, subtitle: String)] = [
        (
            "hanger",
            "Track Your Wardrobe",
            "Add your clothing items with photos and purchase prices. Build a complete picture of your wardrobe investments."
        ),
        (
            "calendar.badge.checkmark",
            "Log What You Wear",
            "Each day, mark the items you wore. The app tracks every outfit to calculate the true value of each piece."
        ),
        (
            "chart.line.downtrend.xyaxis",
            "Discover Cost Per Wear",
            "Watch your cost per wear drop with every use. Make smarter purchasing decisions based on real data."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    onboardingPage(icon: page.icon, title: page.title, subtitle: page.subtitle)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            // Page Indicators
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? CPWTheme.accent : CPWTheme.separator)
                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }
            .padding(.bottom, 32)

            // Action Button
            Button {
                if currentPage < pages.count - 1 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage += 1
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        isComplete = true
                    }
                }
            } label: {
                Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                    .font(CPWTheme.headlineFont)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(CPWTheme.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: CPWTheme.cornerRadius, style: .continuous))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)

            if currentPage < pages.count - 1 {
                Button("Skip") {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        isComplete = true
                    }
                }
                .font(CPWTheme.bodyFont)
                .foregroundStyle(CPWTheme.secondaryText)
                .padding(.bottom, 16)
            } else {
                DisclaimerFooter()
                    .padding(.bottom, 16)
            }
        }
        .background(CPWTheme.background.ignoresSafeArea())
    }

    @ViewBuilder
    private func onboardingPage(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(CPWTheme.accent.opacity(0.1))
                    .frame(width: 140, height: 140)

                Image(systemName: icon)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(CPWTheme.accent)
            }

            Text(title)
                .font(CPWTheme.largeTitleFont)
                .foregroundStyle(CPWTheme.primaryText)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(CPWTheme.bodyFont)
                .foregroundStyle(CPWTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(isComplete: .constant(false))
}
