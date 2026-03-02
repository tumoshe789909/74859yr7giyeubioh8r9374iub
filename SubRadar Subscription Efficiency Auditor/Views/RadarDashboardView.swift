import SwiftUI
import Charts

struct RadarDashboardView: View {
    @Environment(SubscriptionStore.self) private var store
    @AppStorage("selectedCurrency") private var selectedCurrency = "USD"
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 0
    @State private var showAddSheet = false
    @State private var selectedSubscription: CDSubscription?
    @State private var showYearly = false
    @State private var zombieCount = 0

    private var currencySymbol: String { CurrencyHelper.symbol(for: selectedCurrency) }

    var body: some View {
        ZStack {
            CyberTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    spendSummary
                    if monthlyBudget > 0 {
                        budgetProgressCard
                    }
                    if !store.upcomingRenewals.isEmpty {
                        upcomingRenewalsSection
                    }
                    radarSection
                    quickStatsGrid
                    subscriptionsList

                    NavigationLink(destination: CategoryBattleView()) {
                        categoryBattleCard
                    }

                    NavigationLink(destination: ComparisonView()) {
                        comparisonCard
                    }

                    DisclaimerView()
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Radar")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(CyberTheme.neonGreen)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddSubscriptionSheet()
        }
        .navigationDestination(item: $selectedSubscription) { sub in
            SubscriptionDetailView(subscription: sub)
        }
        .onAppear { refreshZombieCount() }
        .onChange(of: store.subscriptions.count) { _, _ in refreshZombieCount() }
    }

    private func refreshZombieCount() {
        zombieCount = store.zombieSubscriptions.count
    }

    private var spendSummary: some View {
        CyberCard {
            VStack(spacing: 12) {
                HStack {
                    Text("Total Spend")
                        .font(CyberTheme.bodyFont())
                        .foregroundStyle(CyberTheme.textSecondary)
                    Spacer()
                    Picker("Period", selection: $showYearly) {
                        Text("Month").tag(false)
                        Text("Year").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(currencySymbol)
                        .font(CyberTheme.headlineFont(20))
                        .foregroundStyle(CyberTheme.neonGreen)
                    Text(String(format: "%.2f", showYearly ? store.totalYearlySpend : store.totalMonthlySpend))
                        .font(CyberTheme.displayFont(36))
                        .foregroundStyle(CyberTheme.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4), value: showYearly)
                    Spacer()
                }

                HStack(spacing: 16) {
                    StatBadge(label: "Active", value: "\(store.activeSubscriptions.count)", color: CyberTheme.neonGreen)
                    StatBadge(label: "Zombies", value: "\(zombieCount)", color: CyberTheme.neonRed)
                    StatBadge(
                        label: "Avg CPU",
                        value: store.averageCPU > 0 ? String(format: "%.1f", store.averageCPU) : "—",
                        color: CyberTheme.neonBlue
                    )
                    Spacer()
                }
            }
        }
    }

    private var budgetProgressCard: some View {
        let spent = store.totalMonthlySpend
        let percent = monthlyBudget > 0 ? min(1, spent / monthlyBudget) : 0
        let isOver = spent > monthlyBudget

        return CyberCard {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "chart.pie.fill")
                        .foregroundStyle(CyberTheme.neonBlue)
                    Text("MONTHLY BUDGET")
                        .font(CyberTheme.captionFont(11))
                        .foregroundStyle(CyberTheme.textTertiary)
                        .tracking(1.2)
                    Spacer()
                    Text("\(currencySymbol)\(String(format: "%.0f", spent)) / \(currencySymbol)\(String(format: "%.0f", monthlyBudget))")
                        .font(CyberTheme.captionFont(11))
                        .foregroundStyle(isOver ? CyberTheme.neonRed : CyberTheme.textSecondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(CyberTheme.surfaceLight)
                            .frame(height: 10)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isOver ? CyberTheme.neonRed : CyberTheme.neonGreen)
                            .frame(width: geo.size.width * min(percent, 1), height: 10)
                    }
                }
                .frame(height: 10)

                if isOver {
                    Text("Over budget by \(CostFormatter.format(spent - monthlyBudget, currency: selectedCurrency))")
                        .font(CyberTheme.captionFont(11))
                        .foregroundStyle(CyberTheme.neonRed)
                }
            }
        }
        .neonBorder(isOver ? CyberTheme.neonRed.opacity(0.4) : CyberTheme.neonGreen.opacity(0.2))
    }

    private var upcomingRenewalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UPCOMING RENEWALS")
                .font(CyberTheme.captionFont(11))
                .foregroundStyle(CyberTheme.textTertiary)
                .tracking(1.5)

            VStack(spacing: 8) {
                ForEach(store.upcomingRenewals.prefix(5), id: \.id) { sub in
                    Button { selectedSubscription = sub } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(CyberTheme.neonYellow.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 16))
                                    .foregroundStyle(CyberTheme.neonYellow)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sub.wrappedName)
                                    .font(CyberTheme.bodyFont())
                                    .foregroundStyle(CyberTheme.textPrimary)
                                if let days = sub.daysUntilRenewal {
                                    Text("In \(days) \(days == 1 ? "day" : "days")")
                                        .font(CyberTheme.captionFont(10))
                                        .foregroundStyle(CyberTheme.neonYellow)
                                }
                            }
                            Spacer()
                            Text(CostFormatter.format(sub.wrappedBillingCycle == .annual ? sub.monthlyCost : sub.effectiveMonthlyCost, currency: sub.wrappedCurrency) + (sub.wrappedBillingCycle == .annual ? "/yr" : "/mo"))
                                .font(CyberTheme.headlineFont(14))
                                .foregroundStyle(CyberTheme.textPrimary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(CyberTheme.textTertiary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: CyberTheme.cornerRadius)
                                .fill(CyberTheme.surface)
                        )
                    }
                }
            }
        }
    }

    private var radarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EFFICIENCY RADAR")
                .font(CyberTheme.captionFont(11))
                .foregroundStyle(CyberTheme.textTertiary)
                .tracking(1.5)

            if store.subscriptions.isEmpty {
                emptyRadarPlaceholder
            } else {
                BubbleRadarView(subscriptions: store.subscriptions) { sub in
                    selectedSubscription = sub
                }
                .frame(height: 300)
                .background(
                    RoundedRectangle(cornerRadius: CyberTheme.cornerRadiusLarge)
                        .fill(CyberTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: CyberTheme.cornerRadiusLarge)
                                .stroke(CyberTheme.neonGreen.opacity(0.08), lineWidth: 1)
                        )
                )
            }
        }
    }

    private var emptyRadarPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 40))
                .foregroundStyle(CyberTheme.neonGreen.opacity(0.3))
            Text("No subscriptions yet")
                .font(CyberTheme.bodyFont())
                .foregroundStyle(CyberTheme.textSecondary)
            Button {
                showAddSheet = true
            } label: {
                Label("Add First Subscription", systemImage: "plus")
                    .font(CyberTheme.bodyFont())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(CyberTheme.neonGreen))
            }
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CyberTheme.cornerRadiusLarge)
                .fill(CyberTheme.surface)
        )
    }

    private var quickStatsGrid: some View {
        let usedSubs = store.subscriptions.filter { $0.usageCount > 0 }
        let highestCPU = usedSubs.max(by: { $0.cpu < $1.cpu })
        let bestValue = usedSubs.min(by: { $0.cpu < $1.cpu })

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            QuickStatCard(
                icon: "flame.fill", title: "Highest CPU",
                value: highestCPU.map { CostFormatter.format($0.cpu, currency: $0.wrappedCurrency) } ?? "—",
                subtitle: highestCPU?.wrappedName,
                color: CyberTheme.neonRed
            )
            QuickStatCard(
                icon: "star.fill", title: "Best Value",
                value: bestValue.map { CostFormatter.format($0.cpu, currency: $0.wrappedCurrency) } ?? "—",
                subtitle: bestValue?.wrappedName,
                color: CyberTheme.neonGreen
            )
            QuickStatCard(
                icon: "exclamationmark.triangle.fill", title: "Zombies Found",
                value: "\(zombieCount)",
                subtitle: zombieCount == 0 ? "All clear" : "Need attention",
                color: zombieCount == 0 ? CyberTheme.neonGreen : CyberTheme.neonRed
            )
            QuickStatCard(
                icon: "dollarsign.arrow.circlepath", title: "Can Save",
                value: CostFormatter.format(store.potentialYearlySavings, currency: selectedCurrency) + "/yr",
                subtitle: "\(store.killListSubscriptions.count) marked",
                color: CyberTheme.neonYellow
            )
        }
    }

    private var subscriptionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ALL SUBSCRIPTIONS")
                .font(CyberTheme.captionFont(11))
                .foregroundStyle(CyberTheme.textTertiary)
                .tracking(1.5)

            ForEach(store.subscriptions) { sub in
                Button { selectedSubscription = sub } label: {
                    SubscriptionRow(subscription: sub, currencySymbol: currencySymbol)
                }
            }
        }
    }

    private var categoryBattleCard: some View {
        CyberCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Category Battle")
                        .font(CyberTheme.headlineFont(16))
                        .foregroundStyle(CyberTheme.textPrimary)
                    Text("Compare spending vs usage by category")
                        .font(CyberTheme.captionFont())
                        .foregroundStyle(CyberTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(CyberTheme.neonPurple)
            }
        }
        .neonBorder(CyberTheme.neonPurple.opacity(0.3))
    }

    private var comparisonCard: some View {
        CyberCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Compare Subscriptions")
                        .font(CyberTheme.headlineFont(16))
                        .foregroundStyle(CyberTheme.textPrimary)
                    Text("Head-to-head: CPU, cost, efficiency")
                        .font(CyberTheme.captionFont())
                        .foregroundStyle(CyberTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(CyberTheme.neonBlue)
            }
        }
        .neonBorder(CyberTheme.neonBlue.opacity(0.3))
    }
}

struct StatBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(CyberTheme.headlineFont(16))
                .foregroundStyle(color)
            Text(label)
                .font(CyberTheme.captionFont(10))
                .foregroundStyle(CyberTheme.textTertiary)
        }
    }
}

struct QuickStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String?
    let color: Color

    var body: some View {
        CyberCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(color)
                    Text(title)
                        .font(CyberTheme.captionFont(11))
                        .foregroundStyle(CyberTheme.textSecondary)
                }
                Text(value)
                    .font(CyberTheme.headlineFont(18))
                    .foregroundStyle(CyberTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let subtitle {
                    Text(subtitle)
                        .font(CyberTheme.captionFont(10))
                        .foregroundStyle(CyberTheme.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SubscriptionRow: View {
    let subscription: CDSubscription
    let currencySymbol: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(subscription.statusColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: CyberTheme.iconForCategory(subscription.wrappedCategory))
                    .font(.system(size: 16))
                    .foregroundStyle(subscription.statusColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(subscription.wrappedName)
                    .font(CyberTheme.bodyFont())
                    .foregroundStyle(CyberTheme.textPrimary)
                HStack(spacing: 8) {
                    Text(subscription.wrappedCategory)
                        .font(CyberTheme.captionFont(10))
                        .foregroundStyle(CyberTheme.textTertiary)
                    if subscription.wrappedStatus == .zombie {
                        Text("ZOMBIE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(CyberTheme.neonRed)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(CyberTheme.neonRed.opacity(0.15)))
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(CostFormatter.format(subscription.effectiveMonthlyCost, currency: subscription.wrappedCurrency) + "/mo")
                    .font(CyberTheme.bodyFont())
                    .foregroundStyle(CyberTheme.textPrimary)
                Text("CPU: \(subscription.cpuFormatted)")
                    .font(CyberTheme.captionFont(10))
                    .foregroundStyle(subscription.efficiencyRating.color)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(CyberTheme.textTertiary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: CyberTheme.cornerRadius)
                .fill(CyberTheme.surface)
        )
    }
}

#Preview {
    NavigationStack {
        RadarDashboardView()
            .environment(SubscriptionStore(context: PersistenceController.preview.container.viewContext))
    }
}
