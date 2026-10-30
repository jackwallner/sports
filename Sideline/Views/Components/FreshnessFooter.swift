import Shared
import SwiftUI

enum SidelineBrand {
    static let name = "Sports Cheat Sheet"
    static let proName = "Sports Cheat Sheet Pro"
}

struct FreshnessFooter: View {
    let briefing: Briefing
    let isOffline: Bool
    var isPro: Bool = false

    var body: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-SidelineSafeScreenshot") {
            EmptyView()
        } else {
            freshnessContent
        }
        #else
        freshnessContent
        #endif
    }

    /// The age is redrawn every minute: SwiftUI never re-runs a body because
    /// time passed, and the app can sit suspended for hours.
    private var freshnessContent: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            content(now: context.date)
        }
    }

    private func content(now: Date) -> some View {
        let stale = isStale(now: now)
        return VStack(alignment: .center, spacing: 4) {
            Label(text(now: now), systemImage: isOffline ? "wifi.slash" : iconName(isStale: stale))
                .font(.caption)
                .foregroundStyle(stale ? SidelineTheme.amberText : SidelineTheme.inkTertiary)

            if !isOffline, isPro {
                Text(briefing.refreshWindow.nextUpdateHint)
                    .font(.caption2)
                    .foregroundStyle(SidelineTheme.inkTertiary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(now: now))
    }

    private func iconName(isStale: Bool) -> String {
        isStale ? "exclamationmark.triangle" : "clock"
    }

    private func isStale(now: Date) -> Bool {
        now.timeIntervalSince(briefing.generatedAt) > 24 * 60 * 60
    }

    private func text(now: Date) -> String {
        if isOffline {
            return "Offline. Showing your last saved briefing."
        }
        if isStale(now: now) {
            return "Updated \(relativeDate(now: now)). Double-check before quoting."
        }
        return "Updated \(relativeDate(now: now)) · \(briefing.sourceCount) sources"
    }

    private func accessibilityText(now: Date) -> String {
        if isOffline {
            return "Offline, showing your last saved briefing."
        }
        if isStale(now: now) {
            return "Updated \(relativeDate(now: now)). May be out of date, double-check before quoting."
        }
        return "Updated \(relativeDate(now: now)), \(briefing.sourceCount) sources"
    }

    /// Clamped to now, so a device clock behind the server never reads
    /// "Updated in 2 minutes".
    private func relativeDate(now: Date) -> String {
        RelativeDateTimeFormatter().localizedString(for: min(briefing.generatedAt, now), relativeTo: now)
    }
}
