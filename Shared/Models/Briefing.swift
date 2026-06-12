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
    /// 2-3 sentences of setup behind the TL;DR, shown on the cover card's
    /// flip side. Older rows lack it; the cover card stays single-faced.
    public let leadBackstory: String?
    /// Cover-card art stamped by the pipeline, distinct from every story's
    /// art. Older rows lack it; the app falls back to derived art.
    public let leadImageURL: URL?
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
        leadBackstory: String? = nil,
        leadImageURL: URL? = nil,
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
        self.leadBackstory = leadBackstory
        self.leadImageURL = leadImageURL
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
        case leadBackstory = "lead_backstory"
        case leadImageURL = "lead_image_url"
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
    public let subject: String?
    public let tieIn: String?
    /// 2-3 sentences of context for when someone asks a follow-up: what
    /// actually happened and why people care. Older rows lack it; the card
    /// back falls back to the tie-in.
    public let backstory: String?
    public let tag: BriefingTag?
    public let tagReason: String?
    public let sourceHeadline: String
    public let sourceURL: URL
    /// Card art pre-stamped by the content pipeline (and pre-warmed onto the
    /// image CDN by the cron). Older rows lack it; the app derives a URL
    /// client-side as the fallback.
    public let imageURL: URL?

    public init(
        id: UUID = UUID(),
        talkingPoint: String,
        subject: String? = nil,
        tieIn: String? = nil,
        backstory: String? = nil,
        tag: BriefingTag? = nil,
        tagReason: String? = nil,
        sourceHeadline: String,
        sourceURL: URL,
        imageURL: URL? = nil
    ) {
        self.id = id
        self.talkingPoint = talkingPoint
        self.subject = subject
        self.tieIn = tieIn
        self.backstory = backstory
        self.tag = tag
        self.tagReason = tagReason
        self.sourceHeadline = sourceHeadline
        self.sourceURL = sourceURL
        self.imageURL = imageURL
    }

    enum CodingKeys: String, CodingKey {
        case id
        case talkingPoint = "talking_point"
        case subject
        case tieIn = "tie_in"
        case backstory
        case tag
        case tagReason = "tag_reason"
        case sourceHeadline = "source_headline"
        case sourceURL = "source_url"
        case imageURL = "image_url"
    }
}

public extension Briefing {
    static let sample = Briefing(
        persona: .cocktailParty,
        scope: .national,
        refreshWindow: .daily,
        headline: "What everyone's arguing about this week",
        tlDR: "A beloved veteran quarterback got benched, the internet is melting down, and his replacement is a 23-year-old nobody had heard of last month.",
        leadBackstory: "The Cowboys, the most-watched team in football, sat down their starter of 9 years in the middle of a playoff race. Quarterback is the one job everyone in the building depends on, so this is like a company swapping CEOs the week before earnings. The new guy was stocking warehouse shelves 2 years ago, which is why the whole internet has an opinion.",
        bullets: [
            BriefingBullet(
                talkingPoint: "The team benched their longtime starter. Fans are split between 'about time' and 'how dare they.'",
                subject: "Cowboys",
                tieIn: "His wife posted a cryptic quote about loyalty, which did not help.",
                backstory: "He has started every game for 9 years, but the team has lost 5 in a row and the front office is feeling the heat. Coaches say the move is about a playoff push, not his legacy. Fans see a franchise icon getting shoved out the door.",
                tag: .drama,
                tagReason: "Locker-room sources are frustrated, per reporters.",
                sourceHeadline: "Veteran QB benched amid playoff push - The Athletic",
                sourceURL: URL(string: "https://example.com/veteran-qb-benched")!
            ),
            BriefingBullet(
                talkingPoint: "The 23-year-old replacement is the feel-good story: undrafted, was working a normal job 2 years ago.",
                subject: "NFL",
                backstory: "No college program wanted him, so he stocked warehouse shelves while playing semi-pro on weekends. A scout spotted him at an open tryout 2 years ago. Now he is starting in front of 80,000 people.",
                tag: .niceGuy,
                tagReason: "Donated his first big check to his old high school.",
                sourceHeadline: "From warehouse shifts to starting QB - ESPN",
                sourceURL: URL(string: "https://example.com/warehouse-to-qb")!
            ),
            BriefingBullet(
                talkingPoint: "A star player from another team called the benching disrespectful, and now those 2 teams play Sunday.",
                subject: "Eagles",
                backstory: "The two quarterbacks came up together and are close friends, which is why the rival star took it personally. The league fined him for the comments, and he said it was worth every dollar. Sunday is the first meeting since.",
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
