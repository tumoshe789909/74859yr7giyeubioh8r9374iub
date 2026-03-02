import Foundation
import PDFKit
import UIKit

enum PDFReportGenerator {
    static func generate(
        subscriptions: [CDSubscription],
        canceledSubscriptions: [CDSubscription],
        totalMonthly: Double,
        totalSaved: Double,
        currencySymbol: String
    ) -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var yPos: CGFloat = margin

            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let headerAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: UIColor.darkGray
            ]
            let bodyAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]
            let valueAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            let disclaimerAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .regular),
                .foregroundColor: UIColor.gray
            ]

            let title = "SubRadar: Digital Efficiency Analysis"
            title.draw(at: CGPoint(x: margin, y: yPos), withAttributes: titleAttr)
            yPos += 35

            let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none)
            "Report generated: \(dateStr)".draw(at: CGPoint(x: margin, y: yPos), withAttributes: bodyAttr)
            yPos += 30

            let line = UIBezierPath()
            line.move(to: CGPoint(x: margin, y: yPos))
            line.addLine(to: CGPoint(x: pageWidth - margin, y: yPos))
            UIColor.lightGray.setStroke()
            line.lineWidth = 0.5
            line.stroke()
            yPos += 20

            "Summary".draw(at: CGPoint(x: margin, y: yPos), withAttributes: headerAttr)
            yPos += 25
            "Total Monthly Spend: \(currencySymbol)\(String(format: "%.2f", totalMonthly))".draw(at: CGPoint(x: margin, y: yPos), withAttributes: valueAttr)
            yPos += 18
            "Total Annual Spend: \(currencySymbol)\(String(format: "%.2f", totalMonthly * 12))".draw(at: CGPoint(x: margin, y: yPos), withAttributes: valueAttr)
            yPos += 18
            "Active Subscriptions: \(subscriptions.filter { $0.wrappedStatus != .canceled }.count)".draw(at: CGPoint(x: margin, y: yPos), withAttributes: valueAttr)
            yPos += 18
            "Total Saved by Cancellations: \(currencySymbol)\(String(format: "%.2f", totalSaved))".draw(at: CGPoint(x: margin, y: yPos), withAttributes: valueAttr)
            yPos += 30

            "Active Subscriptions".draw(at: CGPoint(x: margin, y: yPos), withAttributes: headerAttr)
            yPos += 25

            let colWidths: [CGFloat] = [contentWidth * 0.30, contentWidth * 0.15, contentWidth * 0.15, contentWidth * 0.15, contentWidth * 0.25]
            let headers = ["Service", "Cost/mo", "Uses", "CPU", "Status"]
            for (i, header) in headers.enumerated() {
                let x = margin + colWidths[0..<i].reduce(0, +)
                header.draw(at: CGPoint(x: x, y: yPos), withAttributes: valueAttr)
            }
            yPos += 18

            for sub in subscriptions {
                if yPos > pageHeight - 100 {
                    ctx.beginPage()
                    yPos = margin
                }
                let cols = [
                    sub.wrappedName,
                    "\(currencySymbol)\(String(format: "%.2f", sub.effectiveMonthlyCost))",
                    "\(sub.usageCount)",
                    sub.cpuFormatted,
                    sub.wrappedStatus.rawValue.capitalized
                ]
                for (i, col) in cols.enumerated() {
                    let x = margin + colWidths[0..<i].reduce(0, +)
                    col.draw(at: CGPoint(x: x, y: yPos), withAttributes: bodyAttr)
                }
                yPos += 16
            }

            let zombies = subscriptions.filter { $0.wrappedStatus == .zombie }
            if !zombies.isEmpty {
                yPos += 20
                if yPos > pageHeight - 100 { ctx.beginPage(); yPos = margin }
                "⚠ Zombie Subscriptions Detected".draw(at: CGPoint(x: margin, y: yPos), withAttributes: headerAttr)
                yPos += 25
                for z in zombies {
                    if yPos > pageHeight - 80 { ctx.beginPage(); yPos = margin }
                    "• \(z.wrappedName) — \(currencySymbol)\(String(format: "%.2f", z.effectiveMonthlyCost))/mo (CPU: \(z.cpuFormatted))".draw(
                        at: CGPoint(x: margin, y: yPos), withAttributes: bodyAttr
                    )
                    yPos += 16
                }
            }

            if !canceledSubscriptions.isEmpty {
                yPos += 20
                if yPos > pageHeight - 100 { ctx.beginPage(); yPos = margin }
                "Canceled Subscriptions".draw(at: CGPoint(x: margin, y: yPos), withAttributes: headerAttr)
                yPos += 25
                for c in canceledSubscriptions {
                    if yPos > pageHeight - 80 { ctx.beginPage(); yPos = margin }
                    let dateStr = c.canceledDate.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none) } ?? "N/A"
                    "• \(c.wrappedName) — \(currencySymbol)\(String(format: "%.2f", c.effectiveMonthlyCost))/mo — Canceled: \(dateStr)".draw(
                        at: CGPoint(x: margin, y: yPos), withAttributes: bodyAttr
                    )
                    yPos += 16
                }
            }

            yPos = pageHeight - margin - 30
            let disclaimer = AppConstants.disclaimerText
            let disclaimerRect = CGRect(x: margin, y: yPos, width: contentWidth, height: 30)
            disclaimer.draw(in: disclaimerRect, withAttributes: disclaimerAttr)
        }
    }
}
