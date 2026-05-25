import Shared
import SwiftUI

struct FreshnessFooter: View {
    let briefing: Briefing
    let isOffline: Bool
    var isPro: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(text, systemImage: isOffline ? "wifi.slash" : iconName)
                .font(.footnote)
                .foregroundStyle(isStale ? SidelineTheme.amberText : .secondary)

            if !isOffline, isPro {
                Text(briefing.refreshWindow.nextUpdateHint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var iconName: String {
        isStale ? "exclamationmark.triangle" : "clock"
    }

    private var isStale: Bool {
        Date().timeIntervalSince(briefing.generatedAt) > 24 * 60 * 60
    }

    private var text: String {
        if isOffline {
            return "Offline. Showing yesterday's update."
        }
        if isStale {
            return "Updated \(relativeDate). Double-check before quoting."
        }
        return "Updated \(relativeDate) · \(briefing.sourceCount) sources"
    }

    private var accessibilityText: String {
        if isOffline {
            return "Offline, showing yesterday's update."
        }
        if isStale {
            return "Updated \(relativeDate). May be out of date, double-check before quoting."
        }
        return "Updated \(relativeDate), \(briefing.sourceCount) sources"
    }

    private var relativeDate: String {
        RelativeDateTimeFormatter().localizedString(for: briefing.generatedAt, relativeTo: Date())
    }
}
