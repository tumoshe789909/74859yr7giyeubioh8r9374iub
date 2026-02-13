import UIKit
import CoreData

// MARK: - PDF Wardrobe Report Generator

enum PDFGenerator {

    static func generateReport(items: [WardrobeItem], currencyManager: CurrencyManager) -> Data {
        let pageWidth: CGFloat = 612   // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )

        let data = renderer.pdfData { context in
            context.beginPage()
            var yPosition: CGFloat = margin

            // Header
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor(red: 0.29, green: 0.29, blue: 0.29, alpha: 1)
            ]
            let title = "Wardrobe Report"
            title.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttrs)
            yPosition += 36

            // Date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.gray
            ]
            let dateStr = "Generated on \(dateFormatter.string(from: Date()))"
            dateStr.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: dateAttrs)
            yPosition += 24

            // Disclaimer
            let disclaimerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .regular),
                .foregroundColor: UIColor.lightGray
            ]
            CPWTheme.disclaimer.draw(
                with: CGRect(x: margin, y: yPosition, width: contentWidth, height: 20),
                options: .usesLineFragmentOrigin,
                attributes: disclaimerAttrs,
                context: nil
            )
            yPosition += 24

            // Separator
            let separatorPath = UIBezierPath()
            separatorPath.move(to: CGPoint(x: margin, y: yPosition))
            separatorPath.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
            UIColor.lightGray.setStroke()
            separatorPath.lineWidth = 0.5
            separatorPath.stroke()
            yPosition += 16

            // Summary
            let activeItems = items.filter { !$0.archived }
            let totalValue = activeItems.reduce(0.0) { $0 + $1.purchasePrice }
            let wornItems = activeItems.filter { $0.wearCount > 0 }
            let avgCPW = wornItems.isEmpty ? 0 : wornItems.reduce(0.0) { $0 + $1.costPerWear } / Double(wornItems.count)
            let totalWears = activeItems.reduce(0) { $0 + Int($1.wearCount) }

            let summaryAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: UIColor(red: 0.29, green: 0.29, blue: 0.29, alpha: 1)
            ]

            let summaryLines = [
                "Total Items: \(activeItems.count)",
                "Total Wardrobe Value: \(currencyManager.format(totalValue))",
                "Total Wears Logged: \(totalWears)",
                "Average Cost Per Wear: \(currencyManager.format(avgCPW))"
            ]

            for line in summaryLines {
                line.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: summaryAttrs)
                yPosition += 18
            }

            yPosition += 16

            // Table header
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: UIColor(red: 0.29, green: 0.29, blue: 0.29, alpha: 1)
            ]

            let colX: [CGFloat] = [margin, margin + 160, margin + 260, margin + 340, margin + 420]
            let headers = ["Item", "Category", "Price", "Wears", "CPW"]
            for (i, header) in headers.enumerated() {
                header.draw(at: CGPoint(x: colX[i], y: yPosition), withAttributes: headerAttrs)
            }
            yPosition += 18

            // Separator
            let headerSep = UIBezierPath()
            headerSep.move(to: CGPoint(x: margin, y: yPosition))
            headerSep.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
            UIColor(red: 0.83, green: 0.63, blue: 0.09, alpha: 1).setStroke()
            headerSep.lineWidth = 1
            headerSep.stroke()
            yPosition += 8

            // Items
            let rowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                .foregroundColor: UIColor(red: 0.29, green: 0.29, blue: 0.29, alpha: 1)
            ]

            let sortedItems = activeItems.sorted { $0.costPerWear < $1.costPerWear }
            for item in sortedItems {
                if yPosition > pageHeight - margin - 40 {
                    context.beginPage()
                    yPosition = margin
                }

                let name = String((item.name ?? "Unnamed").prefix(25))
                let cat = String((item.category ?? "Other").prefix(15))
                let price = currencyManager.format(item.purchasePrice)
                let wears = "\(item.wearCount)"
                let cpw = item.formattedCPW

                let rowData = [name, cat, price, wears, cpw]
                for (i, value) in rowData.enumerated() {
                    value.draw(at: CGPoint(x: colX[i], y: yPosition), withAttributes: rowAttrs)
                }
                yPosition += 16
            }

            // Footer
            yPosition = pageHeight - margin
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .regular),
                .foregroundColor: UIColor.lightGray
            ]
            "Cost Per Wear: Smart Wardrobe — Personal Tracking Report".draw(
                at: CGPoint(x: margin, y: yPosition),
                withAttributes: footerAttrs
            )
        }

        return data
    }
}
