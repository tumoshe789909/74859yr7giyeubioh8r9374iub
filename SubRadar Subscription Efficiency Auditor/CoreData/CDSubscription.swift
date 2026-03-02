import Foundation
import SwiftUI

enum SubscriptionStatus: String, CaseIterable {
    case active
    case zombie
    case canceled
}

extension CDSubscription {
    var wrappedName: String { name ?? "Unnamed" }
    var wrappedCurrency: String { currency ?? "USD" }
    var wrappedCategory: String { category ?? "Other" }
    var wrappedCreatedAt: Date { createdAt ?? Date() }

    var wrappedStatus: SubscriptionStatus {
        SubscriptionStatus(rawValue: status ?? "active") ?? .active
    }

    var cpu: Double {
        guard usageCount > 0 else { return .infinity }
        return effectiveMonthlyCost / Double(usageCount)
    }

    var cpuFormatted: String {
        guard usageCount > 0 else { return "∞" }
        return String(format: "%.2f", cpu)
    }

    var formattedMonthlyCost: String {
        CostFormatter.format(effectiveMonthlyCost, currency: wrappedCurrency)
    }

    var statusColor: Color {
        switch wrappedStatus {
        case .active: return CyberTheme.neonGreen
        case .zombie: return CyberTheme.neonRed
        case .canceled: return CyberTheme.textTertiary
        }
    }

    var efficiencyRating: EfficiencyRating {
        AuditEngine.efficiencyRating(cpu, monthlyCost: effectiveMonthlyCost)
    }

    var logsArray: [CDUsageLog] {
        let set = usageLogs as? Set<CDUsageLog> ?? []
        return set.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    var usesThisMonth: Int64 {
        let cal = Calendar.current
        let now = Date()
        guard let start = cal.date(from: cal.dateComponents([.year, .month], from: now)) else { return 0 }
        let set = usageLogs as? Set<CDUsageLog> ?? []
        return set
            .filter { ($0.date ?? .distantPast) >= start }
            .reduce(0) { $0 + Int64($1.uses) }
    }

    var usesLastMonth: Int64 {
        let cal = Calendar.current
        let now = Date()
        guard let thisMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)),
              let lastMonthStart = cal.date(byAdding: .month, value: -1, to: thisMonthStart) else { return 0 }
        let set = usageLogs as? Set<CDUsageLog> ?? []
        return set
            .filter { guard let d = $0.date else { return false }; return d >= lastMonthStart && d < thisMonthStart }
            .reduce(0) { $0 + Int64($1.uses) }
    }

    var usesThisWeek: Int64 {
        let cal = Calendar.current
        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        let set = usageLogs as? Set<CDUsageLog> ?? []
        return set
            .filter { ($0.date ?? .distantPast) >= weekInterval.start }
            .reduce(0) { $0 + Int64($1.uses) }
    }

    // MARK: - Billing Cycle
    var wrappedBillingCycle: BillingCycle {
        BillingCycle(rawValue: billingCycle ?? "monthly") ?? .monthly
    }

    var wrappedNextRenewalDate: Date? { nextRenewalDate }

    /// Effective monthly cost (for annual: yearly/12)
    var effectiveMonthlyCost: Double {
        wrappedBillingCycle == .annual ? monthlyCost / 12 : monthlyCost
    }

    var daysUntilRenewal: Int? {
        guard let date = nextRenewalDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: date).day
    }
}

enum BillingCycle: String, CaseIterable {
    case monthly = "monthly"
    case annual = "annual"

    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .annual: return "Annual"
        }
    }

    var icon: String {
        switch self {
        case .monthly: return "calendar"
        case .annual: return "calendar.badge.clock"
        }
    }
}
