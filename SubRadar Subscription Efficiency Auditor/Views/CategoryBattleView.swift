import SwiftUI
import Charts

struct CategoryBattleView: View {
    @Environment(SubscriptionStore.self) private var store
    @AppStorage("selectedCurrency") private var selectedCurrency = "USD"

    private var currencySymbol: String { CurrencyHelper.symbol(for: selectedCurrency) }
    private var analysis: [CategoryAnalysis] {
        AuditEngine.categoryAnalysis(subscriptions: store.subscriptions)
    }

    var body: some View {
        ZStack {
            CyberTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    if analysis.isEmpty {
                        emptyState
                    } else {
                        battleChart
                        efficiencyRanking
                        categoryCards
                    }

                    DisclaimerView()
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Category Battle")
        .navigationBarTitleDisplayMode(.large)
    }

    private var headerCard: some View {
        CyberCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundStyle(CyberTheme.neonPurple)
                    Text("Budget vs Usage")
                        .font(CyberTheme.headlineFont(16))
                        .foregroundStyle(CyberTheme.textPrimary)
                }
                Text("Compare how much you spend on each category versus how much you actually use it. A high cost% with low usage% signals inefficiency.")
                    .font(CyberTheme.captionFont(11))
                    .foregroundStyle(CyberTheme.textSecondary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 36))
                .foregroundStyle(CyberTheme.textTertiary)
            Text("Add subscriptions with categories to see the battle")
                .font(CyberTheme.bodyFont())
                .foregroundStyle(CyberTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
    }

    private var battleChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COST % VS USAGE %")
                .font(CyberTheme.captionFont(11))
                .foregroundStyle(CyberTheme.textTertiary)
                .tracking(1.5)

            CyberCard {
                Chart(analysis) { cat in
                    BarMark(
                        x: .value("Category", cat.category),
                        y: .value("Percentage", cat.costPercentage)
                    )
                    .foregroundStyle(CyberTheme.neonRed.opacity(0.7))
                    .position(by: .value("Type", "Cost"))
                    .cornerRadius(4)

                    BarMark(
                        x: .value("Category", cat.category),
                        y: .value("Percentage", cat.usagePercentage)
                    )
                    .foregroundStyle(CyberTheme.neonGreen.opacity(0.7))
                    .position(by: .value("Type", "Usage"))
                    .cornerRadius(4)
                }
                .chartForegroundStyleScale([
                    "Cost": CyberTheme.neonRed.opacity(0.7),
                    "Usage": CyberTheme.neonGreen.opacity(0.7)
                ])
                .chartLegend(position: .top)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                            .foregroundStyle(CyberTheme.textTertiary)
                        AxisValueLabel()
                            .foregroundStyle(CyberTheme.textTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(CyberTheme.textSecondary)
                            .font(CyberTheme.captionFont(9))
                    }
                }
                .frame(height: 220)
            }
        }
    }

    private var efficiencyRanking: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EFFICIENCY RANKING")
                .font(CyberTheme.captionFont(11))
                .foregroundStyle(CyberTheme.textTertiary)
                .tracking(1.5)

            ForEach(Array(analysis.sorted { $0.efficiency > $1.efficiency }.enumerated()), id: \.element.id) { index, cat in
                HStack(spacing: 12) {
                    Text("#\(index + 1)")
                        .font(CyberTheme.headlineFont(16))
                        .foregroundStyle(index == 0 ? CyberTheme.neonGreen : CyberTheme.textTertiary)
                        .frame(width: 32)

                    Image(systemName: CyberTheme.iconForCategory(cat.category))
                        .font(.system(size: 14))
                        .foregroundStyle(CyberTheme.colorForCategory(cat.category))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(CyberTheme.colorForCategory(cat.category).opacity(0.15)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(cat.category)
                            .font(CyberTheme.bodyFont(14))
                            .foregroundStyle(CyberTheme.textPrimary)
                        Text("\(String(format: "%.0f", cat.costPercentage))% budget, \(String(format: "%.0f", cat.usagePercentage))% usage")
                            .font(CyberTheme.captionFont(10))
                            .foregroundStyle(CyberTheme.textTertiary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1fx", cat.efficiency))
                            .font(CyberTheme.headlineFont(14))
                            .foregroundStyle(cat.efficiency >= 1 ? CyberTheme.neonGreen : CyberTheme.neonRed)
                        Text("efficiency")
                            .font(CyberTheme.captionFont(9))
                            .foregroundStyle(CyberTheme.textTertiary)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(CyberTheme.surface)
                )
            }
        }
    }

    private var categoryCards: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CATEGORY DETAILS")
                .font(CyberTheme.captionFont(11))
                .foregroundStyle(CyberTheme.textTertiary)
                .tracking(1.5)

            ForEach(analysis) { cat in
                CyberCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: CyberTheme.iconForCategory(cat.category))
                                .foregroundStyle(CyberTheme.colorForCategory(cat.category))
                            Text(cat.category)
                                .font(CyberTheme.headlineFont(16))
                                .foregroundStyle(CyberTheme.textPrimary)
                            Spacer()
                            Text("\(currencySymbol)\(String(format: "%.2f", cat.totalCost))/mo")
                                .font(CyberTheme.headlineFont(14))
                                .foregroundStyle(CyberTheme.textSecondary)
                        }

                        HStack(spacing: 16) {
                            VStack(spacing: 2) {
                                Text("\(cat.subscriptionCount)")
                                    .font(CyberTheme.headlineFont(18))
                                    .foregroundStyle(CyberTheme.neonBlue)
                                Text("services")
                                    .font(CyberTheme.captionFont(9))
                                    .foregroundStyle(CyberTheme.textTertiary)
                            }
                            VStack(spacing: 2) {
                                Text("\(cat.totalUsage)")
                                    .font(CyberTheme.headlineFont(18))
                                    .foregroundStyle(CyberTheme.neonGreen)
                                Text("total uses")
                                    .font(CyberTheme.captionFont(9))
                                    .foregroundStyle(CyberTheme.textTertiary)
                            }
                            Spacer()
                            VStack(spacing: 2) {
                                Text(String(format: "%.0f%%", cat.costPercentage))
                                    .font(CyberTheme.headlineFont(18))
                                    .foregroundStyle(CyberTheme.neonRed)
                                Text("of budget")
                                    .font(CyberTheme.captionFont(9))
                                    .foregroundStyle(CyberTheme.textTertiary)
                            }
                            VStack(spacing: 2) {
                                Text(String(format: "%.0f%%", cat.usagePercentage))
                                    .font(CyberTheme.headlineFont(18))
                                    .foregroundStyle(CyberTheme.neonGreen)
                                Text("of usage")
                                    .font(CyberTheme.captionFont(9))
                                    .foregroundStyle(CyberTheme.textTertiary)
                            }
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(CyberTheme.surfaceLight)
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(cat.efficiency >= 1 ? CyberTheme.neonGreen : CyberTheme.neonRed)
                                    .frame(width: geo.size.width * min(cat.efficiency, 2) / 2, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CategoryBattleView()
            .environment(SubscriptionStore(context: PersistenceController.preview.container.viewContext))
    }
}
