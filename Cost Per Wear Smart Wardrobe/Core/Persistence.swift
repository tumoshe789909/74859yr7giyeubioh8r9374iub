import CoreData

// MARK: - Core Data Stack

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        return result
    }()

    let container: NSPersistentContainer

    /// Indicates if the persistent store loaded successfully
    private(set) var loadError: Error?

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "CostPerWear")

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        var capturedError: Error?
        container.loadPersistentStores { _, error in
            if let error = error {
                capturedError = error
                print("Core Data store failed to load: \(error.localizedDescription)")
            }
        }
        self.loadError = capturedError

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Save

    func save() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            print("Core Data save error: \(nsError), \(nsError.userInfo)")
        }
    }

    // MARK: - Wear Logging

    func logWear(for item: WardrobeItem) {
        let context = container.viewContext
        let log = WearLog(context: context)
        log.id = UUID()
        log.date = Date()
        log.item = item
        item.wearCount += 1
        save()
    }

    func hasLoggedWearToday(for item: WardrobeItem) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let request: NSFetchRequest<WearLog> = WearLog.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "item == %@", item),
            NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        ])

        let count = (try? container.viewContext.count(for: request)) ?? 0
        return count > 0
    }

    // MARK: - Item CRUD

    func createItem(
        name: String,
        category: String,
        brand: String?,
        purchasePrice: Double,
        purchaseDate: Date,
        photoData: Data?
    ) -> WardrobeItem {
        let context = container.viewContext
        let item = WardrobeItem(context: context)
        item.id = UUID()
        item.name = name
        item.category = category
        item.brand = brand
        item.purchasePrice = purchasePrice
        item.purchaseDate = purchaseDate
        item.photoData = photoData
        item.wearCount = 0
        item.archived = false
        item.createdAt = Date()
        save()
        return item
    }

    func updateItem(
        _ item: WardrobeItem,
        name: String,
        category: String,
        brand: String?,
        purchasePrice: Double,
        purchaseDate: Date,
        photoData: Data?
    ) {
        item.name = name
        item.category = category
        item.brand = brand
        item.purchasePrice = purchasePrice
        item.purchaseDate = purchaseDate
        item.photoData = photoData
        save()
    }

    func deleteItem(_ item: WardrobeItem) {
        container.viewContext.delete(item)
        save()
    }

    func archiveItem(_ item: WardrobeItem) {
        item.archived = true
        save()
    }

    func unarchiveItem(_ item: WardrobeItem) {
        item.archived = false
        save()
    }

    // MARK: - Goals

    func createGoal(title: String, targetValue: Double, goalType: String, linkedItemID: UUID? = nil) {
        let context = container.viewContext
        let goal = SustainabilityGoal(context: context)
        goal.id = UUID()
        goal.title = title
        goal.targetValue = targetValue
        goal.goalType = goalType
        goal.linkedItemID = linkedItemID
        goal.createdAt = Date()
        save()
    }

    func deleteGoal(_ goal: SustainabilityGoal) {
        container.viewContext.delete(goal)
        save()
    }

    // MARK: - Analytics Queries

    func wearLogsForDate(_ date: Date) -> [WearLog] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let request: NSFetchRequest<WearLog> = WearLog.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WearLog.date, ascending: true)]

        return (try? container.viewContext.fetch(request)) ?? []
    }

    func wearLogsForItem(_ item: WardrobeItem) -> [WearLog] {
        let request: NSFetchRequest<WearLog> = WearLog.fetchRequest()
        request.predicate = NSPredicate(format: "item == %@", item)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WearLog.date, ascending: true)]
        return (try? container.viewContext.fetch(request)) ?? []
    }

    func allActiveItems() -> [WardrobeItem] {
        let request: NSFetchRequest<WardrobeItem> = WardrobeItem.fetchRequest()
        request.predicate = NSPredicate(format: "archived == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WardrobeItem.createdAt, ascending: false)]
        return (try? container.viewContext.fetch(request)) ?? []
    }

    func allWearLogs() -> [WearLog] {
        let request: NSFetchRequest<WearLog> = WearLog.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WearLog.date, ascending: true)]
        return (try? container.viewContext.fetch(request)) ?? []
    }

    // MARK: - Clear All Data

    func clearAllData() {
        let entities = ["WearLog", "SustainabilityGoal", "WardrobeItem"]
        for entityName in entities {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDelete = NSBatchDeleteRequest(fetchRequest: request)
            _ = try? container.viewContext.execute(batchDelete)
        }
        save()
    }
}
