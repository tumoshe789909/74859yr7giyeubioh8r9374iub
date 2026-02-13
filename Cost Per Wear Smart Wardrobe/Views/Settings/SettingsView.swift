import SwiftUI
import CoreData

// MARK: - Settings & Export

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var currencyManager = CurrencyManager.shared

    @AppStorage("appTheme") private var appTheme: String = "system"

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WardrobeItem.createdAt, ascending: false)]
    )
    private var allItems: FetchedResults<WardrobeItem>

    @State private var showClearConfirmation = false
    @State private var showPDFShare = false
    @State private var pdfData: Data?

    var body: some View {
        NavigationStack {
            ZStack {
                CPWTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: CPWTheme.sectionSpacing) {

                        // Appearance
                        appearanceSection

                        // Currency
                        currencySection

                        // Export
                        exportSection

                        // Data Management
                        dataSection

                        // About
                        aboutSection

                        DisclaimerFooter()
                            .padding(.bottom, 20)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Appearance", icon: "paintbrush.fill")

            // Theme Picker
            HStack(spacing: 0) {
                themeOption(
                    title: "Light",
                    icon: "sun.max.fill",
                    value: "light",
                    iconColor: .orange
                )
                themeOption(
                    title: "Dark",
                    icon: "moon.fill",
                    value: "dark",
                    iconColor: .indigo
                )
                themeOption(
                    title: "System",
                    icon: "iphone",
                    value: "system",
                    iconColor: CPWTheme.accent
                )
            }
            .padding(4)
            .background(CPWTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Current theme indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(colorScheme == .dark ? Color.indigo : .orange)
                    .frame(width: 8, height: 8)
                Text("Currently using \(colorScheme == .dark ? "dark" : "light") mode")
                    .font(.system(size: 12))
                    .foregroundStyle(CPWTheme.secondaryText)
            }
        }
        .padding(CPWTheme.cardPadding)
        .cpwCard()
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    private func themeOption(title: String, icon: String, value: String, iconColor: Color) -> some View {
        let isSelected = appTheme == value

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                appTheme = value
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? CPWTheme.accent.opacity(0.12) : .clear)
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? iconColor : CPWTheme.secondaryText.opacity(0.5))
                        .symbolEffect(.bounce, value: isSelected)
                }

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? CPWTheme.primaryText : CPWTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isSelected
                ? CPWTheme.cardBackground
                : .clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: isSelected ? .black.opacity(0.05) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Currency Section

    private var currencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Currency", icon: "banknote")

            Picker("Currency", selection: $currencyManager.currencyCode) {
                ForEach(CurrencyManager.availableCurrencies, id: \.code) { currency in
                    Text("\(currency.symbol) \(currency.code) — \(currency.name)")
                        .tag(currency.code)
                }
            }
            .pickerStyle(.navigationLink)
            .tint(CPWTheme.primaryText)
        }
        .padding(CPWTheme.cardPadding)
        .cpwCard()
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    // MARK: - Export Section

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Export", icon: "square.and.arrow.up")

            Button {
                generateAndSharePDF()
            } label: {
                HStack {
                    Image(systemName: "doc.richtext")
                        .foregroundStyle(CPWTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export Wardrobe Report")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(CPWTheme.primaryText)
                        Text("PDF report with all items, CPW values & stats")
                            .font(.system(size: 12))
                            .foregroundStyle(CPWTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(CPWTheme.secondaryText)
                }
            }
            .disabled(allItems.isEmpty)
            .opacity(allItems.isEmpty ? 0.5 : 1.0)

            if allItems.isEmpty {
                Text("Add items to your wardrobe to generate a report.")
                    .font(CPWTheme.captionFont)
                    .foregroundStyle(CPWTheme.secondaryText)
            }
        }
        .padding(CPWTheme.cardPadding)
        .cpwCard()
        .padding(.horizontal, CPWTheme.cardPadding)
        .sheet(isPresented: $showPDFShare) {
            if let data = pdfData {
                ShareSheet(items: [data])
            }
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Data", icon: "externaldrive")

            HStack {
                Text("Total items:")
                    .font(CPWTheme.bodyFont)
                    .foregroundStyle(CPWTheme.secondaryText)
                Spacer()
                Text("\(allItems.count)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(CPWTheme.primaryText)
            }

            let archivedCount = allItems.filter { $0.archived }.count
            HStack {
                Text("Archived:")
                    .font(CPWTheme.bodyFont)
                    .foregroundStyle(CPWTheme.secondaryText)
                Spacer()
                Text("\(archivedCount)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(CPWTheme.secondaryText)
            }

            Divider()

            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear All Data")
                    Spacer()
                }
                .foregroundStyle(CPWTheme.destructive)
                .font(.system(size: 15, weight: .medium))
            }
            .alert("Clear All Data?", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear Everything", role: .destructive) {
                    PersistenceController.shared.clearAllData()
                }
            } message: {
                Text("This will permanently delete all wardrobe items, wear logs, and goals. This action cannot be undone.")
            }
        }
        .padding(CPWTheme.cardPadding)
        .cpwCard()
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "About", icon: "info.circle")

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Cost Per Wear: Smart Wardrobe")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CPWTheme.primaryText)
                    Spacer()
                    Text("v1.0")
                        .font(CPWTheme.captionFont)
                        .foregroundStyle(CPWTheme.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(CPWTheme.separator.opacity(0.5))
                        .clipShape(Capsule())
                }

                Text("A mindful wardrobe tracking tool that helps you understand the true cost of your clothing through the Cost Per Wear metric. Make smarter purchasing decisions by investing in quality over quantity.")
                    .font(.system(size: 13))
                    .foregroundStyle(CPWTheme.secondaryText)
                    .lineSpacing(3)

                Divider()
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Privacy")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CPWTheme.primaryText)
                    Text("All data is stored locally on your device. No data is collected, shared, or transmitted. Your wardrobe is yours alone.")
                        .font(.system(size: 12))
                        .foregroundStyle(CPWTheme.secondaryText)
                        .lineSpacing(2)
                }

                Divider()
                    .padding(.vertical, 4)

                Text(CPWTheme.disclaimer)
                    .font(.system(size: 10))
                    .foregroundStyle(CPWTheme.secondaryText)
                    .italic()
            }
        }
        .padding(CPWTheme.cardPadding)
        .cpwCard()
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    // MARK: - Helpers

    private func generateAndSharePDF() {
        let data = PDFGenerator.generateReport(
            items: Array(allItems),
            currencyManager: currencyManager
        )
        pdfData = data
        showPDFShare = true
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
