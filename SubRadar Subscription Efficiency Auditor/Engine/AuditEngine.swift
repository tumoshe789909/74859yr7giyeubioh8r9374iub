import Foundation
import SwiftUI

enum AuditEngine {
    static func cpu(monthlyCost: Double, uses: Int64) -> Double {
        guard uses > 0 else { return .infinity }
        return monthlyCost / Double(uses)
    }

    static func cpuTrend(currentUses: Int64, previousUses: Int64, monthlyCost: Double) -> Double {
        let currentCPU = cpu(monthlyCost: monthlyCost, uses: currentUses)
        let previousCPU = cpu(monthlyCost: monthlyCost, uses: previousUses)
        guard previousCPU > 0, previousCPU.isFinite, currentCPU.isFinite else { return 0 }
        return (currentCPU - previousCPU) / previousCPU * 100
    }

    static func efficiencyRating(_ cpuValue: Double, monthlyCost: Double) -> EfficiencyRating {
        guard cpuValue.isFinite, cpuValue > 0 else { return .critical }
        if cpuValue <= monthlyCost * 0.15 { return .excellent }
        if cpuValue <= monthlyCost * 0.35 { return .good }
        if cpuValue <= monthlyCost * 0.6 { return .fair }
        if cpuValue <= monthlyCost * 0.85 { return .poor }
        return .critical
    }

    static func projectedSavings(monthlyCost: Double, months: Int = 12) -> Double {
        monthlyCost * Double(months)
    }

    static func categoryAnalysis(subscriptions: [CDSubscription]) -> [CategoryAnalysis] {
        let active = subscriptions.filter { $0.wrappedStatus != .canceled }
        let grouped = Dictionary(grouping: active) { $0.wrappedCategory }
        let totalCost = active.reduce(0.0) { $0 + $1.effectiveMonthlyCost }
        let totalUsage = active.reduce(Int64(0)) { $0 + $1.usageCount }

        return grouped.map { category, subs in
            let cost = subs.reduce(0.0) { $0 + $1.effectiveMonthlyCost }
            let usage = subs.reduce(Int64(0)) { $0 + $1.usageCount }
            let costPct = totalCost > 0 ? (cost / totalCost) * 100 : 0
            let usagePct = totalUsage > 0 ? (Double(usage) / Double(totalUsage)) * 100 : 0
            return CategoryAnalysis(
                category: category,
                totalCost: cost,
                subscriptionCount: subs.count,
                totalUsage: usage,
                costPercentage: costPct,
                usagePercentage: usagePct,
                efficiency: costPct > 0 ? usagePct / costPct : 0
            )
        }.sorted { $0.totalCost > $1.totalCost }
    }

    /// Pure detection — does NOT mutate any data. Returns reports only.
    static func detectZombies(_ subscriptions: [CDSubscription]) -> [ZombieReport] {
        subscriptions.compactMap { sub in
            guard sub.wrappedStatus != .canceled else { return nil }
            let cpuValue = cpu(monthlyCost: sub.effectiveMonthlyCost, uses: sub.usageCount)

            let trend = cpuTrend(
                currentUses: sub.usesThisMonth,
                previousUses: sub.usesLastMonth,
                monthlyCost: sub.effectiveMonthlyCost
            )

            let reason: String

            if sub.usageCount == 0 {
                reason = "No usage recorded — pure cost with zero value"
            } else if trend > 30 {
                reason = "CPU trend up \(String(format: "%.0f", trend))% — declining usage efficiency"
            } else if cpuValue > sub.effectiveMonthlyCost * 0.8 {
                reason = "Extremely high cost per use: \(CostFormatter.format(cpuValue, currency: sub.wrappedCurrency))"
            } else {
                return nil
            }

            return ZombieReport(
                subscription: sub,
                cpu: cpuValue,
                trend: trend,
                potentialSavings: projectedSavings(monthlyCost: sub.effectiveMonthlyCost),
                reason: reason
            )
        }
    }

    private static let monthFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        return fmt
    }()

    static func monthlyUsageHistory(for sub: CDSubscription, months: Int = 6) -> [MonthlyUsage] {
        let cal = Calendar.current
        let now = Date()
        guard let currentMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) else {
            return []
        }

        return (0..<months).reversed().map { offset in
            guard let monthStart = cal.date(byAdding: .month, value: -offset, to: currentMonthStart),
                  let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart) else {
                return MonthlyUsage(month: now, uses: 0, cpu: .infinity)
            }
            let logs = sub.logsArray.filter { $0.wrappedDate >= monthStart && $0.wrappedDate < monthEnd }
            let uses = Int64(logs.reduce(0) { $0 + Int($1.uses) })
            return MonthlyUsage(
                month: monthStart,
                uses: uses,
                cpu: cpu(monthlyCost: sub.effectiveMonthlyCost, uses: uses)
            )
        }
    }

    static func formatMonth(_ date: Date) -> String {
        monthFormatter.string(from: date)
    }
}

enum EfficiencyRating: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case critical = "Critical"

    var color: Color {
        switch self {
        case .excellent: return CyberTheme.neonGreen
        case .good: return CyberTheme.neonBlue
        case .fair: return CyberTheme.neonYellow
        case .poor: return CyberTheme.neonOrange
        case .critical: return CyberTheme.neonRed
        }
    }

    var icon: String {
        switch self {
        case .excellent: return "checkmark.seal.fill"
        case .good: return "hand.thumbsup.fill"
        case .fair: return "exclamationmark.triangle"
        case .poor: return "exclamationmark.circle"
        case .critical: return "xmark.octagon.fill"
        }
    }
}

struct CategoryAnalysis: Identifiable {
    let id = UUID()
    let category: String
    let totalCost: Double
    let subscriptionCount: Int
    let totalUsage: Int64
    let costPercentage: Double
    let usagePercentage: Double
    let efficiency: Double
}

struct ZombieReport: Identifiable {
    let id = UUID()
    let subscription: CDSubscription
    let cpu: Double
    let trend: Double
    let potentialSavings: Double
    let reason: String
}

struct MonthlyUsage: Identifiable {
    let id = UUID()
    let month: Date
    let uses: Int64
    let cpu: Double

    var monthLabel: String {
        AuditEngine.formatMonth(month)
    }
}

enum CostFormatter {
    private static let zeroDecimalCurrencies: Set<String> = ["JPY", "KRW"]

    static func format(_ amount: Double, currency: String) -> String {
        let symbol = CurrencyHelper.symbol(for: currency)
        let fmt = zeroDecimalCurrencies.contains(currency) ? "%.0f" : "%.2f"
        return "\(symbol)\(String(format: fmt, amount))"
    }
}
