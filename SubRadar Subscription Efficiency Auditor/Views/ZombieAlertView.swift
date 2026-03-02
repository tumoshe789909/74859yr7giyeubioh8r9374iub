import SwiftUI

struct ZombieAlertView: View {
    @Environment(SubscriptionStore.self) private var store
    @AppStorage("selectedCurrency") private var selectedCurrency = "USD"
    @State private var zombieReports: [ZombieReport] = []
    @State private var selectedSubscription: CDSubscription?
    @State private var subscriptionToCancel: CDSubscription?

    private var currencySymbol: String { CurrencyHelper.symbol(for: selectedCurrency) }

    var body: some View {
        ZStack {
            CyberTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    zombieHeader
                    if zombieReports.isEmpty {
                        cleanState
                    } else {
                        totalThreatCard
                        zombieList
                    }
                    manualZombies

                    DisclaimerView()
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Zombie Detector")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { runDetection() } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(CyberTheme.neonGreen)
                }
            }
        }
        .onAppear { runDetection() }
        .navigationDestination(item: $selectedSubscription) { sub in
            SubscriptionDetailView(subscription: sub)
        }
        .confirmationDialog(
            "Cancel Subscription?",
            isPresented: .init(
                get: { subscriptionToCancel != nil },
                set: { if !$0 { subscriptionToCancel = nil } }
            )
        ) {
            if let sub = subscriptionToCancel {
                Button("Cancel \(sub.wrappedName)", role: .destructive) {
                    withAnimation {
                        store.updateStatus(sub, to: .canceled)
                        runDetection()
                    }
                    subscriptionToCancel = nil
                }
            }
        } message: {
            if let sub = subscriptionToCancel {
                Text("This will move \(sub.wrappedName) to savings history. You'll save \(CostFormatter.format(sub.effectiveMonthlyCost, currency: sub.wrappedCurrency))/mo.")
            }
        }
    }

    private var zombieHeader: some View {
        CyberCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(CyberTheme.neonRed.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(CyberTheme.neonRed)
                }
                .neonGlow(CyberTheme.neonRed, radius: 8, active: !zombieReports.isEmpty)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Zombie Analysis")
                        .font(CyberTheme.headlineFont(18))
                        .foregroundStyle(CyberTheme.textPrimary)
                    Text("Subscriptions with CPU increase >30%, high cost-per-use, or zero usage")
                        .font(CyberTheme.captionFont(11))
                        .foregroundStyle(CyberTheme.textSecondary)
                }
            }
        }
        .neonBorder(zombieReports.isEmpty ? CyberTheme.neonGreen.opacity(0.2) : CyberTheme.neonRed.opacity(0.4))
    }

    private var cleanState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(CyberTheme.neonGreen)
                .neonGlow(CyberTheme.neonGreen, radius: 12)

            Text("No Zombies Detected")
                .font(CyberTheme.headlineFont(20))
                .foregroundStyle(CyberTheme.textPrimary)

            Text("All your subscriptions are performing within acceptable efficiency ranges. Keep tracking your usage!")
                .font(CyberTheme.bodyFont(14))
                .foregroundStyle(CyberTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }

    private var totalThreatCard: some View {
        CyberCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL THREAT")
                        .font(CyberTheme.captionFont(10))
                        .foregroundStyle(CyberTheme.neonRed)
                        .tracking(1.2)
                    let totalWaste = zombieReports.reduce(0.0) { $0 + $1.subscription.effectiveMonthlyCost }
                    Text("\(CostFormatter.format(totalWaste, currency: selectedCurrency))/mo wasted")
                        .font(CyberTheme.displayFont(24))
                        .foregroundStyle(CyberTheme.textPrimary)
                    Text("Cancel all to save \(CostFormatter.format(totalWaste * 12, currency: selectedCurrency))/year")
                        .font(CyberTheme.captionFont())
                        .foregroundStyle(CyberTheme.neonYellow)
                }
                Spacer()
                VStack {
                    Text("\(zombieReports.count)")
                        .font(CyberTheme.displayFont(36))
                        .foregroundStyle(CyberTheme.neonRed)
                        .neonText(CyberTheme.neonRed)
                    Text("zombies")
                        .font(CyberTheme.captionFont(10))
                        .foregroundStyle(CyberTheme.textTertiary)
                }
            }
        }
        .neonBorder(CyberTheme.neonRed.opacity(0.3))
    }

    private var zombieList: some View {
        VStack(spacing: 10) {
            ForEach(zombieReports) { report in
                Button { selectedSubscription = report.subscription } label: {
                    ZombieCard(report: report, currencySymbol: currencySymbol) {
                        subscriptionToCancel = report.subscription
                    }
                }
            }
        }
    }

    private var manualZombies: some View {
        let manualZombies = store.zombieSubscriptions.filter { zombie in
            !zombieReports.contains { $0.subscription.id == zombie.id }
        }
        return Group {
            if !manualZombies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("MANUALLY FLAGGED")
                        .font(CyberTheme.captionFont(11))
                        .foregroundStyle(CyberTheme.textTertiary)
                        .tracking(1.5)

                    ForEach(manualZombies) { sub in
                        Button { selectedSubscription = sub } label: {
                            SubscriptionRow(subscription: sub, currencySymbol: currencySymbol)
                        }
                    }
                }
            }
        }
    }

    private func runDetection() {
        withAnimation(.spring(response: 0.5)) {
            zombieReports = store.applyZombieDetection()
        }
    }
}

struct ZombieCard: View {
    let report: ZombieReport
    let currencySymbol: String
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(CyberTheme.neonRed.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(CyberTheme.neonRed)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(report.subscription.wrappedName)
                        .font(CyberTheme.headlineFont(16))
                        .foregroundStyle(CyberTheme.textPrimary)
                    Text(CostFormatter.format(report.subscription.effectiveMonthlyCost, currency: report.subscription.wrappedCurrency) + "/mo")
                        .font(CyberTheme.captionFont())
                        .foregroundStyle(CyberTheme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("CPU")
                        .font(CyberTheme.captionFont(9))
                        .foregroundStyle(CyberTheme.textTertiary)
                    Text(report.cpu.isFinite ? String(format: "%.2f", report.cpu) : "∞")
                        .font(CyberTheme.headlineFont(18))
                        .foregroundStyle(CyberTheme.neonRed)
                }
            }

            Text(report.reason)
                .font(CyberTheme.captionFont(11))
                .foregroundStyle(CyberTheme.neonYellow)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(CyberTheme.neonYellow.opacity(0.08))
                )

            HStack {
                Text("Potential savings: \(CostFormatter.format(report.potentialSavings, currency: report.subscription.wrappedCurrency))/yr")
                    .font(CyberTheme.captionFont(11))
                    .foregroundStyle(CyberTheme.neonGreen)
                Spacer()
                Button(action: onCancel) {
                    Text("Cancel Now")
                        .font(CyberTheme.captionFont(11))
                        .fontWeight(.semibold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(CyberTheme.neonRed))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: CyberTheme.cornerRadius)
                .fill(CyberTheme.surface)
        )
        .neonBorder(CyberTheme.neonRed.opacity(0.2))
    }
}

#Preview {
    NavigationStack {
        ZombieAlertView()
            .environment(SubscriptionStore(context: PersistenceController.preview.container.viewContext))
    }
}
