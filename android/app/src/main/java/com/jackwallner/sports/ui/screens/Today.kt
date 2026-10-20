package com.jackwallner.sports.ui.screens

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Newspaper
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.rounded.CheckCircleOutline
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.WarningAmber
import androidx.compose.material.icons.rounded.WifiOff
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.google.android.play.core.review.ReviewManagerFactory
import com.jackwallner.sports.data.LoadState
import com.jackwallner.sports.data.TodayBriefingViewModel
import com.jackwallner.sports.model.Briefing
import com.jackwallner.sports.model.Persona
import com.jackwallner.sports.ui.Formats
import com.jackwallner.sports.ui.LocalGraph
import com.jackwallner.sports.ui.Symbols
import com.jackwallner.sports.ui.components.BorderedButton
import com.jackwallner.sports.ui.components.LocalSheets
import com.jackwallner.sports.ui.components.ProminentButton
import com.jackwallner.sports.ui.components.T
import com.jackwallner.sports.ui.components.TextLink
import com.jackwallner.sports.ui.components.TopBar
import com.jackwallner.sports.ui.findActivity
import com.jackwallner.sports.ui.openLink
import com.jackwallner.sports.ui.theme.Deck
import com.jackwallner.sports.ui.theme.Sideline
import com.jackwallner.sports.ui.theme.Type
import com.jackwallner.sports.ui.theme.medium
import com.jackwallner.sports.ui.theme.semibold
import java.time.Duration
import java.time.Instant
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** `SidelineBrand`. */
object SidelineBrand {
    const val NAME = "Sports Cheat Sheet"
    const val PRO_NAME = "Sports Cheat Sheet Pro"
}

/** `TodayBriefingView.briefingRoot`: the rail, the deck, and every state in between. */
@Composable
fun TodayScreen(isCovered: Boolean, onOpenSettings: () -> Unit) {
    val graph = LocalGraph.current
    val vm = graph.viewModel
    val store = graph.store
    val sheets = LocalSheets.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val colors = Sideline.colors
    val isPro = store.isPro
    val trialAvailable = store.trialAvailable

    var deckIndex by remember { mutableIntStateOf(0) }
    var reviewShownThisSession by remember { mutableStateOf(false) }
    var finishedBriefingId by remember { mutableStateOf<java.util.UUID?>(null) }
    var isShowingSource by remember { mutableStateOf(false) }
    var sourceOpenedAtTick by remember { mutableIntStateOf(0) }
    var shownBriefingId by remember { mutableStateOf<java.util.UUID?>(null) }

    fun presentPaywall(impressionId: String) = sheets.presentPaywall(vm.selectedPersona, impressionId)

    /** Restore the last room, but only if it is still usable. */
    fun applyUsablePersonaFromStorage() {
        val stored = Persona.from(graph.defaults.getString(TodayBriefingViewModel.LAST_PERSONA_KEY))
        if (stored != null && store.canUse(stored)) vm.selectedPersona = stored
        else if (!store.canUse(vm.selectedPersona)) vm.selectedPersona = Persona.COCKTAIL_PARTY
    }

    LaunchedEffect(Unit) {
        if (vm.state !is LoadState.Idle) return@LaunchedEffect
        applyUsablePersonaFromStorage()
        vm.load()
        graph.debugDeckStart?.let { start -> deckIndex = minOf(start, (vm.lastBriefing?.bullets?.size ?: 0) + 1) }
    }

    // Entitlements arrive async: when Pro confirms, put the user back in the room they left.
    var wasPro by remember { mutableStateOf(isPro) }
    LaunchedEffect(isPro) {
        val before = wasPro
        wasPro = isPro
        if (before || !isPro) return@LaunchedEffect
        val stored = Persona.from(graph.defaults.getString(TodayBriefingViewModel.LAST_PERSONA_KEY)) ?: return@LaunchedEffect
        if (stored == vm.selectedPersona || !store.canUse(stored)) return@LaunchedEffect
        vm.selectedPersona = stored
        vm.load()
    }

    val briefingOnScreen = (vm.state as? LoadState.Populated)?.briefing
    val clear by rememberUpdatedState(
        sheets.isEmpty && !isCovered && !isShowingSource && briefingOnScreen != null && deckIndex <= briefingOnScreen.bullets.size + 1,
    )

    /** Play's own review card after a positive moment, with no question in front of it. */
    fun scheduleReview() {
        val onboarded = graph.settings.hasCompletedOnboarding
        fun eligible() = !graph.isDemo && onboarded && clear && !reviewShownThisSession &&
            graph.review.shouldRequestAfterPositiveMoment(onboarded)
        if (!eligible()) return
        scope.launch {
            delay(3_500)
            if (!eligible()) return@launch
            reviewShownThisSession = true
            graph.review.markShown()
            val activity = context.findActivity() ?: return@launch
            val manager = ReviewManagerFactory.create(activity)
            manager.requestReviewFlow().addOnCompleteListener { request ->
                if (request.isSuccessful) manager.launchReviewFlow(activity, request.result)
            }
        }
    }

    LaunchedEffect(graph.positiveMoments) { if (graph.positiveMoments > 0) scheduleReview() }

    // A source opened in a Custom Tab: coming back retries a blocked ask.
    LaunchedEffect(graph.resumeTick) {
        if (isShowingSource && graph.resumeTick > sourceOpenedAtTick) {
            isShowingSource = false
            scheduleReview()
        }
    }

    // Reaching the "Ask this" card means the briefing was read through.
    LaunchedEffect(deckIndex, vm.lastBriefing?.id) {
        val briefing = vm.lastBriefing ?: return@LaunchedEffect
        if (graph.isDemo || deckIndex != briefing.bullets.size + 1 || finishedBriefingId == briefing.id) return@LaunchedEffect
        finishedBriefingId = briefing.id
        graph.review.recordPositiveMoment()
    }

    val showsDemoBanner = graph.isDemo && !graph.safeScreenshot

    Column(Modifier.fillMaxSize().background(colors.background).navigationBarsPadding().testTag("today")) {
        TopBar(
            SidelineBrand.NAME,
            titleStyle = Type.headline.copy(fontFamily = Type.serif),
            trailing = {
                IconButton(onClick = onOpenSettings, modifier = Modifier.testTag("settings.open").semantics { contentDescription = "Settings" }) {
                    Icon(Icons.Outlined.Settings, null, tint = colors.brandPrimary)
                }
            },
        )
        PersonaRail(vm.selectedPersona, store::canUse, graph.safeScreenshot) { persona ->
            scope.launch {
                if (!vm.select(persona)) {
                    sheets.presentProPreview(persona, trialAvailable) { presentPaywall("sideline_locked_room_paywall_${persona.raw}") }
                }
            }
        }
        Box(Modifier.weight(1f).fillMaxWidth()) {
            val state = vm.state
            val deck: @Composable (Briefing, Boolean, Boolean) -> Unit = { briefing, offline, caughtUp ->
                LaunchedEffect(briefing.id) {
                    if (shownBriefingId != null && shownBriefingId != briefing.id) deckIndex = 0
                    shownBriefingId = briefing.id
                }
                Column(Modifier.fillMaxSize().padding(top = 4.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    when {
                        showsDemoBanner -> Banner(Icons.Rounded.Visibility, "Preview briefing. Not today's news.", colors.amberText, colors.brandAccent.copy(alpha = 0.12f), medium = true)
                        caughtUp -> CaughtUpBanner(trialAvailable) { presentPaywall("sideline_refresh_limit_paywall") }
                        offline -> Banner(Icons.Rounded.WifiOff, "Offline. Showing your last saved briefing.", colors.inkSecondary, colors.tagFill(colors.inkPrimary))
                    }
                    BriefingDeck(
                        briefing = briefing,
                        index = deckIndex,
                        onIndexChange = { deckIndex = it },
                        isPro = isPro,
                        trialAvailable = trialAvailable,
                        onOpenSource = { url ->
                            isShowingSource = true
                            sourceOpenedAtTick = graph.resumeTick
                            openLink(context, url)
                        },
                        onExploreRooms = { presentPaywall("sideline_free_deck_rooms_paywall") },
                        modifier = Modifier.weight(1f).fillMaxWidth(),
                    )
                    if (!graph.safeScreenshot) FreshnessFooter(briefing, offline, isPro)
                }
            }
            AnimatedContent(
                state,
                contentKey = { it::class },
                transitionSpec = { fadeIn(tween(250)) togetherWith fadeOut(tween(200)) },
                label = "state",
            ) { target ->
                when (target) {
                    LoadState.Idle, LoadState.Loading -> SkeletonCard()
                    is LoadState.Populated -> deck(target.briefing, target.isOffline, false)
                    is LoadState.Failed -> EmptyState(Icons.Outlined.Newspaper, colors.inkTertiary, "Can't reach today's briefing", target.message, "state.failed") {
                        BorderedButton("Try again", tag = "state.retry") { scope.launch { vm.load() } }
                    }
                    LoadState.RefreshLimit -> {
                        val last = vm.lastBriefing
                        if (last != null) {
                            deck(last, false, true)
                        } else {
                            EmptyState(
                                Icons.Rounded.CheckCircleOutline, colors.brandPrimary, "You're caught up",
                                "Today's free briefing is the latest. Pro refreshes 3 times a day.", "state.caughtUp",
                            ) {
                                ProminentButton(if (trialAvailable) "Try Pro Free" else "See Pro", tag = "state.seePro") {
                                    presentPaywall("sideline_refresh_limit_paywall")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/** `PersonaRail`: framed as who you'll be talking to, not as filters. */
@Composable
private fun PersonaRail(selected: Persona, canUse: (Persona) -> Boolean, screenshotMode: Boolean, onSelect: (Persona) -> Unit) {
    val colors = Sideline.colors
    val visible = if (screenshotMode) Persona.entries.filter(canUse) else Persona.entries
    Column(Modifier.fillMaxWidth()) {
        Row(
            Modifier.padding(horizontal = 16.dp).padding(top = 8.dp).semantics(mergeDescendants = true) { heading() },
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            T("ROOMS", Type.eyebrow, colors.brandPrimary)
            T("Pick who you'll be talking to", Type.caption, colors.inkTertiary)
        }
        Row(
            Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            visible.forEach { persona ->
                val isSelected = persona == selected
                val locked = !canUse(persona)
                val foreground = if (isSelected) Color.White else colors.inkPrimary
                Row(
                    Modifier.clip(CircleShape)
                        .background(if (isSelected) colors.brandPrimary else Color.Transparent)
                        .border(1.dp, if (isSelected) Color.Transparent else colors.rule, CircleShape)
                        .clickable(role = Role.Button) { onSelect(persona) }
                        .semantics(mergeDescendants = true) {
                            contentDescription = when {
                                locked -> "${persona.displayName}, Pro context"
                                isSelected -> "${persona.displayName}, selected"
                                else -> persona.displayName
                            }
                            this.selected = isSelected
                        }
                        .testTag("persona.${persona.raw}")
                        .padding(horizontal = 14.dp, vertical = 9.dp),
                    horizontalArrangement = Arrangement.spacedBy(7.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Symbols.persona(persona), null, tint = foreground, modifier = Modifier.size(17.dp))
                    T(persona.displayName, Type.subheadline.semibold, foreground, maxLines = 1)
                    if (locked) Icon(Icons.Rounded.Lock, null, tint = foreground, modifier = Modifier.size(11.dp))
                }
            }
        }
        T(
            selected.shortPitch, Type.caption, colors.inkTertiary,
            Modifier.padding(horizontal = 16.dp).padding(bottom = 6.dp).testTag("persona.pitch"), maxLines = 1,
        )
    }
}

/** `FreshnessFooter`. */
@Composable
private fun FreshnessFooter(briefing: Briefing, isOffline: Boolean, isPro: Boolean) {
    val colors = Sideline.colors
    val stale = Duration.between(briefing.generatedAt, Instant.now()).seconds > 24 * 60 * 60
    val relative = Formats.relative(briefing.generatedAt)
    val text = when {
        isOffline -> "Offline. Showing your last saved briefing."
        stale -> "Updated $relative. Double-check before quoting."
        else -> "Updated $relative · ${briefing.sourceCount} sources"
    }
    val tint = if (stale) colors.amberText else colors.inkTertiary
    val icon = when {
        isOffline -> Icons.Rounded.WifiOff
        stale -> Icons.Rounded.WarningAmber
        else -> Icons.Rounded.Schedule
    }
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 26.dp).padding(bottom = 6.dp).testTag("freshness"),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(5.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(13.dp))
            T(text, Type.caption, tint, align = TextAlign.Center)
        }
        if (!isOffline && isPro) T(briefing.refreshWindow.nextUpdateHint, Type.caption2, colors.inkTertiary, align = TextAlign.Center)
    }
}

@Composable
private fun Banner(icon: ImageVector, text: String, iconTint: Color, background: Color, medium: Boolean = false) {
    val colors = Sideline.colors
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 18.dp).clip(RoundedCornerShape(12.dp)).background(background).padding(10.dp).testTag("banner"),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, tint = iconTint, modifier = Modifier.size(16.dp))
        T(text, if (medium) Type.footnote.medium else Type.footnote, colors.inkSecondary)
    }
}

@Composable
private fun CaughtUpBanner(trialAvailable: Boolean, onSeePro: () -> Unit) {
    val colors = Sideline.colors
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 18.dp).clip(RoundedCornerShape(12.dp))
            .background(colors.brandAccent.copy(alpha = 0.12f)).padding(start = 10.dp, top = 4.dp, bottom = 4.dp).testTag("banner.caughtUp"),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Rounded.CheckCircleOutline, null, tint = colors.inkSecondary, modifier = Modifier.size(16.dp))
        T("You're caught up. Pro refreshes 3 times a day.", Type.footnote, colors.inkSecondary, Modifier.weight(1f))
        TextLink(if (trialAvailable) "Try Pro Free" else "See Pro", Type.footnote.semibold, tag = "banner.seePro", onClick = onSeePro)
    }
}

@Composable
private fun EmptyState(icon: ImageVector, iconTint: Color, title: String, message: String, tag: String, action: @Composable () -> Unit) {
    val colors = Sideline.colors
    Column(
        Modifier.fillMaxSize().padding(horizontal = 24.dp).testTag(tag),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterVertically),
    ) {
        Icon(icon, null, tint = iconTint, modifier = Modifier.size(46.dp))
        T(title, Type.title3.semibold, align = TextAlign.Center)
        T(message, Type.callout, colors.inkSecondary, align = TextAlign.Center)
        Box(Modifier.padding(top = 4.dp)) { action() }
    }
}

/** Mirrors the deck card's two zones so loading resolves into the real card without a jump. */
@Composable
private fun SkeletonCard() {
    val shape = RoundedCornerShape(Deck.cornerRadius)
    Column(
        Modifier.fillMaxSize().padding(start = 18.dp, end = 18.dp, top = 8.dp, bottom = 30.dp)
            .clip(shape).testTag("state.loading")
            .semantics { contentDescription = "Loading briefing" },
    ) {
        Box(Modifier.weight(1f).fillMaxWidth().background(Brush.verticalGradient(Deck.artPlaceholder)))
        Column(
            Modifier.fillMaxWidth().background(Brush.verticalGradient(Deck.cardPanel)).padding(22.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            val bar = Color.White.copy(alpha = 0.22f)
            Box(Modifier.width(110.dp).height(12.dp).clip(CircleShape).background(bar))
            Box(Modifier.fillMaxWidth().height(22.dp).clip(CircleShape).background(bar))
            Box(Modifier.width(220.dp).height(22.dp).clip(CircleShape).background(bar))
        }
    }
}
