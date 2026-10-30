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

/// `-SidelineSlowNetwork` holds each debug briefing for 600 ms, like a real
/// fetch, so a room switch passes through the loading skeleton. DEBUG only.
struct SlowBriefingService: BriefingServing {
    let wrapped: any BriefingServing

    func latestBriefing(persona: Persona, scope: BriefingScope) async throws -> Briefing {
        try await Task.sleep(nanoseconds: 600_000_000)
        return try await wrapped.latestBriefing(persona: persona, scope: scope)
    }
}

/// Screenshot helper: `-DuoScreen <surface>` opens one store surface, read
/// once at launch. Pair it with `-SidelineSafeScreenshot -SidelineForcePro`
/// so every room has its seeded briefing. DEBUG only.
enum DuoScreen: String {
    /// Cocktail Party, the brief on top of the deck.
    case brief
    /// Office Watercooler, its first story.
    case story
    /// Date Night, its second story.
    case date
    /// Sports Talk for Moms, the "Your move" question card.
    case question
    /// Cocktail Party with Settings pushed in the deck's pane.
    case settings

    static let current: DuoScreen? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-DuoScreen"), i + 1 < args.count else { return nil }
        return DuoScreen(rawValue: args[i + 1])
    }()

    var persona: Persona {
        switch self {
        case .brief, .settings: return .cocktailParty
        case .story: return .officeWatercooler
        case .date: return .dateNight
        case .question: return .sportsTalkForMoms
        }
    }

    /// Deck position: 0 the brief, 1...n stories; the deck clamps larger
    /// values to the question card.
    var deckCard: Int {
        switch self {
        case .brief, .settings: return 0
        case .story: return 1
        case .date: return 2
        case .question: return .max
        }
    }

    /// Skips onboarding and the swipe hint and restores the surface's room,
    /// before any view reads these defaults.
    func seedDefaults(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: "sideline.hasCompletedOnboarding")
        defaults.set(true, forKey: "sideline.hasSwipedDeck")
        defaults.set(persona.rawValue, forKey: "sideline.lastPersona")
    }
}

/// Debug-only, current-safe briefings used to verify the screenshot deck without
/// synthetic celebrity gossip or claims about real people. Each room gets its
/// own evergreen briefing, so room switches read as different stories.
struct SafeScreenshotBriefingService: BriefingServing {
    func latestBriefing(persona: Persona, scope: BriefingScope) async throws -> Briefing {
        let content = Self.content(for: persona)
        return Briefing(
            persona: persona,
            scope: scope,
            refreshWindow: .daily,
            headline: content.headline,
            tlDR: content.tlDR,
            leadBackstory: content.leadBackstory,
            leadImageURL: ScreenshotArt.url(for: persona.rawValue),
            bullets: content.bullets,
            suggestedQuestion: content.question,
            sourceCount: content.bullets.count,
            generatedAt: Date().addingTimeInterval(-50 * 60)
        )
    }

    private struct Content {
        let headline: String
        let tlDR: String
        let leadBackstory: String
        let bullets: [BriefingBullet]
        let question: String
    }

    private static func bullet(
        _ subject: String,
        _ talkingPoint: String,
        tieIn: String,
        backstory: String,
        tag: BriefingTag = .neutral,
        tagReason: String,
        source: String,
        slug: String
    ) -> BriefingBullet {
        BriefingBullet(
            talkingPoint: talkingPoint,
            subject: subject,
            tieIn: tieIn,
            backstory: backstory,
            tag: tag,
            tagReason: tagReason,
            sourceHeadline: source,
            sourceURL: URL(string: "https://example.com/\(slug)")!,
            imageURL: ScreenshotArt.url(for: slug)
        )
    }

    private static func content(for persona: Persona) -> Content {
        switch persona {
        case .cocktailParty:
            return Content(
                headline: "The small details that change a game",
                tlDR: "A clear game plan starts with field position, tempo, and the matchup that keeps showing up.",
                leadBackstory: "Coaches tend to talk about the final score, but repeatable edges appear earlier: where possessions begin, how quickly a team resets, and which matchup creates extra room. Those details are useful because they give you something concrete to watch.",
                bullets: [
                    bullet(
                        "Field position",
                        "Field position can quietly shape a close game.",
                        tieIn: "Watch where each drive begins before looking at the final score.",
                        backstory: "Starting closer to midfield gives an offense fewer yards to cover. It also changes how a team can use its playbook on the next series.",
                        tagReason: "A useful detail to track from the opening drive.",
                        source: "Field position basics",
                        slug: "field-position-basics"
                    ),
                    bullet(
                        "Tempo",
                        "Tempo is a choice, not just a pace.",
                        tieIn: "Notice whether the offense stays patient or pushes the next snap.",
                        backstory: "A faster tempo can limit defensive substitutions, while a slower sequence can give an offense time to reset its look. The contrast is easy to spot possession by possession.",
                        tagReason: "A simple way to follow the shape of a possession.",
                        source: "How tempo changes a possession",
                        slug: "tempo-and-possession"
                    ),
                    bullet(
                        "Matchups",
                        "A matchup is easier to follow when you name the task.",
                        tieIn: "Ask which unit has the clearer assignment this week.",
                        backstory: "Instead of tracking every player, follow one job: protect the passer, win the first tackle, or create space on the edge. A specific task gives the conversation a useful anchor.",
                        tagReason: "A concrete question is easier to carry into the game.",
                        source: "A simple guide to watching matchups",
                        slug: "watching-matchups"
                    )
                ],
                question: "Which part of this matchup are you watching first?"
            )
        case .officeWatercooler:
            return Content(
                headline: "Safe takes for Monday morning",
                tlDR: "Playoff season is when the whole office suddenly cares. One calm line about how the bracket works is all you need.",
                leadBackstory: "Postseason games get more airtime, more office pools and more small talk than the regular season. You don't need to know the standings, just how a series or an elimination game plays out.",
                bullets: [
                    bullet(
                        "Basketball playoffs",
                        "In a best-of-seven series, losing game one rarely decides anything.",
                        tieIn: "Safe line: \"It's a long series, they'll adjust.\"",
                        backstory: "Teams play up to seven games, so coaches treat the opener as scouting. Plenty of teams drop game one and win the series once they change their matchups.",
                        tagReason: "Agreeable, current, and true almost every year.",
                        source: "How a best-of-seven basketball series works",
                        slug: "best-of-seven"
                    ),
                    bullet(
                        "Baseball",
                        "In October, a pitcher's rest days matter more than any other month.",
                        tieIn: "Ask who's starting tonight and you sound like you follow it.",
                        backstory: "Starters usually need four days between outings. In the postseason, managers juggle that schedule to get their best arm out there as often as possible, which is why you hear so much about the rotation.",
                        tagReason: "The one baseball detail everyone repeats in October.",
                        source: "Why baseball pitchers need rest days",
                        slug: "pitcher-rest"
                    ),
                    bullet(
                        "Hockey",
                        "Pulling the goalie late is a gamble the whole building understands.",
                        tieIn: "Nobody leaves early once the net is empty.",
                        backstory: "When a team is down a goal near the end, it swaps its goalie for an extra skater. The net sits empty, so the game can swing either way in seconds, which is why the last two minutes get so loud.",
                        tag: .drama,
                        tagReason: "The last two minutes are where the tension lives.",
                        source: "Hockey's empty-net gamble, explained",
                        slug: "empty-net"
                    )
                ],
                question: "Are you the type to stay for the last two minutes, or beat the traffic?"
            )
        case .dateNight:
            return Content(
                headline: "One story worth telling tonight",
                tlDR: "Comebacks are the story everyone retells. Lead with how it turned around, then ask which kind of fan they are.",
                leadBackstory: "A comeback has a beginning, a turn and an ending, which makes it the easiest sports story to tell well. You don't need names or numbers, just the moment it changed.",
                bullets: [
                    bullet(
                        "Comebacks",
                        "The best comeback stories come down to one change at halftime.",
                        tieIn: "Ask what they'd have changed. Everyone has a theory.",
                        backstory: "Teams that come back from a big deficit usually change one thing: a matchup, the pace, a single play they keep running. Talking about what changed is more fun than recapping the score.",
                        tag: .redemption,
                        tagReason: "Everyone loves a turnaround.",
                        source: "What actually changes in a halftime comeback",
                        slug: "halftime-comeback"
                    ),
                    bullet(
                        "Tennis",
                        "Tennis has no clock, so a match is never over until the last point.",
                        tieIn: "It's why a five-set match can feel like a movie.",
                        backstory: "Without a clock, a player down two sets can still win in five. That's why long matches turn into marathons, and why fans remember them for years.",
                        tagReason: "A detail that makes any match easier to watch.",
                        source: "Why tennis matches can last for hours",
                        slug: "tennis-no-clock"
                    ),
                    bullet(
                        "Underdogs",
                        "Underdog runs are fun because nobody expected them, including the players.",
                        tieIn: "Most people pick a side here, so it's an easy follow-up.",
                        backstory: "When a lower seed makes a deep run, the whole league gets a new storyline. Players often say they play loose because nobody expects anything from them.",
                        tag: .niceGuy,
                        tagReason: "Easy to root for, hard to argue with.",
                        source: "Why underdog runs capture everyone",
                        slug: "underdog-runs"
                    )
                ],
                question: "Do you root for the underdog or the favorite?"
            )
        case .sportsTalkForMoms:
            return Content(
                headline: "Keep up with your kid's favorite sport",
                tlDR: "Your kid will bring up a rookie, a rivalry or a big game. One good question keeps them talking for twenty minutes.",
                leadBackstory: "Kids follow sports through players their own age and the teams their friends like. You don't have to know the scores; asking them to explain is the best part.",
                bullets: [
                    bullet(
                        "Soccer",
                        "Kids love explaining which soccer position they'd play, and why.",
                        tieIn: "Ask which position fits them. You'll hear a lot.",
                        backstory: "Defenders stop goals, midfielders connect the field and forwards score. Asking which one fits them gets a better answer than asking who won.",
                        tagReason: "An easy opener that lets them be the expert.",
                        source: "Soccer positions for beginners",
                        slug: "soccer-positions"
                    ),
                    bullet(
                        "Rookies",
                        "A first season is a big deal, and kids follow rookies closely.",
                        tieIn: "Ask which new player they'd want on their team.",
                        backstory: "First-year players are often only a few years older than high schoolers. Kids see themselves in them, which is why the new names come up first at dinner.",
                        tag: .niceGuy,
                        tagReason: "Rookies give kids someone to root for.",
                        source: "Why rookie seasons matter to young fans",
                        slug: "rookie-seasons"
                    ),
                    bullet(
                        "Rivalries",
                        "Every team has a rival, and your kid will happily explain why.",
                        tieIn: "Ask how it started. It's usually a great story.",
                        backstory: "Rivalries grow out of geography, history or one big game years ago. Asking how it began is an easy way to let your kid be the expert.",
                        tag: .drama,
                        tagReason: "Rivalry week brings out big feelings.",
                        source: "How sports rivalries get started",
                        slug: "rivalries"
                    )
                ],
                question: "Who's the one player you'd most want to watch in person?"
            )
        }
    }
}

/// Card art for the safe screenshot briefings: Pollinations URLs whose images
/// were checked by eye (no lettering, no people) and are already on its CDN,
/// so captures load them at once instead of queueing for the free tier's one
/// image every 45 seconds. The derived house-style art drew garbled
/// scoreboard lettering on these generic stories.
private enum ScreenshotArt {
    /// Card key (room raw value for the brief, story slug otherwise) to the
    /// scene and seed it was rendered with.
    private static let scenes: [String: (scene: String, seed: Int)] = [
        "cocktail_party": ("a brown leather american football with white laces resting on short grass at golden hour, long soft shadows", 71),
        "field-position-basics": ("a football standing on a kicking tee on green grass, warm evening light", 72),
        "tempo-and-possession": ("a silver stopwatch lying on green grass, warm evening light, close-up", 73),
        "watching-matchups": ("a coach's whistle on a cord resting on a wooden bench, warm lamp light, close-up", 74),
        "office_watercooler": ("a basketball hoop and net against a deep navy evening sky, low angle view", 31),
        "best-of-seven": ("a basketball resting on a polished hardwood floor under a single spotlight", 32),
        "pitcher-rest": ("a white baseball with red stitching resting on a weathered wooden dugout bench at dusk, warm low light", 61),
        "empty-net": ("an empty ice hockey goal net on fresh ice under cold arena light, ice spray in the air", 34),
        "date_night": ("two empty stadium seats in warm sunset light, confetti drifting in the air", 41),
        "halftime-comeback": ("a football and a whistle on a wooden locker room bench, warm lamp light", 42),
        "tennis-no-clock": ("a tennis racket and a yellow ball resting on a clay court at golden hour, long shadows", 43),
        "underdog-runs": ("a single sneaker on a curved running track lane at sunrise, long shadows", 44),
        "sports_talk_for_moms": ("a soccer ball on green grass in the morning, dew drops, soft warm light", 51),
        "soccer-positions": ("a soccer ball resting in the corner of a goal net, green grass, morning light", 52),
        "rookie-seasons": ("a pair of new soccer cleats on green grass, morning light, close-up", 53),
        "rivalries": ("two soccer balls facing each other on a green pitch, dramatic side light", 54)
    ]

    private static let style = "Deep navy, forest green and antique gold tones, soft film grain, "
        + "shallow depth of field, plain unmarked surfaces, no people, no text, no letters, "
        + "no numbers, no logos, no signage."

    /// Percent-encoded exactly as the URLs were first fetched, so each one
    /// hits the CDN copy that was checked.
    private static let allowed = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~,:'"
    )

    static func url(for key: String) -> URL? {
        guard let art = scenes[key] else { return nil }
        let prompt = "Moody cinematic still life photograph: \(art.scene). \(style)"
        guard let path = prompt.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://image.pollinations.ai/prompt/\(path)"
            + "?width=768&height=960&nologo=true&safe=true&seed=\(art.seed)")
    }
}
#endif
