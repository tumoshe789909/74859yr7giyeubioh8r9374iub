import SwiftUI

struct ActivityLoggerView: View {
    @Environment(SubscriptionStore.self) private var store
    @AppStorage("selectedCurrency") private var selectedCurrency = "USD"
    @State private var loggedIds: Set<UUID> = []
    @State private var period: LogPeriod = .month

    private var currencySymbol: String { CurrencyHelper.symbol(for: selectedCurrency) }

    enum LogPeriod: String, CaseIterable {
        case week = "This Week"
        case month = "This Month"
    }

    var body: some View {
        ZStack {
            CyberTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    streakAndWeeklyCard
                    periodPicker
                    subscriptionLogList

                    DisclaimerView()
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Activity Logger")
        .navigationBarTitleDisplayMode(.large)
    }

    private var headerCard: some View {
        CyberCard {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "hand.tap.fill")
                        .foregroundStyle(CyberTheme.neonBlue)
                    Text("Tap to log usage")
                        .font(CyberTheme.headlineFont(16))
                        .foregroundStyle(CyberTheme.textPrimary)
                    Spacer()
                }
                Text("Each tap records +1 use for the subscription. Your CPU updates in real-time.")
                    .font(CyberTheme.captionFont())
                    .foregroundStyle(CyberTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var streakAndWeeklyCard: some View {
        let streak = store.usageStreak
        let weekly = store.weeklySummary

        return CyberCard {
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(streak > 0 ? CyberTheme.neonOrange : CyberTheme.textTertiary)
                        Text("\(streak)")
                            .font(CyberTheme.displayFont(28))
                            .foregroundStyle(streak > 0 ? CyberTheme.neonOrange : CyberTheme.textTertiary)
                    }
                    Text("Day Streak")
                        .font(CyberTheme.captionFont(10))
                        .foregroundStyle(CyberTheme.textTertiary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(CyberTheme.textTertiary.opacity(0.3))
                    .frame(width: 1, height: 40)

                VStack(spacing: 4) {
                    Text("\(weekly.totalUses)")
                        .font(CyberTheme.displayFont(28))
                        .foregroundStyle(CyberTheme.neonGreen)
                    Text("Uses this week")
                        .font(CyberTheme.captionFont(10))
                        .foregroundStyle(CyberTheme.textTertiary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(CyberTheme.textTertiary.opacity(0.3))
                    .frame(width: 1, height: 40)

                VStack(spacing: 4) {
                    Text("\(weekly.subsUsed)")
                        .font(CyberTheme.displayFont(28))
                        .foregroundStyle(CyberTheme.neonPurple)
                    Text("Services used")
                        .font(CyberTheme.captionFont(10))
                        .foregroundStyle(CyberTheme.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .neonBorder(streak > 0 ? CyberTheme.neonOrange.opacity(0.2) : Color.clear)
    }

    private var periodPicker: some View {
        Picker("Period", selection: $period) {
            ForEach(LogPeriod.allCases, id: \.self) { p in
                Text(p.rawValue).tag(p)
            }
        }
        .pickerStyle(.segmented)
    }

    private func usesForPeriod(_ sub: CDSubscription) -> Int64 {
        switch period {
        case .week: return sub.usesThisWeek
        case .month: return sub.usesThisMonth
        }
    }

    private var subscriptionLogList: some View {
        VStack(spacing: 10) {
            let subs = store.subscriptions.filter { $0.wrappedStatus != .canceled }
            if subs.isEmpty {
                emptyState
            } else {
                ForEach(subs) { sub in
                    LogRow(
                        subscription: sub,
                        currencySymbol: currencySymbol,
                        periodUses: usesForPeriod(sub),
                        periodLabel: period == .week ? "this week" : "this month",
                        justLogged: loggedIds.contains(sub.id ?? UUID())
                    ) {
                        logUse(for: sub)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(CyberTheme.textTertiary)
            Text("No active subscriptions to log")
                .font(CyberTheme.bodyFont())
                .foregroundStyle(CyberTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func logUse(for sub: CDSubscription) {
        withAnimation(.spring(response: 0.3)) {
            store.logUsage(for: sub)
            if let id = sub.id {
                loggedIds.insert(id)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                if let id = sub.id {
                    loggedIds.remove(id)
                }
            }
        }
    }
}

struct LogRow: View {
    let subscription: CDSubscription
    let currencySymbol: String
    let periodUses: Int64
    let periodLabel: String
    let justLogged: Bool
    let onLog: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(subscription.statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: CyberTheme.iconForCategory(subscription.wrappedCategory))
                    .font(.system(size: 18))
                    .foregroundStyle(subscription.statusColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(subscription.wrappedName)
                    .font(CyberTheme.bodyFont())
                    .foregroundStyle(CyberTheme.textPrimary)
                HStack(spacing: 10) {
                    Label("\(periodUses) \(periodLabel)", systemImage: "chart.bar")
                        .font(CyberTheme.captionFont(10))
                        .foregroundStyle(CyberTheme.textTertiary)
                    Text("CPU: \(subscription.cpuFormatted)")
                        .font(CyberTheme.captionFont(10))
                        .foregroundStyle(subscription.efficiencyRating.color)
                }
            }

            Spacer()

            Button(action: onLog) {
                ZStack {
                    Circle()
                        .fill(justLogged ? CyberTheme.neonGreen : CyberTheme.surfaceLight)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(CyberTheme.neonGreen.opacity(justLogged ? 0.8 : 0.3), lineWidth: 1.5)
                        )

                    if justLogged {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("+1")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(CyberTheme.neonGreen)
                    }
                }
                .neonGlow(CyberTheme.neonGreen, radius: 6, active: justLogged)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: CyberTheme.cornerRadius)
                .fill(CyberTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: CyberTheme.cornerRadius)
                        .stroke(justLogged ? CyberTheme.neonGreen.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .animation(.spring(response: 0.3), value: justLogged)
    }
}

#Preview {
    NavigationStack {
        ActivityLoggerView()
            .environment(SubscriptionStore(context: PersistenceController.preview.container.viewContext))
    }
}
