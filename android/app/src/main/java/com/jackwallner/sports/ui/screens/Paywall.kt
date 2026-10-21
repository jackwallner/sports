package com.jackwallner.sports.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CardGiftcard
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.WifiOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.sports.data.PaywallCopy
import com.jackwallner.sports.data.PlanInfo
import com.jackwallner.sports.data.PlanKind
import com.jackwallner.sports.data.PurchaseException
import com.jackwallner.sports.data.PurchaseOutcome
import com.jackwallner.sports.data.StoreLinks
import com.jackwallner.sports.model.Persona
import com.jackwallner.sports.ui.LocalGraph
import com.jackwallner.sports.ui.Symbols
import com.jackwallner.sports.ui.components.Detent
import com.jackwallner.sports.ui.components.ProminentButton
import com.jackwallner.sports.ui.components.SheetController
import com.jackwallner.sports.ui.components.T
import com.jackwallner.sports.ui.components.TextLink
import com.jackwallner.sports.ui.components.TopBar
import com.jackwallner.sports.ui.findActivity
import com.jackwallner.sports.ui.openLink
import com.jackwallner.sports.ui.theme.Sideline
import com.jackwallner.sports.ui.theme.Type
import com.jackwallner.sports.ui.theme.bold
import com.jackwallner.sports.ui.theme.heavy
import com.jackwallner.sports.ui.theme.medium
import com.jackwallner.sports.ui.theme.semibold
import kotlinx.coroutines.launch

fun SheetController.presentPaywall(context: Persona, impressionId: String) {
    present("paywall", Detent.LARGE) { dismiss -> PaywallSheet(context, impressionId, onClose = dismiss) }
}

/** `PaywallView`: the room's hook, three benefits, the plans, and the billed amount first. */
@Composable
fun PaywallSheet(context: Persona, impressionId: String, onClose: () -> Unit) {
    val graph = LocalGraph.current
    val store = graph.store
    val colors = Sideline.colors
    val activity = LocalContext.current.findActivity()
    val scope = rememberCoroutineScope()
    var selectedId by remember { mutableStateOf<String?>(null) }
    var isPurchasing by remember { mutableStateOf(false) }
    var isRestoring by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var restoreMessage by remember { mutableStateOf<String?>(null) }

    val plans = store.plans
    val selected = plans.firstOrNull { it.id == selectedId }

    LaunchedEffect(impressionId) { store.trackPaywallImpression(impressionId) }
    LaunchedEffect(Unit) { if (store.plans.isEmpty()) store.fetchProducts() }
    LaunchedEffect(plans) {
        if (selectedId == null && plans.isNotEmpty()) selectedId = (plans.firstOrNull { it.kind == PlanKind.ANNUAL } ?: plans.first()).id
    }
    LaunchedEffect(store.isPro) { if (store.isPro) onClose() }

    fun purchase() {
        val plan = selected ?: return
        val host = activity ?: return
        store.trackPaywallImpression("${impressionId}_purchase_${plan.kind.name.lowercase()}", oncePerSession = true)
        errorMessage = null
        restoreMessage = null
        isPurchasing = true
        scope.launch {
            try {
                when (store.purchase(host, plan)) {
                    // isPro flips and the effect above closes the sheet.
                    PurchaseOutcome.PURCHASED -> Unit
                    PurchaseOutcome.PENDING -> restoreMessage = "Your purchase is pending approval. Gist Pro unlocks automatically once it's approved."
                    // A deliberate cancel is not an error.
                    PurchaseOutcome.CANCELLED -> Unit
                }
            } catch (_: PurchaseException) {
                errorMessage = "Couldn't complete the purchase. Please try again."
            } finally {
                isPurchasing = false
            }
        }
    }

    fun restore() {
        errorMessage = null
        restoreMessage = null
        isRestoring = true
        scope.launch {
            store.restore()
            if (!store.isPro) restoreMessage = store.lastError ?: "No active Gist Pro purchase found for this Google account."
            isRestoring = false
        }
    }

    Column(Modifier.fillMaxSize().testTag("paywall")) {
        TopBar("Gist Pro", statusBarPadding = false, leading = { TextLink("Not now", tag = "paywall.notNow", onClick = onClose) })
        Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
            when {
                store.isLoadingProducts && plans.isEmpty() -> Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    CircularProgressIndicator(color = colors.inkTertiary, strokeWidth = 2.5.dp, modifier = Modifier.size(28.dp))
                    T("Loading plans…", Type.footnote, colors.inkTertiary)
                }
                plans.isEmpty() -> Column(
                    Modifier.padding(horizontal = 32.dp).testTag("paywall.empty"),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Icon(Icons.Rounded.WifiOff, null, tint = colors.inkTertiary, modifier = Modifier.size(40.dp))
                    T("Couldn't Load Plans", Type.headline, colors.inkSecondary)
                    T(store.lastError ?: "Check your connection and try again.", Type.subheadline, colors.inkTertiary, align = TextAlign.Center)
                    TextLink("Try Again", Type.subheadline.semibold, tag = "paywall.retry") { scope.launch { store.fetchProducts() } }
                }
                else -> BoxWithConstraints(Modifier.fillMaxSize()) {
                    val minHeight = maxHeight
                    Column(
                        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).heightIn(min = minHeight)
                            .padding(horizontal = 22.dp).padding(top = 8.dp, bottom = 14.dp),
                        verticalArrangement = Arrangement.SpaceBetween,
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Column(Modifier.widthIn(max = 520.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Hero(context)
                            PaywallCopy.trialBannerText(selected, selected?.let(store::isEligibleForIntroOffer) == true)?.let { TrialBanner(it) }
                            Benefits()
                            val monthly = plans.firstOrNull { it.kind == PlanKind.MONTHLY }
                            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                plans.forEach { plan ->
                                    PlanCard(plan, plan.id == selectedId, store.isEligibleForIntroOffer(plan), PaywallCopy.badge(plan, monthly)) { selectedId = plan.id }
                                }
                            }
                        }
                        Column(
                            Modifier.widthIn(max = 520.dp).fillMaxWidth().padding(top = 12.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            val eligible = selected?.let(store::isEligibleForIntroOffer) == true
                            // The billed amount is the most conspicuous pricing element; trial detail stays subordinate.
                            Column(Modifier.fillMaxWidth().heightIn(min = 48.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                T(selected?.priceLabel ?: " ", Type.title3.bold, modifier = Modifier.testTag("paywall.price"))
                                val subtext = PaywallCopy.billingSubtext(selected, eligible)
                                T(subtext ?: " ", Type.caption2, colors.inkTertiary, Modifier.alpha(if (subtext == null) 0f else 1f), align = TextAlign.Center, maxLines = 2)
                            }
                            ProminentButton(
                                PaywallCopy.ctaTitle(selected, eligible),
                                modifier = Modifier.fillMaxWidth(),
                                enabled = !isPurchasing && selected != null,
                                tag = "paywall.cta",
                                content = if (isPurchasing) {
                                    { CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp, modifier = Modifier.size(22.dp)) }
                                } else null,
                                onClick = ::purchase,
                            )
                            val reassurance = PaywallCopy.trialReassuranceLine(selected, eligible)
                            T(
                                reassurance ?: " ", Type.caption.semibold, colors.brandPrimary,
                                Modifier.heightIn(min = 18.dp).alpha(if (reassurance == null) 0f else 1f), align = TextAlign.Center, maxLines = 1,
                            )
                            val disclosure = PaywallCopy.disclosure(selected, eligible)
                            T(
                                disclosure ?: " ", Type.caption2, colors.inkTertiary,
                                Modifier.fillMaxWidth().heightIn(min = 56.dp).alpha(if (disclosure == null) 0f else 1f).testTag("paywall.disclosure"),
                                align = TextAlign.Center, maxLines = 4,
                            )
                            errorMessage?.let { T(it, Type.footnote, Color(0xFFD93025), align = TextAlign.Center) }
                            restoreMessage?.let { T(it, Type.footnote, colors.inkSecondary, align = TextAlign.Center) }
                            FooterLinks(isRestoring, enabled = !isRestoring && !isPurchasing, onRestore = ::restore)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun Hero(context: Persona) {
    val colors = Sideline.colors
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        if (!context.isFree) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Symbols.persona(context), null, tint = colors.brandPrimary, modifier = Modifier.size(12.dp))
                T(context.contextHeader, Type.caption2.heavy.copy(letterSpacing = 1.2.sp), colors.brandPrimary)
            }
        }
        T(PaywallCopy.headline(context), Type.display(24f), maxLines = 2, modifier = Modifier.testTag("paywall.headline"))
        T("Fresh takes for every room, all day.", Type.footnote, colors.inkSecondary, maxLines = 1)
    }
}

/** The trial-forward banner, high on the screen. Hidden for plans without a trial. */
@Composable
private fun TrialBanner(text: String) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Sideline.colors.brandPrimary)
            .padding(horizontal = 14.dp, vertical = 10.dp).testTag("paywall.trialBanner"),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Rounded.CardGiftcard, null, tint = Color.White, modifier = Modifier.size(15.dp))
        T(text, Type.subheadline.bold, Color.White, maxLines = 1)
    }
}

@Composable
private fun Benefits() {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        listOf(
            "A separate daily briefing for every room",
            "Fresh stories morning, midday, and evening",
            "Plain-English context and one thing to say",
        ).forEach { title ->
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(24.dp), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.CheckCircle, null, tint = Sideline.colors.brandPrimary, modifier = Modifier.size(17.dp))
                }
                T(title, Type.subheadline, maxLines = 2)
            }
        }
    }
}

@Composable
private fun PlanCard(plan: PlanInfo, isSelected: Boolean, showsTrial: Boolean, badge: String?, onTap: () -> Unit) {
    val colors = Sideline.colors
    val shape = RoundedCornerShape(12.dp)
    val secondary = plan.kind == PlanKind.LIFETIME
    Row(
        Modifier.fillMaxWidth().alpha(if (secondary && !isSelected) 0.72f else 1f).clip(shape).background(colors.card)
            .border(2.dp, if (isSelected) colors.brandPrimary else Color.Transparent, shape)
            .clickable(role = Role.RadioButton, onClick = onTap)
            .semantics { selected = isSelected }
            .testTag("plan.${plan.kind.name.lowercase()}")
            .padding(horizontal = 16.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier.size(22.dp).border(2.dp, if (isSelected) colors.brandPrimary else colors.inkSecondary, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            if (isSelected) Box(Modifier.size(12.dp).clip(CircleShape).background(colors.brandPrimary))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                T(plan.displayName, Type.subheadline.bold)
                badge?.let {
                    T(it, Type.caption2.bold, Color.White, Modifier.clip(CircleShape).background(colors.brandPrimary).padding(horizontal = 6.dp, vertical = 2.dp), maxLines = 1)
                }
            }
            val trial = plan.introOfferLabel
            if (showsTrial && trial != null) T(PaywallCopy.capitalized(trial), Type.caption2, colors.inkTertiary)
            else plan.monthlyEquivalentLabel?.let { T(it, Type.caption2.medium, colors.inkTertiary) }
        }
        T(plan.priceLabel, Type.subheadline.bold.copy(fontFeatureSettings = "tnum"), maxLines = 1)
    }
}

@Composable
private fun FooterLinks(isRestoring: Boolean, enabled: Boolean, onRestore: () -> Unit) {
    val colors = Sideline.colors
    val context = LocalContext.current
    Row(Modifier.padding(top = 4.dp), horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
        TextLink(if (isRestoring) "Restoring…" else "Restore Purchases", Type.caption2, colors.inkTertiary, enabled = enabled, tag = "paywall.restore", onClick = onRestore)
        T("·", Type.caption2, colors.inkTertiary)
        TextLink("Terms", Type.caption2, colors.inkTertiary) { openLink(context, StoreLinks.TERMS_URL) }
        T("·", Type.caption2, colors.inkTertiary)
        TextLink("Privacy", Type.caption2, colors.inkTertiary) { openLink(context, StoreLinks.PRIVACY_URL) }
    }
}
