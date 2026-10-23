package com.jackwallner.sports

import com.jackwallner.sports.data.InMemoryStore
import com.jackwallner.sports.data.LocalEntitlementStore
import com.jackwallner.sports.data.PaywallCopy
import com.jackwallner.sports.data.PeriodUnit
import com.jackwallner.sports.data.PlanInfo
import com.jackwallner.sports.data.PlanKind
import com.jackwallner.sports.data.ReviewAccess
import com.jackwallner.sports.model.Briefing
import com.jackwallner.sports.model.BriefingBullet
import com.jackwallner.sports.model.BriefingScope
import com.jackwallner.sports.model.BriefingTag
import com.jackwallner.sports.model.CardArt
import com.jackwallner.sports.model.DeckCard
import com.jackwallner.sports.model.Persona
import com.jackwallner.sports.model.RefreshWindow
import java.math.BigDecimal
import java.security.MessageDigest
import java.time.Instant
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * CardArt against `cardart-parity.json`, which `scripts/sync-android-fixtures.sh`
 * writes by running Swift's own CardArt. Every URL, seed and sport chip must match.
 */
class CardArtParityTests {
    private val fixture: JSONObject by lazy {
        val text = javaClass.classLoader!!.getResource("cardart-parity.json")!!.readText()
        JSONObject(text)
    }

    private fun JSONObject.optText(key: String): String? = if (isNull(key)) null else getString(key)

    private fun JSONArray.strings(): List<String> = (0 until length()).map(::getString)

    private fun bullets(): List<BriefingBullet> {
        val rows = fixture.getJSONArray("bullets")
        return (0 until rows.length()).map { i ->
            val row = rows.getJSONObject(i)
            BriefingBullet(
                talkingPoint = "Point",
                subject = row.optText("subject"),
                tag = BriefingTag.from(row.optText("tag")),
                sourceHeadline = row.getString("sourceHeadline"),
                sourceURL = row.getString("sourceURL"),
                imageURL = row.optText("imageURL"),
            )
        }
    }

    @Test fun fixtureCoversEverySportAndTheFallbacks() {
        val names = bullets().map { CardArt.sport(it).name }.toSet()
        assertEquals(setOf("NFL", "NBA", "WNBA", "MLB", "SOCCER", "TENNIS", "NHL", "GOLF", "OLYMPICS", ""), names)
        assertEquals(15, fixture.getJSONArray("bullets").length())
    }

    @Test fun sportChipMatchesSwift() {
        val rows = fixture.getJSONArray("bullets")
        bullets().forEachIndexed { i, bullet ->
            val row = rows.getJSONObject(i)
            val sport = CardArt.sport(bullet)
            assertEquals("symbol for ${bullet.sourceHeadline}", row.getString("symbol"), sport.symbol)
            assertEquals("name for ${bullet.sourceHeadline}", row.getString("name"), sport.name)
        }
    }

    @Test fun storyArtURLsMatchSwiftByteForByte() {
        val rows = fixture.getJSONArray("bullets")
        bullets().forEachIndexed { i, bullet ->
            assertEquals(bullet.sourceHeadline, rows.getJSONObject(i).getJSONArray("urls").strings(), CardArt.imageURLs(bullet))
        }
    }

    @Test fun stampedArtLeadsTheFallbackChain() {
        val stamped = bullets().first { it.imageURL != null }
        val chain = CardArt.imageURLs(stamped)
        assertEquals(2, chain.size)
        assertEquals(stamped.imageURL, chain.first())
        assertTrue(chain.last().startsWith("https://image.pollinations.ai/prompt/"))
    }

    @Test fun coverArtURLsMatchSwift() {
        val all = bullets()
        val leads = fixture.getJSONArray("leads")
        assertEquals(3, leads.length())
        for (i in 0 until leads.length()) {
            val row = leads.getJSONObject(i)
            val indexes = row.getJSONArray("bulletIndexes")
            val briefing = Briefing(
                persona = Persona.COCKTAIL_PARTY,
                scope = BriefingScope.NATIONAL,
                refreshWindow = RefreshWindow.DAILY,
                headline = "h",
                tlDR = row.getString("tlDR"),
                leadImageURL = row.optText("leadImageURL"),
                bullets = (0 until indexes.length()).map { all[indexes.getInt(it)] },
                suggestedQuestion = "q",
                sourceCount = indexes.length(),
                generatedAt = Instant.EPOCH,
            )
            assertEquals(row.getString("tlDR"), row.getJSONArray("urls").strings(), CardArt.leadImageURLs(briefing))
        }
    }

    @Test fun stableSeedMatchesSwiftIncludingUnicode() {
        val seeds = fixture.getJSONArray("seeds")
        assertEquals(5, seeds.length())
        for (i in 0 until seeds.length()) {
            val row = seeds.getJSONObject(i)
            assertEquals(row.getString("text"), row.getLong("seed"), CardArt.stableSeed(row.getString("text")))
        }
    }
}

/** The deck order and the free/Pro boundary on it (`BriefingDeck.swift`). */
class DeckAndBoundaryTests {
    @Test fun freeDeckEndsOnTheRoomsPitch() {
        val cards = DeckCard.cards(Briefing.sample, isPro = false)
        assertEquals(Briefing.sample.bullets.size + 3, cards.size)
        assertTrue(cards.first() is DeckCard.Lead)
        assertTrue(cards[cards.size - 2] is DeckCard.Question)
        assertEquals(DeckCard.Rooms, cards.last())
    }

    @Test fun proDeckHasNoRoomsPitch() {
        val cards = DeckCard.cards(Briefing.sample, isPro = true)
        assertEquals(Briefing.sample.bullets.size + 2, cards.size)
        assertTrue(cards.last() is DeckCard.Question)
        assertFalse(cards.any { it == DeckCard.Rooms })
    }

    @Test fun cardsWithoutBackContentNeverFlip() {
        val bare = BriefingBullet(talkingPoint = "p", sourceHeadline = "h", sourceURL = "https://example.com")
        assertFalse(DeckCard.Point(bare).hasBack)
        assertTrue(DeckCard.Point(bare.copy(tieIn = "tie")).hasBack)
        assertTrue(DeckCard.Lead(Briefing.sample).hasBack)
        assertFalse(DeckCard.Lead(Briefing.sample.copy(leadBackstory = null)).hasBack)
        assertFalse(DeckCard.Question("q").hasBack)
    }

    @Test fun kickerFallsBackToTheSportThenAPlainLabel() {
        val nba = BriefingBullet(talkingPoint = "p", sourceHeadline = "Lakers rally", sourceURL = "https://e.com")
        assertEquals("NBA", DeckCard.kicker(nba))
        assertEquals("Lakers", DeckCard.kicker(nba.copy(subject = "Lakers")))
        assertEquals("Worth mentioning", DeckCard.kicker(nba.copy(sourceHeadline = "Something happened")))
    }

    @Test fun onlyCocktailPartyIsFree() {
        val free = LocalEntitlementStore(isPro = false)
        val pro = LocalEntitlementStore(isPro = true)
        assertEquals(listOf(Persona.COCKTAIL_PARTY), Persona.entries.filter(free::canUse))
        assertEquals(Persona.entries, Persona.entries.filter(pro::canUse))
    }
}

/** Paywall copy built from store data, never a hardcoded price. */
class PaywallCopyTests {
    private fun plan(
        kind: PlanKind,
        price: String,
        unit: PeriodUnit?,
        trialUnit: PeriodUnit? = null,
        trialValue: Int = 0,
    ) = PlanInfo(
        id = kind.name.lowercase(),
        productId = "sports.${kind.name.lowercase()}",
        kind = kind,
        storeTitle = "Gist Pro",
        price = BigDecimal(price),
        formattedPrice = "$$price",
        currencyCode = "USD",
        periodUnit = unit,
        trialUnit = trialUnit,
        trialValue = trialValue,
    )

    private val monthly = plan(PlanKind.MONTHLY, "3.99", PeriodUnit.MONTH)
    private val annual = plan(PlanKind.ANNUAL, "19.99", PeriodUnit.YEAR, PeriodUnit.WEEK, 1)
    private val lifetime = plan(PlanKind.LIFETIME, "49.99", null)

    @Test fun priceLabelsComeFromTheStore() {
        Locale.setDefault(Locale.US)
        assertEquals("$3.99 / month", monthly.priceLabel)
        assertEquals("$19.99 / year", annual.priceLabel)
        assertEquals("$49.99", lifetime.priceLabel)
        assertEquals("$1.67/mo", annual.monthlyEquivalentLabel)
        assertNull(monthly.monthlyEquivalentLabel)
    }

    @Test fun annualBadgeShowsTheSavingAgainstMonthly() {
        assertEquals(58, annual.savingsPercent(monthly))
        assertEquals("SAVE 58%", PaywallCopy.badge(annual, monthly))
        assertEquals("BEST VALUE", PaywallCopy.badge(annual, null))
        assertNull(PaywallCopy.badge(monthly, monthly))
    }

    @Test fun trialCopyOnlyWhenEligible() {
        assertEquals("7-day free trial", annual.introOfferLabel)
        assertEquals("Start My 7-Day Free Trial", PaywallCopy.ctaTitle(annual, eligible = true))
        assertEquals("Subscribe", PaywallCopy.ctaTitle(annual, eligible = false))
        assertEquals("7 days free, then $19.99 / year", PaywallCopy.trialBannerText(annual, eligible = true))
        assertNull(PaywallCopy.trialBannerText(annual, eligible = false))
        assertEquals("No payment today · Billing day 7", PaywallCopy.trialReassuranceLine(annual, true))
        assertNull(PaywallCopy.trialReassuranceLine(annual, false))
        assertNull(PaywallCopy.trialReassuranceLine(monthly, true))
        assertNull(PaywallCopy.trialReassuranceLine(lifetime, true))
    }

    @Test fun disclosureNamesGooglePlayAndRenewal() {
        val text = PaywallCopy.disclosure(monthly, eligible = false)!!
        assertTrue(text.startsWith("$3.99 / month."))
        assertTrue("Renews automatically until you cancel in Google Play" in text)
        assertEquals("$49.99. One-time purchase. Lifetime access, no subscription.", PaywallCopy.disclosure(lifetime, false))
        assertEquals("Unlock Lifetime", PaywallCopy.ctaTitle(lifetime, eligible = true))
    }

    @Test fun plansSortAnnualMonthlyLifetime() {
        assertEquals(listOf(annual, monthly, lifetime), PlanInfo.sorted(listOf(lifetime, monthly, annual)))
        assertEquals(PlanKind.ANNUAL, PlanInfo.kindFor("CUSTOM", "pro_yearly", "sports.pro"))
        assertEquals(PlanKind.LIFETIME, PlanInfo.kindFor("LIFETIME", "x", "y"))
        assertEquals(PlanKind.OTHER, PlanInfo.kindFor("CUSTOM", "x", "y"))
    }
}

/** The Play reviewer code: only its digest ships, and a wrong code never unlocks. */
class ReviewAccessTests {
    private fun sha256(text: String) = MessageDigest.getInstance("SHA-256").digest(text.toByteArray())
        .joinToString("") { "%02x".format(it) }

    @Test fun rightCodeUnlocksAndPersists() {
        val store = InMemoryStore()
        val access = ReviewAccess(store, sha256("open-sesame"))
        assertFalse(access.isGranted)
        assertTrue(access.activate("  open-sesame \n"))
        assertTrue(access.isGranted)
        assertTrue(ReviewAccess(store, sha256("open-sesame")).isGranted)
    }

    @Test fun wrongCodeNeverUnlocks() {
        val access = ReviewAccess(InMemoryStore(), sha256("open-sesame"))
        assertFalse(access.activate("open-sesam"))
        assertFalse(access.activate(""))
        assertFalse(access.isGranted)
    }

    @Test fun aBuildWithoutADigestHasNoReviewerUnlock() {
        val access = ReviewAccess(InMemoryStore(), "")
        assertFalse(access.activate(""))
        assertFalse(access.activate("anything"))
        assertFalse(access.isGranted)
    }

    @Test fun aChangedDigestRevokesAnOldGrant() {
        val store = InMemoryStore()
        ReviewAccess(store, sha256("old")).activate("old")
        assertFalse(ReviewAccess(store, sha256("new")).isGranted)
    }
}

/** Play's AI-generated content policy: every generated card can be reported from the app. */
class ReportCardTests {
    @Test fun everyContentCardCanBeReportedButNotTheRoomsPitch() {
        val cards = DeckCard.cards(Briefing.sample, isPro = false)
        val reportable = cards.filter { DeckCard.reportSummary(it) != null }
        assertEquals(cards.size - 1, reportable.size)
        assertNull(DeckCard.reportSummary(DeckCard.Rooms))
    }

    @Test fun reportQuotesTheCardAndItsSource() {
        val bullet = Briefing.sample.bullets.first()
        val summary = DeckCard.reportSummary(DeckCard.Point(bullet))!!
        assertTrue(bullet.sourceURL in summary)
        val uri = com.jackwallner.sports.data.StoreLinks.reportCardMailURI(summary)
        assertTrue(uri.startsWith("mailto:jack@jackwallner.com?subject=Gist%3A%20report%20a%20card&body="))
        assertFalse(" " in uri)
        assertTrue(java.net.URLDecoder.decode(uri.substringAfter("&body="), "UTF-8").endsWith(summary))
    }
}
