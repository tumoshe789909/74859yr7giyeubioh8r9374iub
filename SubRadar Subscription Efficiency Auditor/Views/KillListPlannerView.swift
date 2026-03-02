import SwiftUI

struct KillListPlannerView: View {
    @Environment(SubscriptionStore.self) private var store
    @AppStorage("selectedCurrency") private var selectedCurrency = "USD"
    @State private var showConfirmation = false
    @State private var showParticles = false

    private var currencySymbol: String { CurrencyHelper.symbol(for: selectedCurrency) }

    private var scaledGoals: [(name: String, icon: String, amount: Double)] {
        let scale = CurrencyHelper.purchasingPowerScale(for: selectedCurrency)
        return [
            ("Nice Dinner Out", "fork.knife", 150 * scale),
            ("Online Course Bundle", "book.closed", 200 * scale),
            ("Weekend Trip", "airplane", 500 * scale),
            ("New Gadget", "desktopcomputer", 1000 * scale),
            ("Emergency Fund Boost", "shield.checkered", 2000 * scale),
        ]
    }

    var body: some View {
        ZStack {
            CyberTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    savingsProjection
                    subscriptionToggleList
                    if store.potentialYearlySavings > 0 {
                        whatYouCouldBuy
                    }
                    cancelAllButton

                    DisclaimerView()
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal)
                .id(store.refreshTrigger)
            }

            if showParticles {
                ParticleExplosionView(color: CyberTheme.neonGreen, particleCount: 40)
                    .allowsHitTesting(false)
            }
        }
        .confirmationDialog("Cancel All Marked?", isPresented: $showConfirmation) {
            Button("Cancel All \(store.killListSubscriptions.count) Subscriptions", role: .destructive) {
                cancelAll()
            }
        } message: {
            Text("This will mark all kill-list items as canceled and start tracking your savings.")
        }
    }

    private var savingsProjection: some View {
        CyberCard {
            VStack(spacing: 12) {
                HStack {
                    Text("SAVINGS PROJECTION")
                        .font(CyberTheme.captionFont(10))
                        .foregroundStyle(CyberTheme.textTertiary)
                        .tracking(1.2)
                    Spacer()
                    Text("\(store.killListSubscriptions.count) marked")
                        .font(CyberTheme.captionFont(11))
                        .foregroundStyle(CyberTheme.neonYellow)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(currencySymbol)
                        .font(CyberTheme.headlineFont(20))
                        .foregroundStyle(CyberTheme.neonGreen)
                    Text(String(format: "%.0f", store.potentialYearlySavings))
                        .font(CyberTheme.displayFont(42))
                        .foregroundStyle(CyberTheme.textPrimary)
                        .contentTransition(.numericText())
                    Text("/year")
                        .font(CyberTheme.bodyFont())
                        .foregroundStyle(CyberTheme.textSecondary)
                    Spacer()
                }

                HStack(spacing: 20) {
                    VStack(spacing: 2) {
                        Text(CostFormatter.format(store.potentialMonthlySavings, currency: selectedCurrency))
                            .font(CyberTheme.headlineFont(14))
                            .foregroundStyle(CyberTheme.neonBlue)
                        Text("per month")
                            .font(CyberTheme.captionFont(9))
                            .foregroundStyle(CyberTheme.textTertiary)
                    }
                    VStack(spacing: 2) {
                        Text(CostFormatter.format(store.potentialMonthlySavings * 12 / 52, currency: selectedCurrency))
                            .font(CyberTheme.headlineFont(14))
                            .foregroundStyle(CyberTheme.neonPurple)
                        Text("per week")
                            .font(CyberTheme.captionFont(9))
                            .foregroundStyle(CyberTheme.textTertiary)
                    }
                    Spacer()
                }
            }
        }
        .neonBorder(CyberTheme.neonGreen.opacity(0.2))
    }

    private var subscriptionToggleList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SELECT SUBSCRIPTIONS TO CANCEL")
                .font(CyberTheme.captionFont(11))
                .foregroundStyle(CyberTheme.textTertiary)
                .tracking(1.5)

            ForEach(store.subscriptions.filter { $0.wrappedStatus != .canceled }) { sub in
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            store.toggleKillMark(sub)
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(sub.isMarkedForKill ? CyberTheme.neonRed.opacity(0.15) : CyberTheme.surfaceLight)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(sub.isMarkedForKill ? CyberTheme.neonRed : CyberTheme.textTertiary.opacity(0.3), lineWidth: 1.5)
                                )
                            if sub.isMarkedForKill {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(CyberTheme.neonRed)
                            }
                        }
                    }

                    Image(systemName: CyberTheme.iconForCategory(sub.wrappedCategory))
                        .font(.system(size: 14))
                        .foregroundStyle(sub.isMarkedForKill ? CyberTheme.neonRed : sub.statusColor)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(sub.wrappedName)
                            .font(CyberTheme.bodyFont(14))
                            .foregroundStyle(sub.isMarkedForKill ? CyberTheme.neonRed : CyberTheme.textPrimary)
                            .strikethrough(sub.isMarkedForKill)
                        Text("CPU: \(sub.cpuFormatted)")
                            .font(CyberTheme.captionFont(10))
                            .foregroundStyle(CyberTheme.textTertiary)
                    }

                    Spacer()

                    Text(CostFormatter.format(sub.effectiveMonthlyCost, currency: sub.wrappedCurrency) + "/mo")
                        .font(CyberTheme.bodyFont(14))
                        .foregroundStyle(sub.isMarkedForKill ? CyberTheme.neonRed : CyberTheme.textSecondary)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(CyberTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(sub.isMarkedForKill ? CyberTheme.neonRed.opacity(0.2) : Color.clear, lineWidth: 1)
                        )
                )
            }
        }
    }

    private var whatYouCouldBuy: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHAT YOU COULD BUY INSTEAD")
                .font(CyberTheme.captionFont(11))
                .foregroundStyle(CyberTheme.textTertiary)
                .tracking(1.5)

            let yearlySavings = store.potentialYearlySavings
            ForEach(scaledGoals.filter { $0.amount <= yearlySavings }, id: \.name) { goal in
                HStack(spacing: 12) {
                    Image(systemName: goal.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(CyberTheme.neonYellow)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(CyberTheme.neonYellow.opacity(0.12)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.name)
                            .font(CyberTheme.bodyFont(14))
                            .foregroundStyle(CyberTheme.textPrimary)
                        Text(CostFormatter.format(goal.amount, currency: selectedCurrency))
                            .font(CyberTheme.captionFont(10))
                            .foregroundStyle(CyberTheme.textTertiary)
                    }

                    Spacer()

                    let times = Int(yearlySavings / goal.amount)
                    Text("\(times)x")
                        .font(CyberTheme.headlineFont(16))
                        .foregroundStyle(CyberTheme.neonGreen)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(CyberTheme.surface)
                )
            }
        }
    }

    private var cancelAllButton: some View {
        Group {
            if !store.killListSubscriptions.isEmpty {
                Button { showConfirmation = true } label: {
                    HStack {
                        Image(systemName: "scissors")
                        Text("Cancel All Marked (\(store.killListSubscriptions.count))")
                    }
                    .font(CyberTheme.headlineFont(16))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: CyberTheme.cornerRadiusLarge)
                            .fill(CyberTheme.neonRed)
                    )
                    .neonGlow(CyberTheme.neonRed, radius: 10)
                }
            }
        }
    }

    private func cancelAll() {
        showParticles = true
        for sub in store.killListSubscriptions {
            store.updateStatus(sub, to: .canceled)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showParticles = false
        }
    }
}

#Preview {
    NavigationStack {
        KillListPlannerView()
            .environment(SubscriptionStore(context: PersistenceController.preview.container.viewContext))
    }
}
