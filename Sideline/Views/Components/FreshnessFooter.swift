import Shared
import SwiftUI

struct FreshnessFooter: View {
    let briefing: Briefing
    let isOffline: Bool

    var body: some View {
        Label(text, systemImage: isOffline ? "wifi.slash" : "clock")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(accessibilityText)
    }

    private var text: String {
        if isOffline {
            return "Offline - showing the last update."
        }

        return "Updated \(relativeDate) · \(briefing.sourceCount) sources"
    }

    private var accessibilityText: String {
        if isOffline {
            return "Offline, showing the last update."
        }

        return "Updated \(relativeDate), \(briefing.sourceCount) sources"
    }

    private var relativeDate: String {
        RelativeDateTimeFormatter().localizedString(for: briefing.generatedAt, relativeTo: Date())
    }
}
