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

/// Debug-only, current-safe briefing used to verify the screenshot deck without
/// synthetic celebrity gossip or claims about real people.
struct SafeScreenshotBriefingService: BriefingServing {
    func latestBriefing(persona: Persona, scope: BriefingScope) async throws -> Briefing {
        Briefing(
            persona: persona,
            scope: scope,
            refreshWindow: .daily,
            headline: "The small details that change a game",
            tlDR: "A clear game plan starts with field position, tempo, and the matchup that keeps showing up.",
            leadBackstory: "Coaches tend to talk about the final score, but repeatable edges appear earlier: where possessions begin, how quickly a team resets, and which matchup creates extra room. Those details are useful because they give you something concrete to watch.",
            bullets: [
                BriefingBullet(
                    talkingPoint: "Field position can quietly shape a close game.",
                    subject: "Field position",
                    tieIn: "Watch where each drive begins before looking at the final score.",
                    backstory: "Starting closer to midfield gives an offense fewer yards to cover. It also changes how a team can use its playbook on the next series.",
                    tag: .neutral,
                    tagReason: "A useful detail to track from the opening drive.",
                    sourceHeadline: "Field position basics",
                    sourceURL: URL(string: "https://example.com/field-position-basics")!
                ),
                BriefingBullet(
                    talkingPoint: "Tempo is a choice, not just a pace.",
                    subject: "Tempo",
                    tieIn: "Notice whether the offense stays patient or pushes the next snap.",
                    backstory: "A faster tempo can limit defensive substitutions, while a slower sequence can give an offense time to reset its look. The contrast is easy to spot possession by possession.",
                    tag: .neutral,
                    tagReason: "A simple way to follow the shape of a possession.",
                    sourceHeadline: "How tempo changes a possession",
                    sourceURL: URL(string: "https://example.com/tempo-and-possession")!
                ),
                BriefingBullet(
                    talkingPoint: "A matchup is easier to follow when you name the task.",
                    subject: "Matchups",
                    tieIn: "Ask which unit has the clearer assignment this week.",
                    backstory: "Instead of tracking every player, follow one job: protect the passer, win the first tackle, or create space on the edge. A specific task gives the conversation a useful anchor.",
                    tag: .neutral,
                    tagReason: "A concrete question is easier to carry into the game.",
                    sourceHeadline: "A simple guide to watching matchups",
                    sourceURL: URL(string: "https://example.com/watching-matchups")!
                )
            ],
            suggestedQuestion: "Which part of this matchup are you watching first?",
            sourceCount: 3,
            generatedAt: Date()
        )
    }
}
#endif
