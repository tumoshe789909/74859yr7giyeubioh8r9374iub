import SwiftUI

enum AppConstants {
    static let disclaimerText = "This is a private personal subscription tracking tool for mindful spending. Not financial advice or professional auditing service."
}

struct DisclaimerView: View {
    var body: some View {
        Text(AppConstants.disclaimerText)
            .font(.system(size: 9, weight: .regular))
            .foregroundStyle(CyberTheme.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
    }
}
