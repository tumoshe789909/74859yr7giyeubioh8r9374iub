import Foundation
import CoreData
import UIKit

// MARK: - CPW Calculations

extension WardrobeItem {

    var costPerWear: Double {
        guard wearCount > 0 else { return purchasePrice }
        return purchasePrice / Double(wearCount)
    }

    var formattedCPW: String {
        CurrencyManager.shared.format(costPerWear)
    }

    var formattedPrice: String {
        CurrencyManager.shared.format(purchasePrice)
    }

    var cpwLabel: String {
        "\(formattedCPW) / wear"
    }

    var daysSincePurchase: Int {
        guard let date = purchaseDate else { return 0 }
        return max(Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0, 0)
    }

    var wearsPerMonth: Double {
        let months = max(Double(daysSincePurchase) / 30.0, 1.0)
        return Double(wearCount) / months
    }

    var wearsPerWeek: Double {
        let weeks = max(Double(daysSincePurchase) / 7.0, 1.0)
        return Double(wearCount) / weeks
    }

    /// Efficiency score 0-100 based on CPW relative to price
    var efficiencyScore: Double {
        guard wearCount > 0, purchasePrice > 0 else { return 0 }
        // At 30+ wears, score approaches 100
        let normalized = min(Double(wearCount) / 30.0, 1.0)
        return normalized * 100.0
    }

    var isEfficient: Bool {
        wearCount > 0 && efficiencyScore >= 40
    }

    var displayImage: Data? {
        photoData
    }

    var safeName: String {
        name ?? "Unnamed Item"
    }

    var safeCategory: String {
        category ?? "Other"
    }

    var sortedWearLogs: [WearLog] {
        let logs = wearLogs as? Set<WearLog> ?? []
        return logs.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    /// CPW data points for chart — shows how CPW decreases over time
    var cpwOverTime: [(date: Date, cpw: Double)] {
        let logs = sortedWearLogs
        guard !logs.isEmpty else { return [] }

        var points: [(date: Date, cpw: Double)] = []

        if let purchaseDate = purchaseDate {
            points.append((date: purchaseDate, cpw: purchasePrice))
        }

        for (index, log) in logs.enumerated() {
            let wearNumber = index + 1
            let cpw = purchasePrice / Double(wearNumber)
            points.append((date: log.date ?? Date(), cpw: cpw))
        }

        return points
    }

    /// Days since last worn
    var daysSinceLastWorn: Int? {
        guard let lastLog = sortedWearLogs.last, let date = lastLog.date else { return nil }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day
    }

    /// Projected wears per year based on current rate
    var projectedYearlyWears: Int {
        Int(wearsPerMonth * 12)
    }

    /// Projected CPW at end of year
    var projectedYearlyCPW: Double {
        let projectedWears = Double(wearCount) + (wearsPerMonth * 12)
        guard projectedWears > 0 else { return purchasePrice }
        return purchasePrice / projectedWears
    }
}

// MARK: - Currency Manager

@Observable
final class CurrencyManager {
    static let shared = CurrencyManager()

    var currencyCode: String {
        didSet {
            UserDefaults.standard.set(currencyCode, forKey: "selectedCurrency")
        }
    }

    static let availableCurrencies: [(code: String, name: String, symbol: String)] = [
        ("USD", "US Dollar", "$"),
        ("EUR", "Euro", "€"),
        ("GBP", "British Pound", "£"),
        ("JPY", "Japanese Yen", "¥"),
        ("CAD", "Canadian Dollar", "CA$"),
        ("AUD", "Australian Dollar", "A$"),
        ("CHF", "Swiss Franc", "CHF"),
        ("CNY", "Chinese Yuan", "¥"),
        ("RUB", "Russian Ruble", "₽"),
        ("KRW", "Korean Won", "₩"),
        ("INR", "Indian Rupee", "₹"),
        ("BRL", "Brazilian Real", "R$"),
        ("TRY", "Turkish Lira", "₺"),
        ("SEK", "Swedish Krona", "kr"),
        ("PLN", "Polish Zloty", "zł")
    ]

    private init() {
        self.currencyCode = UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD"
    }

    func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(currencyCode) \(String(format: "%.2f", value))"
    }

    func formatCompact(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.currencySymbol ?? "$"
    }
}

// MARK: - Analytics Engine

final class AnalyticsEngine {
    let context: NSManagedObjectContext

    // Cached results
    private var _activeItems: [WardrobeItem]?
    private var _allItems: [WardrobeItem]?
    private var _allLogs: [WearLog]?

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    /// Force refresh cached data
    func refresh() {
        _activeItems = nil
        _allItems = nil
        _allLogs = nil
    }

    var activeItems: [WardrobeItem] {
        if let cached = _activeItems { return cached }
        let request: NSFetchRequest<WardrobeItem> = WardrobeItem.fetchRequest()
        request.predicate = NSPredicate(format: "archived == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WardrobeItem.createdAt, ascending: false)]
        let result = (try? context.fetch(request)) ?? []
        _activeItems = result
        return result
    }

    var allItems: [WardrobeItem] {
        if let cached = _allItems { return cached }
        let request: NSFetchRequest<WardrobeItem> = WardrobeItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WardrobeItem.createdAt, ascending: false)]
        let result = (try? context.fetch(request)) ?? []
        _allItems = result
        return result
    }

    private var allLogs: [WearLog] {
        if let cached = _allLogs { return cached }
        let request: NSFetchRequest<WearLog> = WearLog.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WearLog.date, ascending: true)]
        let result = (try? context.fetch(request)) ?? []
        _allLogs = result
        return result
    }

    // MARK: - Core Metrics

    var topEfficient: [WardrobeItem] {
        let items = activeItems.filter { $0.wearCount > 0 }
        return Array(items.sorted { $0.costPerWear < $1.costPerWear }.prefix(10))
    }

    var worstInvestments: [WardrobeItem] {
        let items = activeItems.filter { $0.wearCount > 0 }
        return Array(items.sorted { $0.costPerWear > $1.costPerWear }.prefix(5))
    }

    var averageCPW: Double {
        let items = activeItems.filter { $0.wearCount > 0 }
        guard !items.isEmpty else { return 0 }
        let totalCPW = items.reduce(0.0) { $0 + $1.costPerWear }
        return totalCPW / Double(items.count)
    }

    var totalWardrobeValue: Double {
        activeItems.reduce(0.0) { $0 + $1.purchasePrice }
    }

    var totalWears: Int {
        activeItems.reduce(0) { $0 + Int($1.wearCount) }
    }

    var unusedItems: [WardrobeItem] {
        activeItems.filter { $0.wearCount == 0 && $0.daysSincePurchase > 30 }
    }

    // MARK: - Advanced Analytics

    /// Overall wardrobe efficiency score (0-100)
    var wardrobeEfficiencyScore: Double {
        let items = activeItems.filter { $0.wearCount > 0 }
        guard !items.isEmpty else { return 0 }
        let totalScore = items.reduce(0.0) { $0 + $1.efficiencyScore }
        return totalScore / Double(items.count)
    }

    /// Percentage of wardrobe that's been worn at least once
    var utilizationRate: Double {
        guard !activeItems.isEmpty else { return 0 }
        let wornCount = activeItems.filter { $0.wearCount > 0 }.count
        return Double(wornCount) / Double(activeItems.count) * 100
    }

    /// Value of items never worn (money sitting idle)
    var idleValue: Double {
        activeItems.filter { $0.wearCount == 0 }.reduce(0.0) { $0 + $1.purchasePrice }
    }

    /// Average price per item
    var averageItemPrice: Double {
        guard !activeItems.isEmpty else { return 0 }
        return totalWardrobeValue / Double(activeItems.count)
    }

    /// Cost Per Wear breakdown by category
    var cpwByCategory: [(category: String, cpw: Double, count: Int)] {
        let grouped = Dictionary(grouping: activeItems.filter { $0.wearCount > 0 }) { $0.safeCategory }
        return grouped.map { category, items in
            let avgCPW = items.reduce(0.0) { $0 + $1.costPerWear } / Double(items.count)
            return (category: category, cpw: avgCPW, count: items.count)
        }.sorted { $0.cpw < $1.cpw }
    }

    /// Item count by category
    var itemsByCategory: [(category: String, count: Int, value: Double)] {
        let grouped = Dictionary(grouping: activeItems) { $0.safeCategory }
        return grouped.map { category, items in
            let value = items.reduce(0.0) { $0 + $1.purchasePrice }
            return (category: category, count: items.count, value: value)
        }.sorted { $0.count > $1.count }
    }

    /// Wears per day over last 30 days
    var wearsPerDayLast30: [(date: Date, count: Int)] {
        let calendar = Calendar.current
        return (0..<30).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: Date())!
            let count = wearCountForDate(date)
            return (date: date, count: count)
        }
    }

    /// Weekly wear trend (last 12 weeks)
    var weeklyWearTrend: [(weekStart: Date, count: Int)] {
        let calendar = Calendar.current
        let logs = allLogs

        return (0..<12).reversed().map { weekOffset in
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: Date())!
            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
            let startOfWeek = calendar.startOfDay(for: weekStart)
            let count = logs.filter { log in
                guard let date = log.date else { return false }
                return date >= startOfWeek && date < weekEnd
            }.count
            return (weekStart: startOfWeek, count: count)
        }
    }

    /// Monthly spending (last 6 months based on purchase dates)
    var monthlySpending: [(month: Date, amount: Double, itemCount: Int)] {
        let calendar = Calendar.current
        return (0..<6).reversed().map { monthOffset in
            let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: Date())!
            let components = calendar.dateComponents([.year, .month], from: monthDate)
            let monthStart = calendar.date(from: components)!
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!

            let monthItems = allItems.filter { item in
                guard let purchaseDate = item.purchaseDate else { return false }
                return purchaseDate >= monthStart && purchaseDate < monthEnd
            }

            let totalSpent = monthItems.reduce(0.0) { $0 + $1.purchasePrice }
            return (month: monthStart, amount: totalSpent, itemCount: monthItems.count)
        }
    }

    /// Current wear streak (consecutive days with at least one wear)
    var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = Date()

        for _ in 0..<365 {
            if wearCountForDate(checkDate) > 0 {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }
        return streak
    }

    /// Best streak ever
    var bestStreak: Int {
        let calendar = Calendar.current
        let logs = allLogs
        guard let firstLog = logs.first?.date, let lastLog = logs.last?.date else { return 0 }

        var best = 0
        var current = 0
        var checkDate = calendar.startOfDay(for: firstLog)
        let endDate = calendar.startOfDay(for: lastLog)

        while checkDate <= endDate {
            let dayLogs = logs.filter { log in
                guard let date = log.date else { return false }
                return calendar.isDate(date, inSameDayAs: checkDate)
            }
            if !dayLogs.isEmpty {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate)!
        }
        return best
    }

    /// Most active day of week (0 = Sunday, 6 = Saturday)
    var mostActiveDayOfWeek: (day: Int, count: Int)? {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: allLogs) { log -> Int in
            calendar.component(.weekday, from: log.date ?? Date())
        }
        return grouped.map { (day: $0.key, count: $0.value.count) }
            .max(by: { $0.count < $1.count })
    }

    /// CPW trend over time (monthly average CPW)
    var cpwTrendMonthly: [(month: Date, avgCPW: Double)] {
        let calendar = Calendar.current
        let wornItems = activeItems.filter { $0.wearCount > 0 }
        guard !wornItems.isEmpty else { return [] }

        return (0..<6).reversed().compactMap { monthOffset in
            let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: Date())!
            let components = calendar.dateComponents([.year, .month], from: monthDate)
            guard let monthEnd = calendar.date(from: components),
                  let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthEnd) else { return nil }

            // Calculate what the avg CPW was at the end of that month
            var totalCPW = 0.0
            var count = 0
            for item in wornItems {
                let logsUpToMonth = item.sortedWearLogs.filter { ($0.date ?? .distantFuture) < nextMonth }
                let wearCountAtMonth = logsUpToMonth.count
                if wearCountAtMonth > 0 {
                    totalCPW += item.purchasePrice / Double(wearCountAtMonth)
                    count += 1
                }
            }

            guard count > 0 else { return nil }
            return (month: monthEnd, avgCPW: totalCPW / Double(count))
        }
    }

    // MARK: - Date Queries

    func wearCountForDate(_ date: Date) -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let request: NSFetchRequest<WearLog> = WearLog.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)

        return (try? context.count(for: request)) ?? 0
    }

    func categoriesWornOnDate(_ date: Date) -> [String] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let request: NSFetchRequest<WearLog> = WearLog.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)

        let logs = (try? context.fetch(request)) ?? []
        let categories = Set(logs.compactMap { $0.item?.category })
        return Array(categories)
    }
}

// MARK: - Achievement System

struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let isUnlocked: Bool
}

struct AchievementEngine {
    let context: NSManagedObjectContext

    var achievements: [Achievement] {
        let items = allItems
        let totalWears = items.reduce(0) { $0 + Int($1.wearCount) }
        let hasSubDollarCPW = items.contains { $0.wearCount > 0 && $0.costPerWear < 1.0 }
        let hasCenturyItem = items.contains { $0.wearCount >= 100 }
        let wornItems = items.filter { $0.wearCount > 0 }
        let avgCPW = wornItems.isEmpty ? 0 : wornItems.reduce(0.0) { $0 + $1.costPerWear } / Double(wornItems.count)
        let categoryCount = Set(items.compactMap { $0.category }).count

        return [
            Achievement(
                id: "first_item",
                title: "Getting Started",
                description: "Add your first wardrobe item",
                icon: "star.fill",
                isUnlocked: !items.isEmpty
            ),
            Achievement(
                id: "first_wear",
                title: "Outfit Logger",
                description: "Log your first outfit",
                icon: "checkmark.circle.fill",
                isUnlocked: totalWears > 0
            ),
            Achievement(
                id: "ten_items",
                title: "Wardrobe Builder",
                description: "Track 10 or more items",
                icon: "square.grid.3x3.fill",
                isUnlocked: items.count >= 10
            ),
            Achievement(
                id: "smart_shopper",
                title: "Smart Shopper",
                description: "Achieve a CPW under \(CurrencyManager.shared.currencySymbol)1 on any item",
                icon: "dollarsign.circle.fill",
                isUnlocked: hasSubDollarCPW
            ),
            Achievement(
                id: "century_club",
                title: "Century Club",
                description: "Wear a single item 100 times",
                icon: "trophy.fill",
                isUnlocked: hasCenturyItem
            ),
            Achievement(
                id: "sustainability_star",
                title: "Sustainability Star",
                description: "Keep average CPW below \(CurrencyManager.shared.currencySymbol)5",
                icon: "leaf.fill",
                isUnlocked: !wornItems.isEmpty && avgCPW < 5.0
            ),
            Achievement(
                id: "fifty_wears",
                title: "Dedicated Dresser",
                description: "Log 50 total outfit entries",
                icon: "flame.fill",
                isUnlocked: totalWears >= 50
            ),
            Achievement(
                id: "diverse_wardrobe",
                title: "Style Variety",
                description: "Have items in 5+ categories",
                icon: "paintpalette.fill",
                isUnlocked: categoryCount >= 5
            ),
            Achievement(
                id: "twenty_five_items",
                title: "Wardrobe Master",
                description: "Track 25 or more items",
                icon: "crown.fill",
                isUnlocked: items.count >= 25
            )
        ]
    }

    private var allItems: [WardrobeItem] {
        let request: NSFetchRequest<WardrobeItem> = WardrobeItem.fetchRequest()
        return (try? context.fetch(request)) ?? []
    }
}

// MARK: - Image Compression Utility

enum ImageCompressor {
    static func compress(_ imageData: Data?, maxDimension: CGFloat = 800, quality: CGFloat = 0.7) -> Data? {
        guard let data = imageData, let image = UIImage(data: data) else { return nil }
        return compress(image: image, maxDimension: maxDimension, quality: quality)
    }

    static func compress(image: UIImage, maxDimension: CGFloat = 800, quality: CGFloat = 0.7) -> Data? {
        let size = image.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
