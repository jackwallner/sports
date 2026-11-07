import Shared
import SwiftUI

enum SidelineBrand {
    static let name = "Sports Cheat Sheet"
    static let proName = "Sports Cheat Sheet Pro"
}

struct FreshnessFooter: View {
    let briefing: Briefing
    let savedBecause: SavedCopyReason?
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
        let freshness = BriefingFreshness(briefing: briefing, savedBecause: savedBecause)
        return VStack(alignment: .center, spacing: 4) {
            Label(freshness.text(now: now), systemImage: freshness.iconName(now: now))
                .font(.caption)
                .foregroundStyle(freshness.isStale(now: now) ? SidelineTheme.amberText : SidelineTheme.inkTertiary)

            if isPro, freshness.showsNextRefreshHint(now: now) {
                Text(briefing.refreshWindow.nextUpdateHint)
                    .font(.caption2)
                    .foregroundStyle(SidelineTheme.inkTertiary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(freshness.accessibilityText(now: now))
    }
}
