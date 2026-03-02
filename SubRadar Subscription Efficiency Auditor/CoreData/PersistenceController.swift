import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.container.viewContext
        let categories = ["Entertainment", "Education", "Productivity", "Health", "Music"]
        let names = ["Streaming Platform", "Learning App", "Task Manager", "Fitness Tracker", "Music Player"]
        for i in 0..<5 {
            let sub = CDSubscription(context: ctx)
            sub.id = UUID()
            sub.name = names[i]
            sub.monthlyCost = [14.99, 9.99, 4.99, 12.99, 10.99][i]
            sub.currency = "USD"
            sub.category = categories[i]
            sub.usageCount = [18, 5, 25, 2, 12][i]
            sub.status = i == 3 ? "zombie" : "active"
            sub.createdAt = Calendar.current.date(byAdding: .month, value: -Int.random(in: 1...6), to: Date())
            sub.isMarkedForKill = i == 3

            for j in 0..<Int.random(in: 3...10) {
                let log = CDUsageLog(context: ctx)
                log.id = UUID()
                log.date = Calendar.current.date(byAdding: .day, value: -j * 3, to: Date())
                log.uses = Int16.random(in: 1...4)
                log.subscription = sub
            }
        }

        let canceled = CDSubscription(context: ctx)
        canceled.id = UUID()
        canceled.name = "Old Cloud Service"
        canceled.monthlyCost = 7.99
        canceled.currency = "USD"
        canceled.category = "Cloud Storage"
        canceled.status = "canceled"
        canceled.createdAt = Calendar.current.date(byAdding: .month, value: -8, to: Date())
        canceled.canceledDate = Calendar.current.date(byAdding: .month, value: -2, to: Date())

        try? ctx.save()
        return controller
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SubRadar")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        let persistentContainer = container
        persistentContainer.loadPersistentStores { description, error in
            if let error = error as NSError? {
                print("[SubRadar] Core Data failed to load: \(error), \(error.userInfo)")
                if let storeURL = description.url {
                    try? FileManager.default.removeItem(at: storeURL)
                    persistentContainer.loadPersistentStores { _, retryError in
                        if let retryError {
                            print("[SubRadar] Core Data retry also failed: \(retryError)")
                        }
                    }
                }
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
