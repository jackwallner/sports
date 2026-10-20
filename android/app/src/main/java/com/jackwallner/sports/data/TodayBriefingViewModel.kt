package com.jackwallner.sports.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.sports.model.Briefing
import com.jackwallner.sports.model.BriefingScope
import com.jackwallner.sports.model.Persona
import kotlin.coroutines.cancellation.CancellationException

/** `EntitlementProviding`: the one paid boundary. */
interface EntitlementProviding {
    val isPro: Boolean
    fun canUse(persona: Persona): Boolean = isPro || persona.isFree
}

/** `LocalEntitlementStore`, for tests. */
class LocalEntitlementStore(override var isPro: Boolean = false) : EntitlementProviding

/** `TodayBriefingViewModel.LoadState`. */
sealed interface LoadState {
    object Idle : LoadState
    object Loading : LoadState
    data class Populated(val briefing: Briefing, val isOffline: Boolean) : LoadState
    data class Failed(val message: String) : LoadState
    object RefreshLimit : LoadState
}

/**
 * `TodayBriefingViewModel.swift`: loads the selected room's briefing, falls
 * back to the offline copy, and holds the free tier to one manual refresh a
 * day on Cocktail Party.
 */
class TodayBriefingViewModel(
    private val service: BriefingServing,
    private val entitlement: EntitlementProviding,
    private val defaults: KeyValueStore,
    private val clock: AppClock = AppClock(),
    private val cache: BriefingCache? = BriefingCache(defaults),
    private val onPositiveMoment: () -> Unit = {},
    initialPersona: Persona? = null,
) {
    var selectedPersona by mutableStateOf(initialPersona ?: Persona.from(defaults.getString(LAST_PERSONA_KEY)) ?: Persona.COCKTAIL_PARTY)
    var state by mutableStateOf<LoadState>(LoadState.Idle)
        private set
    var lastBriefing by mutableStateOf<Briefing?>(null)
        private set

    private var hasShownLimitThisSession = false
    private var shouldRecordPositiveMomentOnNextSuccess = false

    /** Bumped on every load. A response lands only if its generation is still current. */
    private var loadGeneration = 0

    suspend fun load() {
        loadGeneration += 1
        val generation = loadGeneration
        state = LoadState.Loading
        val persona = selectedPersona
        try {
            val briefing = service.latestBriefing(persona, BriefingScope.NATIONAL)
            if (generation != loadGeneration) return
            runCatching { cache?.save(briefing) }
            lastBriefing = briefing
            state = LoadState.Populated(briefing, isOffline = false)
            notifyPositiveMomentIfRequested()
        } catch (error: CancellationException) {
            throw error
        } catch (error: Throwable) {
            if (generation != loadGeneration) return
            val cached = runCatching { cache?.load(persona, BriefingScope.NATIONAL) }.getOrNull()
            if (cached != null) {
                lastBriefing = cached
                state = LoadState.Populated(cached, isOffline = true)
                return
            }
            state = LoadState.Failed(friendlyMessage(error))
            shouldRecordPositiveMomentOnNextSuccess = false
        }
    }

    suspend fun select(persona: Persona): Boolean {
        if (!entitlement.canUse(persona)) return false
        selectedPersona = persona
        defaults.putString(LAST_PERSONA_KEY, persona.raw)
        shouldRecordPositiveMomentOnNextSuccess = true
        load()
        return true
    }

    suspend fun refresh() {
        shouldRecordPositiveMomentOnNextSuccess = true
        if (!entitlement.isPro) {
            if (selectedPersona != Persona.COCKTAIL_PARTY || isFreeRefreshExhaustedToday) {
                shouldRecordPositiveMomentOnNextSuccess = false
                showLimitOrStayPopulated()
                return
            }
            load()
            if (state is LoadState.Populated) defaults.putString(LAST_FREE_REFRESH_KEY, todayStamp())
            return
        }
        load()
    }

    private val isFreeRefreshExhaustedToday: Boolean
        get() = defaults.getString(LAST_FREE_REFRESH_KEY) == todayStamp()

    private fun showLimitOrStayPopulated() {
        // Quiet repeat upsell: keep the user on their briefing.
        if (hasShownLimitThisSession && lastBriefing != null) return
        hasShownLimitThisSession = true
        state = LoadState.RefreshLimit
    }

    /** ISO full date (`ISO8601DateFormatter` `.withFullDate`, which is UTC). */
    private fun todayStamp(): String = clock.now().atZone(java.time.ZoneOffset.UTC).toLocalDate().toString()

    private fun notifyPositiveMomentIfRequested() {
        if (!shouldRecordPositiveMomentOnNextSuccess) return
        shouldRecordPositiveMomentOnNextSuccess = false
        val current = state
        if (current !is LoadState.Populated || current.isOffline) return
        onPositiveMoment()
    }

    companion object {
        const val LAST_PERSONA_KEY = "sideline.lastPersona"
        const val LAST_FREE_REFRESH_KEY = "sideline.lastFreeRefreshDay"

        fun friendlyMessage(error: Throwable): String =
            (error as? BriefingServiceError)?.message
                ?: "Couldn't reach today's briefing. Check your connection and try again."
    }
}
