import Foundation

public enum BriefingTag: String, Codable, CaseIterable, Identifiable, Sendable {
    case niceGuy = "nice_guy"
    case jerk
    case redemption
    case drama
    case neutral

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .niceGuy:
            return "Nice guy"
        case .jerk:
            return "Jerk"
        case .redemption:
            return "Redemption"
        case .drama:
            return "Drama"
        case .neutral:
            return "Neutral"
        }
    }

    public var symbolName: String {
        switch self {
        case .niceGuy:
            return "hand.thumbsup"
        case .jerk:
            return "hand.thumbsdown"
        case .redemption:
            return "arrow.uturn.up"
        case .drama:
            return "flame"
        case .neutral:
            return "circle"
        }
    }
}
