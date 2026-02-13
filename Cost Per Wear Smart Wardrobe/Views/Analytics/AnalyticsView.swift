import SwiftUI
import Charts
import CoreData

// MARK: - Analytics Dashboard

struct AnalyticsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WardrobeItem.createdAt, ascending: false)],
        predicate: NSPredicate(format: "archived == NO"),
        animation: .easeInOut(duration: 0.3)
    )
    private var items: FetchedResults<WardrobeItem>

    @State private var showGoals = false
    @State private var selectedAnalyticsTab = 0

    private var engine: AnalyticsEngine {
        AnalyticsEngine(context: viewContext)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CPWTheme.background.ignoresSafeArea()

                if items.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: CPWTheme.sectionSpacing) {

                            // Wardrobe Health Score
                            wardrobeHealthCard

                            // Quick Stats Row
                            quickStatsRow

                            // Tab Picker for charts
                            analyticsTabPicker

                            // Charts based on selected tab
                            Group {
                                switch selectedAnalyticsTab {
                                case 0: wearActivitySection
                                case 1: categoryBreakdownSection
                                case 2: spendingSection
                                default: wearActivitySection
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .animation(.easeInOut(duration: 0.3), value: selectedAnalyticsTab)

                            // CPW Trend
                            cpwTrendSection

                            // Streaks & Activity
                            streaksSection

                            // Top & Worst
                            topEfficientSection
                            worstInvestmentsSection

                            // Unused Items
                            if !engine.unusedItems.isEmpty {
                                unusedSection
                            }

                            // Goals Button
                            goalsButton

                            DisclaimerFooter()
                                .padding(.bottom, 20)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Analytics")
            .navigationDestination(isPresented: $showGoals) {
                GoalsView()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(CPWTheme.accent.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "chart.bar.xaxis.ascending")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(CPWTheme.accent)
            }
            Text("No Data Yet")
                .font(CPWTheme.titleFont)
                .foregroundStyle(CPWTheme.primaryText)
            Text("Add items and start logging outfits to see your wardrobe analytics.")
                .font(CPWTheme.bodyFont)
                .foregroundStyle(CPWTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            DisclaimerFooter()
        }
    }

    // MARK: - Wardrobe Health Card

    private var wardrobeHealthCard: some View {
        let score = engine.wardrobeEfficiencyScore
        let utilization = engine.utilizationRate

        return VStack(spacing: 16) {
            HStack(spacing: 20) {
                // Ring chart
                ZStack {
                    AnimatedRing(progress: score / 100.0, lineWidth: 10, size: 90, color: CPWTheme.accent)

                    VStack(spacing: 2) {
                        Text("\(Int(score))")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(CPWTheme.primaryText)
                        Text("Score")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(CPWTheme.secondaryText)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Wardrobe Health")
                        .font(CPWTheme.title3Font)
                        .foregroundStyle(CPWTheme.primaryText)

                    HStack(spacing: 4) {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(CPWTheme.accent)
                        Text("\(Int(utilization))% utilized")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(CPWTheme.secondaryText)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "banknote")
                            .font(.system(size: 12))
                            .foregroundStyle(engine.idleValue > 0 ? .orange : CPWTheme.success)
                        Text("\(CurrencyManager.shared.formatCompact(engine.idleValue)) idle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(CPWTheme.secondaryText)
                    }

                    Text(healthMessage(score: score))
                        .font(.system(size: 12))
                        .foregroundStyle(CPWTheme.accent)
                        .italic()
                }

                Spacer()
            }
        }
        .padding(CPWTheme.cardPadding)
        .cpwCard()
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    private func healthMessage(score: Double) -> String {
        switch score {
        case 80...: return "Exceptional wardrobe efficiency!"
        case 60..<80: return "Great habits — keep it up!"
        case 40..<60: return "Room for improvement."
        case 20..<40: return "Wear your clothes more often."
        default: return "Start logging outfits to build your score."
        }
    }

    // MARK: - Quick Stats

    private var quickStatsRow: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatBadge(
                value: "\(items.count)",
                label: "Items",
                icon: "hanger"
            )
            StatBadge(
                value: CurrencyManager.shared.formatCompact(engine.averageCPW),
                label: "Avg CPW",
                icon: "chart.line.downtrend.xyaxis",
                color: engine.averageCPW > 0 ? CPWTheme.accent : CPWTheme.secondaryText
            )
            StatBadge(
                value: "\(engine.totalWears)",
                label: "Wears",
                icon: "number"
            )
            StatBadge(
                value: CurrencyManager.shared.formatCompact(engine.totalWardrobeValue),
                label: "Value",
                icon: "banknote"
            )
        }
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    // MARK: - Analytics Tab Picker

    private var analyticsTabPicker: some View {
        HStack(spacing: 0) {
            ForEach(Array(["Activity", "Categories", "Spending"].enumerated()), id: \.offset) { index, title in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedAnalyticsTab = index
                    }
                } label: {
                    Text(title)
                        .font(.system(size: 13, weight: selectedAnalyticsTab == index ? .semibold : .regular))
                        .foregroundStyle(selectedAnalyticsTab == index ? .white : CPWTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedAnalyticsTab == index
                            ? CPWTheme.accent
                            : Color.clear
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(3)
        .background(CPWTheme.cardBackground)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    // MARK: - Wear Activity Chart

    private var wearActivitySection: some View {
        let data = engine.wearsPerDayLast30

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Daily Wear Activity", icon: "waveform.path.ecg", trailing: "Last 30 days")

            Chart(data, id: \.date) { point in
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Wears", point.count)
                )
                .foregroundStyle(
                    point.count > 0
                    ? CPWTheme.accentGradient
                    : LinearGradient(colors: [CPWTheme.separator], startPoint: .top, endPoint: .bottom)
                )
                .cornerRadius(3)
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
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [4]))
                        .foregroundStyle(CPWTheme.separator)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(.dateTime.day().month(.abbreviated)))
                                .font(.system(size: 9))
                                .foregroundStyle(CPWTheme.secondaryText)
                        }
                    }
                }
            }
            .frame(height: 180)

            // Weekly summary
            let weeklyData = engine.weeklyWearTrend
            if weeklyData.count >= 2 {
                let lastWeek = weeklyData.last?.count ?? 0
                let prevWeek = weeklyData.dropLast().last?.count ?? 0
                let diff = lastWeek - prevWeek

                HStack(spacing: 6) {
                    Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(diff >= 0 ? CPWTheme.success : .orange)
                    Text("\(abs(diff)) \(diff >= 0 ? "more" : "fewer") wears this week vs last")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CPWTheme.secondaryText)
                }
            }
        }
        .padding(CPWTheme.cardPadding)
        .cpwCard()
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownSection: some View {
        let categoryData = engine.itemsByCategory

        return VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Category Breakdown", icon: "chart.pie.fill")

            if !categoryData.isEmpty {
                // Donut chart
                Chart(categoryData, id: \.category) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(CPWTheme.categoryColors[item.category] ?? .gray)
                    .cornerRadius(4)
                }
                .frame(height: 200)

                // Legend
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(categoryData, id: \.category) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(CPWTheme.categoryColors[item.category] ?? .gray)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.category)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(CPWTheme.primaryText)
                                    .lineLimit(1)
                                Text("\(item.count) items · \(CurrencyManager.shared.formatCompact(item.value))")
                                    .font(.system(size: 10))
                                    .foregroundStyle(CPWTheme.secondaryText)
                            }
                            Spacer()
                        }
                    }
                }

                // CPW by Category
                let cpwData = engine.cpwByCategory
                if !cpwData.isEmpty {
                    Divider()
                        .padding(.vertical, 4)

                    Text("CPW BY CATEGORY")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CPWTheme.secondaryText)
                        .tracking(1)

                    Chart(cpwData, id: \.category) { item in
                        BarMark(
                            x: .value("CPW", item.cpw),
                            y: .value("Category", item.category)
                        )
                        .foregroundStyle(CPWTheme.categoryColors[item.category] ?? .gray)
                        .cornerRadius(4)
                        .annotation(position: .trailing, spacing: 4) {
                            Text(CurrencyManager.shared.format(item.cpw))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(CPWTheme.secondaryText)
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let cat = value.as(String.self) {
                                    Text(cat)
                                        .font(.system(size: 11))
                                        .foregroundStyle(CPWTheme.primaryText)
                                }
                            }
                        }
                    }
                    .frame(height: CGFloat(cpwData.count) * 36)
                }
            }
        }
        .padding(CPWTheme.cardPadding)
        .cpwCard()
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    // MARK: - Spending Section

    private var spendingSection: some View {
        let monthlyData = engine.monthlySpending

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Monthly Spending", icon: "creditcard.fill", trailing: "Last 6 months")

            if monthlyData.contains(where: { $0.amount > 0 }) {
                Chart(monthlyData, id: \.month) { point in
                    BarMark(
                        x: .value("Month", point.month, unit: .month),
                        y: .value("Amount", point.amount)
                    )
                    .foregroundStyle(CPWTheme.accentGradient)
                    .cornerRadius(6)

                    if point.itemCount > 0 {
                        PointMark(
                            x: .value("Month", point.month, unit: .month),
                            y: .value("Amount", point.amount)
                        )
                        .annotation(position: .top, spacing: 4) {
                            Text("\(point.itemCount)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(CPWTheme.accent)
                        }
                        .opacity(0)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(CurrencyManager.shared.formatCompact(v))
                                    .font(.system(size: 10))
                                    .foregroundStyle(CPWTheme.secondaryText)
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [4]))
                            .foregroundStyle(CPWTheme.separator)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date.formatted(.dateTime.month(.abbreviated)))
                                    .font(.system(size: 10))
                                    .foregroundStyle(CPWTheme.secondaryText)
                            }
                        }
                    }
                }
                .frame(height: 180)

                // Total & average
                let total = monthlyData.reduce(0.0) { $0 + $1.amount }
                let avgMonthly = total / max(Double(monthlyData.filter { $0.amount > 0 }.count), 1)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total spent")
                            .font(.system(size: 11))
                            .foregroundStyle(CPWTheme.secondaryText)
                        Text(CurrencyManager.shared.format(total))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(CPWTheme.primaryText)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Avg / month")
                            .font(.system(size: 11))
                            .foregroundStyle(CPWTheme.secondaryText)
                        Text(CurrencyManager.shared.format(avgMonthly))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(CPWTheme.accent)
                    }
                }
            } else {
                Text("No purchases recorded in the last 6 months.")
                    .font(CPWTheme.captionFont)
                    .foregroundStyle(CPWTheme.secondaryText)
            }
        }
        .padding(CPWTheme.cardPadding)
        .cpwCard()
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    // MARK: - CPW Trend

    private var cpwTrendSection: some View {
        let trendData = engine.cpwTrendMonthly

        return Group {
            if trendData.count >= 2 {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "CPW Trend", icon: "chart.line.downtrend.xyaxis", trailing: "Lower is better")

                    Chart(trendData, id: \.month) { point in
                        LineMark(
                            x: .value("Month", point.month, unit: .month),
                            y: .value("CPW", point.avgCPW)
                        )
                        .foregroundStyle(CPWTheme.accent)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        AreaMark(
                            x: .value("Month", point.month, unit: .month),
                            y: .value("CPW", point.avgCPW)
                        )
                        .foregroundStyle(
                            .linearGradient(
                                colors: [CPWTheme.accent.opacity(0.2), CPWTheme.accent.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Month", point.month, unit: .month),
                            y: .value("CPW", point.avgCPW)
                        )
                        .foregroundStyle(CPWTheme.accent)
                        .symbolSize(30)
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
                        AxisMarks(values: .stride(by: .month)) { value in
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(date.formatted(.dateTime.month(.abbreviated)))
                                        .font(.system(size: 10))
                                        .foregroundStyle(CPWTheme.secondaryText)
                                }
                            }
                        }
                    }
                    .frame(height: 160)

                    if let first = trendData.first, let last = trendData.last {
                        let diff = last.avgCPW - first.avgCPW
                        HStack(spacing: 6) {
                            Image(systemName: diff <= 0 ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill")
                                .foregroundStyle(diff <= 0 ? CPWTheme.success : .orange)
                            Text(diff <= 0
                                 ? "CPW dropped by \(CurrencyManager.shared.format(abs(diff)))"
                                 : "CPW increased by \(CurrencyManager.shared.format(abs(diff)))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(CPWTheme.secondaryText)
                        }
                    }
                }
                .padding(CPWTheme.cardPadding)
                .cpwCard()
                .padding(.horizontal, CPWTheme.cardPadding)
            }
        }
    }

    // MARK: - Streaks

    private var streaksSection: some View {
        let streak = engine.currentStreak
        let bestStreak = engine.bestStreak
        let mostActive = engine.mostActiveDayOfWeek

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Activity & Streaks", icon: "flame.fill")

            HStack(spacing: 12) {
                // Current streak
                VStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(streak > 0 ? .orange : CPWTheme.secondaryText.opacity(0.3))
                    Text("\(streak)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(CPWTheme.primaryText)
                    Text("Current\nStreak")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(CPWTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .cpwCard()

                // Best streak
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(bestStreak > 0 ? CPWTheme.accent : CPWTheme.secondaryText.opacity(0.3))
                    Text("\(bestStreak)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(CPWTheme.primaryText)
                    Text("Best\nStreak")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(CPWTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .cpwCard()

                // Most active day
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 22))
                        .foregroundStyle(CPWTheme.accent)
                    if let active = mostActive {
                        Text(dayName(active.day))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(CPWTheme.primaryText)
                    } else {
                        Text("—")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(CPWTheme.secondaryText)
                    }
                    Text("Most\nActive")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(CPWTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .cpwCard()
            }
        }
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    private func dayName(_ weekday: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let symbols = formatter.shortWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let index = (weekday - 1) % 7
        return symbols[index]
    }

    // MARK: - Top Efficient

    private var topEfficientSection: some View {
        let topItems = engine.topEfficient

        return Group {
            if !topItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Most Efficient", icon: "star.fill", trailing: "Top \(topItems.count)")

                    ForEach(Array(topItems.prefix(5).enumerated()), id: \.element.objectID) { index, item in
                        AnalyticsItemRow(
                            rank: index + 1,
                            item: item,
                            accentColor: CPWTheme.accent
                        )
                    }
                }
                .padding(CPWTheme.cardPadding)
                .cpwCard()
                .padding(.horizontal, CPWTheme.cardPadding)
            }
        }
    }

    // MARK: - Worst Investments

    private var worstInvestmentsSection: some View {
        let worstItems = engine.worstInvestments

        return Group {
            if !worstItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Needs More Wear", icon: "exclamationmark.triangle")

                    ForEach(Array(worstItems.enumerated()), id: \.element.objectID) { index, item in
                        AnalyticsItemRow(
                            rank: index + 1,
                            item: item,
                            accentColor: .orange
                        )
                    }
                }
                .padding(CPWTheme.cardPadding)
                .cpwCard()
                .padding(.horizontal, CPWTheme.cardPadding)
            }
        }
    }

    // MARK: - Unused Items

    private var unusedSection: some View {
        let unused = engine.unusedItems

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Unused Items", icon: "moon.zzz", trailing: "\(unused.count)")

            Text("Items not worn in 30+ days since purchase")
                .font(CPWTheme.captionFont)
                .foregroundStyle(CPWTheme.secondaryText)

            ForEach(unused, id: \.objectID) { item in
                HStack(spacing: 12) {
                    itemThumbnail(item)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.safeName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(CPWTheme.primaryText)
                        Text("\(item.daysSincePurchase) days · \(item.formattedPrice)")
                            .font(.system(size: 12))
                            .foregroundStyle(CPWTheme.secondaryText)
                    }

                    Spacer()

                    Button {
                        withAnimation {
                            PersistenceController.shared.archiveItem(item)
                        }
                    } label: {
                        Text("Archive")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CPWTheme.secondaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(CPWTheme.separator.opacity(0.5))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(CPWTheme.cardPadding)
        .cpwCard()
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    // MARK: - Goals Button

    private var goalsButton: some View {
        Button {
            showGoals = true
        } label: {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(CPWTheme.accent)
                Text("Sustainability Goals")
                    .font(CPWTheme.headlineFont)
                    .foregroundStyle(CPWTheme.primaryText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(CPWTheme.secondaryText)
            }
            .padding(CPWTheme.cardPadding)
            .cpwCard()
        }
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    // MARK: - Helpers

    private func itemThumbnail(_ item: WardrobeItem) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(CPWTheme.background)

            if let photoData = item.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: CPWTheme.categoryIcons[item.safeCategory] ?? "hanger")
                    .font(.system(size: 14))
                    .foregroundStyle(CPWTheme.secondaryText.opacity(0.5))
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Analytics Item Row

struct AnalyticsItemRow: View {
    let rank: Int
    @ObservedObject var item: WardrobeItem
    let accentColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(accentColor)
                .frame(width: 30)

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(CPWTheme.background)
                if let photoData = item.photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: CPWTheme.categoryIcons[item.safeCategory] ?? "hanger")
                        .font(.system(size: 14))
                        .foregroundStyle(CPWTheme.secondaryText.opacity(0.5))
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.safeName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CPWTheme.primaryText)
                    .lineLimit(1)
                Text("\(item.wearCount) wears")
                    .font(.system(size: 12))
                    .foregroundStyle(CPWTheme.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.formattedCPW)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
                Text("/ wear")
                    .font(.system(size: 10))
                    .foregroundStyle(CPWTheme.secondaryText)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AnalyticsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
