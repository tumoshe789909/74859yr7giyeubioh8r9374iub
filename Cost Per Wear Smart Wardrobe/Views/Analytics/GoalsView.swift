import SwiftUI
import CoreData

// MARK: - Sustainability Goals

struct GoalsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SustainabilityGoal.createdAt, ascending: false)],
        animation: .easeInOut(duration: 0.3)
    )
    private var goals: FetchedResults<SustainabilityGoal>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WardrobeItem.name, ascending: true)],
        predicate: NSPredicate(format: "archived == NO"),
        animation: .easeInOut(duration: 0.3)
    )
    private var items: FetchedResults<WardrobeItem>

    @State private var showAddGoal = false

    var body: some View {
        ZStack {
            CPWTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: CPWTheme.sectionSpacing) {

                    // Active Goals
                    if goals.isEmpty {
                        goalsEmptyState
                    } else {
                        goalsSection
                    }

                    // Achievements
                    achievementsSection

                    DisclaimerFooter()
                        .padding(.bottom, 20)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Goals")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddGoal = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(CPWTheme.accent)
                }
            }
        }
        .sheet(isPresented: $showAddGoal) {
            AddGoalSheet(items: Array(items))
        }
    }

    // MARK: - Goals Empty State

    private var goalsEmptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(CPWTheme.accent.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "target")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(CPWTheme.accent)
            }

            Text("Set Your First Goal")
                .font(CPWTheme.titleFont)
                .foregroundStyle(CPWTheme.primaryText)

            Text("Create sustainability goals to track your mindful consumption journey.")
                .font(CPWTheme.bodyFont)
                .foregroundStyle(CPWTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showAddGoal = true
            } label: {
                Label("Add Goal", systemImage: "plus")
                    .font(CPWTheme.headlineFont)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(CPWTheme.accentGradient)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 32)
    }

    // MARK: - Goals Section

    private var goalsSection: some View {
        VStack(spacing: 12) {
            ForEach(goals, id: \.objectID) { goal in
                GoalCard(goal: goal, items: Array(items))
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation {
                                PersistenceController.shared.deleteGoal(goal)
                            }
                        } label: {
                            Label("Delete Goal", systemImage: "trash")
                        }
                    }
            }
        }
        .padding(.horizontal, CPWTheme.cardPadding)
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        let achievementEngine = AchievementEngine(context: viewContext)
        let allAchievements = achievementEngine.achievements
        let unlockedCount = allAchievements.filter(\.isUnlocked).count

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Achievements")
                    .font(CPWTheme.titleFont)
                    .foregroundStyle(CPWTheme.primaryText)
                Spacer()
                Text("\(unlockedCount)/\(allAchievements.count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(CPWTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(CPWTheme.accent.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, CPWTheme.cardPadding)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(allAchievements) { achievement in
                    achievementCard(achievement)
                }
            }
            .padding(.horizontal, CPWTheme.cardPadding)
        }
    }

    private func achievementCard(_ achievement: Achievement) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? CPWTheme.accent.opacity(0.15) : CPWTheme.separator.opacity(0.3))
                    .frame(width: 52, height: 52)

                Image(systemName: achievement.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(achievement.isUnlocked ? CPWTheme.accent : CPWTheme.secondaryText.opacity(0.3))
            }

            Text(achievement.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(achievement.isUnlocked ? CPWTheme.primaryText : CPWTheme.secondaryText)
                .lineLimit(1)

            Text(achievement.description)
                .font(.system(size: 10))
                .foregroundStyle(CPWTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(CPWTheme.cardPadding)
        .frame(maxWidth: .infinity)
        .cpwCard()
        .opacity(achievement.isUnlocked ? 1.0 : 0.6)
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    @ObservedObject var goal: SustainabilityGoal
    let items: [WardrobeItem]

    private var currentProgress: Double {
        switch goal.goalType ?? "" {
        case "AverageCPW":
            let wornItems = items.filter { $0.wearCount > 0 }
            guard !wornItems.isEmpty else { return 0 }
            let avgCPW = wornItems.reduce(0.0) { $0 + $1.costPerWear } / Double(wornItems.count)
            return goal.targetValue > 0 ? min(goal.targetValue / max(avgCPW, 0.01), 1.0) : 0
        case "WearCount":
            if let linkedID = goal.linkedItemID,
               let item = items.first(where: { $0.id == linkedID }) {
                return goal.targetValue > 0 ? min(Double(item.wearCount) / goal.targetValue, 1.0) : 0
            }
            return 0
        default:
            return 0
        }
    }

    private var currentValueText: String {
        switch goal.goalType ?? "" {
        case "AverageCPW":
            let wornItems = items.filter { $0.wearCount > 0 }
            guard !wornItems.isEmpty else { return CurrencyManager.shared.format(0) }
            let avgCPW = wornItems.reduce(0.0) { $0 + $1.costPerWear } / Double(wornItems.count)
            return CurrencyManager.shared.format(avgCPW)
        case "WearCount":
            if let linkedID = goal.linkedItemID,
               let item = items.first(where: { $0.id == linkedID }) {
                return "\(item.wearCount)"
            }
            return "0"
        default:
            return "—"
        }
    }

    private var isCompleted: Bool {
        currentProgress >= 1.0
    }

    private var motivationalMessage: String {
        if isCompleted { return "Goal achieved! Keep going!" }
        if currentProgress > 0.75 { return "Almost there — you're doing great!" }
        if currentProgress > 0.5 { return "Over halfway! Stay consistent." }
        if currentProgress > 0.25 { return "Good progress — keep wearing mindfully." }
        return "Every wear counts toward your goal."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: isCompleted ? "checkmark.seal.fill" : "target")
                    .foregroundStyle(isCompleted ? CPWTheme.success : CPWTheme.accent)

                Text(goal.title ?? "Goal")
                    .font(CPWTheme.headlineFont)
                    .foregroundStyle(CPWTheme.primaryText)

                Spacer()

                if isCompleted {
                    Text("Done!")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(CPWTheme.success)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(CPWTheme.success.opacity(0.1))
                        .clipShape(Capsule())
                } else {
                    Text("\(Int(currentProgress * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(CPWTheme.accent)
                }
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(CPWTheme.separator)

                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isCompleted ? CPWTheme.success.gradient : CPWTheme.accent.gradient)
                            .frame(width: geometry.size.width * min(currentProgress, 1.0))
                            .animation(.easeOut(duration: 0.8), value: currentProgress)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("Current: \(currentValueText)")
                        .font(.system(size: 11))
                        .foregroundStyle(CPWTheme.secondaryText)
                    Spacer()
                    let targetText = goal.goalType == "AverageCPW"
                        ? "Target: \(CurrencyManager.shared.format(goal.targetValue))"
                        : "Target: \(Int(goal.targetValue))"
                    Text(targetText)
                        .font(.system(size: 11))
                        .foregroundStyle(CPWTheme.secondaryText)
                }
            }

            // Motivational message
            Text(motivationalMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isCompleted ? CPWTheme.success : CPWTheme.accent.opacity(0.8))
                .italic()
        }
        .padding(CPWTheme.cardPadding)
        .cpwCard()
    }
}

// MARK: - Add Goal Sheet

struct AddGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    let items: [WardrobeItem]

    @State private var title = ""
    @State private var goalType = "AverageCPW"
    @State private var targetValueText = ""
    @State private var selectedItemID: UUID?

    let goalTypes = [
        ("AverageCPW", "Lower Average CPW"),
        ("WearCount", "Wear Item X Times")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                CPWTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 16) {
                            fieldRow(title: "Goal Title") {
                                TextField("e.g. Lower avg CPW to $3", text: $title)
                                    .font(CPWTheme.bodyFont)
                            }

                            fieldRow(title: "Goal Type") {
                                Picker("Type", selection: $goalType) {
                                    ForEach(goalTypes, id: \.0) { type in
                                        Text(type.1).tag(type.0)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            if goalType == "WearCount" && !items.isEmpty {
                                fieldRow(title: "Item") {
                                    Picker("Select Item", selection: $selectedItemID) {
                                        Text("Select…").tag(nil as UUID?)
                                        ForEach(items, id: \.id) { item in
                                            Text(item.safeName).tag(item.id as UUID?)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(CPWTheme.primaryText)
                                }
                            }

                            fieldRow(title: goalType == "AverageCPW" ? "Target CPW" : "Target Wears") {
                                HStack {
                                    if goalType == "AverageCPW" {
                                        Text(CurrencyManager.shared.currencySymbol)
                                            .foregroundStyle(CPWTheme.secondaryText)
                                    }
                                    TextField("0", text: $targetValueText)
                                        .keyboardType(.decimalPad)
                                        .font(CPWTheme.bodyFont)
                                }
                            }
                        }
                        .padding(CPWTheme.cardPadding)
                        .cpwCard()
                        .padding(.horizontal, CPWTheme.cardPadding)

                        Button(action: saveGoal) {
                            Text("Create Goal")
                                .font(CPWTheme.headlineFont)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(canSave ? CPWTheme.accentGradient : LinearGradient(colors: [CPWTheme.secondaryText.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                                .clipShape(RoundedRectangle(cornerRadius: CPWTheme.cornerRadius, style: .continuous))
                        }
                        .disabled(!canSave)
                        .padding(.horizontal, CPWTheme.cardPadding)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(CPWTheme.secondaryText)
                }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(targetValueText.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0 &&
        (goalType != "WearCount" || selectedItemID != nil)
    }

    private func saveGoal() {
        let target = Double(targetValueText.replacingOccurrences(of: ",", with: ".")) ?? 0
        PersistenceController.shared.createGoal(
            title: title.trimmingCharacters(in: .whitespaces),
            targetValue: target,
            goalType: goalType,
            linkedItemID: goalType == "WearCount" ? selectedItemID : nil
        )
        dismiss()
    }

    private func fieldRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CPWTheme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
            Divider()
        }
    }
}

#Preview {
    NavigationStack {
        GoalsView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
