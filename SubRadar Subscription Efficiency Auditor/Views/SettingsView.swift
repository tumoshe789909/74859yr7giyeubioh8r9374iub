import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                parent.onPick(url)
            }
            parent.isPresented = false
        }
    }
}

struct SettingsView: View {
    @Environment(SubscriptionStore.self) private var store
    @AppStorage("selectedCurrency") private var selectedCurrency = "USD"
    @AppStorage("weeklyReminderEnabled") private var weeklyReminderEnabled = false
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    @State private var showResetConfirmation = false
    @State private var showExportSheet = false
    @State private var pdfURL: URL?
    @State private var showImportPicker = false
    @State private var showImportSuccess = false
    @State private var showImportError = false
    @State private var importErrorString = ""

    private var currencySymbol: String { CurrencyHelper.symbol(for: selectedCurrency) }

    var body: some View {
        ZStack {
            CyberTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    appHeader
                    currencySection
                    budgetSection
                    notificationSection
                    exportSection
                    dataSection
                    aboutSection

                    DisclaimerView()
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog("Reset All Data?", isPresented: $showResetConfirmation) {
            Button("Delete Everything", role: .destructive) {
                store.resetAll()
            }
        } message: {
            Text("This will permanently delete all subscriptions, usage logs, and savings history. This action cannot be undone.")
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = pdfURL {
                ShareSheet(items: [url])
            }
        }
    }

    private var appHeader: some View {
        CyberCard {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [CyberTheme.neonGreen, CyberTheme.neonBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.black)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("SubRadar")
                        .font(CyberTheme.headlineFont(20))
                        .foregroundStyle(CyberTheme.textPrimary)
                    Text("Subscription Efficiency Auditor")
                        .font(CyberTheme.captionFont(12))
                        .foregroundStyle(CyberTheme.textSecondary)
                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .font(CyberTheme.captionFont(10))
                        .foregroundStyle(CyberTheme.textTertiary)
                }
                Spacer()
            }
        }
    }

    private var currencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("CURRENCY")

            CyberCard {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "dollarsign.circle")
                            .foregroundStyle(CyberTheme.neonGreen)
                        Text("Display Currency")
                            .font(CyberTheme.bodyFont())
                            .foregroundStyle(CyberTheme.textPrimary)
                        Spacer()
                        Text(currencySymbol)
                            .font(CyberTheme.headlineFont())
                            .foregroundStyle(CyberTheme.neonGreen)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(CurrencyHelper.currencies, id: \.0) { code, symbol in
                                Button {
                                    selectedCurrency = code
                                } label: {
                                    VStack(spacing: 2) {
                                        Text(symbol)
                                            .font(CyberTheme.headlineFont(16))
                                        Text(code)
                                            .font(CyberTheme.captionFont(9))
                                    }
                                    .frame(width: 48, height: 48)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedCurrency == code
                                                ? CyberTheme.neonGreen.opacity(0.15)
                                                : CyberTheme.surfaceLight)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(selectedCurrency == code
                                                        ? CyberTheme.neonGreen.opacity(0.5)
                                                        : Color.clear, lineWidth: 1)
                                            )
                                    )
                                    .foregroundStyle(selectedCurrency == code
                                        ? CyberTheme.neonGreen
                                        : CyberTheme.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("BUDGET")

            CyberCard {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "chart.pie.fill")
                            .foregroundStyle(CyberTheme.neonGreen)
                        Text("Monthly Spend Limit")
                            .font(CyberTheme.bodyFont())
                            .foregroundStyle(CyberTheme.textPrimary)
                        Spacer()
                    }
                    Text("Set a target monthly budget. You'll see progress on the Radar tab.")
                        .font(CyberTheme.captionFont(10))
                        .foregroundStyle(CyberTheme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 12) {
                        Text(currencySymbol)
                            .font(CyberTheme.headlineFont(18))
                            .foregroundStyle(CyberTheme.neonGreen)
                        TextField("0", value: $monthlyBudget, format: .number)
                            .keyboardType(.decimalPad)
                            .font(CyberTheme.headlineFont(24))
                            .foregroundStyle(CyberTheme.textPrimary)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(CyberTheme.surfaceLight)
                            )
                    }
                }
            }
        }
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("REMINDERS")

            CyberCard {
                VStack(spacing: 14) {
                    HStack {
                        Image(systemName: "bell.badge")
                            .foregroundStyle(CyberTheme.neonBlue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weekly Audit Hour")
                                .font(CyberTheme.bodyFont())
                                .foregroundStyle(CyberTheme.textPrimary)
                            Text("Sunday 10:00 AM reminder to review subscriptions")
                                .font(CyberTheme.captionFont(10))
                                .foregroundStyle(CyberTheme.textTertiary)
                        }
                        Spacer()
                        Toggle("", isOn: $weeklyReminderEnabled)
                            .labelsHidden()
                            .tint(CyberTheme.neonGreen)
                    }
                    .onChange(of: weeklyReminderEnabled) { _, newValue in
                        if newValue { NotificationManager.requestPermission() }
                        NotificationManager.scheduleWeeklyAuditReminder(enabled: newValue)
                    }
                }
            }
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("EXPORT & IMPORT")

            Button { generateAndSharePDF() } label: {
                CyberCard {
                    HStack {
                        Image(systemName: "doc.richtext")
                            .foregroundStyle(CyberTheme.neonPurple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export PDF Report")
                                .font(CyberTheme.bodyFont())
                                .foregroundStyle(CyberTheme.textPrimary)
                            Text("Digital Efficiency Analysis with all metrics")
                                .font(CyberTheme.captionFont(10))
                                .foregroundStyle(CyberTheme.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(CyberTheme.neonPurple)
                    }
                }
                .neonBorder(CyberTheme.neonPurple.opacity(0.2))
            }

            Button { exportJSON() } label: {
                CyberCard {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(CyberTheme.neonBlue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export All Data (JSON)")
                                .font(CyberTheme.bodyFont())
                                .foregroundStyle(CyberTheme.textPrimary)
                            Text("Backup subscriptions and usage logs")
                                .font(CyberTheme.captionFont(10))
                                .foregroundStyle(CyberTheme.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(CyberTheme.neonBlue)
                    }
                }
            }

            Button { showImportPicker = true } label: {
                CyberCard {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundStyle(CyberTheme.neonGreen)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import from Backup")
                                .font(CyberTheme.bodyFont())
                                .foregroundStyle(CyberTheme.textPrimary)
                            Text("Restore from JSON backup")
                                .font(CyberTheme.captionFont(10))
                                .foregroundStyle(CyberTheme.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(CyberTheme.textTertiary)
                    }
                }
            }
        }
        .sheet(isPresented: $showImportPicker) {
            DocumentPicker(isPresented: $showImportPicker) { url in
                importFromURL(url)
            }
        }
        .alert("Import Successful", isPresented: $showImportSuccess) {
            Button("OK") { showImportSuccess = false }
        } message: {
            Text("Your data has been restored from backup.")
        }
        .alert("Import Failed", isPresented: $showImportError) {
            Button("OK") { showImportError = false }
        } message: {
            Text(importErrorString)
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("DATA")

            Button { hasCompletedOnboarding = false } label: {
                settingsRow(
                    icon: "arrow.counterclockwise",
                    title: "Replay Onboarding",
                    color: CyberTheme.neonBlue
                )
            }

            Button { showResetConfirmation = true } label: {
                settingsRow(
                    icon: "trash",
                    title: "Reset All Data",
                    color: CyberTheme.neonRed
                )
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("ABOUT")

            CyberCard {
                VStack(alignment: .leading, spacing: 10) {
                    aboutRow(label: "Privacy", value: "100% offline, zero data collection")
                    Divider().overlay(CyberTheme.textTertiary.opacity(0.2))
                    aboutRow(label: "Storage", value: "Local device only (Core Data)")
                    Divider().overlay(CyberTheme.textTertiary.opacity(0.2))
                    aboutRow(label: "Network", value: "No internet connection required")
                    Divider().overlay(CyberTheme.textTertiary.opacity(0.2))
                    aboutRow(label: "Cost", value: "Free forever, no in-app purchases")
                    Divider().overlay(CyberTheme.textTertiary.opacity(0.2))
                    aboutRow(label: "Permissions", value: "Notifications (optional)")
                }
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(CyberTheme.captionFont(11))
            .foregroundStyle(CyberTheme.textTertiary)
            .tracking(1.5)
    }

    private func settingsRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(title)
                .font(CyberTheme.bodyFont())
                .foregroundStyle(CyberTheme.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(CyberTheme.textTertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: CyberTheme.cornerRadius)
                .fill(CyberTheme.surface)
        )
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(CyberTheme.bodyFont(14))
                .foregroundStyle(CyberTheme.textSecondary)
            Spacer()
            Text(value)
                .font(CyberTheme.captionFont(12))
                .foregroundStyle(CyberTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func generateAndSharePDF() {
        let data = PDFReportGenerator.generate(
            subscriptions: store.subscriptions,
            canceledSubscriptions: store.canceledSubscriptions,
            totalMonthly: store.totalMonthlySpend,
            totalSaved: store.totalSaved,
            currencySymbol: currencySymbol
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SubRadar_Efficiency_Report.pdf")
        try? data.write(to: url)
        pdfURL = url
        showExportSheet = true
    }

    private func exportJSON() {
        guard let data = DataExportImport.export(from: store.context) else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SubRadar_Backup_\(formattedDate()).json")
        try? data.write(to: url)
        pdfURL = url
        showExportSheet = true
    }

    private func formattedDate() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HHmm"
        return fmt.string(from: Date())
    }

    private func importFromURL(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            importErrorString = "Could not access the selected file."
            showImportError = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else {
            importErrorString = "Could not read the file."
            showImportError = true
            return
        }

        do {
            try DataExportImport.importData(data, into: store.context, mergeStrategy: .replace)
            store.refresh()
            showImportSuccess = true
        } catch {
            importErrorString = error.localizedDescription
            showImportError = true
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(SubscriptionStore(context: PersistenceController.preview.container.viewContext))
    }
}
