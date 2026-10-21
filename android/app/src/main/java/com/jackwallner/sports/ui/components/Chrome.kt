package com.jackwallner.sports.ui.components

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.SubcomposeLayout
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import com.jackwallner.sports.ui.theme.Sideline
import com.jackwallner.sports.ui.theme.Type
import com.jackwallner.sports.ui.theme.bold
import com.jackwallner.sports.ui.theme.semibold

/** A `Text` with the app's colour default. */
@Composable
fun T(
    text: String,
    style: TextStyle,
    color: Color = Sideline.colors.inkPrimary,
    modifier: Modifier = Modifier,
    align: TextAlign? = null,
    maxLines: Int = Int.MAX_VALUE,
) {
    Text(
        text, modifier = modifier, style = style, color = color, textAlign = align,
        maxLines = maxLines, overflow = if (maxLines == Int.MAX_VALUE) TextOverflow.Clip else TextOverflow.Ellipsis,
    )
}

/** `.borderedProminent` with `.controlSize(.large)`, tinted brand green. */
@Composable
fun ProminentButton(
    title: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    tag: String? = null,
    content: (@Composable RowScope.() -> Unit)? = null,
    onClick: () -> Unit,
) {
    val colors = Sideline.colors
    Row(
        modifier
            .heightIn(min = 50.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(colors.brandPrimary)
            .alpha(if (enabled) 1f else 0.5f)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .then(if (tag != null) Modifier.testTag(tag) else Modifier)
            .padding(horizontal = 20.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (content != null) content() else T(title, Type.headline, Color.White, maxLines = 1)
    }
}

/** `.bordered`: a tinted, filled capsule-ish button. */
@Composable
fun BorderedButton(title: String, tag: String? = null, onClick: () -> Unit) {
    val colors = Sideline.colors
    Box(
        Modifier.clip(RoundedCornerShape(10.dp)).background(colors.brandPrimary.copy(alpha = 0.14f))
            .clickable(role = Role.Button, onClick = onClick)
            .then(if (tag != null) Modifier.testTag(tag) else Modifier)
            .padding(horizontal = 14.dp, vertical = 8.dp),
    ) { T(title, Type.body, colors.brandPrimary) }
}

/** A plain text bar button ("Not now", "Back"). */
@Composable
fun TextLink(title: String, style: TextStyle = Type.body, color: Color = Sideline.colors.brandPrimary, enabled: Boolean = true, tag: String? = null, onClick: () -> Unit) {
    Box(
        Modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(8.dp))
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .then(if (tag != null) Modifier.testTag(tag) else Modifier)
            .padding(horizontal = 12.dp),
        contentAlignment = Alignment.Center,
    ) { T(title, style, if (enabled) color else color.copy(alpha = 0.4f), maxLines = 1) }
}

/** iOS navigation bar: inline title, leading and trailing slots. */
@Composable
fun TopBar(
    title: String,
    titleStyle: TextStyle = Type.headline,
    leading: (@Composable () -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
    statusBarPadding: Boolean = true,
) {
    Box(
        Modifier.fillMaxWidth().then(if (statusBarPadding) Modifier.statusBarsPadding() else Modifier).height(52.dp).padding(horizontal = 6.dp),
    ) {
        Row(Modifier.align(Alignment.CenterStart), verticalAlignment = Alignment.CenterVertically) { leading?.invoke() }
        T(title, titleStyle, modifier = Modifier.align(Alignment.Center).padding(horizontal = 88.dp), align = TextAlign.Center, maxLines = 1)
        Row(Modifier.align(Alignment.CenterEnd), verticalAlignment = Alignment.CenterVertically) { trailing?.invoke() }
    }
}

/** `ViewThatFits(in: .vertical)` over scale steps: the first scale whose content fits the height wins. */
@Composable
fun FitByScale(scales: List<Float>, modifier: Modifier = Modifier, content: @Composable (Float) -> Unit) {
    SubcomposeLayout(modifier) { constraints ->
        val loose = constraints.copy(minHeight = 0, maxHeight = Constraints.Infinity)
        var chosen = scales.last()
        for (scale in scales) {
            val height = subcompose("probe-$scale") { content(scale) }.maxOfOrNull { it.measure(loose).height } ?: 0
            if (height <= constraints.maxHeight) {
                chosen = scale
                break
            }
        }
        val placeables = subcompose("final") { content(chosen) }.map { it.measure(constraints.copy(minHeight = 0)) }
        val width = placeables.maxOfOrNull { it.width } ?: constraints.minWidth
        val height = placeables.maxOfOrNull { it.height } ?: 0
        layout(width.coerceAtLeast(constraints.minWidth), height.coerceIn(constraints.minHeight, constraints.maxHeight)) {
            placeables.forEach { it.place(0, 0) }
        }
    }
}

enum class Detent { MEDIUM, LARGE }

/** One presented sheet. Content gets a `dismiss` that runs the sheet's onDismiss once. */
class SheetEntry(
    val id: String,
    val detent: Detent,
    val onDismiss: () -> Unit,
    val content: @Composable (dismiss: () -> Unit) -> Unit,
) {
    internal val visibility = MutableTransitionState(false).apply { targetState = true }
    internal var closing = false
}

/** iOS sheets as in-window overlays, so UI tests and screenshots see one window. */
@Stable
class SheetController {
    internal val stack = mutableStateListOf<SheetEntry>()

    val isEmpty: Boolean get() = stack.none { !it.closing }

    fun present(id: String, detent: Detent = Detent.LARGE, onDismiss: () -> Unit = {}, content: @Composable (dismiss: () -> Unit) -> Unit) {
        if (stack.any { it.id == id && !it.closing }) return
        stack.removeAll { it.id == id }
        stack.add(SheetEntry(id, detent, onDismiss, content))
    }

    fun dismiss(id: String) {
        val entry = stack.lastOrNull { it.id == id && !it.closing } ?: return
        close(entry)
    }

    internal fun close(entry: SheetEntry) {
        if (entry.closing) return
        entry.closing = true
        entry.visibility.targetState = false
        entry.onDismiss()
    }

    internal fun remove(entry: SheetEntry) {
        stack.remove(entry)
    }
}

val LocalSheets = staticCompositionLocalOf<SheetController> { error("No sheet controller") }

@Composable
fun SheetHost(controller: SheetController, content: @Composable () -> Unit) {
    CompositionLocalProvider(LocalSheets provides controller) {
        Box(Modifier.fillMaxSize()) {
            content()
            controller.stack.toList().forEach { entry -> SheetLayer(controller, entry) }
        }
    }
}

@Composable
private fun SheetLayer(controller: SheetController, entry: SheetEntry) {
    val dismiss = { controller.close(entry) }
    BackHandler(enabled = !entry.closing && controller.stack.lastOrNull() == entry) { dismiss() }
    LaunchedEffect(entry.visibility.isIdle, entry.visibility.currentState) {
        if (entry.visibility.isIdle && !entry.visibility.currentState && entry.closing) controller.remove(entry)
    }
    Box(Modifier.fillMaxSize()) {
        AnimatedVisibility(entry.visibility, enter = fadeIn(tween(220)), exit = fadeOut(tween(200))) {
            Box(
                Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.32f))
                    .clickable(remember { MutableInteractionSource() }, indication = null) { dismiss() },
            )
        }
        BoxWithConstraints(Modifier.fillMaxSize().statusBarsPadding()) {
            val maxHeight = maxHeight
            AnimatedVisibility(
                entry.visibility,
                modifier = Modifier.align(Alignment.BottomCenter),
                enter = slideInVertically(tween(300)) { it },
                exit = slideOutVertically(tween(240)) { it },
            ) {
                val shape = RoundedCornerShape(topStart = 22.dp, topEnd = 22.dp)
                val height = if (entry.detent == Detent.LARGE) Modifier.height(maxHeight - 10.dp) else Modifier.heightIn(max = maxHeight - 10.dp)
                Column(
                    Modifier.fillMaxWidth().then(height).clip(shape)
                        .background(Sideline.colors.background)
                        // Swallow taps so they never reach the scrim.
                        .pointerInput(Unit) { detectTapGestures { } }
                        .testTag("sheet.${entry.id}"),
                ) {
                    Box(Modifier.fillMaxWidth().padding(top = 6.dp), contentAlignment = Alignment.Center) {
                        Box(Modifier.size(36.dp, 5.dp).clip(RoundedCornerShape(3.dp)).background(Sideline.colors.inkTertiary.copy(alpha = 0.4f)))
                    }
                    Box(Modifier.weight(1f, fill = entry.detent == Detent.LARGE).navigationBarsPadding()) {
                        entry.content(dismiss)
                    }
                }
            }
        }
    }
}

/** A small capsule pill ("Pro" lock badge, plan badges). */
@Composable
fun Pill(text: String, background: Color, foreground: Color, style: TextStyle = Type.caption2.bold, icon: (@Composable () -> Unit)? = null) {
    Row(
        Modifier.clip(CircleShape).background(background).padding(horizontal = 6.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        icon?.invoke()
        T(text, style, foreground, maxLines = 1)
    }
}

/** iOS inset-grouped list section. */
@Composable
fun GroupSection(header: String? = null, footer: String? = null, content: @Composable () -> Unit) {
    val colors = Sideline.colors
    Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
        header?.let { T(it.uppercase(), Type.footnote, colors.inkSecondary, Modifier.padding(start = 16.dp, bottom = 6.dp)) }
        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp))
                .background(if (colors.isDark) colors.deckCard else Color.White)
                .border(0.5.dp, colors.rule, RoundedCornerShape(12.dp)),
        ) { content() }
        footer?.let { T(it, Type.footnote, colors.inkSecondary, Modifier.padding(start = 16.dp, end = 16.dp, top = 6.dp)) }
    }
}

@Composable
fun GroupRow(
    onClick: (() -> Unit)? = null,
    onLongClick: (() -> Unit)? = null,
    tag: String? = null,
    padding: PaddingValues = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
    content: @Composable RowScope.() -> Unit,
) {
    val base = Modifier.fillMaxWidth().heightIn(min = 46.dp)
    val clickable = when {
        onLongClick != null -> base.pointerInput(onLongClick) { detectTapGestures(onLongPress = { onLongClick() }, onTap = { onClick?.invoke() }) }
        onClick != null -> base.clickable(role = Role.Button, onClick = onClick)
        else -> base
    }
    Row(
        clickable.then(if (tag != null) Modifier.testTag(tag) else Modifier).padding(padding),
        verticalAlignment = Alignment.CenterVertically,
        content = content,
    )
}

@Composable
fun RowDivider() {
    Box(Modifier.fillMaxWidth().padding(start = 16.dp).height(0.5.dp).background(Sideline.colors.rule))
}
