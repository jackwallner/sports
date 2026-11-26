import Foundation

/// Everything RevenueCat can change without a release, read from the current
/// offering's metadata (a running Experiment's variant included). Every
/// variant ships in the binary; a missing, non-string or unknown value is the
/// control, which is what the app shipped before the reader existed. Keys that
/// a switch reads must be set the same on every offering, or an Experiment arm
/// would flip them as a side effect.
///
/// DEBUG builds can pin any key for captures: `-sideline.rc.<key> <value>`.

/// The trial button's wording. The paywall button names the trial length and
/// is title case; the Pro preview sheet's button names the room.
public enum TrialCTA: String, CaseIterable, Sendable {
    public static let metadataKey = "trial_cta"

    /// Control: today's copy, "Start My 7-Day Free Trial" on the paywall (the
    /// length comes from the intro offer) and "Try <Room> Free" on the sheet.
    case control = "seven_day"
    case my
    case your

    public static func from(metadata: [String: Any]?) -> TrialCTA {
        RemoteConfig.value(metadataKey, in: metadata, default: .control)
    }

    /// The paywall button. `trialLabel` is the intro offer's label, for
    /// example "7-day free trial", and is nil once this Apple Account has used
    /// its trial: that button promises no trial (3.1.2).
    public func paywallTitle(trialLabel: String?) -> String {
        guard let trialLabel else { return "Subscribe" }
        switch self {
        case .control: return "Start My \(trialLabel.capitalized)"
        case .my: return "Start My Free Trial"
        case .your: return "Start Your Free Trial"
        }
    }

    /// The Pro preview sheet's button, one tap before the paywall.
    public func previewTitle(room: String, trialAvailable: Bool) -> String {
        guard trialAvailable else { return "Unlock \(room)" }
        switch self {
        case .control: return "Try \(room) Free"
        case .my: return "Start My Free Trial"
        case .your: return "Start Your Free Trial"
        }
    }
}

/// Remote off switches, for what is worth pausing without a release. On
/// unless the metadata says "off".
public enum RemoteSwitch: String, CaseIterable, Sendable {
    /// Apple's rating prompt after a good moment on the briefing screen.
    case ratingPrompt = "rating_prompt"
}

public enum RemoteConfig {
    /// The value for `key`, or `fallback` when it is missing, not a string,
    /// or not one of the shipped variants.
    public static func value<T: RawRepresentable>(
        _ key: String,
        in metadata: [String: Any]?,
        default fallback: T
    ) -> T where T.RawValue == String {
        #if DEBUG
        if let pinned = launchOverride(key).flatMap(T.init(rawValue:)) { return pinned }
        #endif
        guard let raw = metadata?[key] as? String else { return fallback }
        return T(rawValue: raw) ?? fallback
    }

    public static func isOn(_ remoteSwitch: RemoteSwitch, in metadata: [String: Any]?) -> Bool {
        #if DEBUG
        if let pinned = launchOverride(remoteSwitch.rawValue) { return pinned != "off" }
        #endif
        return (metadata?[remoteSwitch.rawValue] as? String) != "off"
    }

    #if DEBUG
    private static func launchOverride(_ key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-sideline.rc.\(key)"), index + 1 < args.count else { return nil }
        return args[index + 1]
    }
    #endif
}
