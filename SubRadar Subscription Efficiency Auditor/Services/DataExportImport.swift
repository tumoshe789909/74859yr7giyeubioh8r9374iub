import Foundation
import CoreData

struct ExportData: Codable {
    let exportedAt: Date
    let version: Int
    let subscriptions: [ExportedSubscription]
}

struct ExportedSubscription: Codable {
    let id: UUID
    let name: String
    let monthlyCost: Double
    let currency: String
    let category: String?
    let status: String
    let usageCount: Int64
    let createdAt: Date
    let canceledDate: Date?
    let isMarkedForKill: Bool
    let billingCycle: String?
    let nextRenewalDate: Date?
    let logs: [ExportedUsageLog]
}

struct ExportedUsageLog: Codable {
    let id: UUID
    let date: Date
    let uses: Int16
}

enum DataExportImport {
    static func export(from context: NSManagedObjectContext) -> Data? {
        let subRequest = CDSubscription.fetchRequest()
        guard let allSubs = try? context.fetch(subRequest) else { return nil }

        let exported = allSubs.map { sub -> ExportedSubscription in
            let logs = (sub.usageLogs as? Set<CDUsageLog> ?? [])
                .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
                .map { log in
                    ExportedUsageLog(
                        id: log.id ?? UUID(),
                        date: log.date ?? Date(),
                        uses: log.uses
                    )
                }
            return ExportedSubscription(
                id: sub.id ?? UUID(),
                name: sub.name ?? "",
                monthlyCost: sub.monthlyCost,
                currency: sub.currency ?? "USD",
                category: sub.category,
                status: sub.status ?? "active",
                usageCount: sub.usageCount,
                createdAt: sub.createdAt ?? Date(),
                canceledDate: sub.canceledDate,
                isMarkedForKill: sub.isMarkedForKill,
                billingCycle: sub.billingCycle,
                nextRenewalDate: sub.nextRenewalDate,
                logs: logs
            )
        }

        let data = ExportData(
            exportedAt: Date(),
            version: 1,
            subscriptions: exported
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(data)
    }

    static func importData(_ data: Data, into context: NSManagedObjectContext, mergeStrategy: ImportStrategy) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let exported = try decoder.decode(ExportData.self, from: data)

        if mergeStrategy == .replace {
            let subRequest = CDSubscription.fetchRequest()
            if let existing = try? context.fetch(subRequest) {
                existing.forEach { context.delete($0) }
            }
        }

        for ex in exported.subscriptions {
            if mergeStrategy == .skipDuplicates {
                let req = CDSubscription.fetchRequest()
                req.predicate = NSPredicate(format: "id == %@", ex.id as CVarArg)
                req.fetchLimit = 1
                if (try? context.count(for: req)) ?? 0 > 0 { continue }
            }

            let sub = CDSubscription(context: context)
            sub.id = ex.id
            sub.name = ex.name
            sub.monthlyCost = ex.monthlyCost
            sub.currency = ex.currency
            sub.category = ex.category
            sub.status = ex.status
            sub.usageCount = ex.usageCount
            sub.createdAt = ex.createdAt
            sub.canceledDate = ex.canceledDate
            sub.isMarkedForKill = ex.isMarkedForKill
            sub.billingCycle = ex.billingCycle
            sub.nextRenewalDate = ex.nextRenewalDate
            sub.iconName = CyberTheme.iconForCategory(ex.category ?? "Other")

            for log in ex.logs {
                let cdLog = CDUsageLog(context: context)
                cdLog.id = log.id
                cdLog.date = log.date
                cdLog.uses = log.uses
                cdLog.subscription = sub
            }
        }

        try context.save()
    }
}

enum ImportStrategy {
    case replace   // Replace all data
    case merge     // Add new, overwrite existing by ID
    case skipDuplicates  // Add only new, skip existing IDs
}
