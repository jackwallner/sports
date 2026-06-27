import Foundation

public extension Notification.Name {
    /// Posted when the user has a satisfaction moment — host may present the enjoyment funnel after a short delay.
    static let sidelinePositiveMomentForReview = Notification.Name("com.jackwallner.sideline.positiveMomentForReview")
}

/// How the user last resolved the in-app review / feedback prompt.
public enum ReviewPromptOutcome: String, Sendable {
    case openedWriteReview
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

    public static let minimumLaunchCount = 5
    public static let minimumDaysSinceFirstOpen = 7
    /// Minimum cumulative positive moments before the passive enjoyment funnel surfaces.
    public static let minimumPositiveMoments = 3
    public static let cooldownDays = 120

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
        guard outcome == nil else { return false }
        guard let last = lastShownDate else { return true }
        let cooldown = TimeInterval(cooldownDays) * 86_400
        return now.timeIntervalSince(last) >= cooldown
    }

    public static func canPresentEnjoymentPrompt(
        hasCompletedSetup: Bool,
        now: Date = .now
    ) -> Bool {
        guard !isScreenshotOrUITest else { return false }
        guard hasCompletedSetup else { return false }
        guard passivePromptAllowed(now: now) else { return false }
        guard appLaunchCount >= minimumLaunchCount else { return false }
        guard positiveMomentCount >= minimumPositiveMoments else { return false }
        guard let first = firstAppOpenDate else { return false }
        let minInterval = TimeInterval(minimumDaysSinceFirstOpen) * 86_400
        guard now.timeIntervalSince(first) >= minInterval else { return false }
        return true
    }

    public static func shouldShowAfterPositiveMoment(
        hasCompletedSetup: Bool,
        now: Date = .now
    ) -> Bool {
        guard hasPendingPositiveMoment else { return false }
        return canPresentEnjoymentPrompt(hasCompletedSetup: hasCompletedSetup, now: now)
    }

    public static func markShown(now: Date = .now) {
        lastShownDate = now
        consumePendingPositiveMoment()
    }

    public static func markOpenedWriteReview() {
        outcome = .openedWriteReview
        markShown()
    }

    public static func markFeedbackSubmitted() {
        outcome = .submittedFeedback
        markShown()
    }
}
