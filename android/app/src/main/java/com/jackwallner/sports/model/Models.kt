package com.jackwallner.sports.model

import java.time.Instant
import java.util.UUID

/** `Persona.swift`: the four rooms. Only Cocktail Party is free. */
enum class Persona(val raw: String) {
    COCKTAIL_PARTY("cocktail_party"),
    SPORTS_TALK_FOR_MOMS("sports_talk_for_moms"),
    OFFICE_WATERCOOLER("office_watercooler"),
    DATE_NIGHT("date_night");

    val displayName: String
        get() = when (this) {
            COCKTAIL_PARTY -> "Cocktail Party"
            SPORTS_TALK_FOR_MOMS -> "Sports Talk for Moms"
            OFFICE_WATERCOOLER -> "Office Watercooler"
            DATE_NIGHT -> "Date Night"
        }

    val shortPitch: String
        get() = when (this) {
            COCKTAIL_PARTY -> "Broad, witty, easy to drop anywhere."
            SPORTS_TALK_FOR_MOMS -> "Warm prompts for talking with a sports-obsessed kid."
            OFFICE_WATERCOOLER -> "Safe, current takes for coworkers."
            DATE_NIGHT -> "A charming story and a follow-up question."
        }

    val isFree: Boolean get() = this == COCKTAIL_PARTY

    val contextHeader: String
        get() = when (this) {
            COCKTAIL_PARTY -> "WHEN TALK TURNS TO SPORTS"
            SPORTS_TALK_FOR_MOMS -> "WHEN YOUR KID BRINGS IT UP"
            OFFICE_WATERCOOLER -> "AT THE OFFICE TODAY"
            DATE_NIGHT -> "FOR THE DINNER TABLE"
        }

    /** A real, readable taste of how this room sounds, shown unblurred in the Pro preview. */
    val proPreviewTeaser: String
        get() = when (this) {
            COCKTAIL_PARTY ->
                "\"Everyone's calling it the upset of the year, but honestly the favorite looked tired all night.\" Drop that and you're in the conversation."
            SPORTS_TALK_FOR_MOMS ->
                "Your kid won't stop talking about the rookie everyone's hyping. Try: \"Is he actually better than the guy who got hurt?\" Watch them light up."
            OFFICE_WATERCOOLER ->
                "Someone will bring up last night's blown call. Safe line: \"The refs are having a rough season, huh?\" Agreeable, current, done."
            DATE_NIGHT ->
                "Lead with the comeback: a player benched all year won it in the final seconds. Then ask, \"Do you root for the underdog or the favorite?\""
        }

    val paywallHook: String
        get() = when (this) {
            COCKTAIL_PARTY -> "Sound prepared anywhere"
            SPORTS_TALK_FOR_MOMS -> "Sound tuned-in to your kid"
            OFFICE_WATERCOOLER -> "Sound prepared at the office"
            DATE_NIGHT -> "Sound prepared at dinner"
        }

    companion object {
        fun from(raw: String?): Persona? = entries.firstOrNull { it.raw == raw }
    }
}

/** `BriefingTag.swift`. */
enum class BriefingTag(val raw: String, val displayName: String) {
    NICE_GUY("nice_guy", "Nice guy"),
    JERK("jerk", "Jerk"),
    REDEMPTION("redemption", "Redemption"),
    DRAMA("drama", "Drama"),
    NEUTRAL("neutral", "Neutral");

    companion object {
        fun from(raw: String?): BriefingTag? = entries.firstOrNull { it.raw == raw }
    }
}

enum class BriefingScope(val raw: String) {
    NATIONAL("national"),
    LOCAL("local");

    companion object {
        fun from(raw: String?): BriefingScope? = entries.firstOrNull { it.raw == raw }
    }
}

enum class RefreshWindow(val raw: String) {
    DAILY("daily"),
    MORNING("morning"),
    MIDDAY("midday"),
    EVENING("evening");

    val nextUpdateHint: String
        get() = when (this) {
            DAILY -> "Next briefing tomorrow morning"
            MORNING -> "Next refresh midday"
            MIDDAY -> "Next refresh this evening"
            EVENING -> "Next briefing tomorrow morning"
        }

    companion object {
        fun from(raw: String?): RefreshWindow? = entries.firstOrNull { it.raw == raw }
    }
}

/** `Briefing.swift`: one persona's newest cached briefing. */
data class Briefing(
    val id: UUID = UUID.randomUUID(),
    val persona: Persona,
    val scope: BriefingScope,
    val refreshWindow: RefreshWindow,
    val headline: String,
    val tlDR: String,
    /** 2-3 sentences of setup behind the TL;DR, on the cover card's back. Older rows lack it. */
    val leadBackstory: String? = null,
    /** Cover-card art stamped by the pipeline. Older rows lack it. */
    val leadImageURL: String? = null,
    val bullets: List<BriefingBullet>,
    val suggestedQuestion: String,
    val sourceCount: Int,
    val generatedAt: Instant,
    val expiresAt: Instant? = null,
) {
    companion object {
        val sample: Briefing by lazy {
            Briefing(
                persona = Persona.COCKTAIL_PARTY,
                scope = BriefingScope.NATIONAL,
                refreshWindow = RefreshWindow.DAILY,
                headline = "What everyone's arguing about this week",
                tlDR = "A beloved veteran quarterback got benched, the internet is melting down, and his replacement is a 23-year-old nobody had heard of last month.",
                leadBackstory = "The Cowboys, the most-watched team in football, sat down their starter of 9 years in the middle of a playoff race. Quarterback is the one job everyone in the building depends on, so this is like a company swapping CEOs the week before earnings. The new guy was stocking warehouse shelves 2 years ago, which is why the whole internet has an opinion.",
                bullets = listOf(
                    BriefingBullet(
                        talkingPoint = "The team benched their longtime starter. Fans are split between 'about time' and 'how dare they.'",
                        subject = "Cowboys",
                        tieIn = "His wife posted a cryptic quote about loyalty, which did not help.",
                        backstory = "He has started every game for 9 years, but the team has lost 5 in a row and the front office is feeling the heat. Coaches say the move is about a playoff push, not his legacy. Fans see a franchise icon getting shoved out the door.",
                        tag = BriefingTag.DRAMA,
                        tagReason = "Locker-room sources are frustrated, per reporters.",
                        sourceHeadline = "Veteran QB benched amid playoff push - The Athletic",
                        sourceURL = "https://example.com/veteran-qb-benched",
                    ),
                    BriefingBullet(
                        talkingPoint = "The 23-year-old replacement is the feel-good story: undrafted, was working a normal job 2 years ago.",
                        subject = "NFL",
                        backstory = "No college program wanted him, so he stocked warehouse shelves while playing semi-pro on weekends. A scout spotted him at an open tryout 2 years ago. Now he is starting in front of 80,000 people.",
                        tag = BriefingTag.NICE_GUY,
                        tagReason = "Donated his first big check to his old high school.",
                        sourceHeadline = "From warehouse shifts to starting QB - ESPN",
                        sourceURL = "https://example.com/warehouse-to-qb",
                    ),
                    BriefingBullet(
                        talkingPoint = "A star player from another team called the benching disrespectful, and now those 2 teams play Sunday.",
                        subject = "Eagles",
                        backstory = "The two quarterbacks came up together and are close friends, which is why the rival star took it personally. The league fined him for the comments, and he said it was worth every dollar. Sunday is the first meeting since.",
                        tag = BriefingTag.DRAMA,
                        tagReason = "He has a history of saying the quiet part loud.",
                        sourceHeadline = "Rival star sounds off - Yahoo Sports",
                        sourceURL = "https://example.com/rival-star",
                    ),
                ),
                suggestedQuestion = "Do you think they made the right call, or did they just blow up their season?",
                sourceCount = 3,
                generatedAt = Instant.now(),
            )
        }
    }
}

/** `BriefingBullet`: one story card. */
data class BriefingBullet(
    val id: UUID = UUID.randomUUID(),
    val talkingPoint: String,
    val subject: String? = null,
    val tieIn: String? = null,
    /** 2-3 sentences of context for a follow-up. Older rows lack it; the back falls back to the tie-in. */
    val backstory: String? = null,
    val tag: BriefingTag? = null,
    val tagReason: String? = null,
    val sourceHeadline: String,
    val sourceURL: String,
    /** Card art pre-stamped by the pipeline. Older rows lack it; the app derives a URL. */
    val imageURL: String? = null,
)
