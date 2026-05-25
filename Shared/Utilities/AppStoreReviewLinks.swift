import Foundation

/// App Store review deep links for The Sideline.
public enum AppStoreReviewLinks {
    public static let appStoreID = "6770138156"

    /// Opens the App Store write-review page (use for explicit user-initiated rating CTAs).
    public static var writeReviewURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!
    }
}
