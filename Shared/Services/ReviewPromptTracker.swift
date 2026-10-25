import Foundation

public extension Notification.Name {
    /// Posted after a satisfaction moment. The briefing screen may request the
    /// system rating prompt after a short delay, with no question in front of it.
    static let sidelinePositiveMomentForReview = Notification.Name("com.jackwallner.sideline.positiveMomentForReview")
}

/// What the user did about a review. Only opening the review page ends the
/// passive asks: someone who sent feedback can still rate.
public enum ReviewPromptOutcome: String, Sendable {
    case openedWriteReview
    /// Sent feedback by mail. Never stops the asks.
    case submittedFeedback
}

/// Persists launch counts, positive moments, and review-prompt eligibility.
@MainActor
public enum ReviewPromptTracker {
    private static let defaults = UserDefaults.standard

    private static let launchCountKey = "sideline.reviewPrompt.appLaunchCount"
    private static let firstOpenKey = "sideline.reviewPrompt.firstAppOpenDate"
    private static let lastShownKey = "sideline.reviewPrompt.lastShownDate"
    private static let outcomeKey = "sideline.reviewPrompt.outcome"
    private static let positiveMomentCountKey = "sideline.reviewPrompt.positiveMomentCount"
    private static let pendingPositiveMomentKey = "sideline.reviewPrompt.pendingPositiveMoment"

    /// Ask early. Most installs are gone within a week, and a rating from
    /// someone who read two briefings beats no rating at all. The only tenure
    /// gate is "not the first session": a second cold start.
    public static let minimumLaunchCount = 2
    /// Days between our calls. Apple shows the prompt at most three times a
    /// year per device and decides each time, so this paces the asks rather
    /// than the user's answers.
    public static let cooldownDays = 30

    public static var appLaunchCount: Int {
        get { max(defaults.integer(forKey: launchCountKey), 0) }
        set { defaults.set(newValue, forKey: launchCountKey) }
    }

    public static var firstAppOpenDate: Date? {
        get { defaults.object(forKey: firstOpenKey) as? Date }
        set {
            if let date = newValue {
                defaults.set(date, forKey: firstOpenKey)
            } else {
                defaults.removeObject(forKey: firstOpenKey)
            }
        }
    }

    public static var lastShownDate: Date? {
        get { defaults.object(forKey: lastShownKey) as? Date }
        set {
            if let date = newValue {
                defaults.set(date, forKey: lastShownKey)
            } else {
                defaults.removeObject(forKey: lastShownKey)
            }
        }
    }

    public static var outcome: ReviewPromptOutcome? {
        get {
            guard let raw = defaults.string(forKey: outcomeKey) else { return nil }
            return ReviewPromptOutcome(rawValue: raw)
        }
        set {
            if let value = newValue {
                defaults.set(value.rawValue, forKey: outcomeKey)
            } else {
                defaults.removeObject(forKey: outcomeKey)
            }
        }
    }

    public static var positiveMomentCount: Int {
        get { max(defaults.integer(forKey: positiveMomentCountKey), 0) }
        set { defaults.set(newValue, forKey: positiveMomentCountKey) }
    }

    public static var hasPendingPositiveMoment: Bool {
        get { defaults.bool(forKey: pendingPositiveMomentKey) }
        set { defaults.set(newValue, forKey: pendingPositiveMomentKey) }
    }

    private static var isScreenshotOrUITest: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-SidelineScreenshot")
            || args.contains("-SidelineSafeScreenshot")
            || args.contains("-FASTLANE_SNAPSHOT")
            || args.contains("FASTLANE_SNAPSHOT")
    }

    public static func recordAppLaunch(now: Date = .now) {
        if firstAppOpenDate == nil {
            firstAppOpenDate = now
        }
        appLaunchCount += 1
    }

    public static func recordPositiveMoment() {
        positiveMomentCount += 1
        hasPendingPositiveMoment = true
        NotificationCenter.default.post(name: .sidelinePositiveMomentForReview, object: nil)
    }

    public static func consumePendingPositiveMoment() {
        hasPendingPositiveMoment = false
    }

    public static func passivePromptAllowed(now: Date = .now) -> Bool {
        guard outcome != .openedWriteReview else { return false }
        guard let last = lastShownDate else { return true }
        let cooldown = TimeInterval(cooldownDays) * 86_400
        return now.timeIntervalSince(last) >= cooldown
    }

    public static func canRequestReview(hasCompletedSetup: Bool, now: Date = .now) -> Bool {
        guard !isScreenshotOrUITest else { return false }
        guard hasCompletedSetup else { return false }
        guard passivePromptAllowed(now: now) else { return false }
        return appLaunchCount >= minimumLaunchCount
    }

    public static func shouldRequestAfterPositiveMoment(
        hasCompletedSetup: Bool,
        now: Date = .now
    ) -> Bool {
        guard hasPendingPositiveMoment else { return false }
        return canRequestReview(hasCompletedSetup: hasCompletedSetup, now: now)
    }

    public static func markShown(now: Date = .now) {
        lastShownDate = now
        consumePendingPositiveMoment()
    }

    public static func markOpenedWriteReview() {
        outcome = .openedWriteReview
        markShown()
    }

    /// Never overwrites `.openedWriteReview`: feedback sent after the review
    /// page must not reopen the asks that page ended.
    public static func markFeedbackSubmitted() {
        if outcome != .openedWriteReview {
            outcome = .submittedFeedback
        }
    }
}
