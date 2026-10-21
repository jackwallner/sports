package com.jackwallner.sports

import android.app.Application
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.sports.data.AppClock
import com.jackwallner.sports.data.AppSettings
import com.jackwallner.sports.data.BriefingServing
import com.jackwallner.sports.data.ConversionDiagnostics
import com.jackwallner.sports.data.ReviewPromptTracker
import com.jackwallner.sports.data.SampleBriefingService
import com.jackwallner.sports.data.SharedPreferencesStore
import com.jackwallner.sports.data.StoreService
import com.jackwallner.sports.data.SupabaseBriefingService
import com.jackwallner.sports.data.TodayBriefingViewModel
import com.jackwallner.sports.model.Persona
import kotlinx.coroutines.MainScope

class GistApplication : Application() {
    lateinit var graph: AppGraph
        private set

    override fun onCreate() {
        super.onCreate()
        graph = AppGraph(this)
    }
}

/** Every long-lived object the screens share, built once per process (`SidelineApp.init`). */
class AppGraph(context: Context) {
    val appContext: Context = context.applicationContext
    val scope = MainScope()
    val clock = AppClock()
    val defaults = SharedPreferencesStore(appContext)
    val settings = AppSettings(defaults)
    val review = ReviewPromptTracker(defaults, clock)
    val diagnostics = ConversionDiagnostics(defaults, clock)
    val store = StoreService(appContext, defaults, diagnostics)

    /** The live feed when configured, else the preview briefing (iOS `isDemo`). */
    var service: BriefingServing =
        SupabaseBriefingService.fromConfig(BuildConfig.SUPABASE_URL, BuildConfig.SUPABASE_ANON_KEY) ?: SampleBriefingService()
    var isDemo: Boolean = service is SampleBriefingService

    /** Debug options: the deck card to open on, a forced room, and screenshot mode. */
    var debugDeckStart: Int? = null
    var debugPersona: Persona? = null
    var safeScreenshot = false

    /** Bumped on each positive moment (`sidelinePositiveMomentForReview`). */
    var positiveMoments by mutableIntStateOf(0)
        private set

    /** Bumped on every activity resume, so a Custom Tab's dismissal can be seen. */
    var resumeTick by mutableIntStateOf(0)

    init {
        review.onPositiveMoment = { positiveMoments += 1 }
    }

    /** Built on first use, after debug launch options have picked the service. */
    val viewModel: TodayBriefingViewModel by lazy {
        TodayBriefingViewModel(
            service = service,
            entitlement = store,
            defaults = defaults,
            clock = clock,
            onPositiveMoment = review::recordPositiveMoment,
            initialPersona = debugPersona,
        )
    }
}
