import Foundation
import CoreData
import Observation

@Observable
final class SubscriptionStore {
    private(set) var subscriptions: [CDSubscription] = []
    private(set) var canceledSubscriptions: [CDSubscription] = []
    private(set) var lastSaveError: String?
    /// Incremented on every save so SwiftUI re-renders when Core Data objects change
    private(set) var refreshTrigger: Int = 0
    let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
        refresh()
    }

    func refresh() {
        let activeRequest = CDSubscription.fetchRequest()
        activeRequest.predicate = NSPredicate(format: "status != %@", "canceled")
        activeRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDSubscription.createdAt, ascending: false)]
        subscriptions = (try? context.fetch(activeRequest)) ?? []

        let canceledRequest = CDSubscription.fetchRequest()
        canceledRequest.predicate = NSPredicate(format: "status == %@", "canceled")
        canceledRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDSubscription.canceledDate, ascending: false)]
        canceledSubscriptions = (try? context.fetch(canceledRequest)) ?? []
    }

    func addSubscription(
        name: String,
        monthlyCost: Double,
        currency: String,
        category: String?,
        iconName: String? = nil,
        billingCycle: BillingCycle = .monthly,
        nextRenewalDate: Date? = nil
    ) {
        let sub = CDSubscription(context: context)
        sub.id = UUID()
        sub.name = name
        sub.monthlyCost = monthlyCost
        sub.currency = currency
        sub.category = category
        sub.usageCount = 0
        sub.status = "active"
        sub.createdAt = Date()
        sub.isMarkedForKill = false
        sub.iconName = iconName
        sub.billingCycle = billingCycle.rawValue
        sub.nextRenewalDate = nextRenewalDate
        save()
    }

    func logUsage(for subscription: CDSubscription, uses: Int16 = 1) {
        let log = CDUsageLog(context: context)
        log.id = UUID()
        log.date = Date()
        log.uses = uses
        log.subscription = subscription
        subscription.usageCount += Int64(uses)
        save()

        if let subId = subscription.id?.uuidString {
            NotificationManager.scheduleInactivityReminder(
                for: subscription.wrappedName, id: subId
            )
        }
    }

    func updateStatus(_ subscription: CDSubscription, to status: SubscriptionStatus) {
        subscription.status = status.rawValue
        if status == .canceled {
            subscription.canceledDate = Date()
            subscription.isMarkedForKill = false
        }
        save()
    }

    func toggleKillMark(_ subscription: CDSubscription) {
        subscription.isMarkedForKill.toggle()
        save()
    }

    func updateSubscription(
        _ sub: CDSubscription,
        name: String,
        monthlyCost: Double,
        category: String?,
        billingCycle: BillingCycle? = nil,
        nextRenewalDate: Date? = nil
    ) {
        guard monthlyCost > 0 else { return }
        sub.name = name
        sub.monthlyCost = monthlyCost
        sub.category = category
        if let bc = billingCycle { sub.billingCycle = bc.rawValue }
        sub.nextRenewalDate = nextRenewalDate
        save()
    }

    func deleteSubscription(_ sub: CDSubscription) {
        context.delete(sub)
        save()
    }

    func resetAll() {
        let request = CDSubscription.fetchRequest()
        if let all = try? context.fetch(request) {
            all.forEach { context.delete($0) }
        }
        NotificationManager.cancelAllNotifications()
        save()
    }

    /// Applies zombie status based on detection reports. Call explicitly, never from SwiftUI body.
    func applyZombieDetection() -> [ZombieReport] {
        let reports = AuditEngine.detectZombies(subscriptions)
        var changed = false
        for report in reports {
            if report.subscription.wrappedStatus != .zombie {
                report.subscription.status = "zombie"
                changed = true
            }
        }
        if changed { save() }
        return reports
    }

    func hasDuplicate(name: String) -> Bool {
        subscriptions.contains { $0.wrappedName.lowercased() == name.lowercased() }
    }

    private func save() {
        do {
            try context.save()
            lastSaveError = nil
        } catch {
            lastSaveError = error.localizedDescription
            print("[SubRadar] Core Data save failed: \(error)")
        }
        refresh()
        refreshTrigger += 1
    }

    // MARK: - Computed

    var totalMonthlySpend: Double {
        subscriptions.reduce(0) { $0 + $1.effectiveMonthlyCost }
    }

    /// Subscriptions with renewal date in next 30 days
    var upcomingRenewals: [CDSubscription] {
        let now = Date()
        let in30Days = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        return subscriptions
            .filter { $0.wrappedStatus != .canceled }
            .compactMap { sub -> CDSubscription? in
                guard let date = sub.nextRenewalDate, date >= now, date <= in30Days else { return nil }
                return sub
            }
            .sorted { ($0.nextRenewalDate ?? .distantFuture) < ($1.nextRenewalDate ?? .distantFuture) }
    }

    var totalYearlySpend: Double { totalMonthlySpend * 12 }

    var zombieSubscriptions: [CDSubscription] {
        subscriptions.filter { $0.wrappedStatus == .zombie }
    }

    var activeSubscriptions: [CDSubscription] {
        subscriptions.filter { $0.wrappedStatus == .active }
    }

    var killListSubscriptions: [CDSubscription] {
        subscriptions.filter { $0.isMarkedForKill }
    }

    var potentialMonthlySavings: Double {
        killListSubscriptions.reduce(0) { $0 + $1.effectiveMonthlyCost }
    }

    var potentialYearlySavings: Double { potentialMonthlySavings * 12 }

    var totalSaved: Double {
        canceledSubscriptions.reduce(0) { total, sub in
            guard let cancelDate = sub.canceledDate else { return total }
            let days = max(0, Calendar.current.dateComponents([.day], from: cancelDate, to: Date()).day ?? 0)
            let months = Double(days) / 30.44
            return total + sub.effectiveMonthlyCost * months
        }
    }

    var averageCPU: Double {
        let active = subscriptions.filter { $0.usageCount > 0 }
        guard !active.isEmpty else { return 0 }
        let total = active.reduce(0.0) { $0 + $1.cpu }
        return total / Double(active.count)
    }

    // MARK: - Streaks & Weekly Summary

    var usageStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = cal.startOfDay(for: Date())

        while true {
            let nextDay = cal.date(byAdding: .day, value: 1, to: checkDate)!
            let logsRequest = CDUsageLog.fetchRequest()
            logsRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", checkDate as NSDate, nextDay as NSDate)
            logsRequest.fetchLimit = 1
            let hasLog = (try? context.count(for: logsRequest)) ?? 0 > 0
            if hasLog {
                streak += 1
                checkDate = cal.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }
        return streak
    }

    var weeklySummary: (totalUses: Int64, subsUsed: Int) {
        let cal = Calendar.current
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return (0, 0) }
        let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!

        let logsRequest = CDUsageLog.fetchRequest()
        logsRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", weekStart as NSDate, weekEnd as NSDate)
        let logs = (try? context.fetch(logsRequest)) ?? []

        let totalUses = logs.reduce(Int64(0)) { $0 + Int64($1.uses) }
        let subIds = Set(logs.compactMap { $0.subscription?.id })
        return (totalUses, subIds.count)
    }
}
