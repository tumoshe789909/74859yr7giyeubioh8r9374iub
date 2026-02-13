import SwiftUI
import CoreData

// MARK: - OOTD Tracker (Daily Outfit)

struct OOTDTrackerView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WardrobeItem.name, ascending: true)],
        predicate: NSPredicate(format: "archived == NO"),
        animation: .easeInOut(duration: 0.3)
    )
    private var items: FetchedResults<WardrobeItem>

    @State private var selectedItems: Set<NSManagedObjectID> = []
    @State private var showConfirmation = false
    @State private var recentDays: [(date: Date, count: Int)] = []

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                CPWTheme.background.ignoresSafeArea()

                if items.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: CPWTheme.sectionSpacing) {

                            // Today's Selection Header
                            todayHeader

                            // Recent Days Preview
                            if !recentDays.isEmpty {
                                recentDaysPreview
                            }

                            // Items to select
                            VStack(alignment: .leading, spacing: 12) {
                                Text("TAP TO SELECT TODAY'S OUTFIT")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(CPWTheme.secondaryText)
                                    .tracking(1)
                                    .padding(.horizontal, CPWTheme.cardPadding)

                                LazyVGrid(columns: columns, spacing: 10) {
                                    ForEach(items, id: \.objectID) { item in
                                        OOTDItemCard(
                                            item: item,
                                            isSelected: selectedItems.contains(item.objectID)
                                        )
                                        .onTapGesture {
                                            toggleSelection(item)
                                        }
                                    }
                                }
                                .padding(.horizontal, CPWTheme.cardPadding)
                            }

                            // Log Button
                            if !selectedItems.isEmpty {
                                Button(action: logOutfit) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20))
                                        Text("Log Today's Outfit (\(selectedItems.count) items)")
                                    }
                                    .font(CPWTheme.headlineFont)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(CPWTheme.accentGradient)
                                    .clipShape(RoundedRectangle(cornerRadius: CPWTheme.cornerRadius, style: .continuous))
                                }
                                .padding(.horizontal, CPWTheme.cardPadding)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }

                            DisclaimerFooter()
                                .padding(.bottom, 20)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Today's Outfit")
            .overlay {
                if showConfirmation {
                    confirmationOverlay
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .onAppear {
                loadRecentDays()
                preSelectTodayItems()
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
                Image(systemName: "tshirt")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(CPWTheme.accent)
            }
            Text("No Items Yet")
                .font(CPWTheme.titleFont)
                .foregroundStyle(CPWTheme.primaryText)
            Text("Add items to your wardrobe first, then come back to log your daily outfit.")
                .font(CPWTheme.bodyFont)
                .foregroundStyle(CPWTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            DisclaimerFooter()
        }
    }

    // MARK: - Today Header

    private var todayHeader: some View {
        VStack(spacing: 8) {
            Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(CPWTheme.titleFont)
                .foregroundStyle(CPWTheme.primaryText)

            if selectedItems.isEmpty {
                Text("Select items you're wearing today")
                    .font(CPWTheme.captionFont)
                    .foregroundStyle(CPWTheme.secondaryText)
            } else {
                Text("\(selectedItems.count) item\(selectedItems.count == 1 ? "" : "s") selected")
                    .font(CPWTheme.captionFont)
                    .foregroundStyle(CPWTheme.accent)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Recent Days Preview

    private var recentDaysPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT DAYS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CPWTheme.secondaryText)
                .tracking(1)
                .padding(.horizontal, CPWTheme.cardPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(recentDays, id: \.date) { day in
                        VStack(spacing: 6) {
                            Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(CPWTheme.secondaryText)

                            ZStack {
                                Circle()
                                    .fill(day.count > 0 ? CPWTheme.accent.opacity(0.15) : CPWTheme.separator.opacity(0.5))
                                    .frame(width: 44, height: 44)

                                Text("\(day.count)")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(day.count > 0 ? CPWTheme.accent : CPWTheme.secondaryText)
                            }

                            Text(day.date.formatted(.dateTime.day()))
                                .font(.system(size: 10))
                                .foregroundStyle(CPWTheme.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, CPWTheme.cardPadding)
            }
        }
    }

    // MARK: - Confirmation Overlay

    private var confirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(CPWTheme.success)

                Text("Outfit Logged!")
                    .font(CPWTheme.titleFont)
                    .foregroundStyle(CPWTheme.primaryText)

                Text("\(selectedItems.count) items recorded for today")
                    .font(CPWTheme.bodyFont)
                    .foregroundStyle(CPWTheme.secondaryText)
            }
            .padding(40)
            .background(CPWTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CPWTheme.largeCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
        }
    }

    // MARK: - Actions

    private func toggleSelection(_ item: WardrobeItem) {
        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()

        withAnimation(.spring(response: 0.3)) {
            if selectedItems.contains(item.objectID) {
                selectedItems.remove(item.objectID)
            } else {
                selectedItems.insert(item.objectID)
            }
        }
    }

    private func logOutfit() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)

        for objectID in selectedItems {
            if let item = try? viewContext.existingObject(with: objectID) as? WardrobeItem {
                PersistenceController.shared.logWear(for: item)
            }
        }

        withAnimation(.spring(response: 0.4)) {
            showConfirmation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.4)) {
                showConfirmation = false
                selectedItems.removeAll()
                loadRecentDays()
            }
        }
    }

    private func loadRecentDays() {
        let calendar = Calendar.current
        let engine = AnalyticsEngine(context: viewContext)
        recentDays = (0..<7).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: Date())!
            let count = engine.wearCountForDate(date)
            return (date: date, count: count)
        }
    }

    private func preSelectTodayItems() {
        let todayLogs = PersistenceController.shared.wearLogsForDate(Date())
        for log in todayLogs {
            if let item = log.item {
                selectedItems.insert(item.objectID)
            }
        }
    }
}

// MARK: - OOTD Item Card

struct OOTDItemCard: View {
    @ObservedObject var item: WardrobeItem
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: CPWTheme.smallCornerRadius, style: .continuous)
                    .fill(CPWTheme.background)

                if let photoData = item.photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: CPWTheme.categoryIcons[item.safeCategory] ?? "hanger")
                        .font(.system(size: 28, weight: .ultraLight))
                        .foregroundStyle(CPWTheme.secondaryText.opacity(0.4))
                }

                if isSelected {
                    RoundedRectangle(cornerRadius: CPWTheme.smallCornerRadius, style: .continuous)
                        .fill(CPWTheme.accent.opacity(0.2))

                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(CPWTheme.accent)
                }
            }
            .frame(height: 110)
            .clipShape(RoundedRectangle(cornerRadius: CPWTheme.smallCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CPWTheme.smallCornerRadius, style: .continuous)
                    .stroke(isSelected ? CPWTheme.accent : Color.clear, lineWidth: 2)
            )

            Text(item.safeName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(CPWTheme.primaryText)
                .lineLimit(1)
        }
        .scaleEffect(isSelected ? 0.95 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

#Preview {
    OOTDTrackerView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
