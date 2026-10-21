package com.jackwallner.sports.model

/**
 * `CardArt.swift`: free generated artwork for the deck, served by
 * pollinations.ai. One deterministic URL per card (stable seed from the
 * card's own text), so the same story gets the same art on both platforms and
 * on Pollinations' CDN cache. Prompts ask for editorial illustration of the
 * scene and mood, never a named player.
 */
object CardArt {
    /** [symbol] is the SF Symbol name iOS uses; the UI maps it to a Material icon. */
    data class Sport(val symbol: String, val name: String, val scene: String)

    /** Fallback chain, best first: the pipeline-stamped art, then the derived URL. */
    fun imageURLs(bullet: BriefingBullet): List<String> {
        val chain = mutableListOf<String>()
        bullet.imageURL?.let(chain::add)
        val sport = sport(bullet)
        val prompt = "$STYLE_PREFIX ${sport.scene}, ${mood(bullet.tag)}. $STYLE"
        // Seed on the source URL: the same story keeps the same art across personas.
        chain.add(pollinationsURL(prompt, stableSeed(bullet.sourceURL)))
        return chain.distinct()
    }

    fun leadImageURLs(briefing: Briefing): List<String> {
        val chain = mutableListOf<String>()
        briefing.leadImageURL?.let(chain::add)
        briefing.bullets.firstOrNull()?.imageURL?.let(chain::add)
        val scene = briefing.bullets.firstOrNull()?.let { sport(it).scene } ?: FALLBACK_SCENE
        val prompt = "$STYLE_PREFIX $scene, grand cinematic atmosphere. $STYLE"
        chain.add(pollinationsURL(prompt, stableSeed(briefing.tlDR)))
        return chain.distinct()
    }

    /** Kept in lockstep with `SupabaseFunctions/_shared/cardArt.ts`. */
    private const val STYLE_PREFIX = "Retro editorial sports poster illustration:"
    private const val STYLE = "Flat bold graphic shapes, screen print risograph texture, " +
        "limited palette of deep navy, warm cream, forest green and antique gold, " +
        "dramatic side lighting, grainy shadows, 1960s sports magazine poster aesthetic. " +
        "No real people's likenesses, no readable faces, no text, no words, no letters, " +
        "no numbers, no logos, no watermark, no signature, no caption."

    private const val FALLBACK_SCENE = "packed sports stadium at night under floodlights, " +
        "crowd in silhouette, confetti in the air"

    private fun mood(tag: BriefingTag?): String = when (tag) {
        BriefingTag.JERK, BriefingTag.DRAMA -> "tense dramatic mood, stormy sky, deep red and charcoal palette"
        BriefingTag.NICE_GUY, BriefingTag.REDEMPTION -> "uplifting hopeful mood, warm golden light, green and gold palette"
        else -> "energetic night-game mood, deep navy and teal palette"
    }

    /** Swift `URLComponents` output: path encoded with `urlPathAllowed`, plain numeric query. */
    fun pollinationsURL(prompt: String, seed: Long): String =
        "https://image.pollinations.ai/prompt/${encodePath(prompt)}" +
            "?width=768&height=960&nologo=true&safe=true&seed=$seed"

    private const val PATH_ALLOWED = "!$&'()*+,-./:;=@_~"

    private fun encodePath(text: String): String {
        val out = StringBuilder()
        for (byte in text.toByteArray(Charsets.UTF_8)) {
            val c = byte.toInt() and 0xFF
            val ch = c.toChar()
            if (c < 0x80 && (ch.isLetterOrDigit() || ch in PATH_ALLOWED)) out.append(ch)
            else out.append('%').append("%02X".format(c))
        }
        return out.toString()
    }

    /** FNV-1a over UTF-8, masked to 31 bits. Twin of `stableSeed` in Swift and `fnv1a32` in the pipeline. */
    fun stableSeed(text: String): Long {
        var hash = 2_166_136_261L
        for (byte in text.toByteArray(Charsets.UTF_8)) {
            hash = hash xor (byte.toLong() and 0xFF)
            hash = (hash * 16_777_619L) and 0xFFFF_FFFFL
        }
        return hash and 0x7FFF_FFFFL
    }

    /** Names the sport (chip and scene) from the story's own words. */
    fun sport(bullet: BriefingBullet): Sport {
        val hay = ((bullet.subject ?: "") + " " + bullet.sourceHeadline).lowercase()
        fun has(words: List<String>) = words.any { it in hay }

        if (has(listOf("nfl", "football", "quarterback", "touchdown", "super bowl", " qb",
                "cowboys", "eagles", "chiefs", "packers", "steelers", "49ers", "niners",
                "patriots", "bills", "ravens", "dolphins", "bengals", "broncos", "raiders",
                "browns", "seahawks", "vikings", "buccaneers", "commanders"))
        ) {
            return Sport("football.fill", "NFL", "american football stadium at night, floodlights, players in silhouette on the field")
        }
        if (has(listOf("wnba"))) {
            return Sport("basketball.fill", "WNBA", "basketball arena, single spotlight on the hardwood court, hoop in silhouette")
        }
        if (has(listOf("nba", "basketball", "dunk", "three-pointer",
                "knicks", "lakers", "celtics", "warriors", "bulls", "mavericks", "nuggets",
                "bucks", "sixers", "76ers", "timberwolves", "cavaliers", "thunder"))
        ) {
            return Sport("basketball.fill", "NBA", "basketball arena, single spotlight on the hardwood court, hoop in silhouette")
        }
        if (has(listOf("mlb", "baseball", "pitcher", "home run", "world series",
                "yankees", "dodgers", "red sox", "mets", "cubs", "astros", "braves",
                "phillies", "orioles"))
        ) {
            return Sport("baseball.fill", "MLB", "baseball stadium at dusk, batter in silhouette at home plate, stadium lights glowing")
        }
        if (has(listOf("soccer", "fifa", "premier league", "la liga", " mls", "world cup", "messi", "ronaldo"))) {
            return Sport("soccerball", "SOCCER", "soccer stadium, vivid green pitch under lights, ball in the foreground")
        }
        if (has(listOf("tennis", "wimbledon", "grand slam", "djokovic", "serena", "alcaraz"))) {
            return Sport("tennis.racket", "TENNIS", "tennis court at golden hour, long shadows, racket and ball")
        }
        if (has(listOf("nhl", "hockey", "stanley cup",
                "bruins", "oilers", "maple leafs", "canadiens", "blackhawks", "penguins"))
        ) {
            return Sport("figure.hockey", "NHL", "ice hockey rink, skater in silhouette, ice spray frozen mid-stop, cold arena light")
        }
        if (has(listOf("golf", "pga", "masters", "mcilroy"))) {
            return Sport("figure.golf", "GOLF", "golf course at sunrise, rolling fairway, lone flag on the green")
        }
        if (has(listOf("olympic", "medal"))) {
            return Sport("trophy.fill", "OLYMPICS", "olympic stadium at night, torch flame burning, fireworks above")
        }
        return when (bullet.tag) {
            BriefingTag.DRAMA, BriefingTag.JERK -> Sport("flame.fill", "", FALLBACK_SCENE)
            BriefingTag.NICE_GUY, BriefingTag.REDEMPTION -> Sport("star.fill", "", FALLBACK_SCENE)
            else -> Sport("sportscourt.fill", "", FALLBACK_SCENE)
        }
    }
}
