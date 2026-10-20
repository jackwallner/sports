package com.jackwallner.sports.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.sports.model.Persona

/** `AppearanceMode.swift`. */
enum class AppearanceMode(val raw: String, val label: String) {
    SYSTEM("system", "System"),
    LIGHT("light", "Light"),
    DARK("dark", "Dark");

    companion object {
        fun from(raw: String?): AppearanceMode? = entries.firstOrNull { it.raw == raw }
    }
}

/** The `@AppStorage` values the iOS views share, under the same keys. */
class AppSettings(private val defaults: KeyValueStore) {
    var appearance by mutableStateOf(AppearanceMode.from(defaults.getString(APPEARANCE)) ?: AppearanceMode.SYSTEM)
        private set
    var hasCompletedOnboarding by mutableStateOf(defaults.getBoolean(ONBOARDED))
        private set
    var lastPersonaRaw by mutableStateOf(defaults.getString(TodayBriefingViewModel.LAST_PERSONA_KEY) ?: Persona.COCKTAIL_PARTY.raw)
        private set
    var hasSwipedDeck by mutableStateOf(defaults.getBoolean(SWIPED))
        private set

    fun updateAppearance(value: AppearanceMode) {
        appearance = value
        defaults.putString(APPEARANCE, value.raw)
    }

    fun updateOnboarded(value: Boolean) {
        hasCompletedOnboarding = value
        defaults.putBoolean(ONBOARDED, value)
    }

    fun updateLastPersona(raw: String) {
        lastPersonaRaw = raw
        defaults.putString(TodayBriefingViewModel.LAST_PERSONA_KEY, raw)
    }

    fun markSwiped() {
        if (hasSwipedDeck) return
        hasSwipedDeck = true
        defaults.putBoolean(SWIPED, true)
    }

    private companion object {
        const val APPEARANCE = "sideline.appearanceMode"
        const val ONBOARDED = "sideline.hasCompletedOnboarding"
        const val SWIPED = "sideline.hasSwipedDeck"
    }
}
