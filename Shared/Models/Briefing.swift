import Foundation

public enum BriefingScope: String, Codable, CaseIterable, Sendable {
    case national
    case local
}

public enum RefreshWindow: String, Codable, CaseIterable, Sendable {
    case daily
    case morning
    case midday
    case evening

    public var nextUpdateHint: String {
        switch self {
        case .daily: return "Next briefing tomorrow morning"
        case .morning: return "Next refresh midday"
        case .midday: return "Next refresh this evening"
        case .evening: return "Next briefing tomorrow morning"
        }
    }
}

public struct Briefing: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let persona: Persona
    public let scope: BriefingScope
    public let refreshWindow: RefreshWindow
    public let headline: String
    public let tlDR: String
    public let bullets: [BriefingBullet]
    public let suggestedQuestion: String
    public let sourceCount: Int
    public let generatedAt: Date
    public let expiresAt: Date?

    public init(
        id: UUID = UUID(),
        persona: Persona,
        scope: BriefingScope,
        refreshWindow: RefreshWindow,
        headline: String,
        tlDR: String,
        bullets: [BriefingBullet],
        suggestedQuestion: String,
        sourceCount: Int,
        generatedAt: Date,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.persona = persona
        self.scope = scope
        self.refreshWindow = refreshWindow
        self.headline = headline
        self.tlDR = tlDR
        self.bullets = bullets
        self.suggestedQuestion = suggestedQuestion
        self.sourceCount = sourceCount
        self.generatedAt = generatedAt
        self.expiresAt = expiresAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case persona
        case scope
        case refreshWindow = "refresh_window"
        case headline
        case tlDR = "tl_dr"
        case bullets
        case suggestedQuestion = "suggested_question"
        case sourceCount = "source_count"
        case generatedAt = "generated_at"
        case expiresAt = "expires_at"
    }
}

public struct BriefingBullet: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let talkingPoint: String
    public let tieIn: String?
    public let tag: BriefingTag?
    public let tagReason: String?
    public let sourceHeadline: String
    public let sourceURL: URL

    public init(
        id: UUID = UUID(),
        talkingPoint: String,
        tieIn: String? = nil,
        tag: BriefingTag? = nil,
        tagReason: String? = nil,
        sourceHeadline: String,
        sourceURL: URL
    ) {
        self.id = id
        self.talkingPoint = talkingPoint
        self.tieIn = tieIn
        self.tag = tag
        self.tagReason = tagReason
        self.sourceHeadline = sourceHeadline
        self.sourceURL = sourceURL
    }

    enum CodingKeys: String, CodingKey {
        case id
        case talkingPoint = "talking_point"
        case tieIn = "tie_in"
        case tag
        case tagReason = "tag_reason"
        case sourceHeadline = "source_headline"
        case sourceURL = "source_url"
    }
}

public extension Briefing {
    static let sample = Briefing(
        persona: .cocktailParty,
        scope: .national,
        refreshWindow: .daily,
        headline: "What everyone's arguing about this week",
        tlDR: "A beloved veteran quarterback got benched, the internet is melting down, and his replacement is a 23-year-old nobody had heard of last month.",
        bullets: [
            BriefingBullet(
                talkingPoint: "The team benched their longtime starter. Fans are split between 'about time' and 'how dare they.'",
                tieIn: "His wife posted a cryptic quote about loyalty, which did not help.",
                tag: .drama,
                tagReason: "Locker-room sources are frustrated, per reporters.",
                sourceHeadline: "Veteran QB benched amid playoff push - The Athletic",
                sourceURL: URL(string: "https://example.com/veteran-qb-benched")!
            ),
            BriefingBullet(
                talkingPoint: "The 23-year-old replacement is the feel-good story: undrafted, was working a normal job 2 years ago.",
                tag: .niceGuy,
                tagReason: "Donated his first big check to his old high school.",
                sourceHeadline: "From warehouse shifts to starting QB - ESPN",
                sourceURL: URL(string: "https://example.com/warehouse-to-qb")!
            ),
            BriefingBullet(
                talkingPoint: "A star player from another team called the benching disrespectful, and now those 2 teams play Sunday.",
                tag: .drama,
                tagReason: "He has a history of saying the quiet part loud.",
                sourceHeadline: "Rival star sounds off - Yahoo Sports",
                sourceURL: URL(string: "https://example.com/rival-star")!
            )
        ],
        suggestedQuestion: "Do you think they made the right call, or did they just blow up their season?",
        sourceCount: 3,
        generatedAt: Date()
    )
}
