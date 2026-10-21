package com.jackwallner.sports

import android.content.Intent
import com.jackwallner.sports.data.AppearanceMode
import com.jackwallner.sports.data.SampleBriefingService
import com.jackwallner.sports.model.Persona

/**
 * Debug-only launch extras for tests and screenshots, the Android side of the
 * iOS launch arguments. None of this is compiled into a release build.
 *
 *     adb shell am start -n com.jackwallner.sports/.MainActivity \
 *         --ez uiTest true --ez onboarded true --ez demo true --es appearance dark
 *
 * `demo` (`-SidelineScreenshotDemo`), `safeScreenshot` (`-SidelineSafeScreenshot`)
 * and `edgeCases` (`-SidelineEdgeCases`) swap the live feed for a fixed briefing;
 * `forcePro` (`-SidelineForcePro`), `persona` (`-SidelinePersona`) and
 * `deckStart` (`-SidelineDeckStart`) match their iOS twins.
 */
object DebugLaunchOptions {
    fun apply(graph: AppGraph, intent: Intent?) {
        val extras = intent?.extras ?: return
        if (extras.getBoolean("uiTest")) graph.review.isAutomationRun = true
        if (extras.getBoolean("forcePro")) graph.store.forceProForDebug()
        if (extras.getBoolean("onboarded")) graph.settings.updateOnboarded(true)
        extras.getString("appearance")?.let { raw -> AppearanceMode.from(raw)?.let(graph.settings::updateAppearance) }
        extras.getString("persona")?.let { raw ->
            Persona.from(raw)?.let {
                graph.debugPersona = it
                graph.settings.updateLastPersona(it.raw)
            }
        }
        if (extras.containsKey("deckStart")) graph.debugDeckStart = extras.getInt("deckStart")
        when {
            extras.getBoolean("edgeCases") -> useDebugService(graph, EdgeCaseBriefingService())
            extras.getBoolean("safeScreenshot") -> {
                useDebugService(graph, SafeScreenshotBriefingService())
                graph.safeScreenshot = true
                graph.review.isAutomationRun = true
                graph.store.suppressImpressions = true
            }
            extras.getBoolean("demo") -> useDebugService(graph, SampleBriefingService())
        }
    }

    private fun useDebugService(graph: AppGraph, service: com.jackwallner.sports.data.BriefingServing) {
        graph.service = service
        graph.isDemo = true
    }
}
