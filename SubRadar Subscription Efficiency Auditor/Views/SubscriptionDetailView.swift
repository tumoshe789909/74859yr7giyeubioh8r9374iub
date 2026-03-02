import SwiftUI
import Charts

struct SubscriptionDetailView: View {
    @Environment(SubscriptionStore.self) private var store
    @AppStorage("selectedCurrency") private var selectedCurrency = "USD"
    let subscription: CDSubscription

    @State private var showCancelConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    @State private var showParticles = false
    @State private var dismissTask: DispatchWorkItem?
    @Environment(\.dismiss) private var dismiss

    private var currencySymbol: String { CurrencyHelper.symbol(for: selectedCurrency) }
    private var history: [MonthlyUsage] { AuditEngine.monthlyUsageHistory(for: subscription, months: 6) }

    var body: some View {
        ZStack {
            CyberTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    cpuMetricCard
                    usageChart
                    cpuTrendChart
                    actionsSection

                    DisclaimerView()
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal)
            }

            if showParticles {
                ParticleExplosionView(color: CyberTheme.neonGreen, particleCount: 30)
                    .allowsHitTesting(false)
            }
        }
        .navigationTitle("Deep Audit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if subscription.wrappedStatus != .canceled {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        showEditSheet = true
                    }
                    .foregroundStyle(CyberTheme.neonBlue)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditSubscriptionSheet(subscription: subscription)
        }
        .confirmationDialog("Cancel Subscription?", isPresented: $showCancelConfirmation) {
            Button("Mark as Canceled", role: .destructive) {
                cancelSubscription()
            }
        } message: {
            Text("This will move \(subscription.wrappedName) to your savings history. You'll save \(CostFormatter.format(subscription.effectiveMonthlyCost, currency: subscription.wrappedCurrency))/mo.")
        }
        .confirmationDialog("Delete Subscription?", isPresented: $showDeleteConfirmation) {
            Button("Delete Permanently", role: .destructive) {
                store.deleteSubscription(subscription)
                dismiss()
            }
        } message: {
            Text("This will permanently remove all data for \(subscription.wrappedName).")
        }
        .onDisappear { dismissTask?.cancel() }
    }

    private var headerCard: some View {
        CyberCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(subscription.statusColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: CyberTheme.iconForCategory(subscription.wrappedCategory))
                        .font(.system(size: 24))
                        .foregroundStyle(subscription.statusColor)
                }
                .neonGlow(subscription.statusColor, radius: 8, active: subscription.wrappedStatus == .zombie)

                VStack(alignment: .leading, spacing: 4) {
                    Text(subscription.wrappedName)
                        .font(CyberTheme.headlineFont(20))
                        .foregroundStyle(CyberTheme.textPrimary)

                    HStack(spacing: 8) {
                        Text(CostFormatter.format(subscription.effectiveMonthlyCost, currency: subscription.wrappedCurrency) + (subscription.wrappedBillingCycle == .annual ? "/mo (annual)" : "/mo"))
                            .font(CyberTheme.bodyFont())
                            .foregroundStyle(CyberTheme.textSecondary)

                        Text(subscription.wrappedCategory)
                            .font(CyberTheme.captionFont(10))
                            .foregroundStyle(CyberTheme.colorForCategory(subscription.wrappedCategory))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(CyberTheme.colorForCategory(subscription.wrappedCategory).opacity(0.15))
                            )
                    }

                    if subscription.wrappedStatus == .zombie {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text("ZOMBIE DETECTED")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(CyberTheme.neonRed)
                        .padding(.top, 2)
                    }
                    if let days = subscription.daysUntilRenewal, days >= 0, days <= 31 {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 10))
                            Text("Renews in \(days) \(days == 1 ? "day" : "days")")
                                .font(CyberTheme.captionFont(10))
                        }
                        .foregroundStyle(CyberTheme.neonYellow)
                        .padding(.top, 2)
                    }
                }
                Spacer()
            }
        }
        .neonBorder(subscription.statusColor.opacity(0.3))
    }

    private var cpuMetricCard: some View {
        CyberCard {
            VStack(spacing: 16) {
                HStack {
                    Text("Cost Per Use")
                        .font(CyberTheme.captionFont(11))
                        .foregroundStyle(CyberTheme.textSecondary)
                        .tracking(1)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: subscription.efficiencyRating.icon)
                        Text(subscription.efficiencyRating.rawValue)
                    }
                    .font(CyberTheme.captionFont(11))
                    .foregroundStyle(subscription.efficiencyRating.color)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(currencySymbol)
                        .font(CyberTheme.headlineFont(24))
                        .foregroundStyle(subscription.efficiencyRating.color)
                    Text(subscription.cpuFormatted)
                        .font(CyberTheme.displayFont(48))
                        .foregroundStyle(CyberTheme.textPrimary)
                        .neonText(subscription.efficiencyRating.color)
                    Spacer()
                }

                HStack(spacing: 24) {
                    MetricItem(label: "Monthly Cost", value: CostFormatter.format(subscription.effectiveMonthlyCost, currency: subscription.wrappedCurrency))
                    MetricItem(label: "Total Uses", value: "\(subscription.usageCount)")
                    MetricItem(label: "This Month", value: "\(subscription.usesThisMonth)")
                    Spacer()
                }

                let trend = AuditEngine.cpuTrend(
                    currentUses: subscription.usesThisMonth,
                    previousUses: subscription.usesLastMonth,
                    monthlyCost: subscription.effectiveMonthlyCost
                )
                if trend != 0 {
                    HStack(spacing: 4) {
                        Image(systemName: trend > 0 ? "arrow.up.right" : "arrow.down.right")
                        Text("\(String(format: "%.1f", abs(trend)))% CPU \(trend > 0 ? "increase" : "decrease") vs last month")
                    }
                    .font(CyberTheme.captionFont(11))
                    .foregroundStyle(trend > 0 ? CyberTheme.neonRed : CyberTheme.neonGreen)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var usageChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("USAGE HISTORY")
                .font(CyberTheme.captionFont(11))
                .foregroundStyle(CyberTheme.textTertiary)
                .tracking(1.5)

            CyberCard {
                Chart(history) { data in
                    BarMark(
                        x: .value("Month", data.monthLabel),
                        y: .value("Uses", data.uses)
                    )
                    .foregroundStyle(CyberTheme.neonBlueGradient)
                    .cornerRadius(6)
                }
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
                    }
                }
                .frame(height: 180)
            }
        }
    }

    private var cpuTrendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CPU TREND")
                .font(CyberTheme.captionFont(11))
                .foregroundStyle(CyberTheme.textTertiary)
                .tracking(1.5)

            CyberCard {
                let validHistory = history.filter { $0.cpu.isFinite }
                if validHistory.isEmpty {
                    Text("Not enough data for trend analysis")
                        .font(CyberTheme.captionFont())
                        .foregroundStyle(CyberTheme.textTertiary)
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                } else {
                    Chart(validHistory) { data in
                        LineMark(
                            x: .value("Month", data.monthLabel),
                            y: .value("CPU", data.cpu)
                        )
                        .foregroundStyle(CyberTheme.neonRedGradient)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Month", data.monthLabel),
                            y: .value("CPU", data.cpu)
                        )
                        .foregroundStyle(CyberTheme.neonRed)
                        .symbolSize(30)

                        AreaMark(
                            x: .value("Month", data.monthLabel),
                            y: .value("CPU", data.cpu)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [CyberTheme.neonRed.opacity(0.2), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    }
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
                        }
                    }
                    .frame(height: 150)
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 10) {
            if subscription.wrappedStatus == .active {
                Button {
                    store.updateStatus(subscription, to: .zombie)
                } label: {
                    actionRow(icon: "exclamationmark.triangle.fill", title: "Mark as Zombie",
                              subtitle: "Flag this subscription as inefficient", color: CyberTheme.neonRed)
                }
            }

            if subscription.wrappedStatus == .zombie {
                Button {
                    store.updateStatus(subscription, to: .active)
                } label: {
                    actionRow(icon: "arrow.uturn.backward", title: "Restore to Active",
                              subtitle: "Remove zombie flag", color: CyberTheme.neonGreen)
                }
            }

            if subscription.wrappedStatus != .canceled {
                Button {
                    store.toggleKillMark(subscription)
                } label: {
                    actionRow(
                        icon: subscription.isMarkedForKill ? "xmark.circle.fill" : "target",
                        title: subscription.isMarkedForKill ? "Remove from Kill List" : "Add to Kill List",
                        subtitle: subscription.isMarkedForKill ? "Remove from cancellation plan" : "Plan for cancellation",
                        color: CyberTheme.neonYellow
                    )
                }

                Button { showCancelConfirmation = true } label: {
                    actionRow(icon: "scissors", title: "Cancel Plan",
                              subtitle: "Record cancellation and track savings", color: CyberTheme.neonOrange)
                }
            }

            Button { showDeleteConfirmation = true } label: {
                actionRow(icon: "trash", title: "Delete Record",
                          subtitle: "Permanently remove this subscription", color: CyberTheme.neonRed.opacity(0.7))
            }
        }
    }

    private func actionRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CyberTheme.bodyFont())
                    .foregroundStyle(CyberTheme.textPrimary)
                Text(subtitle)
                    .font(CyberTheme.captionFont(10))
                    .foregroundStyle(CyberTheme.textTertiary)
            }
            Spacer()
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

    private func cancelSubscription() {
        showParticles = true
        withAnimation(.spring(response: 0.5)) {
            store.updateStatus(subscription, to: .canceled)
        }
        let task = DispatchWorkItem { dismiss() }
        dismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: task)
    }
}

struct MetricItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(CyberTheme.headlineFont(14))
                .foregroundStyle(CyberTheme.textPrimary)
            Text(label)
                .font(CyberTheme.captionFont(9))
                .foregroundStyle(CyberTheme.textTertiary)
        }
    }
}

struct EditSubscriptionSheet: View {
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let subscription: CDSubscription

    @State private var editName: String = ""
    @State private var editCost: String = ""
    @State private var editCategory: String = ""
    @State private var editBillingCycle: BillingCycle = .monthly
    @State private var editNextRenewalDate: Date?
    @State private var parseError = false

    var body: some View {
        NavigationStack {
            ZStack {
                CyberTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        CyberCard {
                            VStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Name")
                                        .font(CyberTheme.captionFont())
                                        .foregroundStyle(CyberTheme.textSecondary)
                                    TextField("Name", text: $editName)
                                        .textFieldStyle(.plain)
                                        .font(CyberTheme.bodyFont())
                                        .foregroundStyle(CyberTheme.textPrimary)
                                        .padding(12)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(CyberTheme.surfaceLight))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Billing Cycle")
                                        .font(CyberTheme.captionFont())
                                        .foregroundStyle(CyberTheme.textSecondary)
                                    Picker("Cycle", selection: $editBillingCycle) {
                                        Text("Monthly").tag(BillingCycle.monthly)
                                        Text("Annual").tag(BillingCycle.annual)
                                    }
                                    .pickerStyle(.segmented)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text((editBillingCycle == .monthly ? "Monthly" : "Yearly") + " Cost")
                                        .font(CyberTheme.captionFont())
                                        .foregroundStyle(CyberTheme.textSecondary)
                                    TextField("0.00", text: $editCost)
                                        .textFieldStyle(.plain)
                                        .keyboardType(.decimalPad)
                                        .font(CyberTheme.bodyFont())
                                        .foregroundStyle(CyberTheme.textPrimary)
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(CyberTheme.surfaceLight)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(parseError ? CyberTheme.neonRed.opacity(0.5) : Color.clear, lineWidth: 1)
                                                )
                                        )
                                        .onChange(of: editCost) { _, _ in parseError = false }
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Next Renewal (optional)")
                                            .font(CyberTheme.captionFont())
                                            .foregroundStyle(CyberTheme.textSecondary)
                                        Spacer()
                                        Toggle("Set", isOn: Binding(
                                            get: { editNextRenewalDate != nil },
                                            set: { editNextRenewalDate = $0 ? (editNextRenewalDate ?? Calendar.current.date(byAdding: .month, value: 1, to: Date())) : nil }
                                        ))
                                        .labelsHidden()
                                        .tint(CyberTheme.neonGreen)
                                    }
                                    if editNextRenewalDate != nil {
                                        DatePicker("", selection: Binding(get: { editNextRenewalDate ?? Date() }, set: { editNextRenewalDate = $0 }), displayedComponents: .date)
                                            .datePickerStyle(.compact)
                                            .labelsHidden()
                                            .tint(CyberTheme.neonGreen)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Category")
                                        .font(CyberTheme.captionFont())
                                        .foregroundStyle(CyberTheme.textSecondary)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(SubscriptionPresets.categories, id: \.self) { cat in
                                                Button { editCategory = cat } label: {
                                                    Text(cat)
                                                        .font(CyberTheme.captionFont(11))
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 6)
                                                        .background(
                                                            Capsule().fill(editCategory == cat
                                                                ? CyberTheme.colorForCategory(cat).opacity(0.2)
                                                                : CyberTheme.surfaceLight)
                                                        )
                                                        .foregroundStyle(editCategory == cat
                                                            ? CyberTheme.colorForCategory(cat)
                                                            : CyberTheme.textSecondary)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if parseError {
                            Text("Please enter a valid number")
                                .font(CyberTheme.captionFont(11))
                                .foregroundStyle(CyberTheme.neonRed)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(CyberTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEdits() }
                        .foregroundStyle(CyberTheme.neonGreen)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                editName = subscription.wrappedName
                editCost = String(format: "%.2f", subscription.monthlyCost)
                editCategory = subscription.wrappedCategory
                editBillingCycle = subscription.wrappedBillingCycle
                editNextRenewalDate = subscription.nextRenewalDate
            }
        }
    }

    private func saveEdits() {
        guard !editName.isEmpty else { return }
        let normalized = editCost.replacingOccurrences(of: ",", with: ".")
        guard let cost = Double(normalized), cost > 0 else {
            parseError = true
            return
        }
        store.updateSubscription(
            subscription,
            name: editName,
            monthlyCost: cost,
            category: editCategory,
            billingCycle: editBillingCycle,
            nextRenewalDate: editNextRenewalDate
        )
        dismiss()
    }
}

#Preview {
    let ctx = PersistenceController.preview.container.viewContext
    let sub = (try? ctx.fetch(CDSubscription.fetchRequest()))?.first
    if let sub {
        NavigationStack {
            SubscriptionDetailView(subscription: sub)
                .environment(SubscriptionStore(context: ctx))
        }
    }
}
