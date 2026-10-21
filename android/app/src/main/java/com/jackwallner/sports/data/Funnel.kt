package com.jackwallner.sports.data

import java.time.Instant

object StoreLinks {
    const val PACKAGE = "com.jackwallner.sports"
    const val PLAY_LISTING_URL = "https://play.google.com/store/apps/details?id=$PACKAGE"
    const val PLAY_MARKET_URI = "market://details?id=$PACKAGE"
    const val PRIVACY_URL = "https://jackwallner.github.io/sports/privacy-policy.html"
    const val TERMS_URL = "https://jackwallner.github.io/sports/terms.html"

    /** `SettingsView.feedbackMailURL`. */
    const val FEEDBACK_MAIL_URI = "mailto:jack@jackwallner.com?subject=Gist%20feedback"

    fun manageSubscriptionURL(productId: String?): String =
        if (productId == null) "https://play.google.com/store/account/subscriptions"
        else "https://play.google.com/store/account/subscriptions?sku=$productId&package=$PACKAGE"
}

/** `ReviewPromptOutcome`: only opening the review page ends the passive asks. */
enum class ReviewPromptOutcome(val raw: String) {
    OPENED_WRITE_REVIEW("openedWriteReview"),
    SUBMITTED_FEEDBACK("submittedFeedback"),
}

/**
 * `ReviewPromptTracker.swift`, Gist's rules: from the second launch, a 30-day
 * cooldown between asks, ended only by opening the store listing. On Android
 * the ask is Play's in-app review card with no question in front of it.
 */
class ReviewPromptTracker(
    private val defaults: KeyValueStore,
    private val clock: AppClock,
) {
    /** Tests and screenshot runs never trigger the store card. */
    var isAutomationRun = false

    /** Told about every positive moment (`sidelinePositiveMomentForReview`). */
    var onPositiveMoment: () -> Unit = {}

    var appLaunchCount: Int
        get() = maxOf(defaults.getInt(LAUNCH_COUNT), 0)
        set(value) = defaults.putInt(LAUNCH_COUNT, value)

    var lastShownMillis: Long?
        get() = if (defaults.contains(LAST_SHOWN)) defaults.getLong(LAST_SHOWN) else null
        set(value) = if (value == null) defaults.remove(LAST_SHOWN) else defaults.putLong(LAST_SHOWN, value)

    var outcome: ReviewPromptOutcome?
        get() = ReviewPromptOutcome.entries.firstOrNull { it.raw == defaults.getString(OUTCOME) }
        set(value) = if (value == null) defaults.remove(OUTCOME) else defaults.putString(OUTCOME, value.raw)

    var positiveMomentCount: Int
        get() = maxOf(defaults.getInt(POSITIVE_MOMENTS), 0)
        set(value) = defaults.putInt(POSITIVE_MOMENTS, value)

    var hasPendingPositiveMoment: Boolean
        get() = defaults.getBoolean(PENDING)
        set(value) = defaults.putBoolean(PENDING, value)

    val firstAppOpenMillis: Long?
        get() = if (defaults.contains(FIRST_OPEN)) defaults.getLong(FIRST_OPEN) else null

    fun recordAppLaunch() {
        if (!defaults.contains(FIRST_OPEN)) defaults.putLong(FIRST_OPEN, clock.millis())
        appLaunchCount += 1
    }

    fun recordPositiveMoment() {
        positiveMomentCount += 1
        hasPendingPositiveMoment = true
        onPositiveMoment()
    }

    fun consumePendingPositiveMoment() {
        hasPendingPositiveMoment = false
    }

    fun passivePromptAllowed(): Boolean {
        if (outcome == ReviewPromptOutcome.OPENED_WRITE_REVIEW) return false
        val last = lastShownMillis ?: return true
        return clock.millis() - last >= COOLDOWN_DAYS * DAY_MS
    }

    fun canRequestReview(hasCompletedSetup: Boolean): Boolean {
        if (isAutomationRun || !hasCompletedSetup) return false
        if (!passivePromptAllowed()) return false
        return appLaunchCount >= MINIMUM_LAUNCH_COUNT
    }

    fun shouldRequestAfterPositiveMoment(hasCompletedSetup: Boolean): Boolean =
        hasPendingPositiveMoment && canRequestReview(hasCompletedSetup)

    /** Spent when requested: Play may show nothing (quota) and there is no answer to wait for. */
    fun markShown() {
        lastShownMillis = clock.millis()
        consumePendingPositiveMoment()
    }

    fun markOpenedWriteReview() {
        outcome = ReviewPromptOutcome.OPENED_WRITE_REVIEW
        markShown()
    }

    /** Never overwrites the review-page outcome, and never starts a cooldown. */
    fun markFeedbackSubmitted() {
        if (outcome != ReviewPromptOutcome.OPENED_WRITE_REVIEW) outcome = ReviewPromptOutcome.SUBMITTED_FEEDBACK
    }

    companion object {
        const val MINIMUM_LAUNCH_COUNT = 2
        const val COOLDOWN_DAYS = 30L
        private const val LAUNCH_COUNT = "sideline.reviewPrompt.appLaunchCount"
        private const val FIRST_OPEN = "sideline.reviewPrompt.firstAppOpenDate"
        private const val LAST_SHOWN = "sideline.reviewPrompt.lastShownDate"
        private const val OUTCOME = "sideline.reviewPrompt.outcome"
        private const val POSITIVE_MOMENTS = "sideline.reviewPrompt.positiveMomentCount"
        private const val PENDING = "sideline.reviewPrompt.pendingPositiveMoment"
    }
}

/**
 * On-device record of how someone met Gist Pro before buying, mirrored
 * onto the RevenueCat customer as attributes (`ConversionDiagnostics.swift`).
 * Counts, dates and surface names only.
 */
class ConversionDiagnostics(private val defaults: KeyValueStore, private val clock: AppClock) {
    fun recordAppOpen() {
        if (!defaults.contains(INSTALLED_AT)) defaults.putLong(INSTALLED_AT, clock.millis())
        defaults.putInt(APP_OPENS, defaults.getInt(APP_OPENS) + 1)
    }

    fun recordPitchView(impressionId: String) {
        val surface = impressionId.removePrefix(PREFIX)
        defaults.putInt(TOTAL_VIEWS, defaults.getInt(TOTAL_VIEWS) + 1)
        defaults.putInt(views(surface), defaults.getInt(views(surface)) + 1)
        defaults.putString(LAST_SURFACE, surface)
        if (!defaults.contains(FIRST_SEEN)) {
            defaults.putLong(FIRST_SEEN, clock.millis())
            defaults.putInt(OPENS_BEFORE_FIRST_PITCH, defaults.getInt(APP_OPENS))
            if (defaults.contains(INSTALLED_AT)) defaults.putInt(DAYS_TO_FIRST_PITCH, daysSince(defaults.getLong(INSTALLED_AT)))
        }
    }

    /** Only the first conversion is recorded. */
    fun recordConversion(plan: String, startedTrial: Boolean, offeringId: String? = null) {
        if (defaults.contains(CONVERTED_ON)) return
        defaults.putString(CONVERTED_ON, defaults.getString(LAST_SURFACE) ?: "unknown")
        defaults.putInt(VIEWS_AT_CONVERT, defaults.getInt(TOTAL_VIEWS))
        defaults.putString(CONVERTED_PLAN, plan)
        defaults.putBoolean(CONVERTED_WITH_TRIAL, startedTrial)
        defaults.putLong(CONVERTED_AT, clock.millis())
        offeringId?.let { defaults.putString(CONVERTED_OFFERING, it) }
        if (defaults.contains(FIRST_SEEN)) defaults.putInt(DAYS_TO_CONVERT, daysSince(defaults.getLong(FIRST_SEEN)))
    }

    /** Empty until the first pitch. Keys stay under RevenueCat's 40-character limit. */
    val subscriberAttributes: Map<String, String>
        get() {
            val total = defaults.getInt(TOTAL_VIEWS)
            if (total <= 0) return emptyMap()
            val attributes = mutableMapOf("pitch_views_total" to total.toString())
            for (key in defaults.keys()) {
                if (!key.startsWith(VIEWS_PREFIX) || key == TOTAL_VIEWS) continue
                val count = defaults.getInt(key)
                if (count > 0) attributes["pitch_views_${key.removePrefix(VIEWS_PREFIX)}".take(40)] = count.toString()
            }
            defaults.getString(LAST_SURFACE)?.let { attributes["pitch_last"] = it }
            if (defaults.contains(FIRST_SEEN)) {
                val first = defaults.getLong(FIRST_SEEN)
                attributes["pitch_first_seen"] = Instant.ofEpochMilli(first).toString()
                attributes["days_since_first_pitch"] = daysSince(first).toString()
            }
            if (defaults.contains(DAYS_TO_FIRST_PITCH)) attributes["days_since_install"] = defaults.getInt(DAYS_TO_FIRST_PITCH).toString()
            if (defaults.contains(OPENS_BEFORE_FIRST_PITCH)) attributes["opens_before_first_pitch"] = defaults.getInt(OPENS_BEFORE_FIRST_PITCH).toString()
            defaults.getString(CONVERTED_ON)?.let { convertedOn ->
                attributes["converted_surface"] = convertedOn
                attributes["converted_at"] = Instant.ofEpochMilli(defaults.getLong(CONVERTED_AT)).toString()
                attributes["pitch_views_at_convert"] = defaults.getInt(VIEWS_AT_CONVERT).toString()
                attributes["days_to_convert"] = defaults.getInt(DAYS_TO_CONVERT).toString()
                attributes["converted_plan"] = defaults.getString(CONVERTED_PLAN) ?: "unknown"
                attributes["converted_with_trial"] = if (defaults.getBoolean(CONVERTED_WITH_TRIAL)) "true" else "false"
                defaults.getString(CONVERTED_OFFERING)?.let { attributes["converted_offering"] = it }
            }
            return attributes
        }

    private fun daysSince(millis: Long): Int = maxOf(0, ((clock.millis() - millis) / DAY_MS).toInt())

    private fun views(surface: String) = "$VIEWS_PREFIX$surface"

    private companion object {
        const val PREFIX = "sideline_"
        const val VIEWS_PREFIX = "conv.pitchViews."
        const val TOTAL_VIEWS = "conv.pitchViews.total"
        const val FIRST_SEEN = "conv.pitchFirstSeen"
        const val LAST_SURFACE = "conv.pitchLastSurface"
        const val INSTALLED_AT = "conv.installedAt"
        const val APP_OPENS = "conv.appOpens"
        const val OPENS_BEFORE_FIRST_PITCH = "conv.opensBeforeFirstPitch"
        const val DAYS_TO_FIRST_PITCH = "conv.daysToFirstPitch"
        const val CONVERTED_ON = "conv.convertedOn"
        const val CONVERTED_AT = "conv.convertedAt"
        const val VIEWS_AT_CONVERT = "conv.viewsAtConvert"
        const val DAYS_TO_CONVERT = "conv.daysToConvert"
        const val CONVERTED_PLAN = "conv.convertedPlan"
        const val CONVERTED_WITH_TRIAL = "conv.convertedWithTrial"
        const val CONVERTED_OFFERING = "conv.convertedOffering"
    }
}
