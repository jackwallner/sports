// Writes the CardArt parity fixture the Android unit tests read. Compiled
// together with Shared/Models and the pure half of Sideline/Utilities/CardArt.swift
// by scripts/sync-android-fixtures.sh, so the expected values are Swift's own.
import Foundation

func bullet(_ subject: String?, _ headline: String, _ tag: BriefingTag?, _ url: String, image: String? = nil) -> BriefingBullet {
    BriefingBullet(talkingPoint: "Point", subject: subject, tag: tag, sourceHeadline: headline,
                   sourceURL: URL(string: url)!, imageURL: image.flatMap { URL(string: $0) })
}

let bullets: [BriefingBullet] = [
    bullet("Cowboys", "Veteran QB benched amid playoff push - The Athletic", .drama, "https://example.com/veteran-qb-benched"),
    bullet(nil, "Lakers rally late in the fourth", .niceGuy, "https://example.com/lakers"),
    bullet("Liberty", "WNBA finals set after a wild semifinal", .redemption, "https://example.com/wnba"),
    bullet("Dodgers", "World Series Game 3 recap", nil, "https://example.com/ws"),
    bullet(nil, "Messi scores twice for Inter Miami", .jerk, "https://example.com/messi"),
    bullet(nil, "Alcaraz wins in five sets at Wimbledon", .neutral, "https://example.com/tennis"),
    bullet("Oilers", "Stanley Cup rematch tonight", .drama, "https://example.com/nhl"),
    bullet(nil, "McIlroy leads after round one at the Masters", nil, "https://example.com/golf"),
    bullet(nil, "Olympic committee picks a host city", .niceGuy, "https://example.com/olympics"),
    bullet("Notre Dame", "Big 12 admits error in Notre Dame-BYU ending, says Irish had 1 second left", .drama, "https://www.espn.com/college-football/story/_/id/50208529/big-12-admits-error-says-notre-dame-had-one-more-play"),
    bullet(nil, "A quiet night across the league", .jerk, "https://example.com/quiet"),
    bullet(nil, "Something heartwarming happened", .redemption, "https://example.com/warm"),
    bullet(nil, "Something happened", nil, "https://example.com/plain"),
    bullet(nil, "Café owner's ünïcode story, 49ers fan", .neutral, "https://example.com/caf\u{e9}"),
    bullet("NFL", "With stamped art", .niceGuy, "https://example.com/stamped", image: "https://example.supabase.co/storage/v1/object/public/card-art/story-1.jpg"),
]

func row(_ b: BriefingBullet) -> [String: Any] {
    let s = CardArt.sport(for: b)
    return [
        "subject": b.subject as Any? ?? NSNull(),
        "sourceHeadline": b.sourceHeadline,
        "sourceURL": b.sourceURL.absoluteString,
        "tag": b.tag?.rawValue as Any? ?? NSNull(),
        "imageURL": b.imageURL?.absoluteString as Any? ?? NSNull(),
        "symbol": s.symbol,
        "name": s.name,
        "urls": CardArt.imageURLs(for: b).map(\.absoluteString),
    ]
}

let leadWith = Briefing(persona: .cocktailParty, scope: .national, refreshWindow: .daily, headline: "h",
                        tlDR: "A lead line to seed the cover art.",
                        leadImageURL: URL(string: "https://example.supabase.co/storage/v1/object/public/card-art/lead.jpg"),
                        bullets: [bullets[14], bullets[0]], suggestedQuestion: "q", sourceCount: 2, generatedAt: Date())
let leadBare = Briefing(persona: .cocktailParty, scope: .national, refreshWindow: .daily, headline: "h",
                        tlDR: "No stamped art anywhere.", bullets: [bullets[3]], suggestedQuestion: "q",
                        sourceCount: 1, generatedAt: Date())
let leadEmpty = Briefing(persona: .cocktailParty, scope: .national, refreshWindow: .daily, headline: "h",
                         tlDR: "Empty deck.", bullets: [], suggestedQuestion: "q", sourceCount: 0, generatedAt: Date())

let seeds = ["", "a", "Cowboys", "https://example.com/veteran-qb-benched", "caf\u{e9} \u{1F3C8}"]
var seedRows: [[String: Any]] = []
for text in seeds {
    seedRows.append(["text": text, "seed": Int(CardArt.debugSeed(text))])
}

let fixture: [String: Any] = [
    "bullets": bullets.map(row),
    "leads": [
        ["tlDR": leadWith.tlDR, "leadImageURL": leadWith.leadImageURL!.absoluteString, "bulletIndexes": [14, 0], "urls": CardArt.leadImageURLs(for: leadWith).map(\.absoluteString)],
        ["tlDR": leadBare.tlDR, "leadImageURL": NSNull(), "bulletIndexes": [3], "urls": CardArt.leadImageURLs(for: leadBare).map(\.absoluteString)],
        ["tlDR": leadEmpty.tlDR, "leadImageURL": NSNull(), "bulletIndexes": [Int](), "urls": CardArt.leadImageURLs(for: leadEmpty).map(\.absoluteString)],
    ],
    "seeds": seedRows,
]
let data = try! JSONSerialization.data(withJSONObject: fixture, options: [.prettyPrinted, .sortedKeys])
FileManager.default.createFile(atPath: CommandLine.arguments[1], contents: data)
