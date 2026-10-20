package com.jackwallner.sports.data

import android.app.Activity
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.sports.BuildConfig
import com.jackwallner.sports.model.Persona
import com.revenuecat.purchases.CacheFetchPolicy
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Offering
import com.revenuecat.purchases.Offerings
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PeriodType
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.PurchasesErrorCode
import com.revenuecat.purchases.PurchasesTransactionException
import com.revenuecat.purchases.awaitCustomerInfo
import com.revenuecat.purchases.awaitOfferings
import com.revenuecat.purchases.awaitPurchase
import com.revenuecat.purchases.awaitRestore
import com.revenuecat.purchases.interfaces.UpdatedCustomerInfoListener
import com.revenuecat.purchases.models.Period
import com.revenuecat.purchases.paywalls.events.CustomPaywallImpressionParams
import java.math.BigDecimal
import java.math.RoundingMode
import java.security.MessageDigest
import java.text.NumberFormat
import java.util.Currency
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

object Membership {
    const val PRO = "Gist Pro"
    /** RevenueCat entitlement identifier, the same one iOS checks. */
    const val ENTITLEMENT_ID = "Sports Pro"
}

/** `SidelinePackageKind`: the plan list order (annual, monthly, lifetime). */
enum class PlanKind { ANNUAL, MONTHLY, LIFETIME, OTHER }

enum class PeriodUnit { DAY, WEEK, MONTH, YEAR }

/** What the paywall needs from one store package, free of RevenueCat types so the copy is testable. */
data class PlanInfo(
    val id: String,
    val productId: String,
    val kind: PlanKind,
    val storeTitle: String,
    val price: BigDecimal,
    val formattedPrice: String,
    val currencyCode: String,
    val periodUnit: PeriodUnit? = null,
    val periodValue: Int = 1,
    val trialUnit: PeriodUnit? = null,
    val trialValue: Int = 0,
) {
    val isSubscription: Boolean get() = periodUnit != null

    /** `sidelineDisplayName`. */
    val displayName: String
        get() = when (kind) {
            PlanKind.LIFETIME -> "Lifetime"
            PlanKind.ANNUAL -> "Annual"
            PlanKind.MONTHLY -> "Monthly"
            PlanKind.OTHER -> storeTitle
        }

    /** `sidelinePriceLabel`: "$19.99 / year", or the bare price for a one-time product. */
    val priceLabel: String
        get() {
            val unit = periodUnit ?: return formattedPrice
            val name = unitName(unit, periodValue)
            return if (periodValue == 1) "$formattedPrice / $name" else "$formattedPrice / $periodValue $name"
        }

    /** `sidelineMonthlyEquivalentLabel`: "$1.67/mo" for annual and multi-month plans. */
    val monthlyEquivalentLabel: String?
        get() {
            val months = months ?: return null
            if (months <= 1) return null
            val perMonth = price.divide(BigDecimal(months), 10, RoundingMode.HALF_EVEN)
            return currencyFormat().format(perMonth) + "/mo"
        }

    /** `sidelineSavingsPercent(vsMonthly:)`: whole-percent saving per month against a 1-month plan. */
    fun savingsPercent(monthly: PlanInfo): Int? {
        val unit = periodUnit ?: return null
        if (periodValue <= 0) return null
        val months = when {
            unit == PeriodUnit.YEAR -> 12 * periodValue
            unit == PeriodUnit.MONTH && periodValue > 1 -> periodValue
            else -> return null
        }
        if (monthly.periodUnit != PeriodUnit.MONTH || monthly.periodValue != 1) return null
        if (monthly.price.signum() <= 0) return null
        val perMonth = price.divide(BigDecimal(months), 10, RoundingMode.HALF_EVEN)
        val pct = monthly.price.subtract(perMonth).divide(monthly.price, 10, RoundingMode.HALF_EVEN)
            .multiply(BigDecimal(100)).toDouble()
        if (pct < 1) return null
        return Math.round(pct).toInt()
    }

    /** `sidelineIntroOfferLabel`: "7-day free trial" when the plan carries a free phase. */
    val introOfferLabel: String?
        get() {
            val unit = trialUnit ?: return null
            if (trialValue <= 0) return null
            if (unit == PeriodUnit.WEEK) return "${trialValue * 7}-day free trial"
            return "$trialValue-${unitName(unit, 1)} free trial"
        }

    /** Free-trial length in days, read straight from the free phase. */
    val trialDays: Int?
        get() {
            val unit = trialUnit ?: return null
            if (trialValue <= 0) return null
            return when (unit) {
                PeriodUnit.DAY -> trialValue
                PeriodUnit.WEEK -> trialValue * 7
                PeriodUnit.MONTH -> trialValue * 30
                PeriodUnit.YEAR -> trialValue * 365
            }
        }

    private val months: Int?
        get() = when (periodUnit) {
            PeriodUnit.YEAR -> 12 * periodValue
            PeriodUnit.MONTH -> periodValue
            else -> null
        }?.takeIf { periodValue > 0 }

    private fun currencyFormat(): NumberFormat = NumberFormat.getCurrencyInstance().apply {
        runCatching { currency = Currency.getInstance(currencyCode) }
    }

    companion object {
        fun unitName(unit: PeriodUnit, value: Int): String {
            val base = when (unit) {
                PeriodUnit.DAY -> "day"
                PeriodUnit.WEEK -> "week"
                PeriodUnit.MONTH -> "month"
                PeriodUnit.YEAR -> "year"
            }
            return if (value == 1) base else "${base}s"
        }

        /** `SidelinePackageKind(package:)`. */
        fun kindFor(packageType: String, identifier: String, productId: String): PlanKind = when (packageType) {
            "LIFETIME" -> PlanKind.LIFETIME
            "ANNUAL" -> PlanKind.ANNUAL
            "MONTHLY" -> PlanKind.MONTHLY
            else -> {
                val ids = listOf(identifier, productId).map { it.lowercase() }
                when {
                    ids.any { "lifetime" in it } -> PlanKind.LIFETIME
                    ids.any { "annual" in it || "year" in it } -> PlanKind.ANNUAL
                    ids.any { "monthly" in it || "month" in it } -> PlanKind.MONTHLY
                    else -> PlanKind.OTHER
                }
            }
        }

        /** `sidelineSortedPackages`. */
        fun sorted(plans: List<PlanInfo>): List<PlanInfo> =
            plans.sortedWith(compareBy<PlanInfo> { it.kind.ordinal }.thenBy { it.productId })
    }
}

/** `PaywallView.swift` copy, with Google Play wording where Apple's does not apply. */
object PaywallCopy {
    fun headline(context: Persona): String = when (context) {
        Persona.COCKTAIL_PARTY -> "Walk in knowing what to say"
        Persona.OFFICE_WATERCOOLER -> "Walk into Monday knowing what to say"
        Persona.SPORTS_TALK_FOR_MOMS -> "Keep up with your kid's favorite topic"
        Persona.DATE_NIGHT -> "Sound like you actually follow it"
    }

    fun billingSubtext(plan: PlanInfo?, eligible: Boolean): String? {
        plan ?: return null
        if (plan.kind == PlanKind.LIFETIME) return "One-time purchase, no subscription"
        val trial = plan.introOfferLabel
        if (eligible && trial != null) return "Includes a $trial"
        return plan.monthlyEquivalentLabel?.let { "Just $it" }
    }

    fun ctaTitle(plan: PlanInfo?, eligible: Boolean): String {
        plan ?: return "Continue"
        if (plan.kind == PlanKind.LIFETIME) return "Unlock Lifetime"
        val trial = plan.introOfferLabel
        if (eligible && trial != null) return "Start My ${capitalized(trial)}"
        return "Subscribe"
    }

    fun trialBannerText(plan: PlanInfo?, eligible: Boolean): String? {
        plan ?: return null
        val days = plan.trialDays ?: return null
        if (!eligible) return null
        return "$days days free, then ${plan.priceLabel}"
    }

    fun trialReassuranceLine(plan: PlanInfo?, eligible: Boolean): String? {
        plan ?: return null
        val days = plan.trialDays ?: return null
        if (!eligible) return null
        return "No payment today · Reminder day ${maxOf(1, days - 2)} · Billing day $days"
    }

    /** iOS names Apple's 24-hour rule; Play has none, so this names Google Play instead. */
    fun disclosure(plan: PlanInfo?, eligible: Boolean): String? {
        plan ?: return null
        val price = plan.priceLabel
        if (plan.kind == PlanKind.LIFETIME) return "$price. One-time purchase. Lifetime access, no subscription."
        val renew = "Renews automatically until you cancel in Google Play. Cancel anytime."
        val trial = plan.introOfferLabel
        if (eligible && trial != null) return "$price after a $trial. $renew"
        return "$price. $renew"
    }

    /** The plan badge: "SAVE 58%" against monthly, else "BEST VALUE" on annual. */
    fun badge(plan: PlanInfo, monthly: PlanInfo?): String? {
        val savings = monthly?.let { plan.savingsPercent(it) }
        if (savings != null) return "SAVE $savings%"
        return if (plan.kind == PlanKind.ANNUAL) "BEST VALUE" else null
    }

    /** `String.capitalized`: "7-Day Free Trial". */
    fun capitalized(text: String): String =
        text.split(" ").joinToString(" ") { word ->
            word.split("-").joinToString("-") { part -> part.lowercase().replaceFirstChar { it.titlecase() } }
        }
}

enum class PurchaseOutcome { PURCHASED, PENDING, CANCELLED }

class PurchaseException(message: String) : Exception(message)

/** Google Play reviewers reach Gist Pro with a code; only its SHA-256 ships in the build. */
class ReviewAccess(private val defaults: KeyValueStore, private val expectedDigest: String) {
    val isGranted: Boolean get() = expectedDigest.length == 64 && defaults.getString(KEY) == expectedDigest

    fun activate(code: String): Boolean {
        if (!expectedDigest.matches(Regex("[a-f0-9]{64}"))) return false
        val digest = MessageDigest.getInstance("SHA-256").digest(code.trim().toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
        if (!MessageDigest.isEqual(digest.toByteArray(), expectedDigest.toByteArray())) return false
        defaults.putString(KEY, expectedDigest)
        return true
    }

    private companion object {
        const val KEY = "subscription.playReviewAccess"
    }
}

/**
 * `StoreService.swift`: RevenueCat behind the "Sports Pro" entitlement. Debug
 * builds use the Test Store key and release builds the Play key; neither ever
 * runs on the other. Reads the `default` offering like iOS.
 */
class StoreService(
    private val context: Context,
    defaults: KeyValueStore,
    private val diagnostics: ConversionDiagnostics,
    reviewCodeDigest: String = BuildConfig.PLAY_REVIEW_CODE_SHA256,
) : EntitlementProviding {
    private val reviewAccess = ReviewAccess(defaults, reviewCodeDigest)

    override var isPro by mutableStateOf(reviewAccess.isGranted)
        private set
    var plans by mutableStateOf<List<PlanInfo>>(emptyList())
        private set
    var isLoadingProducts by mutableStateOf(false)
        private set
    var lastError by mutableStateOf<String?>(null)
    var activeProductId by mutableStateOf<String?>(null)
        private set

    /** Debug screenshot runs record no paywall impressions (`-SidelineScreenshotMode`). */
    var suppressImpressions = false

    private var packages: Map<String, Package> = emptyMap()
    private var offering: Offering? = null
    private var isConfigured = false
    private var forcePro = false
    private val impressionsThisSession = mutableSetOf<String>()

    val isConfiguredForPurchases: Boolean get() = isConfigured

    fun activateReviewAccess(code: String): Boolean {
        if (!reviewAccess.activate(code)) return false
        isPro = true
        return true
    }

    /** Debug-only: open the paid boundary for screenshots and tests (`-SidelineForcePro`). */
    fun forceProForDebug(value: Boolean = true) {
        if (!BuildConfig.DEBUG) return
        forcePro = value
        isPro = value
    }

    /** Play only returns offers this account may take, so a free phase is eligibility. */
    fun isEligibleForIntroOffer(plan: PlanInfo): Boolean = plan.introOfferLabel != null

    /** An unused free trial is on the table, so upsells lead with "try free". */
    val trialAvailable: Boolean get() = plans.any(::isEligibleForIntroOffer)

    /** Pro is active through a subscription, not lifetime. */
    val hasActiveSubscription: Boolean
        get() = isPro && activeProductId?.lowercase()?.contains("lifetime") == false

    fun start(scope: CoroutineScope) {
        if (!configureIfNeeded()) return
        scope.launch { refresh() }
        scope.launch { fetchProducts() }
    }

    suspend fun refresh() {
        if (!configureIfNeeded()) return
        try {
            apply(Purchases.sharedInstance.awaitCustomerInfo(CacheFetchPolicy.FETCH_CURRENT))
            lastError = null
        } catch (error: CancellationException) {
            throw error
        } catch (_: Throwable) {
            lastError = "Couldn't refresh your subscription status. Check your connection and try again."
        }
    }

    suspend fun fetchProducts() {
        if (!configureIfNeeded()) {
            lastError = "Couldn't load subscription options. Check your connection and try again."
            return
        }
        isLoadingProducts = true
        try {
            val offerings = Purchases.sharedInstance.awaitOfferings()
            val chosen = paywallOffering(offerings)
            offering = chosen
            val available = chosen?.availablePackages.orEmpty()
            packages = available.associateBy { it.identifier }
            plans = PlanInfo.sorted(available.map(::planInfo))
            lastError = if (plans.isEmpty()) {
                "No subscription plans available yet. If you just set them up, give Google Play a minute and try again."
            } else null
        } catch (error: CancellationException) {
            throw error
        } catch (_: Throwable) {
            lastError = "Couldn't load subscription options. Check your connection and try again."
        } finally {
            isLoadingProducts = false
        }
    }

    /** `sidelinePaywallOffering`: `default`, then current, then the first non-empty offering. */
    private fun paywallOffering(offerings: Offerings): Offering? {
        offerings.all[DEFAULT_OFFERING]?.takeIf { it.availablePackages.isNotEmpty() }?.let { return it }
        offerings.current?.takeIf { it.availablePackages.isNotEmpty() }?.let { return it }
        return offerings.all.values.firstOrNull { it.availablePackages.isNotEmpty() }
    }

    fun trackPaywallImpression(id: String, oncePerSession: Boolean = false) {
        if (suppressImpressions) return
        if (oncePerSession && !impressionsThisSession.add(id)) return
        if (!configureIfNeeded()) return
        diagnostics.recordPitchView(id)
        syncConversionAttributes()
        runCatching { Purchases.sharedInstance.trackCustomPaywallImpression(CustomPaywallImpressionParams(id)) }
    }

    private fun syncConversionAttributes() {
        if (!isConfigured) return
        val attributes = diagnostics.subscriberAttributes.toMutableMap()
        if (attributes.isEmpty()) return
        offering?.identifier?.let { attributes["offering_id"] = it }
        runCatching { Purchases.sharedInstance.setAttributes(attributes) }
    }

    suspend fun purchase(activity: Activity, plan: PlanInfo): PurchaseOutcome {
        val pkg = packages[plan.id]
        if (!configureIfNeeded() || pkg == null) throw PurchaseException(UNAVAILABLE)
        val startedTrial = isEligibleForIntroOffer(plan)
        return try {
            val result = Purchases.sharedInstance.awaitPurchase(PurchaseParams.Builder(activity, pkg).build())
            apply(result.customerInfo)
            if (isPro) {
                val trial = startedTrial || result.customerInfo.entitlements.active.values.any { it.periodType == PeriodType.TRIAL }
                diagnostics.recordConversion(pkg.product.id, trial, offering?.identifier)
                syncConversionAttributes()
                return PurchaseOutcome.PURCHASED
            }
            // Play can take a moment to hand the purchase to RevenueCat.
            repeat(10) {
                delay(600)
                refresh()
                if (isPro) return PurchaseOutcome.PURCHASED
            }
            PurchaseOutcome.PENDING
        } catch (error: PurchasesTransactionException) {
            when {
                error.userCancelled -> PurchaseOutcome.CANCELLED
                error.code == PurchasesErrorCode.PaymentPendingError -> PurchaseOutcome.PENDING
                error.code == PurchasesErrorCode.ProductAlreadyPurchasedError -> {
                    restore()
                    if (isPro) PurchaseOutcome.PURCHASED else throw PurchaseException("Couldn't complete the purchase. Please try again.")
                }
                else -> throw PurchaseException("Couldn't complete the purchase. Please try again.")
            }
        }
    }

    suspend fun restore() {
        if (!configureIfNeeded()) {
            lastError = UNAVAILABLE
            return
        }
        lastError = null
        try {
            apply(Purchases.sharedInstance.awaitRestore())
            lastError = if (isPro) null else "No active ${Membership.PRO} purchase was found for this Google account."
        } catch (error: CancellationException) {
            throw error
        } catch (_: Throwable) {
            lastError = "Couldn't restore purchases. Try again."
        }
    }

    private fun apply(info: CustomerInfo) {
        if (forcePro) return
        // The dashboard entitlement first, then any active one: the app ships a single entitlement.
        val entitlement = info.entitlements.active[Membership.ENTITLEMENT_ID] ?: info.entitlements.active.values.firstOrNull()
        activeProductId = entitlement?.productIdentifier?.substringBefore(":")
        isPro = entitlement != null || reviewAccess.isGranted
    }

    private fun planInfo(pkg: Package): PlanInfo {
        val product = pkg.product
        val trial = product.defaultOption?.freePhase?.billingPeriod
        return PlanInfo(
            id = pkg.identifier,
            productId = product.id.substringBefore(":"),
            kind = PlanInfo.kindFor(pkg.packageType.name, pkg.identifier, product.id),
            storeTitle = product.title,
            price = BigDecimal.valueOf(product.price.amountMicros, 6),
            formattedPrice = product.price.formatted,
            currencyCode = product.price.currencyCode,
            periodUnit = product.period?.let(::unitOf),
            periodValue = product.period?.value ?: 1,
            trialUnit = trial?.let(::unitOf),
            trialValue = trial?.value ?: 0,
        )
    }

    private fun unitOf(period: Period): PeriodUnit? = when (period.unit) {
        Period.Unit.DAY -> PeriodUnit.DAY
        Period.Unit.WEEK -> PeriodUnit.WEEK
        Period.Unit.MONTH -> PeriodUnit.MONTH
        Period.Unit.YEAR -> PeriodUnit.YEAR
        else -> null
    }

    private fun configureIfNeeded(): Boolean {
        if (isConfigured) return true
        if (forcePro) return false
        val key = BuildConfig.REVENUECAT_API_KEY
        if (key.isBlank()) return false
        // Never the production Play key in a debug build, and never a test key in release.
        if (BuildConfig.DEBUG && key.startsWith("goog_")) return false
        if (!BuildConfig.DEBUG && !key.startsWith("goog_")) return false
        Purchases.logLevel = if (BuildConfig.DEBUG) LogLevel.DEBUG else LogLevel.ERROR
        Purchases.configure(PurchasesConfiguration.Builder(context, key).build())
        Purchases.sharedInstance.updatedCustomerInfoListener = UpdatedCustomerInfoListener { apply(it) }
        isConfigured = true
        return true
    }

    private companion object {
        const val DEFAULT_OFFERING = "default"
        const val UNAVAILABLE = "Google Play isn't reachable right now. Check your connection and try again."
    }
}
