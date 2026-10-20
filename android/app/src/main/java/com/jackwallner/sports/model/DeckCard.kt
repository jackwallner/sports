package com.jackwallner.sports.model

/** `DeckCard`: one card in the briefing deck. */
sealed interface DeckCard {
    data class Lead(val briefing: Briefing) : DeckCard
    data class Point(val bullet: BriefingBullet) : DeckCard
    data class Question(val text: String) : DeckCard

    /** Free-deck finale: the other rooms, framed as more stories, not tones. */
    object Rooms : DeckCard

    /**
     * Story cards carry their detail on the back, the lead card too when the
     * pipeline wrote a setup. A story card has a back only if the row carries
     * back content, so an old row never flips onto an empty panel.
     */
    val hasBack: Boolean
        get() = when (this) {
            is Point -> !bullet.backstory.isNullOrEmpty() || !bullet.tieIn.isNullOrEmpty() || !bullet.tagReason.isNullOrEmpty()
            is Lead -> !briefing.leadBackstory.isNullOrEmpty()
            is Question, Rooms -> false
        }

    companion object {
        /** Lead, the stories, the question, then the rooms card for free users only. */
        fun cards(briefing: Briefing, isPro: Boolean): List<DeckCard> {
            val cards = mutableListOf<DeckCard>(Lead(briefing))
            briefing.bullets.mapTo(cards, ::Point)
            cards.add(Question(briefing.suggestedQuestion))
            if (!isPro) cards.add(Rooms)
            return cards
        }

        /** Story kicker: the subject when there is one, the sport otherwise. */
        fun kicker(bullet: BriefingBullet): String {
            bullet.subject?.takeIf { it.isNotEmpty() }?.let { return it }
            val name = CardArt.sport(bullet).name
            return name.ifEmpty { "Worth mentioning" }
        }

        /** What a report about this card quotes, so the problem can be found in the pipeline. */
        fun reportSummary(card: DeckCard): String? = when (card) {
            is Lead -> "Brief: ${card.briefing.tlDR}"
            is Point -> "Card: ${card.bullet.talkingPoint}\nSource: ${card.bullet.sourceHeadline}\n${card.bullet.sourceURL}"
            is Question -> "Question: ${card.text}"
            Rooms -> null
        }

        /** Scale steps the card backs try, largest first (`fitScales`). */
        val fitScales = listOf(1.0f, 0.92f, 0.84f, 0.76f, 0.68f, 0.6f, 0.52f, 0.44f)
    }
}
