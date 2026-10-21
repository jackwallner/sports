package com.jackwallner.sports

import com.jackwallner.sports.data.BriefingServiceError
import com.jackwallner.sports.data.BriefingServing
import com.jackwallner.sports.data.ConversionDiagnostics
import com.jackwallner.sports.data.InMemoryStore
import com.jackwallner.sports.data.AppClock
import com.jackwallner.sports.data.LoadState
import com.jackwallner.sports.data.LocalEntitlementStore
import com.jackwallner.sports.data.PlanKind
import com.jackwallner.sports.data.ReviewPromptOutcome
import com.jackwallner.sports.data.ReviewPromptTracker
import com.jackwallner.sports.data.TodayBriefingViewModel
import com.jackwallner.sports.model.Briefing
import com.jackwallner.sports.model.BriefingBullet
import com.jackwallner.sports.model.BriefingJson
import com.jackwallner.sports.model.BriefingScope
import com.jackwallner.sports.model.BriefingTag
import com.jackwallner.sports.model.Persona
import com.jackwallner.sports.model.RefreshWindow
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.ZoneOffset
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/** A clock the test can move. */
class MutableClock(var instant: Instant = Instant.parse("2026-10-18T12:00:00Z")) : Clock() {
    override fun getZone() = ZoneOffset.UTC
    override fun withZone(zone: java.time.ZoneId?) = this
    override fun instant() = instant
    fun advance(duration: Duration) { instant = instant.plus(duration) }
}

/** `BriefingDecodingTests.swift`. */
class BriefingDecodingTests {
    @Test fun decodesSupabaseBriefingContract() {
        val json = """
        [{
          "id": "11111111-1111-1111-1111-111111111111",
          "persona": "cocktail_party",
          "scope": "national",
          "refresh_window": "daily",
          "headline": "What everyone's arguing about this week",
          "tl_dr": "A beloved veteran quarterback got benched, the internet is melting down, and his replacement is a 23-year-old nobody had heard of last month.",
          "lead_image_url": "https://example.supabase.co/storage/v1/object/public/card-art/lead.jpg",
          "lead_backstory": "The Cowboys, the most-watched team in football, benched their starter of 9 years mid-playoff race.",
          "bullets": [{
            "id": "22222222-2222-2222-2222-222222222222",
            "talking_point": "The team benched their longtime starter, and fans are split.",
            "tie_in": "His wife posted a cryptic quote about loyalty.",
            "backstory": "He has started every game for 9 years, but the team lost 5 straight and the front office blinked first.",
            "tag": "drama",
            "tag_reason": "Locker-room sources are frustrated.",
            "source_headline": "Veteran QB benched amid playoff push - The Athletic",
            "source_url": "https://example.com/story",
            "image_url": "https://image.pollinations.ai/prompt/test?seed=1"
          }, {
            "id": "33333333-3333-3333-3333-333333333333",
            "talking_point": "Older bullet without pipeline-stamped art still decodes.",
            "source_headline": "From warehouse shifts to starting QB - ESPN",
            "source_url": "https://example.com/other"
          }],
          "suggested_question": "Do you think they made the right call?",
          "source_count": 1,
          "generated_at": "2026-05-16T12:00:00Z",
          "expires_at": "2026-05-17T12:00:00Z"
        }]
        """.trimIndent()

        val briefing = BriefingJson.decodeRows(json).first()

        assertEquals(Persona.COCKTAIL_PARTY, briefing.persona)
        assertEquals(BriefingTag.DRAMA, briefing.bullets.first().tag)
        assertEquals(1, briefing.sourceCount)
        assertEquals("https://image.pollinations.ai/prompt/test?seed=1", briefing.bullets.first().imageURL)
        assertEquals("https://example.supabase.co/storage/v1/object/public/card-art/lead.jpg", briefing.leadImageURL)
        assertEquals("The Cowboys, the most-watched team in football, benched their starter of 9 years mid-playoff race.", briefing.leadBackstory)
        assertEquals(
            "He has started every game for 9 years, but the team lost 5 straight and the front office blinked first.",
            briefing.bullets.first().backstory,
        )
        assertNull(briefing.bullets.last().imageURL)
        // Pre-v2 rows decode without the new fields.
        assertNull(briefing.bullets.last().backstory)
    }

    @Test fun sampleBriefingHasRequiredSourceLinks() {
        assertFalse(Briefing.sample.bullets.isEmpty())
        assertTrue(Briefing.sample.bullets.all { it.sourceURL.startsWith("https://") })
    }

    @Test fun paywallPackagePriorityLeadsWithSubscriptions() {
        assertTrue(PlanKind.ANNUAL.ordinal < PlanKind.MONTHLY.ordinal)
        assertTrue(PlanKind.MONTHLY.ordinal < PlanKind.LIFETIME.ordinal)
        assertTrue(PlanKind.LIFETIME.ordinal < PlanKind.OTHER.ordinal)
    }
}

/** `PaywallFunnelTests.swift`: a fresh store per test, like the throwaway suite. */
class PaywallFunnelTests {
    private val clock = MutableClock()
    private val diagnostics = ConversionDiagnostics(InMemoryStore(), AppClock(clock))

    @Test fun countsPitchesPerSurfaceAndInTotal() {
        diagnostics.recordPitchView("sideline_onboarding_paywall")
        diagnostics.recordPitchView("sideline_onboarding_paywall")
        diagnostics.recordPitchView("sideline_paywall_sheet")
        val attributes = diagnostics.subscriberAttributes
        assertEquals("3", attributes["pitch_views_total"])
        assertEquals("2", attributes["pitch_views_onboarding_paywall"])
        assertEquals("paywall_sheet", attributes["pitch_last"])
    }

    @Test fun noAttributesBeforeAnyPitchIsSeen() {
        diagnostics.recordAppOpen()
        assertTrue(diagnostics.subscriberAttributes.isEmpty())
    }

    @Test fun recordsHowEarlyTheFirstPitchArrived() {
        diagnostics.recordAppOpen()
        diagnostics.recordAppOpen()
        diagnostics.recordPitchView("sideline_onboarding_paywall")
        val attributes = diagnostics.subscriberAttributes
        assertEquals("2", attributes["opens_before_first_pitch"])
        assertEquals("0", attributes["days_since_install"])
    }

    @Test fun theEarlinessPairIsFrozenOnTheFirstPitchOnly() {
        diagnostics.recordAppOpen()
        diagnostics.recordPitchView("sideline_onboarding_paywall")
        diagnostics.recordAppOpen()
        diagnostics.recordPitchView("sideline_paywall_sheet")
        assertEquals("1", diagnostics.subscriberAttributes["opens_before_first_pitch"])
    }

    @Test fun anInstallThatPredatesThisCodeReportsNoAge() {
        diagnostics.recordPitchView("sideline_onboarding_paywall")
        assertNull(diagnostics.subscriberAttributes["days_since_install"])
        assertNotNull(diagnostics.subscriberAttributes["pitch_views_total"])
    }

    @Test fun conversionFreezesTheSurfaceAndCountAtTheMomentOfSale() {
        diagnostics.recordPitchView("sideline_onboarding_paywall")
        diagnostics.recordPitchView("sideline_paywall_sheet")
        diagnostics.recordConversion("yearly", startedTrial = true, offeringId = "default")
        diagnostics.recordPitchView("sideline_onboarding_paywall")
        val attributes = diagnostics.subscriberAttributes
        assertEquals("paywall_sheet", attributes["converted_surface"])
        assertEquals("2", attributes["pitch_views_at_convert"])
        assertEquals("yearly", attributes["converted_plan"])
        assertEquals("true", attributes["converted_with_trial"])
        assertEquals("default", attributes["converted_offering"])
    }

    @Test fun onlyTheFirstConversionIsRecorded() {
        diagnostics.recordPitchView("sideline_onboarding_paywall")
        diagnostics.recordConversion("monthly", startedTrial = true)
        diagnostics.recordConversion("yearly", startedTrial = false)
        val attributes = diagnostics.subscriberAttributes
        assertEquals("monthly", attributes["converted_plan"])
        assertEquals("true", attributes["converted_with_trial"])
    }

    @Test fun attributeKeysStayInsideRevenueCatsLimit() {
        diagnostics.recordPitchView("sideline_" + "a".repeat(80))
        diagnostics.subscriberAttributes.keys.forEach { assertTrue("attribute key too long: $it", it.length <= 40) }
    }

    @Test fun noAttributeCarriesFreeTextOrHealthData() {
        diagnostics.recordAppOpen()
        diagnostics.recordPitchView("sideline_onboarding_paywall")
        diagnostics.recordConversion("monthly", startedTrial = false)
        diagnostics.subscriberAttributes.forEach { (key, value) ->
            assertFalse("$key looks like free text: $value", value.contains(" "))
            assertTrue("$key is too long to be a label", value.length <= 64)
        }
    }
}

/** `ReviewPromptTrackerTests.swift`: ask from the second launch, 30-day cooldown, stop only on the review page. */
class ReviewPromptTrackerTests {
    private val clock = MutableClock()
    private val tracker = ReviewPromptTracker(InMemoryStore(), AppClock(clock))

    @Test fun asksFromTheSecondSession() {
        tracker.appLaunchCount = 2
        assertTrue(tracker.canRequestReview(hasCompletedSetup = true))
    }

    @Test fun neverAsksInTheFirstSession() {
        tracker.appLaunchCount = 1
        assertFalse(tracker.canRequestReview(hasCompletedSetup = true))
    }

    @Test fun stillRequiresFinishedOnboarding() {
        tracker.appLaunchCount = 9
        assertFalse(tracker.canRequestReview(hasCompletedSetup = false))
    }

    @Test fun openingTheReviewPageEndsTheAsks() {
        tracker.appLaunchCount = 9
        tracker.markOpenedWriteReview()
        tracker.lastShownMillis = clock.millis() - 365 * 86_400_000L
        assertFalse(tracker.canRequestReview(hasCompletedSetup = true))
    }

    @Test fun waitsOutTheCooldown() {
        tracker.appLaunchCount = 9
        tracker.lastShownMillis = clock.millis() - 10 * 86_400_000L
        assertFalse(tracker.canRequestReview(hasCompletedSetup = true))
        tracker.lastShownMillis = clock.millis() - 31 * 86_400_000L
        assertTrue(tracker.canRequestReview(hasCompletedSetup = true))
    }

    @Test fun feedbackNeverEndsTheAsks() {
        tracker.appLaunchCount = 9
        tracker.markFeedbackSubmitted()
        assertEquals(ReviewPromptOutcome.SUBMITTED_FEEDBACK, tracker.outcome)
        assertNull("feedback must not start a cooldown", tracker.lastShownMillis)
        assertTrue(tracker.canRequestReview(hasCompletedSetup = true))
    }

    @Test fun feedbackAfterTheReviewPageKeepsTheAsksEnded() {
        tracker.appLaunchCount = 9
        tracker.markOpenedWriteReview()
        tracker.markFeedbackSubmitted()
        assertEquals(ReviewPromptOutcome.OPENED_WRITE_REVIEW, tracker.outcome)
        assertFalse(tracker.canRequestReview(hasCompletedSetup = true))
    }

    @Test fun blockedAskKeepsTheMomentPending() {
        tracker.appLaunchCount = 9
        tracker.recordPositiveMoment()
        assertTrue(tracker.shouldRequestAfterPositiveMoment(hasCompletedSetup = true))
        assertTrue(tracker.shouldRequestAfterPositiveMoment(hasCompletedSetup = true))
        tracker.markShown()
        assertFalse(tracker.shouldRequestAfterPositiveMoment(hasCompletedSetup = true))
    }
}

/** `TodayBriefingViewModelTests.swift`. */
class TodayBriefingViewModelTests {
    private val defaults = InMemoryStore()

    private fun makeBriefing(tlDR: String = "Test TLDR") = Briefing(
        persona = Persona.COCKTAIL_PARTY,
        scope = BriefingScope.NATIONAL,
        refreshWindow = RefreshWindow.DAILY,
        headline = "Test headline",
        tlDR = tlDR,
        bullets = listOf(BriefingBullet(talkingPoint = "Test point", sourceHeadline = "Test - Source", sourceURL = "https://example.com/test")),
        suggestedQuestion = "Test question?",
        sourceCount = 1,
        generatedAt = Instant.now(),
    )

    private class MockService : BriefingServing {
        var result: Result<Briefing>? = null
        override suspend fun latestBriefing(persona: Persona, scope: BriefingScope): Briefing =
            (result ?: throw BriefingServiceError.EmptyResult).getOrThrow()
    }

    private fun vm(service: BriefingServing, isPro: Boolean = false) =
        TodayBriefingViewModel(service, LocalEntitlementStore(isPro), defaults)

    @Test fun initialStateIsIdle() {
        val vm = vm(MockService())
        assertEquals(LoadState.Idle, vm.state)
        assertEquals(Persona.COCKTAIL_PARTY, vm.selectedPersona)
        assertNull(vm.lastBriefing)
    }

    @Test fun loadPopulatesBriefing() = runTest {
        val service = MockService().apply { result = Result.success(makeBriefing()) }
        val vm = vm(service)
        vm.load()
        val state = vm.state as? LoadState.Populated ?: return@runTest fail("Expected populated, got ${vm.state}")
        assertEquals("Test TLDR", state.briefing.tlDR)
        assertFalse(state.isOffline)
    }

    @Test fun loadFailureTransitionsToFailed() = runTest {
        val service = MockService().apply { result = Result.failure(BriefingServiceError.EmptyResult) }
        val vm = vm(service)
        vm.selectedPersona = Persona.SPORTS_TALK_FOR_MOMS
        vm.load()
        val state = vm.state as? LoadState.Failed ?: return@runTest fail("Expected failed, got ${vm.state}")
        assertFalse(state.message.isEmpty())
    }

    @Test fun selectFreePersonaWithoutProSucceeds() = runTest {
        val vm = vm(MockService().apply { result = Result.success(makeBriefing()) })
        assertTrue(vm.select(Persona.COCKTAIL_PARTY))
        assertEquals(Persona.COCKTAIL_PARTY, vm.selectedPersona)
    }

    @Test fun selectLockedPersonaWithoutProReturnsFalse() = runTest {
        val vm = vm(MockService())
        assertFalse(vm.select(Persona.DATE_NIGHT))
        assertEquals(Persona.COCKTAIL_PARTY, vm.selectedPersona)
    }

    @Test fun selectLockedPersonaWithProSucceeds() = runTest {
        val vm = vm(MockService().apply { result = Result.success(makeBriefing()) }, isPro = true)
        assertTrue(vm.select(Persona.DATE_NIGHT))
        assertEquals(Persona.DATE_NIGHT, vm.selectedPersona)
    }

    @Test fun refreshOnFreePersonaWorksWithoutPro() = runTest {
        val vm = vm(MockService().apply { result = Result.success(makeBriefing()) })
        vm.load()
        vm.refresh()
        assertTrue("Expected populated after refresh, got ${vm.state}", vm.state is LoadState.Populated)
    }

    @Test fun secondFreeRefreshSameDayHitsLimit() = runTest {
        val vm = vm(MockService().apply { result = Result.success(makeBriefing()) })
        vm.load()
        vm.refresh()
        assertTrue("First refresh should populate, got ${vm.state}", vm.state is LoadState.Populated)
        vm.refresh()
        assertEquals(LoadState.RefreshLimit, vm.state)
    }

    @Test fun refreshOnLockedPersonaHitsLimitForNonPro() = runTest {
        val vm = vm(MockService().apply { result = Result.success(makeBriefing()) })
        vm.selectedPersona = Persona.DATE_NIGHT
        vm.refresh()
        assertEquals(LoadState.RefreshLimit, vm.state)
    }

    @Test fun refreshOnLockedPersonaWorksWithPro() = runTest {
        val vm = vm(MockService().apply { result = Result.success(makeBriefing()) }, isPro = true)
        vm.load()
        vm.select(Persona.OFFICE_WATERCOOLER)
        vm.refresh()
        assertTrue("Expected populated after pro refresh, got ${vm.state}", vm.state is LoadState.Populated)
    }

    /** Slow for the room the user is leaving, instant for the rest. */
    private class DelayedMockService : BriefingServing {
        override suspend fun latestBriefing(persona: Persona, scope: BriefingScope): Briefing {
            if (persona == Persona.COCKTAIL_PARTY) delay(200)
            return Briefing(
                persona = persona, scope = scope, refreshWindow = RefreshWindow.DAILY, headline = "h", tlDR = persona.raw,
                bullets = emptyList(), suggestedQuestion = "q", sourceCount = 1, generatedAt = Instant.now(),
            )
        }
    }

    @Test fun slowStaleLoadDoesNotOverwriteNewerSelection() = runTest {
        val vm = vm(DelayedMockService(), isPro = true)
        val slowLoad = launch { vm.load() }
        runCurrent()
        advanceTimeBy(50)
        vm.select(Persona.DATE_NIGHT)
        slowLoad.join()
        val state = vm.state as? LoadState.Populated ?: return@runTest fail("Expected populated, got ${vm.state}")
        assertEquals("Stale cocktail party response overwrote the newer selection", Persona.DATE_NIGHT, state.briefing.persona)
    }

    @Test fun lastBriefingIsSetAfterSuccessfulLoad() = runTest {
        val vm = vm(MockService().apply { result = Result.success(makeBriefing()) })
        vm.load()
        assertNotNull(vm.lastBriefing)
        assertEquals("Test TLDR", vm.lastBriefing?.tlDR)
    }

    @Test fun lastBriefingUpdatesOnSubsequentLoad() = runTest {
        val service = MockService()
        val vm = vm(service)
        service.result = Result.success(makeBriefing("First"))
        vm.load()
        assertEquals("First", vm.lastBriefing?.tlDR)
        service.result = Result.success(makeBriefing("Second"))
        vm.load()
        assertEquals("Second", vm.lastBriefing?.tlDR)
    }

    @Test fun lastBriefingSurvivesRefreshLimit() = runTest {
        val vm = vm(MockService().apply { result = Result.success(makeBriefing("Original")) })
        vm.load()
        assertEquals("Original", vm.lastBriefing?.tlDR)
        vm.selectedPersona = Persona.DATE_NIGHT
        vm.refresh()
        assertEquals(LoadState.RefreshLimit, vm.state)
        assertEquals("Original", vm.lastBriefing?.tlDR)
    }
}
