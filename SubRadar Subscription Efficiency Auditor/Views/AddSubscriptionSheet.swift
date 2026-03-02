import SwiftUI

struct AddSubscriptionSheet: View {
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedCurrency") private var selectedCurrency = "USD"

    @State private var name = ""
    @State private var costText = ""
    @State private var category = "Other"
    @State private var billingCycle: BillingCycle = .monthly
    @State private var nextRenewalDate: Date?
    @State private var showPresets = true
    @State private var showDuplicateWarning = false
    @State private var parseError = false

    var body: some View {
        NavigationStack {
            ZStack {
                CyberTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if showPresets {
                            presetsSection
                        }
                        customEntrySection

                        if parseError {
                            Text("Please enter a valid number (e.g. 9.99)")
                                .font(CyberTheme.captionFont(11))
                                .foregroundStyle(CyberTheme.neonRed)
                        }

                        if showDuplicateWarning {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(CyberTheme.neonYellow)
                                Text("A subscription with this name already exists")
                                    .font(CyberTheme.captionFont(11))
                                    .foregroundStyle(CyberTheme.neonYellow)
                            }
                        }

                        DisclaimerView()
                            .padding(.top, 8)
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(CyberTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addSubscription() }
                        .foregroundStyle(CyberTheme.neonGreen)
                        .fontWeight(.semibold)
                        .disabled(name.isEmpty || costText.isEmpty)
                }
            }
            .onChange(of: name) { _, newValue in
                showDuplicateWarning = store.hasDuplicate(name: newValue)
            }
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quick Add from Presets")
                    .font(CyberTheme.headlineFont(16))
                    .foregroundStyle(CyberTheme.textPrimary)
                Spacer()
                Button {
                    withAnimation { showPresets.toggle() }
                } label: {
                    Image(systemName: "chevron.up")
                        .foregroundStyle(CyberTheme.textSecondary)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(SubscriptionPresets.all) { preset in
                    Button {
                        name = preset.name
                        costText = String(format: "%.2f", preset.suggestedCost)
                        category = preset.category
                        parseError = false
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: preset.iconName)
                                .font(.system(size: 14))
                                .foregroundStyle(CyberTheme.colorForCategory(preset.category))
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle().fill(CyberTheme.colorForCategory(preset.category).opacity(0.15))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(CyberTheme.captionFont(11))
                                    .foregroundStyle(CyberTheme.textPrimary)
                                    .lineLimit(1)
                                Text(CostFormatter.format(preset.suggestedCost, currency: selectedCurrency) + "/mo")
                                    .font(CyberTheme.captionFont(10))
                                    .foregroundStyle(CyberTheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(CyberTheme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            name == preset.name ? CyberTheme.neonGreen.opacity(0.5) : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                }
            }
        }
    }

    private var customEntrySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Subscription Details")
                .font(CyberTheme.headlineFont(16))
                .foregroundStyle(CyberTheme.textPrimary)

            CyberCard {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name")
                            .font(CyberTheme.captionFont())
                            .foregroundStyle(CyberTheme.textSecondary)
                        TextField("e.g. Streaming Service", text: $name)
                            .textFieldStyle(.plain)
                            .font(CyberTheme.bodyFont())
                            .foregroundStyle(CyberTheme.textPrimary)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(CyberTheme.surfaceLight)
                            )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Billing Cycle")
                            .font(CyberTheme.captionFont())
                            .foregroundStyle(CyberTheme.textSecondary)
                        Picker("Cycle", selection: $billingCycle) {
                            Text("Monthly").tag(BillingCycle.monthly)
                            Text("Annual").tag(BillingCycle.annual)
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text((billingCycle == .monthly ? "Monthly" : "Yearly") + " Cost (\(CurrencyHelper.symbol(for: selectedCurrency)))")
                            .font(CyberTheme.captionFont())
                            .foregroundStyle(CyberTheme.textSecondary)
                        TextField(billingCycle == .monthly ? "0.00" : "0.00", text: $costText)
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
                            .onChange(of: costText) { _, _ in parseError = false }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Next Renewal (optional)")
                                .font(CyberTheme.captionFont())
                                .foregroundStyle(CyberTheme.textSecondary)
                            Spacer()
                            Toggle("Set", isOn: Binding(
                                get: { nextRenewalDate != nil },
                                set: { nextRenewalDate = $0 ? Calendar.current.date(byAdding: .month, value: 1, to: Date()) : nil }
                            ))
                            .labelsHidden()
                            .tint(CyberTheme.neonGreen)
                        }
                        if nextRenewalDate != nil {
                            DatePicker("", selection: Binding(get: { nextRenewalDate ?? Date() }, set: { nextRenewalDate = $0 }), displayedComponents: .date)
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
                                    Button { category = cat } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: CyberTheme.iconForCategory(cat))
                                                .font(.system(size: 11))
                                            Text(cat)
                                                .font(CyberTheme.captionFont(11))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule().fill(category == cat
                                                ? CyberTheme.colorForCategory(cat).opacity(0.2)
                                                : CyberTheme.surfaceLight)
                                        )
                                        .overlay(
                                            Capsule().stroke(category == cat
                                                ? CyberTheme.colorForCategory(cat).opacity(0.6)
                                                : Color.clear, lineWidth: 1)
                                        )
                                        .foregroundStyle(category == cat
                                            ? CyberTheme.colorForCategory(cat)
                                            : CyberTheme.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func parseCost(_ text: String) -> Double? {
        if let value = Double(text), value > 0 { return value }
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        if let value = Double(normalized), value > 0 { return value }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if let value = formatter.number(from: text)?.doubleValue, value > 0 { return value }
        return nil
    }

    private func addSubscription() {
        guard !name.isEmpty else { return }
        guard let cost = parseCost(costText) else {
            parseError = true
            return
        }
        store.addSubscription(
            name: name,
            monthlyCost: cost,
            currency: selectedCurrency,
            category: category,
            iconName: CyberTheme.iconForCategory(category),
            billingCycle: billingCycle,
            nextRenewalDate: nextRenewalDate
        )
        dismiss()
    }
}

enum CurrencyHelper {
    static let currencies = [
        ("USD", "$"), ("EUR", "€"), ("GBP", "£"), ("JPY", "¥"),
        ("RUB", "₽"), ("CAD", "C$"), ("AUD", "A$"), ("CHF", "CHF"),
        ("CNY", "¥"), ("INR", "₹"), ("BRL", "R$"), ("KRW", "₩")
    ]

    static func symbol(for code: String) -> String {
        currencies.first { $0.0 == code }?.1 ?? "$"
    }

    static func purchasingPowerScale(for code: String) -> Double {
        switch code {
        case "JPY": return 150
        case "KRW": return 1300
        case "RUB": return 95
        case "INR": return 85
        case "CNY": return 7.2
        case "BRL": return 5
        case "GBP": return 0.8
        case "EUR": return 0.92
        case "CHF": return 0.88
        case "CAD": return 1.35
        case "AUD": return 1.55
        default: return 1
        }
    }
}

#Preview {
    AddSubscriptionSheet()
        .environment(SubscriptionStore(context: PersistenceController.preview.container.viewContext))
}
