import SwiftUI
import CoreData

// MARK: - Wardrobe Hub (Main Screen)

struct WardrobeHubView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WardrobeItem.createdAt, ascending: false)],
        predicate: NSPredicate(format: "archived == NO"),
        animation: .easeInOut(duration: 0.3)
    )
    private var items: FetchedResults<WardrobeItem>

    @State private var showingAddItem = false
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var showWornToast = false
    @State private var lastWornItemName = ""
    @State private var sortMode: SortMode = .newest

    enum SortMode: String, CaseIterable {
        case newest = "Newest"
        case lowestCPW = "Best CPW"
        case highestCPW = "Worst CPW"
        case mostWorn = "Most Worn"
    }

    private let columns = [
        GridItem(.flexible(), spacing: CPWTheme.gridSpacing),
        GridItem(.flexible(), spacing: CPWTheme.gridSpacing)
    ]

    private var filteredItems: [WardrobeItem] {
        var result = Array(items)

        if !searchText.isEmpty {
            result = result.filter {
                ($0.name ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.brand ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.category ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        switch sortMode {
        case .newest:
            break // already sorted by createdAt desc
        case .lowestCPW:
            result.sort { $0.costPerWear < $1.costPerWear }
        case .highestCPW:
            result.sort { $0.costPerWear > $1.costPerWear }
        case .mostWorn:
            result.sort { $0.wearCount > $1.wearCount }
        }

        return result
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
                            // Quick summary bar
                            quickSummaryBar

                            // Category filter chips
                            categoryFilter

                            // Sort bar
                            sortBar

                            // Items grid
                            LazyVGrid(columns: columns, spacing: CPWTheme.gridSpacing) {
                                ForEach(filteredItems, id: \.objectID) { item in
                                    NavigationLink(value: item.objectID) {
                                        ItemCardView(item: item)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button {
                                            logWear(for: item)
                                        } label: {
                                            Label("Worn Today", systemImage: "checkmark.circle")
                                        }

                                        Button(role: .destructive) {
                                            archiveItem(item)
                                        } label: {
                                            Label("Archive", systemImage: "archivebox")
                                        }
                                    }
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                }
                            }
                            .padding(.horizontal, CPWTheme.cardPadding)

                            DisclaimerFooter()
                                .padding(.bottom, 20)
                        }
                    }
                }

                // Toast overlay
                if showWornToast {
                    VStack {
                        Spacer()
                        toastView
                            .padding(.bottom, 100)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.spring(response: 0.4), value: showWornToast)
                }
            }
            .navigationTitle("Wardrobe")
            .searchable(text: $searchText, prompt: "Search items...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddItem = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(CPWTheme.accent)
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView()
            }
            .navigationDestination(for: NSManagedObjectID.self) { objectID in
                if let item = try? viewContext.existingObject(with: objectID) as? WardrobeItem {
                    ItemDetailView(item: item)
                }
            }
        }
    }

    // MARK: - Quick Summary Bar

    private var quickSummaryBar: some View {
        let wornItems = items.filter { $0.wearCount > 0 }
        let avgCPW = wornItems.isEmpty ? 0 : wornItems.reduce(0.0) { $0 + $1.costPerWear } / Double(wornItems.count)

        return HStack(spacing: 0) {
            miniStat(value: "\(items.count)", label: "Items")
            Divider().frame(height: 30)
            miniStat(value: CurrencyManager.shared.formatCompact(avgCPW), label: "Avg CPW")
            Divider().frame(height: 30)
            miniStat(
                value: "\(items.reduce(0) { $0 + Int($1.wearCount) })",
                label: "Wears"
            )
        }
        .padding(.vertical, 10)
        .cpwCard()
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(CPWTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(CPWTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(CPWTheme.accent.opacity(0.1))
                    .frame(width: 130, height: 130)

                Image(systemName: "hanger")
                    .font(.system(size: 56, weight: .ultraLight))
                    .foregroundStyle(CPWTheme.accent)
            }

            VStack(spacing: 8) {
                Text("Your Wardrobe Awaits")
                    .font(CPWTheme.titleFont)
                    .foregroundStyle(CPWTheme.primaryText)

                Text(CPWTheme.emptyStateQuotes.randomElement() ?? "")
                    .font(CPWTheme.bodyFont)
                    .foregroundStyle(CPWTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                showingAddItem = true
            } label: {
                Label("Add Your First Item", systemImage: "plus")
                    .font(CPWTheme.headlineFont)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(CPWTheme.accentGradient)
                    .clipShape(Capsule())
            }

            Spacer()
            DisclaimerFooter()
        }
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                categoryChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }

                ForEach(activeCategories, id: \.self) { category in
                    categoryChip(title: category, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, CPWTheme.cardPadding)
        }
    }

    private var activeCategories: [String] {
        let cats = Set(items.compactMap { $0.category })
        return CPWTheme.categories.filter { cats.contains($0) }
    }

    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if title != "All", let icon = CPWTheme.categoryIcons[title] {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                }
                Text(title)
            }
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? .white : CPWTheme.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? CPWTheme.accent : CPWTheme.cardBackground)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(isSelected ? 0 : 0.04), radius: 4, y: 2)
        }
    }

    // MARK: - Sort Bar

    private var sortBar: some View {
        HStack {
            Text("\(filteredItems.count) items")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CPWTheme.secondaryText)

            Spacer()

            Menu {
                ForEach(SortMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation { sortMode = mode }
                    } label: {
                        HStack {
                            Text(mode.rawValue)
                            if sortMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11))
                    Text(sortMode.rawValue)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(CPWTheme.accent)
            }
        }
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    // MARK: - Toast

    private var toastView: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(CPWTheme.success)
            Text("\(lastWornItemName) marked as worn today")
                .font(CPWTheme.captionFont)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .background(CPWTheme.primaryText.opacity(0.8))
        .clipShape(Capsule())
    }

    // MARK: - Actions

    private func logWear(for item: WardrobeItem) {
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()

        PersistenceController.shared.logWear(for: item)
        lastWornItemName = item.safeName

        withAnimation {
            showWornToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showWornToast = false
            }
        }
    }

    private func archiveItem(_ item: WardrobeItem) {
        withAnimation {
            PersistenceController.shared.archiveItem(item)
        }
    }
}

// MARK: - Item Card

struct ItemCardView: View {
    @ObservedObject var item: WardrobeItem
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Photo
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: CPWTheme.smallCornerRadius, style: .continuous)
                        .fill(CPWTheme.background)

                    if let photoData = item.photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: CPWTheme.categoryIcons[item.safeCategory] ?? "hanger")
                            .font(.system(size: 36, weight: .ultraLight))
                            .foregroundStyle(CPWTheme.secondaryText.opacity(0.5))
                    }
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: CPWTheme.smallCornerRadius, style: .continuous))

                // Efficiency badge
                if item.wearCount > 0 {
                    EfficiencyBadge(score: item.efficiencyScore)
                        .padding(6)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.safeName)
                    .font(CPWTheme.headlineFont)
                    .foregroundStyle(CPWTheme.primaryText)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(item.formattedCPW)
                        .font(CPWTheme.cpwCardFont)
                        .foregroundStyle(item.isEfficient ? CPWTheme.accent : CPWTheme.secondaryText)

                    Text("/ wear")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(CPWTheme.secondaryText)
                }

                HStack(spacing: 6) {
                    Text("\(item.wearCount) wear\(item.wearCount == 1 ? "" : "s")")
                        .font(CPWTheme.captionFont)
                        .foregroundStyle(CPWTheme.secondaryText)

                    if let daysSince = item.daysSinceLastWorn, daysSince > 0 {
                        Text("·")
                            .foregroundStyle(CPWTheme.separator)
                        Text("\(daysSince)d ago")
                            .font(CPWTheme.captionFont)
                            .foregroundStyle(daysSince > 30 ? .orange : CPWTheme.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .padding(10)
        .cpwCard()
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.05)) {
                appeared = true
            }
        }
    }
}

#Preview {
    WardrobeHubView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
