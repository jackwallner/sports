import Shared
import SwiftUI

struct FreshnessFooter: View {
    let briefing: Briefing
    let isOffline: Bool
    var isPro: Bool = false

    var body: some View {
        // Centered under the page dots so the deck column reads as one unit.
        VStack(alignment: .center, spacing: 4) {
            Label(text, systemImage: isOffline ? "wifi.slash" : iconName)
                .font(.caption)
                .foregroundStyle(isStale ? SidelineTheme.amberText : SidelineTheme.inkTertiary)

            if !isOffline, isPro {
                Text(briefing.refreshWindow.nextUpdateHint)
                    .font(.caption2)
                    .foregroundStyle(SidelineTheme.inkTertiary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
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
