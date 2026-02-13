import SwiftUI
import Charts
import CoreData

// MARK: - Item Detail View

struct ItemDetailView: View {
    @ObservedObject var item: WardrobeItem
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var showFullScreenPhoto = false
    @State private var showDeleteConfirmation = false
    @State private var showWornAnimation = false
    @State private var showEditSheet = false
    @State private var animatedCPW: Double = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // Hero Section: Photo + CPW overlay
                heroSection

                VStack(spacing: CPWTheme.sectionSpacing) {

                    // Efficiency Score + Quick Stats
                    efficiencySection

                    // Stats Grid
                    statsGrid

                    // CPW Chart
                    if item.wearCount > 0 {
                        cpwChart
                    }

                    // Wear Frequency
                    if item.wearCount > 0 {
                        wearFrequencySection
                    }

                    // Projections
                    if item.wearCount > 0 {
                        projectionsSection
                    }

                    // Action Buttons
                    actionButtons

                    DisclaimerFooter()
                        .padding(.bottom, 20)
                }
                .padding(.top, CPWTheme.sectionSpacing)
            }
        }
        .background(CPWTheme.background.ignoresSafeArea())
        .navigationTitle(item.safeName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit Item", systemImage: "pencil")
                    }

                    if item.archived {
                        Button {
                            PersistenceController.shared.unarchiveItem(item)
                        } label: {
                            Label("Unarchive", systemImage: "archivebox")
                        }
                    } else {
                        Button {
                            PersistenceController.shared.archiveItem(item)
                            dismiss()
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Item", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(CPWTheme.secondaryText)
                }
            }
        }
        .alert("Delete Item?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                PersistenceController.shared.deleteItem(item)
                dismiss()
            }
        } message: {
            Text("This will permanently remove \"\(item.safeName)\" and all its wear history.")
        }
        .sheet(isPresented: $showEditSheet) {
            AddItemView(editingItem: item)
                .onDisappear {
                    withAnimation(.easeOut(duration: 0.6)) {
                        animatedCPW = item.costPerWear
                    }
                }
        }
        .fullScreenCover(isPresented: $showFullScreenPhoto) {
            FullScreenImageView(imageData: item.photoData)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedCPW = item.costPerWear
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Photo
            if let photoData = item.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 320)
                    .clipped()
                    .onTapGesture {
                        showFullScreenPhoto = true
                    }
            } else {
                ZStack {
                    CPWTheme.cardBackground
                    Image(systemName: CPWTheme.categoryIcons[item.safeCategory] ?? "hanger")
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundStyle(CPWTheme.secondaryText.opacity(0.3))
                }
                .frame(height: 240)
            }

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .clear, CPWTheme.background.opacity(0.6), CPWTheme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 160)

            // CPW overlay
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("COST PER WEAR")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(CPWTheme.secondaryText)
                        .tracking(1.5)

                    AnimatedCPWCounter(value: animatedCPW)
                }

                Spacer()

                // Category badge
                Text(item.safeCategory)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(CPWTheme.accent.gradient)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, CPWTheme.cardPadding + 4)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Efficiency Section

    private var efficiencySection: some View {
        HStack(spacing: 12) {
            // Efficiency ring
            ZStack {
                AnimatedRing(
                    progress: item.efficiencyScore / 100.0,
                    lineWidth: 6,
                    size: 56,
                    color: efficiencyColor
                )
                EfficiencyBadge(score: item.efficiencyScore)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Efficiency Score")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CPWTheme.primaryText)
                Text(efficiencyMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(CPWTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            if item.wearCount == 0 {
                Text("Unworn")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.orange.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(CPWTheme.cardPadding)
        .cpwCard()
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    private var efficiencyColor: Color {
        switch item.efficiencyScore {
        case 60...: return CPWTheme.success
        case 30..<60: return CPWTheme.accent
        default: return .orange
        }
    }

    private var efficiencyMessage: String {
        if item.wearCount == 0 { return "Wear this item to start building its efficiency score." }
        if item.efficiencyScore >= 80 { return "Incredible value — one of your best investments!" }
        if item.efficiencyScore >= 60 { return "Great efficiency. Keep wearing it!" }
        if item.efficiencyScore >= 40 { return "Building momentum. More wears will lower CPW." }
        if item.efficiencyScore >= 20 { return "Getting there. A few more wears and it'll be efficient." }
        return "This item needs more love. Wear it more often!"
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatBadge(value: item.formattedPrice, label: "Price", icon: "tag")
            StatBadge(value: "\(item.wearCount)", label: "Wears", icon: "number")
            StatBadge(value: "\(item.daysSincePurchase)d", label: "Owned", icon: "calendar")

            StatBadge(
                value: String(format: "%.1f", item.wearsPerMonth),
                label: "/ Month",
                icon: "chart.line.uptrend.xyaxis"
            )

            if let brand = item.brand, !brand.isEmpty {
                StatBadge(value: brand, label: "Brand", icon: "tag.fill")
            }

            if let daysSince = item.daysSinceLastWorn {
                StatBadge(
                    value: daysSince == 0 ? "Today" : "\(daysSince)d ago",
                    label: "Last Worn",
                    icon: "clock",
                    color: daysSince > 30 ? .orange : CPWTheme.accent
                )
            }
        }
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    // MARK: - CPW Chart

    private var cpwChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "CPW Over Time", icon: "chart.xyaxis.line", trailing: "Decreasing = better")

            let dataPoints = item.cpwOverTime
            if dataPoints.count >= 2 {
                Chart(dataPoints.indices, id: \.self) { index in
                    let point = dataPoints[index]
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("CPW", point.cpw)
                    )
                    .foregroundStyle(CPWTheme.accent)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("CPW", point.cpw)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [CPWTheme.accent.opacity(0.2), CPWTheme.accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    if index == dataPoints.count - 1 {
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("CPW", point.cpw)
                        )
                        .foregroundStyle(CPWTheme.accent)
                        .symbolSize(50)
                        .annotation(position: .top, spacing: 6) {
                            Text(CurrencyManager.shared.format(point.cpw))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(CPWTheme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(CPWTheme.cardBackground.opacity(0.9))
                                .clipShape(Capsule())
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(CurrencyManager.shared.format(v))
                                    .font(.system(size: 10))
                                    .foregroundStyle(CPWTheme.secondaryText)
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [4]))
                            .foregroundStyle(CPWTheme.separator)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(.system(size: 10))
                                    .foregroundStyle(CPWTheme.secondaryText)
                            }
                        }
                    }
                }
                .frame(height: 200)
            } else {
                Text("Wear this item more to see the CPW trend chart.")
                    .font(CPWTheme.captionFont)
                    .foregroundStyle(CPWTheme.secondaryText)
            }
        }
        .padding(CPWTheme.cardPadding)
        .cpwCard()
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    // MARK: - Wear Frequency

    private var wearFrequencySection: some View {
        let logs = item.sortedWearLogs
        let calendar = Calendar.current

        // Group wears by day of week
        let weekdayData: [(day: String, count: Int)] = {
            let grouped = Dictionary(grouping: logs) { log -> Int in
                calendar.component(.weekday, from: log.date ?? Date())
            }
            let formatter = DateFormatter()
            let symbols = formatter.shortWeekdaySymbols ?? []
            return (1...7).map { weekday in
                let name = symbols.isEmpty ? "\(weekday)" : symbols[weekday - 1]
                let count = grouped[weekday]?.count ?? 0
                return (day: name, count: count)
            }
        }()

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Wear Pattern", icon: "chart.bar.fill")

            Chart(weekdayData, id: \.day) { data in
                BarMark(
                    x: .value("Day", data.day),
                    y: .value("Wears", data.count)
                )
                .foregroundStyle(CPWTheme.accentGradient)
                .cornerRadius(4)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text("\(v)")
                                .font(.system(size: 10))
                                .foregroundStyle(CPWTheme.secondaryText)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let day = value.as(String.self) {
                            Text(day)
                                .font(.system(size: 10))
                                .foregroundStyle(CPWTheme.secondaryText)
                        }
                    }
                }
            }
            .frame(height: 140)
        }
        .padding(CPWTheme.cardPadding)
        .cpwCard()
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    // MARK: - Projections

    private var projectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Projections", icon: "sparkles")

            HStack(spacing: 12) {
                VStack(spacing: 6) {
                    Text("\(item.projectedYearlyWears)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(CPWTheme.primaryText)
                    Text("Projected yearly\nwears")
                        .font(.system(size: 11))
                        .foregroundStyle(CPWTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .cpwCard()

                VStack(spacing: 6) {
                    Text(CurrencyManager.shared.format(item.projectedYearlyCPW))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(CPWTheme.accent)
                    Text("Projected CPW\nin 1 year")
                        .font(.system(size: 11))
                        .foregroundStyle(CPWTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .cpwCard()
            }

            // Milestone info
            let nextMilestone = nextWearMilestone
            if let milestone = nextMilestone {
                HStack(spacing: 8) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(CPWTheme.accent)
                    Text("Next milestone: \(milestone) wears (\(milestone - Int(item.wearCount)) to go) → CPW \(CurrencyManager.shared.format(item.purchasePrice / Double(milestone)))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CPWTheme.secondaryText)
                }
            }
        }
        .padding(CPWTheme.cardPadding)
        .cpwCard()
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    private var nextWearMilestone: Int? {
        let milestones = [10, 25, 50, 75, 100, 150, 200, 300, 500]
        return milestones.first { $0 > Int(item.wearCount) }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                markAsWorn()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: showWornAnimation ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 20))
                    Text(showWornAnimation ? "Worn Today!" : "Mark as Worn Today")
                }
                .font(CPWTheme.headlineFont)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    showWornAnimation
                    ? AnyShapeStyle(CPWTheme.success.gradient)
                    : AnyShapeStyle(CPWTheme.accentGradient)
                )
                .clipShape(RoundedRectangle(cornerRadius: CPWTheme.cornerRadius, style: .continuous))
                .animation(.easeInOut(duration: 0.3), value: showWornAnimation)
            }
            .disabled(showWornAnimation)
        }
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    // MARK: - Actions

    private func markAsWorn() {
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()

        PersistenceController.shared.logWear(for: item)

        withAnimation(.spring(response: 0.4)) {
            showWornAnimation = true
            animatedCPW = item.costPerWear
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showWornAnimation = false
            }
        }
    }
}

// MARK: - Animated CPW Counter

struct AnimatedCPWCounter: View {
    let value: Double
    @State private var displayedValue: Double = 0

    var body: some View {
        Text(CurrencyManager.shared.format(displayedValue))
            .font(CPWTheme.cpwDisplayFont)
            .foregroundStyle(displayedValue < 5 ? CPWTheme.accent : CPWTheme.primaryText)
            .contentTransition(.numericText(value: displayedValue))
            .onChange(of: value) { _, newValue in
                withAnimation(.easeOut(duration: 0.6)) {
                    displayedValue = newValue
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    displayedValue = value
                }
            }
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(item: {
            let context = PersistenceController.preview.container.viewContext
            let item = WardrobeItem(context: context)
            item.id = UUID()
            item.name = "Navy Blazer"
            item.category = "Outerwear"
            item.brand = "Uniqlo"
            item.purchasePrice = 89.99
            item.purchaseDate = Calendar.current.date(byAdding: .month, value: -3, to: Date())
            item.wearCount = 24
            item.createdAt = Date()
            item.archived = false
            return item
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
