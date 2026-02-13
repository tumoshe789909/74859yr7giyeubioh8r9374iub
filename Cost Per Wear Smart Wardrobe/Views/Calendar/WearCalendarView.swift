import SwiftUI
import CoreData

// MARK: - Wear Calendar

struct WearCalendarView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var currentMonth = Date()
    @State private var selectedDate: Date?
    @State private var selectedDateItems: [WardrobeItem] = []

    private var engine: AnalyticsEngine {
        AnalyticsEngine(context: viewContext)
    }

    private let weekdays: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let symbols = formatter.veryShortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        // Reorder so Monday is first
        let firstWeekday = Calendar.current.firstWeekday
        if firstWeekday == 2 { // Monday-first
            return Array(symbols[1...]) + [symbols[0]]
        }
        return symbols
    }()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        NavigationStack {
            ZStack {
                CPWTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: CPWTheme.sectionSpacing) {

                        // Month Navigation
                        monthHeader

                        // Month Summary
                        monthSummary

                        // Calendar Grid
                        calendarGrid

                        // Legend
                        legend

                        // Selected Day Detail
                        if let date = selectedDate {
                            selectedDayDetail(date: date)
                        }

                        DisclaimerFooter()
                            .padding(.bottom, 20)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Calendar")
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    selectedDate = nil
                }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title3)
                    .foregroundStyle(CPWTheme.accent)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(currentMonth.formatted(.dateTime.month(.wide)))
                    .font(CPWTheme.titleFont)
                    .foregroundStyle(CPWTheme.primaryText)
                Text(currentMonth.formatted(.dateTime.year()))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(CPWTheme.secondaryText)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    selectedDate = nil
                }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(CPWTheme.accent)
            }
        }
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    // MARK: - Month Summary

    private var monthSummary: some View {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        let monthStart = calendar.date(from: components)!
        let range = calendar.range(of: .day, in: .month, for: monthStart)!

        let totalWears = range.reduce(0) { total, day in
            let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart)!
            return total + engine.wearCountForDate(date)
        }

        let activeDays = range.filter { day in
            let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart)!
            return engine.wearCountForDate(date) > 0
        }.count

        return HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("\(totalWears)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(CPWTheme.primaryText)
                Text("Total Wears")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CPWTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 30)

            VStack(spacing: 2) {
                Text("\(activeDays)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(CPWTheme.accent)
                Text("Active Days")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CPWTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 30)

            VStack(spacing: 2) {
                let avgPerDay = activeDays > 0 ? Double(totalWears) / Double(activeDays) : 0
                Text(String(format: "%.1f", avgPerDay))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(CPWTheme.primaryText)
                Text("Avg / Day")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CPWTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
        .cpwCard()
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        VStack(spacing: 8) {
            // Weekday Headers
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CPWTheme.secondaryText)
                        .frame(height: 24)
                }
            }

            // Days
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        dayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 48)
                    }
                }
            }
        }
        .padding(CPWTheme.cardPadding)
        .cpwCard()
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    private func dayCell(for date: Date) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let count = engine.wearCountForDate(date)
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isFuture = date > Date()

        return Button {
            if !isFuture {
                withAnimation(.spring(response: 0.3)) {
                    selectedDate = date
                    loadSelectedDateItems(date)
                }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(cellColor(count: count, isToday: isToday, isSelected: isSelected))

                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 14, weight: isToday ? .bold : .regular))
                        .foregroundStyle(
                            isFuture ? CPWTheme.secondaryText.opacity(0.3) :
                            isSelected ? .white :
                            isToday ? CPWTheme.accent :
                            CPWTheme.primaryText
                        )

                    if count > 0 && !isSelected {
                        Circle()
                            .fill(CPWTheme.accent)
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .frame(height: 48)
        }
        .disabled(isFuture)
    }

    private func cellColor(count: Int, isToday: Bool, isSelected: Bool) -> Color {
        if isSelected { return CPWTheme.accent }
        if count == 0 { return .clear }
        if count <= 2 { return CPWTheme.calendarLight }
        if count <= 4 { return CPWTheme.calendarMedium.opacity(0.4) }
        return CPWTheme.calendarDark.opacity(0.3)
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: .clear, borderColor: CPWTheme.separator, label: "No wears")
            legendItem(color: CPWTheme.calendarLight, borderColor: .clear, label: "1–2")
            legendItem(color: CPWTheme.calendarMedium.opacity(0.4), borderColor: .clear, label: "3–4")
            legendItem(color: CPWTheme.calendarDark.opacity(0.3), borderColor: .clear, label: "5+")
        }
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    private func legendItem(color: Color, borderColor: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .stroke(borderColor, lineWidth: 1)
                .frame(width: 14, height: 14)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(CPWTheme.secondaryText)
        }
    }

    // MARK: - Selected Day Detail

    private func selectedDayDetail(date: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                .font(CPWTheme.headlineFont)
                .foregroundStyle(CPWTheme.primaryText)

            let count = engine.wearCountForDate(date)
            if count == 0 {
                HStack {
                    Image(systemName: "moon.zzz")
                        .foregroundStyle(CPWTheme.secondaryText)
                    Text("No items worn this day")
                        .font(CPWTheme.bodyFont)
                        .foregroundStyle(CPWTheme.secondaryText)
                }
            } else {
                Text("\(count) item\(count == 1 ? "" : "s") worn")
                    .font(CPWTheme.captionFont)
                    .foregroundStyle(CPWTheme.accent)

                let categories = engine.categoriesWornOnDate(date)
                if !categories.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(categories, id: \.self) { cat in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(CPWTheme.categoryColors[cat] ?? .gray)
                                    .frame(width: 6, height: 6)
                                Text(cat)
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CPWTheme.primaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(CPWTheme.accent.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }

                ForEach(selectedDateItems, id: \.objectID) { item in
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(CPWTheme.background)
                            if let photoData = item.photoData, let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: CPWTheme.categoryIcons[item.safeCategory] ?? "hanger")
                                    .font(.system(size: 12))
                                    .foregroundStyle(CPWTheme.secondaryText.opacity(0.5))
                            }
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        Text(item.safeName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(CPWTheme.primaryText)

                        Spacer()

                        Text(item.formattedCPW)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(CPWTheme.accent)
                    }
                }
            }
        }
        .padding(CPWTheme.cardPadding)
        .cpwCard()
        .padding(.horizontal, CPWTheme.cardPadding)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Helpers

    private func daysInMonth() -> [Date?] {
        let calendar = Calendar.current

        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))
        else {
            return []
        }

        var weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)
        // Adjust based on calendar first weekday
        if calendar.firstWeekday == 2 { // Monday first
            weekdayOfFirst = weekdayOfFirst == 1 ? 7 : weekdayOfFirst - 1
        }
        let leadingEmpty = weekdayOfFirst - (calendar.firstWeekday == 2 ? 1 : 0)

        var dates: [Date?] = Array(repeating: nil, count: max(leadingEmpty, 0))

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                dates.append(date)
            }
        }

        while dates.count % 7 != 0 {
            dates.append(nil)
        }

        return dates
    }

    private func loadSelectedDateItems(_ date: Date) {
        let logs = PersistenceController.shared.wearLogsForDate(date)
        selectedDateItems = logs.compactMap { $0.item }
    }
}

// MARK: - Flow Layout (for category chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            if index < result.positions.count {
                subview.place(
                    at: CGPoint(
                        x: bounds.minX + result.positions[index].x,
                        y: bounds.minY + result.positions[index].y
                    ),
                    proposal: ProposedViewSize(result.sizes[index])
                )
            }
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], sizes: [CGSize], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)

            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, sizes, CGSize(width: maxX, height: y + rowHeight))
    }
}

#Preview {
    WearCalendarView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
