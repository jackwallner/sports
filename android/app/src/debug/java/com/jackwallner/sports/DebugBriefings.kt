package com.jackwallner.sports

import com.jackwallner.sports.data.BriefingServing
import com.jackwallner.sports.model.Briefing
import com.jackwallner.sports.model.BriefingBullet
import com.jackwallner.sports.model.BriefingScope
import com.jackwallner.sports.model.BriefingTag
import com.jackwallner.sports.model.Persona
import com.jackwallner.sports.model.RefreshWindow
import java.time.Instant

/** `EdgeCaseBriefing.swift`: every card back-face branch and the overflow path. */
class EdgeCaseBriefingService : BriefingServing {
    override suspend fun latestBriefing(persona: Persona, scope: BriefingScope) = briefing

    companion object {
        val briefing = Briefing(
            persona = Persona.COCKTAIL_PARTY,
            scope = BriefingScope.NATIONAL,
            refreshWindow = RefreshWindow.DAILY,
            headline = "Edge case harness",
            tlDR = "Short lead line to say on the front of the cover card.",
            leadBackstory = "This is a long setup sentence that keeps going so the lead card back overflows the card height and has to scroll. ".repeat(6),
            bullets = listOf(
                BriefingBullet(
                    talkingPoint = "Long backstory plus long tie-in: should scroll at full size, never shrink.",
                    subject = "Long Both",
                    tieIn = "And the tie-in itself runs long enough to sit below the fold, so you must be able to scroll to reach the end of it. ".repeat(3),
                    backstory = "Backstory sentence that is deliberately long and detailed to guarantee this card overflows its height on every device size. ".repeat(6),
                    tag = BriefingTag.DRAMA,
                    tagReason = "Tag reason that should be hidden because the tie-in takes the secondary row.",
                    sourceHeadline = "Long source headline that should truncate to one line on the button",
                    sourceURL = "https://example.com/a",
                ),
                BriefingBullet(
                    talkingPoint = "Short and sweet, everything fits with room to spare.",
                    subject = "Short Both",
                    tieIn = "Short tie-in line.",
                    backstory = "A short backstory.",
                    tag = BriefingTag.NICE_GUY,
                    tagReason = "reason",
                    sourceHeadline = "Short source",
                    sourceURL = "https://example.com/b",
                ),
                BriefingBullet(
                    talkingPoint = "Backstory but no tie-in: the tag-reason row should render instead.",
                    subject = "No TieIn",
                    backstory = "Backstory with no tie-in present, so the tag-reason row is what shows under it. ".repeat(4),
                    tag = BriefingTag.JERK,
                    tagReason = "He has a history of saying the quiet part out loud, which is why this one is tagged the way it is.",
                    sourceHeadline = "Source C",
                    sourceURL = "https://example.com/c",
                ),
                BriefingBullet(
                    talkingPoint = "Tie-in only, no backstory at all.",
                    subject = "TieIn Only",
                    tieIn = "With no backstory, this tie-in becomes the body text of the card back.",
                    sourceHeadline = "Source D",
                    sourceURL = "https://example.com/d",
                ),
                BriefingBullet(
                    talkingPoint = "No backstory, no tie-in, no tag reason.",
                    subject = "Empty Back",
                    sourceHeadline = "Source E",
                    sourceURL = "https://example.com/e",
                ),
            ),
            suggestedQuestion = "Which of these edge cases worried you the most, and why?",
            sourceCount = 5,
            generatedAt = Instant.now(),
        )
    }
}

/** `SafeScreenshotBriefingService`: a current-safe briefing for store screenshots, no real people. */
class SafeScreenshotBriefingService : BriefingServing {
    override suspend fun latestBriefing(persona: Persona, scope: BriefingScope) = Briefing(
        persona = persona,
        scope = scope,
        refreshWindow = RefreshWindow.DAILY,
        headline = "The small details that change a game",
        tlDR = "A clear game plan starts with field position, tempo, and the matchup that keeps showing up.",
        leadBackstory = "Coaches tend to talk about the final score, but repeatable edges appear earlier: where possessions begin, how quickly a team resets, and which matchup creates extra room. Those details are useful because they give you something concrete to watch.",
        bullets = listOf(
            BriefingBullet(
                talkingPoint = "Field position can quietly shape a close game.",
                subject = "Field position",
                tieIn = "Watch where each drive begins before looking at the final score.",
                backstory = "Starting closer to midfield gives an offense fewer yards to cover. It also changes how a team can use its playbook on the next series.",
                tag = BriefingTag.NEUTRAL,
                tagReason = "A useful detail to track from the opening drive.",
                sourceHeadline = "Field position basics",
                sourceURL = "https://example.com/field-position-basics",
            ),
            BriefingBullet(
                talkingPoint = "Tempo is a choice, not just a pace.",
                subject = "Tempo",
                tieIn = "Notice whether the offense stays patient or pushes the next snap.",
                backstory = "A faster tempo can limit defensive substitutions, while a slower sequence can give an offense time to reset its look. The contrast is easy to spot possession by possession.",
                tag = BriefingTag.NEUTRAL,
                tagReason = "A simple way to follow the shape of a possession.",
                sourceHeadline = "How tempo changes a possession",
                sourceURL = "https://example.com/tempo-and-possession",
            ),
            BriefingBullet(
                talkingPoint = "A matchup is easier to follow when you name the task.",
                subject = "Matchups",
                tieIn = "Ask which unit has the clearer assignment this week.",
                backstory = "Instead of tracking every player, follow one job: protect the passer, win the first tackle, or create space on the edge. A specific task gives the conversation a useful anchor.",
                tag = BriefingTag.NEUTRAL,
                tagReason = "A concrete question is easier to carry into the game.",
                sourceHeadline = "A simple guide to watching matchups",
                sourceURL = "https://example.com/watching-matchups",
            ),
        ),
        suggestedQuestion = "Which part of this matchup are you watching first?",
        sourceCount = 3,
        generatedAt = Instant.now(),
    )
}
