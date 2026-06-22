#if DEBUG
import Foundation
import Shared

/// Debug-only briefing that exercises every card back-face branch and the
/// overflow/scroll path. Served when the app launches with `-SidelineEdgeCases`.
enum EdgeCaseBriefing {
    private static func repeated(_ s: String, _ n: Int) -> String {
        String(repeating: s, count: n)
    }

    static let briefing = Briefing(
        persona: .cocktailParty,
        scope: .national,
        refreshWindow: .daily,
        headline: "Edge case harness",
        tlDR: "Short lead line to say on the front of the cover card.",
        // Long setup → lead card back must scroll, not shrink or clip.
        leadBackstory: repeated("This is a long setup sentence that keeps going so the lead card back overflows the card height and has to scroll. ", 6),
        bullets: [
            // A — long backstory AND long tie-in: the overflow case.
            BriefingBullet(
                talkingPoint: "Long backstory plus long tie-in: should scroll at full size, never shrink.",
                subject: "Long Both",
                tieIn: repeated("And the tie-in itself runs long enough to sit below the fold, so you must be able to scroll to reach the end of it. ", 3),
                backstory: repeated("Backstory sentence that is deliberately long and detailed to guarantee this card overflows its height on every device size. ", 6),
                tag: .drama,
                tagReason: "Tag reason that should be hidden because the tie-in takes the secondary row.",
                sourceHeadline: "Long source headline that should truncate to one line on the button",
                sourceURL: URL(string: "https://example.com/a")!
            ),
            // B — short backstory and short tie-in: the static, no-scroll case.
            BriefingBullet(
                talkingPoint: "Short and sweet, everything fits with room to spare.",
                subject: "Short Both",
                tieIn: "Short tie-in line.",
                backstory: "A short backstory.",
                tag: .niceGuy,
                tagReason: "reason",
                sourceHeadline: "Short source",
                sourceURL: URL(string: "https://example.com/b")!
            ),
            // C — backstory present, NO tie-in: the tagReason fallback row.
            BriefingBullet(
                talkingPoint: "Backstory but no tie-in: the tag-reason row should render instead.",
                subject: "No TieIn",
                tieIn: nil,
                backstory: repeated("Backstory with no tie-in present, so the tag-reason row is what shows under it. ", 4),
                tag: .jerk,
                tagReason: "He has a history of saying the quiet part out loud, which is why this one is tagged the way it is.",
                sourceHeadline: "Source C",
                sourceURL: URL(string: "https://example.com/c")!
            ),
            // D — tie-in only, no backstory, no tagReason: tie-in becomes the body.
            BriefingBullet(
                talkingPoint: "Tie-in only, no backstory at all.",
                subject: "TieIn Only",
                tieIn: "With no backstory, this tie-in becomes the body text of the card back.",
                backstory: nil,
                tag: nil,
                tagReason: nil,
                sourceHeadline: "Source D",
                sourceURL: URL(string: "https://example.com/d")!
            ),
            // E — nothing on the back: degenerate, must not crash or look broken.
            BriefingBullet(
                talkingPoint: "No backstory, no tie-in, no tag reason.",
                subject: "Empty Back",
                tieIn: nil,
                backstory: nil,
                tag: nil,
                tagReason: nil,
                sourceHeadline: "Source E",
                sourceURL: URL(string: "https://example.com/e")!
            )
        ],
        suggestedQuestion: "Which of these edge cases worried you the most, and why?",
        sourceCount: 5,
        generatedAt: Date()
    )
}

struct EdgeCaseBriefingService: BriefingServing {
    func latestBriefing(persona: Persona, scope: BriefingScope) async throws -> Briefing {
        EdgeCaseBriefing.briefing
    }
}
#endif
