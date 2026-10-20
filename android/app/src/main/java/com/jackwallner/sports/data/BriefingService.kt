package com.jackwallner.sports.data

import com.jackwallner.sports.model.Briefing
import com.jackwallner.sports.model.BriefingJson
import com.jackwallner.sports.model.BriefingScope
import com.jackwallner.sports.model.Persona
import com.jackwallner.sports.model.RefreshWindow
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** `BriefingServing`: the app only ever reads the newest cached briefing. */
fun interface BriefingServing {
    suspend fun latestBriefing(persona: Persona, scope: BriefingScope): Briefing
}

/** `BriefingServiceError`, same user-facing copy. */
sealed class BriefingServiceError(message: String) : Exception(message) {
    class InvalidResponse(val statusCode: Int, val body: String) :
        BriefingServiceError("Server returned $statusCode. Try again in a moment.")
    object EmptyResult : BriefingServiceError("Nothing fresh for this room yet. Check back later.")
    object MissingConfiguration : BriefingServiceError("Briefing service isn't configured.")
    class Network(cause: Throwable) : BriefingServiceError("Couldn't reach today's briefing. Check your connection.") {
        init { initCause(cause) }
    }
}

/** One HTTP GET, so the wire contract can be tested without a network. */
fun interface HttpTransport {
    /** Returns status code and body. Throws [IOException] on a network failure. */
    fun get(url: String, headers: Map<String, String>): Pair<Int, String>
}

object UrlConnectionTransport : HttpTransport {
    override fun get(url: String, headers: Map<String, String>): Pair<Int, String> {
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = 15_000
            connection.readTimeout = 30_000
            headers.forEach(connection::setRequestProperty)
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val body = stream?.bufferedReader()?.use { it.readText() } ?: ""
            return status to body
        } finally {
            connection.disconnect()
        }
    }
}

/** `SupabaseBriefingService`: PostgREST `briefings`, newest row for persona and scope. */
class SupabaseBriefingService(
    private val supabaseURL: String,
    private val anonKey: String,
    private val transport: HttpTransport = UrlConnectionTransport,
) : BriefingServing {
    fun requestURL(persona: Persona, scope: BriefingScope): String {
        val query = listOf(
            "select" to "*",
            "persona" to "eq.${persona.raw}",
            "scope" to "eq.${scope.raw}",
            "order" to "generated_at.desc",
            "limit" to "1",
        ).joinToString("&") { (key, value) -> "$key=${URLEncoder.encode(value, "UTF-8")}" }
        return "${supabaseURL.trimEnd('/')}/rest/v1/briefings?$query"
    }

    fun headers(): Map<String, String> = mapOf(
        "apikey" to anonKey,
        "Authorization" to "Bearer $anonKey",
        "Accept" to "application/json",
    )

    override suspend fun latestBriefing(persona: Persona, scope: BriefingScope): Briefing {
        if (supabaseURL.isBlank() || anonKey.isBlank()) throw BriefingServiceError.MissingConfiguration
        val (status, body) = withContext(Dispatchers.IO) {
            try {
                transport.get(requestURL(persona, scope), headers())
            } catch (error: IOException) {
                throw BriefingServiceError.Network(error)
            }
        }
        if (status !in 200..299) throw BriefingServiceError.InvalidResponse(status, body)
        return BriefingJson.decodeRows(body).firstOrNull() ?: throw BriefingServiceError.EmptyResult
    }

    companion object {
        /** `AppConfig.fromBundle`: no URL or key means no backend, not a crash. */
        fun fromConfig(url: String, anonKey: String): SupabaseBriefingService? =
            if (url.startsWith("https://") && anonKey.isNotBlank()) SupabaseBriefingService(url, anonKey) else null
    }
}

/** `SampleBriefingService`: the preview briefing used when there is no backend. */
class SampleBriefingService : BriefingServing {
    override suspend fun latestBriefing(persona: Persona, scope: BriefingScope): Briefing {
        val sample = Briefing.sample
        if (persona == Persona.COCKTAIL_PARTY) return sample
        return Briefing(
            persona = persona,
            scope = scope,
            refreshWindow = RefreshWindow.MORNING,
            headline = sample.headline,
            tlDR = "${persona.displayName}: ${sample.tlDR}",
            bullets = sample.bullets,
            suggestedQuestion = sample.suggestedQuestion,
            sourceCount = sample.sourceCount,
            generatedAt = sample.generatedAt,
        )
    }
}

/** `BriefingCache`: the offline copy of the newest briefing per persona and scope. */
class BriefingCache(private val defaults: KeyValueStore) {
    fun save(briefing: Briefing) {
        defaults.putString(PREFIX + cacheKey(briefing.persona, briefing.scope), BriefingJson.encode(briefing))
    }

    fun load(persona: Persona, scope: BriefingScope): Briefing? {
        val raw = defaults.getString(PREFIX + cacheKey(persona, scope)) ?: return null
        return runCatching { BriefingJson.decode(org.json.JSONObject(raw)) }.getOrNull()
    }

    companion object {
        private const val PREFIX = "sideline.briefingCache."
        fun cacheKey(persona: Persona, scope: BriefingScope) = "${persona.raw}:${scope.raw}"
    }
}
