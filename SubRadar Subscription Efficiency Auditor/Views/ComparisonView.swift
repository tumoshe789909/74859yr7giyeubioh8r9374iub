import SwiftUI
import Charts

struct ComparisonView: View {
    @Environment(SubscriptionStore.self) private var store
    @AppStorage("selectedCurrency") private var selectedCurrency = "USD"
    @State private var leftSub: CDSubscription?
    @State private var rightSub: CDSubscription?
    @State private var showLeftPicker = false
    @State private var showRightPicker = false

    private var currencySymbol: String { CurrencyHelper.symbol(for: selectedCurrency) }
    private var availableSubs: [CDSubscription] {
        store.subscriptions.filter { $0.wrappedStatus != .canceled }
    }

    var body: some View {
        ZStack {
            CyberTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    headerCard
                    pickerSection
                    if let left = leftSub, let right = rightSub {
                        comparisonContent(left: left, right: right)
                    } else {
                        emptyComparison
                    }
                    DisclaimerView()
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showLeftPicker) {
            SubscriptionPickerSheet(
                subscriptions: availableSubs,
                selected: $leftSub,
                onSelect: { leftSub = $0; showLeftPicker = false }
            )
        }
        .sheet(isPresented: $showRightPicker) {
            SubscriptionPickerSheet(
                subscriptions: availableSubs,
                selected: $rightSub,
                onSelect: { rightSub = $0; showRightPicker = false }
            )
        }
    }

    private var headerCard: some View {
        CyberCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundStyle(CyberTheme.neonPurple)
                    Text("Head-to-Head")
                        .font(CyberTheme.headlineFont(18))
                        .foregroundStyle(CyberTheme.textPrimary)
                }
                Text("Compare two subscriptions side by side. See which delivers better value for your money.")
                    .font(CyberTheme.captionFont(11))
                    .foregroundStyle(CyberTheme.textSecondary)
            }
        }
        .neonBorder(CyberTheme.neonPurple.opacity(0.2))
    }

    private var pickerSection: some View {
        HStack(spacing: 16) {
            subscriptionPickerButton(subscription: leftSub, label: "First") {
                showLeftPicker = true
            }
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 20))
                .foregroundStyle(CyberTheme.textTertiary)
            subscriptionPickerButton(subscription: rightSub, label: "Second") {
                showRightPicker = true
            }
        }
    }

    private func subscriptionPickerButton(subscription: CDSubscription?, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if let sub = subscription {
                    ZStack {
                        Circle()
                            .fill(sub.statusColor.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: CyberTheme.iconForCategory(sub.wrappedCategory))
                            .font(.system(size: 20))
                            .foregroundStyle(sub.statusColor)
                    }
                    Text(sub.wrappedName)
                        .font(CyberTheme.captionFont(11))
                        .foregroundStyle(CyberTheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                } else {
                    ZStack {
                        Circle()
                            .strokeBorder(CyberTheme.textTertiary.opacity(0.5), lineWidth: 2)
                            .frame(width: 48, height: 48)
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(CyberTheme.textTertiary)
                    }
                    Text("Select \(label)")
                        .font(CyberTheme.captionFont(11))
                        .foregroundStyle(CyberTheme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: CyberTheme.cornerRadius)
                    .fill(CyberTheme.surface)
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyComparison: some View {
        CyberCard {
            VStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 40))
                    .foregroundStyle(CyberTheme.textTertiary)
                Text("Select two subscriptions to compare")
                    .font(CyberTheme.bodyFont())
                    .foregroundStyle(CyberTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        }
    }

    private func comparisonContent(left: CDSubscription, right: CDSubscription) -> some View {
        VStack(spacing: 20) {
            comparisonRow(title: "Monthly Cost", leftValue: CostFormatter.format(left.effectiveMonthlyCost, currency: left.wrappedCurrency), rightValue: CostFormatter.format(right.effectiveMonthlyCost, currency: right.wrappedCurrency), lowerIsBetter: true)
            comparisonRow(title: "Cost Per Use (CPU)", leftValue: left.cpuFormatted, rightValue: right.cpuFormatted, lowerIsBetter: true)
            comparisonRow(title: "Total Uses", leftValue: "\(left.usageCount)", rightValue: "\(right.usageCount)", lowerIsBetter: false)
            comparisonRow(title: "Efficiency", leftValue: left.efficiencyRating.rawValue, rightValue: right.efficiencyRating.rawValue, lowerIsBetter: false)

            let leftTrend = AuditEngine.cpuTrend(currentUses: left.usesThisMonth, previousUses: left.usesLastMonth, monthlyCost: left.effectiveMonthlyCost)
            let rightTrend = AuditEngine.cpuTrend(currentUses: right.usesThisMonth, previousUses: right.usesLastMonth, monthlyCost: right.effectiveMonthlyCost)
            comparisonRow(title: "CPU Trend vs Last Month", leftValue: String(format: "%.1f%%", leftTrend), rightValue: String(format: "%.1f%%", rightTrend), lowerIsBetter: true)

            verdictCard(left: left, right: right)
        }
    }

    private func comparisonRow(title: String, leftValue: String, rightValue: String, lowerIsBetter: Bool) -> some View {
        CyberCard {
            VStack(spacing: 12) {
                Text(title)
                    .font(CyberTheme.captionFont(11))
                    .foregroundStyle(CyberTheme.textTertiary)
                    .frame(maxWidth: .infinity)
                HStack(spacing: 16) {
                    Text(leftValue)
                        .font(CyberTheme.headlineFont(18))
                        .foregroundStyle(CyberTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                    Rectangle()
                        .fill(CyberTheme.textTertiary.opacity(0.3))
                        .frame(width: 1, height: 24)
                    Text(rightValue)
                        .font(CyberTheme.headlineFont(18))
                        .foregroundStyle(CyberTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func verdictCard(left: CDSubscription, right: CDSubscription) -> some View {
        let leftCPU = left.cpu
        let rightCPU = right.cpu
        let betterCPU = leftCPU.isFinite && rightCPU.isFinite
            ? (leftCPU < rightCPU ? left : right)
            : (leftCPU.isFinite ? left : right)
        let winner = betterCPU

        return CyberCard {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(CyberTheme.neonYellow)
                    Text("BETTER VALUE")
                        .font(CyberTheme.captionFont(11))
                        .foregroundStyle(CyberTheme.neonYellow)
                        .tracking(1.2)
                }
                Text(winner.wrappedName)
                    .font(CyberTheme.displayFont(24))
                    .foregroundStyle(CyberTheme.neonGreen)
                    .multilineTextAlignment(.center)
                Text("Lower cost per use — more value for your money")
                    .font(CyberTheme.captionFont(11))
                    .foregroundStyle(CyberTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .neonBorder(CyberTheme.neonGreen.opacity(0.3))
    }
}

struct SubscriptionPickerSheet: View {
    let subscriptions: [CDSubscription]
    @Binding var selected: CDSubscription?
    let onSelect: (CDSubscription) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                CyberTheme.background.ignoresSafeArea()
                List {
                    ForEach(subscriptions) { sub in
                        Button {
                            onSelect(sub)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(sub.statusColor.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: CyberTheme.iconForCategory(sub.wrappedCategory))
                                        .foregroundStyle(sub.statusColor)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sub.wrappedName)
                                        .font(CyberTheme.bodyFont())
                                        .foregroundStyle(CyberTheme.textPrimary)
                                    Text("CPU: \(sub.cpuFormatted) · \(CostFormatter.format(sub.effectiveMonthlyCost, currency: sub.wrappedCurrency))/mo")
                                        .font(CyberTheme.captionFont(10))
                                        .foregroundStyle(CyberTheme.textSecondary)
                                }
                                Spacer()
                                if selected?.id == sub.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(CyberTheme.neonGreen)
                                }
                            }
                        }
                        .listRowBackground(CyberTheme.surface)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Select Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(CyberTheme.textSecondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ComparisonView()
            .environment(SubscriptionStore(context: PersistenceController.preview.container.viewContext))
    }
}
