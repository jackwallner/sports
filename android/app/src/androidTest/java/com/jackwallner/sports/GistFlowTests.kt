package com.jackwallner.sports

import android.content.Intent
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeLeft
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.jackwallner.sports.model.Briefing
import com.jackwallner.sports.model.Persona
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The first-run path and the paid boundary on a real device. Each test starts
 * from a clean install (`clearPackageData`), so nothing is onboarded or owned.
 */
@OptIn(ExperimentalTestApi::class)
@RunWith(AndroidJUnit4::class)
class GistFlowTests {
    @get:Rule val compose = createEmptyComposeRule()

    private var scenario: ActivityScenario<MainActivity>? = null

    private fun launch(vararg flags: String, persona: Persona? = null) {
        val intent = Intent(ApplicationProvider.getApplicationContext(), MainActivity::class.java)
            .putExtra("uiTest", true)
        flags.forEach { intent.putExtra(it, true) }
        persona?.let { intent.putExtra("persona", it.raw) }
        scenario = ActivityScenario.launch(intent)
    }

    @After fun close() {
        scenario?.close()
    }

    private fun waitFor(tag: String, timeoutMs: Long = 30_000) =
        compose.waitUntilAtLeastOneExists(hasTestTag(tag), timeoutMs)

    /** Runs one of the deck's TalkBack actions by its label. */
    private fun deckAction(label: String) {
        val actions = compose.onNodeWithTag("deck").fetchSemanticsNode().config[SemanticsActions.CustomActions]
        val match = actions.firstOrNull { it.label == label } ?: error("no deck action '$label' in ${actions.map { it.label }}")
        compose.runOnUiThread { match.action() }
        compose.waitForIdle()
    }

    private fun pitch(persona: Persona) = compose.onNodeWithTag("persona.pitch").assert(hasText(persona.shortPitch))

    @Test fun firstRunShowsProRoomsLockedAndLandsOnTheFreeBriefing() {
        launch("demo")
        waitFor("onboarding")
        compose.onNodeWithText("Sports, made simple.").assertIsDisplayed()
        compose.onNodeWithTag("onboarding.primary").performClick()
        waitFor("onboarding.persona.date_night")
        compose.onNodeWithTag("onboarding.persona.date_night")
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.ContentDescription, listOf("Date Night, unlocks with Gist Pro")))
        // A locked room can't be picked during onboarding.
        compose.onNodeWithTag("onboarding.persona.date_night").performClick()
        compose.onNodeWithTag("onboarding.persona.cocktail_party")
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Selected, true))
        compose.onNodeWithTag("onboarding.primary").performClick()
        waitFor("deck.card")
        pitch(Persona.COCKTAIL_PARTY)
        compose.onNodeWithTag("banner").assertIsDisplayed()
    }

    @Test fun lockedRoomShowsAReadableTasteThenThePaywall() {
        launch("demo", "onboarded")
        waitFor("deck.card")
        compose.onNodeWithTag("persona.office_watercooler")
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.ContentDescription, listOf("Office Watercooler, Pro context")))
            .performClick()
        waitFor("preview")
        compose.onNodeWithTag("preview.teaser").assert(hasText(Persona.OFFICE_WATERCOOLER.proPreviewTeaser))
        compose.onNodeWithTag("preview.seePro").performClick()
        waitFor("paywall")
        // The hero shows once the store's plans have loaded.
        waitFor("paywall.headline", 45_000)
        compose.onNodeWithTag("paywall.headline").assert(hasText("Walk in knowing what to say"))
        compose.onNodeWithTag("paywall.notNow").performClick()
        compose.waitUntilDoesNotExist(hasTestTag("paywall"), 15_000)
        // Still in the free room: the boundary held.
        pitch(Persona.COCKTAIL_PARTY)
    }

    @Test fun paywallPricesComeFromTheTestStore() {
        launch("demo", "onboarded")
        waitFor("settings.open")
        compose.onNodeWithTag("settings.open").performClick()
        waitFor("settings.pro")
        compose.onNodeWithTag("settings.pro").performClick()
        waitFor("paywall")
        // The debug build is configured with the RevenueCat Test Store, never the Play key.
        compose.waitUntil(45_000) {
            compose.onAllNodes(hasTestTag("plan.annual")).fetchSemanticsNodes().isNotEmpty() ||
                compose.onAllNodes(hasTestTag("plan.monthly")).fetchSemanticsNodes().isNotEmpty()
        }
        val price = compose.onNodeWithTag("paywall.price").fetchSemanticsNode()
            .config.getOrNull(SemanticsProperties.Text)?.joinToString { it.text }.orEmpty()
        assertTrue("store price shown: '$price'", price.any(Char::isDigit))
        val disclosure = compose.onNodeWithTag("paywall.disclosure").fetchSemanticsNode()
            .config.getOrNull(SemanticsProperties.Text)?.joinToString { it.text }.orEmpty()
        assertTrue(disclosure, "Google Play" in disclosure || "One-time purchase" in disclosure)
    }

    @Test fun proOpensEveryRoomWithoutAPitch() {
        launch("demo", "onboarded", "forcePro")
        waitFor("deck.card")
        // The last chip starts off screen in the horizontally scrolling rail.
        compose.onNodeWithTag("persona.date_night")
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.ContentDescription, listOf("Date Night")))
            .performScrollTo()
            .performClick()
        compose.waitUntil(15_000) {
            compose.onAllNodes(hasTestTag("persona.pitch") and hasText(Persona.DATE_NIGHT.shortPitch)).fetchSemanticsNodes().isNotEmpty()
        }
        assertTrue(compose.onAllNodes(hasTestTag("preview")).fetchSemanticsNodes().isEmpty())
        compose.onNodeWithTag("settings.open").performClick()
        waitFor("settings.pro")
        compose.onNodeWithText("Active").assertIsDisplayed()
    }

    @Test fun freeDeckEndsOnTheRoomsCardAndProDeckDoesNot() {
        launch("demo", "onboarded")
        waitFor("deck.card")
        val cards = Briefing.sample.bullets.size + 3
        compose.onNodeWithTag("deck").assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "Card 1 of $cards"))
        repeat(cards - 1) {
            compose.onNodeWithTag("deck").performTouchInput { swipeLeft() }
            compose.waitForIdle()
        }
        compose.onNodeWithTag("deck").assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "Card $cards of $cards"))
        waitFor("deck.rooms")
        compose.onNodeWithTag("deck.rooms.cta").performClick()
        waitFor("paywall")
    }

    @Test fun talkBackCanStepThroughAndFlipTheDeck() {
        launch("demo", "onboarded", "forcePro")
        waitFor("deck.card")
        val count = Briefing.sample.bullets.size + 2
        deckAction("Show the backstory")
        waitFor("deck.back")
        deckAction("Next card")
        compose.onNodeWithTag("deck").assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "Card 2 of $count"))
        deckAction("Previous card")
        deckAction("Previous card")
        compose.onNodeWithTag("deck").assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "Card $count of $count"))
        assertTrue(compose.onAllNodes(hasTestTag("deck.rooms")).fetchSemanticsNodes().isEmpty())
    }

    @Test fun wrongReviewerCodeNeverOpensPro() {
        launch("demo", "onboarded")
        waitFor("settings.open")
        compose.onNodeWithTag("settings.open").performClick()
        waitFor("settings.version")
        compose.onNodeWithTag("settings.version").performTouchInput { longClick() }
        waitFor("reviewer.code")
        compose.onNodeWithTag("reviewer.code").performTextInput("not-the-code")
        compose.onNodeWithTag("reviewer.unlock").performClick()
        compose.onNodeWithText("That code isn't valid.").assertIsDisplayed()
        compose.onNodeWithText("Cancel").performClick()
        compose.onNodeWithText("See Pro").assertIsDisplayed()
        val graph = (ApplicationProvider.getApplicationContext<GistApplication>()).graph
        assertFalse(graph.store.isPro)
    }

    @Test fun liveBriefingLoadsFromSupabaseWithSources() {
        val graph = (ApplicationProvider.getApplicationContext<GistApplication>()).graph
        assertFalse("debug build has the Supabase config", graph.isDemo)
        launch("onboarded")
        compose.waitUntil(45_000) {
            compose.onAllNodes(hasTestTag("deck.card")).fetchSemanticsNodes().isNotEmpty() ||
                compose.onAllNodes(hasTestTag("state.failed")).fetchSemanticsNodes().isNotEmpty()
        }
        assertTrue("live feed reachable", compose.onAllNodes(hasTestTag("state.failed")).fetchSemanticsNodes().isEmpty())
        // No preview banner on the live feed, and the footer cites its sources.
        assertTrue(compose.onAllNodes(hasTestTag("banner")).fetchSemanticsNodes().isEmpty())
        compose.onNodeWithTag("freshness").assertIsDisplayed()
        val cited = compose.onAllNodes(hasText("sources", substring = true)).fetchSemanticsNodes().isNotEmpty() ||
            compose.onAllNodes(hasText("Double-check before quoting", substring = true)).fetchSemanticsNodes().isNotEmpty()
        assertTrue("freshness footer names its sources or flags staleness", cited)
        // The first story card carries a tappable source link on its back.
        deckAction("Next card")
        deckAction("Show the backstory")
        waitFor("deck.source")
    }
}
