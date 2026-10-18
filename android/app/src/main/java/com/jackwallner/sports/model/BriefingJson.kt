package com.jackwallner.sports.model

import java.time.Instant
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject

class BriefingDecodingException(message: String) : Exception(message)

/**
 * The Supabase `briefings` row contract (`Briefing.CodingKeys`). Decoding is the
 * same JSON shape iOS reads; encoding writes the same keys for the offline cache.
 */
object BriefingJson {
    fun decodeRows(body: String): List<Briefing> {
        val rows = JSONArray(body)
        return (0 until rows.length()).map { decode(rows.getJSONObject(it)) }
    }

    fun decode(json: JSONObject): Briefing = Briefing(
        id = uuid(json.requireString("id")),
        persona = Persona.from(json.requireString("persona")) ?: fail("persona"),
        scope = BriefingScope.from(json.requireString("scope")) ?: fail("scope"),
        refreshWindow = RefreshWindow.from(json.requireString("refresh_window")) ?: fail("refresh_window"),
        headline = json.requireString("headline"),
        tlDR = json.requireString("tl_dr"),
        leadBackstory = json.optionalString("lead_backstory"),
        leadImageURL = json.optionalString("lead_image_url"),
        bullets = json.optJSONArray("bullets")?.let { array -> (0 until array.length()).map { bullet(array.getJSONObject(it)) } }
            ?: fail("bullets"),
        suggestedQuestion = json.requireString("suggested_question"),
        sourceCount = if (json.has("source_count") && !json.isNull("source_count")) json.getInt("source_count") else fail("source_count"),
        generatedAt = parseDate(json.requireString("generated_at")),
        expiresAt = json.optionalString("expires_at")?.let(::parseDate),
    )

    private fun bullet(json: JSONObject): BriefingBullet = BriefingBullet(
        id = uuid(json.requireString("id")),
        talkingPoint = json.requireString("talking_point"),
        subject = json.optionalString("subject"),
        tieIn = json.optionalString("tie_in"),
        backstory = json.optionalString("backstory"),
        tag = json.optionalString("tag")?.let(BriefingTag::from),
        tagReason = json.optionalString("tag_reason"),
        sourceHeadline = json.requireString("source_headline"),
        sourceURL = json.requireString("source_url"),
        imageURL = json.optionalString("image_url"),
    )

    fun encode(briefing: Briefing): String = JSONObject().apply {
        put("id", briefing.id.toString())
        put("persona", briefing.persona.raw)
        put("scope", briefing.scope.raw)
        put("refresh_window", briefing.refreshWindow.raw)
        put("headline", briefing.headline)
        put("tl_dr", briefing.tlDR)
        briefing.leadBackstory?.let { put("lead_backstory", it) }
        briefing.leadImageURL?.let { put("lead_image_url", it) }
        put("bullets", JSONArray(briefing.bullets.map(::encodeBullet)))
        put("suggested_question", briefing.suggestedQuestion)
        put("source_count", briefing.sourceCount)
        put("generated_at", briefing.generatedAt.toString())
        briefing.expiresAt?.let { put("expires_at", it.toString()) }
    }.toString()

    private fun encodeBullet(bullet: BriefingBullet) = JSONObject().apply {
        put("id", bullet.id.toString())
        put("talking_point", bullet.talkingPoint)
        bullet.subject?.let { put("subject", it) }
        bullet.tieIn?.let { put("tie_in", it) }
        bullet.backstory?.let { put("backstory", it) }
        bullet.tag?.let { put("tag", it.raw) }
        bullet.tagReason?.let { put("tag_reason", it) }
        put("source_headline", bullet.sourceHeadline)
        put("source_url", bullet.sourceURL)
        bullet.imageURL?.let { put("image_url", it) }
    }

    /** ISO 8601 with or without fractional seconds, as PostgREST returns them. */
    fun parseDate(raw: String): Instant =
        runCatching { OffsetDateTime.parse(raw, DateTimeFormatter.ISO_OFFSET_DATE_TIME).toInstant() }
            .getOrElse { throw BriefingDecodingException("Bad date: $raw") }

    private fun uuid(raw: String): UUID =
        runCatching { UUID.fromString(raw) }.getOrElse { throw BriefingDecodingException("Bad id: $raw") }

    private fun JSONObject.requireString(key: String): String {
        if (!has(key) || isNull(key)) fail(key)
        return getString(key)
    }

    private fun JSONObject.optionalString(key: String): String? =
        if (!has(key) || isNull(key)) null else getString(key)

    private fun fail(key: String): Nothing = throw BriefingDecodingException("Missing $key")
}
