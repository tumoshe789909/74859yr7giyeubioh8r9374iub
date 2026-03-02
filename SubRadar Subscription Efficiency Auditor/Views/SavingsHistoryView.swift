import SwiftUI

struct SavingsHistoryView: View {
    @Environment(SubscriptionStore.self) private var store
    @AppStorage("selectedCurrency") private var selectedCurrency = "USD"

    private var currencySymbol: String { CurrencyHelper.symbol(for: selectedCurrency) }

    var body: some View {
        ZStack {
            CyberTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    totalSavedCard
                    if store.canceledSubscriptions.isEmpty {
                        emptyState
                    } else {
                        canceledList
                    }

                    DisclaimerView()
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal)
                .id(store.refreshTrigger)
            }
        }
    }

    private var totalSavedCard: some View {
        CyberCard {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "banknote")
                        .foregroundStyle(CyberTheme.neonGreen)
                    Text("TOTAL SAVED")
                        .font(CyberTheme.captionFont(10))
                        .foregroundStyle(CyberTheme.textTertiary)
                        .tracking(1.2)
                    Spacer()
                    Text("since start")
                        .font(CyberTheme.captionFont(10))
                        .foregroundStyle(CyberTheme.textTertiary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(currencySymbol)
                        .font(CyberTheme.headlineFont(24))
                        .foregroundStyle(CyberTheme.neonGreen)
                    Text(String(format: "%.2f", store.totalSaved))
                        .font(CyberTheme.displayFont(42))
                        .foregroundStyle(CyberTheme.textPrimary)
                        .neonText(CyberTheme.neonGreen)
                    Spacer()
                }

                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("\(store.canceledSubscriptions.count)")
                            .font(CyberTheme.headlineFont(18))
                            .foregroundStyle(CyberTheme.neonBlue)
                        Text("canceled")
                            .font(CyberTheme.captionFont(9))
                            .foregroundStyle(CyberTheme.textTertiary)
                    }
                    VStack(spacing: 2) {
                        let monthlySaved = store.canceledSubscriptions.reduce(0.0) { $0 + $1.effectiveMonthlyCost }
                        Text("\(currencySymbol)\(String(format: "%.2f", monthlySaved))")
                            .font(CyberTheme.headlineFont(18))
                            .foregroundStyle(CyberTheme.neonGreen)
                        Text("freed/mo")
                            .font(CyberTheme.captionFont(9))
                            .foregroundStyle(CyberTheme.textTertiary)
                    }
                    Spacer()
                }
            }
        }
        .neonBorder(CyberTheme.neonGreen.opacity(0.3))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(CyberTheme.textTertiary)
            Text("No canceled subscriptions yet")
                .font(CyberTheme.bodyFont())
                .foregroundStyle(CyberTheme.textSecondary)
            Text("Cancel zombie subscriptions to start tracking your savings")
                .font(CyberTheme.captionFont())
                .foregroundStyle(CyberTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var canceledList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("OPTIMIZATION ARCHIVE")
                .font(CyberTheme.captionFont(11))
                .foregroundStyle(CyberTheme.textTertiary)
                .tracking(1.5)

            ForEach(store.canceledSubscriptions) { sub in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(CyberTheme.neonGreen.opacity(0.1))
                            .frame(width: 40, height: 40)
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(CyberTheme.neonGreen)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(sub.wrappedName)
                            .font(CyberTheme.bodyFont(14))
                            .foregroundStyle(CyberTheme.textPrimary)
                            .strikethrough()
                        if let date = sub.canceledDate {
                            Text("Canceled \(date, style: .date)")
                                .font(CyberTheme.captionFont(10))
                                .foregroundStyle(CyberTheme.textTertiary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(currencySymbol)\(String(format: "%.2f", sub.effectiveMonthlyCost))")
                            .font(CyberTheme.bodyFont(14))
                            .foregroundStyle(CyberTheme.neonGreen)
                        let months = monthsSinceCanceled(sub)
                        Text("\(currencySymbol)\(String(format: "%.0f", sub.effectiveMonthlyCost * months)) saved")
                            .font(CyberTheme.captionFont(10))
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

    private func monthsSinceCanceled(_ sub: CDSubscription) -> Double {
        guard let cancelDate = sub.canceledDate else { return 0 }
        let days = max(0, Calendar.current.dateComponents([.day], from: cancelDate, to: Date()).day ?? 0)
        return Double(days) / 30.44
    }
}

#Preview {
    SavingsHistoryView()
        .environment(SubscriptionStore(context: PersistenceController.preview.container.viewContext))
}
