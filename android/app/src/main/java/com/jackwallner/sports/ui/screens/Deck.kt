package com.jackwallner.sports.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.EaseIn
import androidx.compose.animation.core.VectorConverter
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.SubdirectoryArrowRight
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.ChatBubble
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.OutlinedFlag
import androidx.compose.material.icons.rounded.Layers
import androidx.compose.material.icons.rounded.Link
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.LockOpen
import androidx.compose.material.icons.rounded.Newspaper
import androidx.compose.material.icons.rounded.NorthEast
import androidx.compose.material.icons.rounded.People
import androidx.compose.material.icons.rounded.QuestionAnswer
import androidx.compose.material.icons.rounded.Swipe
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import com.jackwallner.sports.data.StoreLinks
import com.jackwallner.sports.model.Briefing
import com.jackwallner.sports.model.BriefingBullet
import com.jackwallner.sports.model.BriefingTag
import com.jackwallner.sports.model.CardArt
import com.jackwallner.sports.model.DeckCard
import com.jackwallner.sports.model.Persona
import com.jackwallner.sports.ui.LocalGraph
import com.jackwallner.sports.ui.Symbols
import com.jackwallner.sports.ui.openLink
import com.jackwallner.sports.ui.components.CardArtImage
import com.jackwallner.sports.ui.components.CardArtStore
import com.jackwallner.sports.ui.components.FitByScale
import com.jackwallner.sports.ui.components.T
import com.jackwallner.sports.ui.theme.Deck
import com.jackwallner.sports.ui.theme.Sideline
import com.jackwallner.sports.ui.theme.Type
import com.jackwallner.sports.ui.theme.heavy
import com.jackwallner.sports.ui.theme.medium
import com.jackwallner.sports.ui.theme.semibold
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** A SwiftUI spring (`response`, `dampingFraction`) as a Compose spring. */
private fun <T> iosSpring(response: Float, damping: Float) =
    spring<T>(dampingRatio = damping, stiffness = (2 * PI / response).let { (it * it).toFloat() })

/**
 * `BriefingDeck`: the briefing as a swipe deck. Fling the top card either way
 * and the next one, already peeking and rising behind it, takes its place.
 * The deck loops. Tap a story to flip it to its backstory; long-press to copy.
 */
@Composable
fun BriefingDeck(
    briefing: Briefing,
    index: Int,
    onIndexChange: (Int) -> Unit,
    isPro: Boolean,
    trialAvailable: Boolean,
    onOpenSource: (String) -> Unit,
    onExploreRooms: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val graph = LocalGraph.current
    val context = LocalContext.current
    val density = LocalDensity.current
    val haptics = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()
    val cards = remember(briefing, isPro) { DeckCard.cards(briefing, isPro) }
    val count = cards.size
    val current = index.coerceIn(0, count - 1)
    val currentIndex by rememberUpdatedState(current)
    val slotCount = min(3, count)

    val drag = remember { Animatable(Offset.Zero, Offset.VectorConverter) }
    var isFlinging by remember { mutableStateOf(false) }
    var flippedPosition by remember { mutableStateOf<Int?>(null) }
    var crossedThreshold by remember { mutableStateOf(false) }
    var copyAt by remember { mutableStateOf<Offset?>(null) }

    LaunchedEffect(current, count) {
        flippedPosition = null
        if (cards[current] == DeckCard.Rooms) graph.store.trackPaywallImpression("sideline_free_deck_rooms_card", oncePerSession = true)
    }

    // Warm each card's primary URL only; the chain's fallbacks are for failures.
    LaunchedEffect(briefing.id) {
        val urls = listOfNotNull(CardArt.leadImageURLs(briefing).firstOrNull()) + briefing.bullets.mapNotNull { CardArt.imageURLs(it).firstOrNull() }
        CardArtStore.prefetch(context.applicationContext, urls, graph.scope)
    }

    // One-time teaching beat: the top card eases over and springs back.
    LaunchedEffect(Unit) {
        if (graph.settings.hasSwipedDeck || count <= 1) return@LaunchedEffect
        delay(750)
        if (graph.settings.hasSwipedDeck || isFlinging || drag.value != Offset.Zero) return@LaunchedEffect
        val nudge = with(density) { 52.dp.toPx() }
        launch { drag.animateTo(Offset(nudge, 0f), iosSpring(0.38f, 0.6f)) }
        delay(430)
        if (!isFlinging) drag.animateTo(Offset.Zero, iosSpring(0.55f, 0.72f))
    }

    fun flip(position: Int) {
        if (!cards[position].hasBack || isFlinging) return
        haptics.performHapticFeedback(HapticFeedbackType.SegmentTick)
        flippedPosition = if (flippedPosition == position) null else position
    }

    Column(modifier, verticalArrangement = Arrangement.spacedBy(14.dp)) {
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            val width = constraints.maxWidth.toFloat()
            val dismissDistance = max(with(density) { 90.dp.toPx() }, width * 0.30f)
            val fullSwipe = with(density) { 110.dp.toPx() }
            val restStep = with(density) { 26.dp.toPx() }

            suspend fun fling(direction: Float) {
                isFlinging = true
                graph.settings.markSwiped()
                haptics.performHapticFeedback(HapticFeedbackType.Confirm)
                drag.animateTo(Offset(direction * width * 1.5f, drag.value.y * 1.1f), tween(260, easing = EaseIn))
                onIndexChange((currentIndex + 1) % count)
                drag.snapTo(Offset.Zero)
                isFlinging = false
                flippedPosition = null
            }

            Box(
                Modifier.fillMaxSize().padding(start = 18.dp, end = 18.dp, top = 4.dp, bottom = 30.dp)
                    .testTag("deck")
                    .semantics {
                        stateDescription = "Card ${current + 1} of $count"
                        // `accessibilityAdjustableAction` and the flip button: TalkBack can't swipe the deck.
                        customActions = buildList {
                            add(CustomAccessibilityAction("Next card") { onIndexChange((currentIndex + 1) % count); true })
                            add(CustomAccessibilityAction("Previous card") { onIndexChange((currentIndex - 1 + count) % count); true })
                            if (cards[current].hasBack) {
                                val label = if (flippedPosition == current) "Show the talking point" else "Show the backstory"
                                add(CustomAccessibilityAction(label) { flip(currentIndex); true })
                            }
                        }
                    }
                    // The gestures live on the still container: the card itself moves under the finger.
                    .pointerInput(count) {
                        val tracker = VelocityTracker()
                        detectDragGestures(
                            onDragStart = {
                                tracker.resetTracking()
                                copyAt = null
                            },
                            onDragEnd = {
                                if (isFlinging) return@detectDragGestures
                                crossedThreshold = false
                                val velocity = tracker.calculateVelocity()
                                val dx = drag.value.x
                                val predicted = dx + velocity.x * 0.2f
                                scope.launch {
                                    if (abs(dx) > dismissDistance || abs(predicted) > width * 0.75f) {
                                        fling(if (dx >= 0) 1f else -1f)
                                    } else {
                                        drag.animateTo(Offset.Zero, iosSpring(0.32f, 0.78f))
                                    }
                                }
                            },
                            onDragCancel = {
                                crossedThreshold = false
                                if (!isFlinging) scope.launch { drag.animateTo(Offset.Zero, iosSpring(0.32f, 0.78f)) }
                            },
                        ) { change, amount ->
                            if (isFlinging) return@detectDragGestures
                            change.consume()
                            tracker.addPosition(change.uptimeMillis, change.position)
                            val next = drag.value + amount
                            scope.launch { drag.snapTo(next) }
                            val past = abs(next.x) > dismissDistance
                            if (past != crossedThreshold) {
                                crossedThreshold = past
                                if (past) haptics.performHapticFeedback(HapticFeedbackType.SegmentTick)
                            }
                        }
                    }
                    .pointerInput(count) {
                        detectTapGestures(
                            onTap = { flip(currentIndex) },
                            onLongPress = { at -> if (copyText(cards[currentIndex], flippedPosition == currentIndex) != null) copyAt = at },
                        )
                    },
            ) {
                val progress = min(1f, abs(drag.value.x) / fullSwipe)
                for (slot in slotCount - 1 downTo 0) {
                    val position = (current + slot) % count
                    key(position) {
                        val restingScale = { s: Int -> 1f - s * 0.04f }
                        val scale = if (slot == 0) 1f else restingScale(slot) + (restingScale(slot - 1) - restingScale(slot)) * progress
                        val y = if (slot == 0) 0f else restStep * slot + (restStep * (slot - 1) - restStep * slot) * progress
                        val top = slot == 0
                        DeckCardView(
                            card = cards[position],
                            isTop = top,
                            isFlipped = flippedPosition == position,
                            trialAvailable = trialAvailable,
                            onOpenSource = onOpenSource,
                            onExploreRooms = onExploreRooms,
                            modifier = Modifier.fillMaxSize()
                                .graphicsLayer {
                                    if (top) {
                                        translationX = drag.value.x
                                        translationY = drag.value.y
                                        rotationZ = (drag.value.x / density.density / 14f).coerceIn(-12f, 12f)
                                        transformOrigin = TransformOrigin(0.5f, 1f)
                                    }
                                }
                                .graphicsLayer {
                                    scaleX = scale
                                    scaleY = scale
                                    translationY = y
                                }
                                // The peeking cards are all but invisible: keep them out of the tree.
                                .then(if (top) Modifier.testTag("deck.card") else Modifier.clearAndSetSemantics { }),
                        )
                    }
                }
                copyAt?.let { at ->
                    Box(Modifier.offset { IntOffset(at.x.roundToInt(), at.y.roundToInt()) }) {
                        DropdownMenu(expanded = true, onDismissRequest = { copyAt = null }) {
                            DropdownMenuItem(
                                text = { T("Copy", Type.body) },
                                leadingIcon = { Icon(Icons.Rounded.ContentCopy, null) },
                                onClick = {
                                    copyText(cards[current], flippedPosition == current)?.let { text ->
                                        context.getSystemService(ClipboardManager::class.java)?.setPrimaryClip(ClipData.newPlainText("Gist", text))
                                    }
                                    copyAt = null
                                },
                                modifier = Modifier.testTag("deck.copy"),
                            )
                            DeckCard.reportSummary(cards[current])?.let { summary ->
                                DropdownMenuItem(
                                    text = { T("Report this card", Type.body) },
                                    leadingIcon = { Icon(Icons.Rounded.OutlinedFlag, null) },
                                    onClick = {
                                        copyAt = null
                                        openLink(context, StoreLinks.reportCardMailURI(summary))
                                    },
                                    modifier = Modifier.testTag("deck.report"),
                                )
                            }
                        }
                    }
                }
            }
        }
        PageDots(count, current)
    }
}

/** The line a long-press copies: the face that is showing. */
private fun copyText(card: DeckCard, flipped: Boolean): String? = when (card) {
    is DeckCard.Lead -> if (flipped) card.briefing.leadBackstory else card.briefing.tlDR
    is DeckCard.Point -> if (flipped) card.bullet.backstory?.takeIf { it.isNotEmpty() } ?: card.bullet.tieIn else card.bullet.talkingPoint
    is DeckCard.Question -> card.text
    DeckCard.Rooms -> null
}

@Composable
private fun PageDots(count: Int, index: Int) {
    val colors = Sideline.colors
    Row(
        Modifier.fillMaxWidth().clearAndSetSemantics { },
        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
    ) {
        repeat(count) { i ->
            val width by animateDpAsState(if (i == index) 22.dp else 7.dp, tween(220), label = "dot")
            Box(Modifier.width(width).height(7.dp).clip(CircleShape).background(if (i == index) colors.brandPrimary else colors.rule))
        }
    }
}

/**
 * One two-sided card that turns on its own spine. The face swaps on the live
 * angle, at 90 degrees, where the card is edge-on and neither face shows.
 */
@Composable
private fun DeckCardView(
    card: DeckCard,
    isTop: Boolean,
    isFlipped: Boolean,
    trialAvailable: Boolean,
    onOpenSource: (String) -> Unit,
    onExploreRooms: () -> Unit,
    modifier: Modifier,
) {
    val angle = remember { Animatable(0f) }
    val density = LocalDensity.current
    LaunchedEffect(isFlipped, isTop) {
        if (!isTop) angle.snapTo(0f) else angle.animateTo(if (isFlipped && card.hasBack) 180f else 0f, iosSpring(0.5f, 0.8f))
    }
    val showingBack = angle.value >= 90f
    val shape = RoundedCornerShape(Deck.cornerRadius)
    Box(
        modifier
            .graphicsLayer {
                rotationY = angle.value
                cameraDistance = 24f * density.density
            }
            .shadow(18.dp, shape, ambientColor = Sideline.colors.inkPrimary.copy(alpha = 0.16f), spotColor = Sideline.colors.inkPrimary.copy(alpha = 0.16f))
            .clip(shape)
            .background(Sideline.colors.deckCard),
    ) {
        if (showingBack) {
            // Pre-mirrored, so once the card is over it reads the right way round.
            Box(Modifier.fillMaxSize().graphicsLayer { rotationY = 180f }.testTag("deck.back")) { BackFace(card, onOpenSource) }
        } else {
            Front(card, trialAvailable, onExploreRooms)
        }
    }
}

// Front: art on top, words on one solid panel below.

@Composable
private fun Front(card: DeckCard, trialAvailable: Boolean, onExploreRooms: () -> Unit) {
    when (card) {
        is DeckCard.Lead -> Column(Modifier.fillMaxSize()) {
            ArtZone(CardArt.leadImageURLs(card.briefing), Modifier.weight(1f)) {}
            Panel {
                Eyebrow(Icons.Rounded.Newspaper, "The brief")
                Line(card.briefing.tlDR, 25f, 9)
                if (card.hasBack) Hint(Icons.Rounded.TouchApp, "Know this and you can hang. Tap for the setup.")
                else Hint(Icons.Rounded.Swipe, "Know this and you can hang. Swipe for the stories.")
            }
        }
        is DeckCard.Point -> Column(Modifier.fillMaxSize()) {
            val bullet = card.bullet
            ArtZone(CardArt.imageURLs(bullet), Modifier.weight(1f)) {
                bullet.tag?.takeIf { it != BriefingTag.NEUTRAL }?.let { TagPill(it) }
                Spacer(Modifier.weight(1f))
                SportChip(bullet)
            }
            Panel {
                Eyebrow(null, DeckCard.kicker(bullet))
                Line(bullet.talkingPoint, 23f, 8)
                // Never promise a back the card doesn't have.
                if (card.hasBack) Hint(Icons.Rounded.TouchApp, "Tap for the backstory")
                else Hint(Icons.Rounded.Swipe, "Swipe for the next story.")
            }
        }
        is DeckCard.Question -> Column(Modifier.fillMaxSize()) {
            QuestionZone(Modifier.weight(1f))
            Panel(Deck.cardPanelGold) {
                Eyebrow(Icons.Rounded.QuestionAnswer, "Ask this")
                Line(card.text, 25f, 8)
                Hint(Icons.Rounded.People, "Toss it out and let them do the talking.")
            }
        }
        DeckCard.Rooms -> RoomsCard(trialAvailable, onExploreRooms)
    }
}

/** The free deck's last card: each other room is its own briefing, with its own stories. */
@Composable
private fun RoomsCard(trialAvailable: Boolean, onExploreRooms: () -> Unit) {
    val proRooms = Persona.entries.filter { !it.isFree }
    Box(Modifier.fillMaxSize().background(Brush.verticalGradient(Deck.cardPanel)).testTag("deck.rooms")) {
        Column(Modifier.fillMaxSize().padding(22.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Eyebrow(Icons.Rounded.Layers, "That was one room")
            Line("${proRooms.size} more rooms got their own stories today.", 24f, 3)
            Column(Modifier.padding(top = 2.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                proRooms.forEach { room ->
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.width(24.dp), contentAlignment = Alignment.Center) {
                            Icon(Symbols.persona(room), null, tint = Color.White.copy(alpha = 0.92f), modifier = Modifier.size(18.dp))
                        }
                        T(room.displayName, Type.subheadline.semibold, Color.White.copy(alpha = 0.92f), Modifier.weight(1f), maxLines = 1)
                        Icon(Icons.Rounded.Lock, null, tint = Color.White.copy(alpha = 0.92f * 0.55f), modifier = Modifier.size(11.dp))
                    }
                }
            }
            Spacer(Modifier.weight(1f).heightIn(min = 8.dp))
            Row(
                Modifier.fillMaxWidth().clip(CircleShape).background(Color.White.copy(alpha = 0.18f))
                    .border(1.dp, Color.White.copy(alpha = 0.28f), CircleShape)
                    .clickable(role = Role.Button, onClick = onExploreRooms)
                    .semantics { contentDescription = if (trialAvailable) "Try every room free" else "Unlock every room" }
                    .testTag("deck.rooms.cta")
                    .padding(horizontal = 14.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Rounded.LockOpen, null, tint = Color.White, modifier = Modifier.size(13.dp))
                T(if (trialAvailable) "Try every room free" else "Unlock every room", Type.subheadline.semibold, Color.White, Modifier.weight(1f), maxLines = 1)
                Icon(Icons.Rounded.NorthEast, null, tint = Color.White, modifier = Modifier.size(13.dp))
            }
            Hint(Icons.Rounded.AutoAwesome, "Different stories, written for that crowd.")
        }
    }
}

/** Placeholder floor, art on top, a light scrim for the pills, and a fade into the panel. */
@Composable
private fun ArtZone(urls: List<String>, modifier: Modifier, chips: @Composable androidx.compose.foundation.layout.RowScope.() -> Unit) {
    val panelTop = Deck.cardPanel[0]
    Box(modifier.fillMaxWidth().clipToBounds().background(Brush.verticalGradient(Deck.artPlaceholder))) {
        CardArtImage(urls)
        Box(
            Modifier.matchParentSize().background(
                Brush.verticalGradient(
                    0f to Color.Black.copy(alpha = 0.28f),
                    0.30f to Color.Transparent,
                    0.62f to panelTop.copy(alpha = 0f),
                    1f to panelTop,
                ),
            ),
        )
        Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(8.dp), content = chips)
    }
}

/** The question card's top zone: an oversized, low-contrast glyph on the gold wash. */
@Composable
private fun QuestionZone(modifier: Modifier) {
    Box(modifier.fillMaxWidth().clipToBounds().background(Brush.verticalGradient(Deck.cardWashGold)).clearAndSetSemantics { }, contentAlignment = Alignment.Center) {
        Icon(Icons.Rounded.ChatBubble, null, tint = Color.White.copy(alpha = 0.15f), modifier = Modifier.size(124.dp).offset(y = (-8).dp))
    }
}

/** The solid panel every card's words sit on. It takes its height first; the art absorbs the rest. */
@Composable
private fun Panel(colors: List<Color> = Deck.cardPanel, content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier.fillMaxWidth().background(Brush.verticalGradient(colors)).padding(22.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        content = content,
    )
}

@Composable
private fun Eyebrow(icon: ImageVector?, text: String, color: Color = Deck.goldOnDark, scale: Float = 1f) {
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
        icon?.let { Icon(it, null, tint = color, modifier = Modifier.size(12.dp)) }
        T(text.uppercase(), Type.eyebrow.copy(fontSize = Type.eyebrow.fontSize * scale), color, maxLines = 1)
    }
}

/** The one line to say: white serif on the panel. It steps down to half size rather than outgrow the card. */
@Composable
private fun Line(text: String, size: Float, limit: Int) {
    BasicText(
        text,
        style = Type.display(size).copy(color = Color.White, lineHeight = 1.25.em),
        maxLines = limit,
        overflow = TextOverflow.Ellipsis,
        autoSize = TextAutoSize.StepBased(minFontSize = (size * 0.5f).sp, maxFontSize = size.sp, stepSize = 0.5.sp),
    )
}

@Composable
private fun Hint(icon: ImageVector, text: String) {
    Row(
        Modifier.padding(top = 2.dp).clearAndSetSemantics { },
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, tint = Color.White.copy(alpha = 0.65f), modifier = Modifier.size(12.dp))
        T(text, Type.footnote.medium, Color.White.copy(alpha = 0.65f))
    }
}

// Back: the backstory, in case they ask.

@Composable
private fun BackFace(card: DeckCard, onOpenSource: (String) -> Unit) {
    Box(Modifier.fillMaxSize().background(Brush.verticalGradient(Deck.cardPanel))) {
        Column(Modifier.fillMaxSize().padding(22.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            when (card) {
                is DeckCard.Lead -> {
                    FitByScale(DeckCard.fitScales, Modifier.weight(1f).fillMaxWidth()) { scale -> LeadSetup(card.briefing, scale) }
                    Hint(Icons.Rounded.Swipe, "Swipe for the stories behind it.")
                }
                is DeckCard.Point -> {
                    FitByScale(DeckCard.fitScales, Modifier.weight(1f).fillMaxWidth()) { scale -> Backstory(card.bullet, scale) }
                    LearnMore(card.bullet, onOpenSource)
                }
                else -> Unit
            }
            FlipBackHint()
        }
    }
}

@Composable
private fun LeadSetup(briefing: Briefing, scale: Float) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy((16 * scale).dp)) {
        Eyebrow(Icons.Rounded.ChatBubble, "The setup")
        briefing.leadBackstory?.takeIf { it.isNotEmpty() }?.let { BackBody(it, 22f * scale, 5f * scale) }
    }
}

@Composable
private fun Backstory(bullet: BriefingBullet, scale: Float) {
    val backstory = bullet.backstory?.takeIf { it.isNotEmpty() }
    val tieIn = bullet.tieIn?.takeIf { it.isNotEmpty() }
    val reason = bullet.tagReason?.takeIf { it.isNotEmpty() }
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy((16 * scale).dp)) {
        Eyebrow(Icons.Rounded.ChatBubble, "The backstory")
        (backstory ?: tieIn)?.let { BackBody(it, 21f * scale, 5f * scale) }
        // The conversational next beat, only when it isn't already the body.
        if (backstory != null && tieIn != null) {
            Aside(Icons.Rounded.SubdirectoryArrowRight, tieIn, Deck.goldOnDark, scale)
        } else if (reason != null) {
            Aside(Symbols.tag(bullet.tag ?: BriefingTag.NEUTRAL), reason, Color.White.copy(alpha = 0.88f), scale)
        }
    }
}

@Composable
private fun BackBody(text: String, size: Float, spacing: Float) {
    T(text, Type.display(size).copy(lineHeight = (size * 1.2f + spacing).sp), Color.White)
}

@Composable
private fun Aside(icon: ImageVector, text: String, color: Color, scale: Float) {
    Row(horizontalArrangement = Arrangement.spacedBy((8 * scale).dp)) {
        Icon(icon, null, tint = color, modifier = Modifier.padding(top = 2.dp).size((16 * scale).dp))
        val size: TextUnit = (17 * scale).sp
        T(text, Type.body.copy(fontSize = size, lineHeight = (17 * scale * 1.3f + 3 * scale).sp), color)
    }
}

@Composable
private fun FlipBackHint() {
    Row(
        Modifier.fillMaxWidth().clearAndSetSemantics { },
        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Rounded.TouchApp, null, tint = Color.White.copy(alpha = 0.7f), modifier = Modifier.size(12.dp))
        T("Tap to flip back", Type.footnote.medium, Color.White.copy(alpha = 0.7f))
    }
}

@Composable
private fun LearnMore(bullet: BriefingBullet, onOpenSource: (String) -> Unit) {
    Row(
        // The tag sits outside the cleared semantics, or clearing would erase it too.
        Modifier.testTag("deck.source").fillMaxWidth().clip(CircleShape).background(Color.White.copy(alpha = 0.18f))
            .border(1.dp, Color.White.copy(alpha = 0.28f), CircleShape)
            .clickable(role = Role.Button) { onOpenSource(bullet.sourceURL) }
            .clearAndSetSemantics { contentDescription = "Learn more. Source: ${bullet.sourceHeadline}" }
            .padding(horizontal = 12.dp, vertical = 13.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Rounded.Link, null, tint = Color.White, modifier = Modifier.size(13.dp))
        T(bullet.sourceHeadline, Type.caption, Color.White, Modifier.weight(1f), maxLines = 1)
        Icon(Icons.Rounded.NorthEast, null, tint = Color.White, modifier = Modifier.size(12.dp))
    }
}

// Art-zone pills.

/** A legible chip naming the sport, icon-only when the sport is unknown. */
@Composable
private fun SportChip(bullet: BriefingBullet) {
    val sport = CardArt.sport(bullet)
    Row(
        Modifier.clip(CircleShape).background(Color.White.copy(alpha = 0.20f)).border(1.dp, Color.White.copy(alpha = 0.30f), CircleShape)
            .padding(horizontal = 9.dp, vertical = 5.dp).clearAndSetSemantics { },
        horizontalArrangement = Arrangement.spacedBy(5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Symbols.sport(sport.symbol), null, tint = Color.White, modifier = Modifier.size(12.dp))
        if (sport.name.isNotEmpty()) T(sport.name, Type.caption2.heavy.copy(letterSpacing = 0.6.sp), Color.White, maxLines = 1)
    }
}

/** The tag colour lives here, in one small dose. */
@Composable
private fun TagPill(tag: BriefingTag) {
    val fill = when (tag) {
        BriefingTag.NICE_GUY, BriefingTag.REDEMPTION -> Deck.tagPillNice
        BriefingTag.JERK, BriefingTag.DRAMA -> Deck.tagPillDrama
        else -> Deck.cardPanel[1]
    }
    Row(
        Modifier.clip(CircleShape).background(fill.copy(alpha = 0.92f)).border(1.dp, Color.White.copy(alpha = 0.25f), CircleShape)
            .padding(horizontal = 9.dp, vertical = 5.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Symbols.tag(tag), null, tint = Color.White, modifier = Modifier.size(12.dp))
        T(tag.displayName.uppercase(), Type.caption2.heavy.copy(letterSpacing = 0.6.sp), Color.White, maxLines = 1)
    }
}
