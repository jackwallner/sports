package com.jackwallner.sports.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private fun rgb(r: Double, g: Double, b: Double, a: Double = 1.0) = Color(r.toFloat(), g.toFloat(), b.toFloat(), a.toFloat())

/**
 * `SidelineTheme` ("Newsroom"): paper-warm cream surface, ink type, brand
 * green as the system colour, gold as a restrained accent. Value for value
 * from `Theme.swift`; nothing else in the app declares a colour.
 */
@Immutable
data class SidelineColors(
    val isDark: Boolean,
    val brandPrimary: Color,
    val amberText: Color,
    val inkPrimary: Color,
    val background: Color,
    val deckCard: Color,
    val tagNiceGuy: Color,
    val tagJerk: Color,
) {
    val brandAccent: Color get() = BRAND_ACCENT
    val inkSecondary: Color get() = inkPrimary.copy(alpha = 0.70f)
    val inkTertiary: Color get() = inkPrimary.copy(alpha = 0.64f)
    val rule: Color get() = inkPrimary.copy(alpha = 0.14f)
    val paperSurface: Color get() = PAPER

    /** `sidelineCard`: a faint gold wash for the few surfaces that must float. */
    val card: Color get() = BRAND_ACCENT.copy(alpha = 0.10f)

    /** `tagFill`: tints [base] and bumps opacity in dark mode. */
    fun tagFill(base: Color): Color = base.copy(alpha = if (isDark) 0.26f else 0.16f)

    companion object {
        val BRAND_ACCENT = rgb(0.773, 0.565, 0.102) // #C5901A
        val PAPER = rgb(0.980, 0.965, 0.933) // #FAF6EE

        val light = SidelineColors(
            isDark = false,
            brandPrimary = rgb(0.122, 0.361, 0.271), // #1F5C45
            amberText = rgb(0.353, 0.251, 0.067), // #5A4011
            inkPrimary = rgb(0.102, 0.086, 0.071), // #1A1612
            background = PAPER,
            deckCard = rgb(1.0, 0.996, 0.984), // #FFFEFB
            tagNiceGuy = rgb(0.180, 0.490, 0.310),
            tagJerk = rgb(0.706, 0.271, 0.184),
        )

        val dark = SidelineColors(
            isDark = true,
            brandPrimary = rgb(0.353, 0.682, 0.502), // #5AAE80
            amberText = rgb(0.937, 0.788, 0.439), // #EFC970
            inkPrimary = rgb(0.953, 0.937, 0.910), // #F3EFE8
            background = rgb(0.066, 0.058, 0.047), // deep paper
            deckCard = rgb(0.118, 0.106, 0.090),
            tagNiceGuy = rgb(0.451, 0.788, 0.580),
            tagJerk = rgb(0.937, 0.490, 0.404),
        )
    }
}

/** Fixed deck tokens: white type sits on these in both appearances. */
object Deck {
    /** The panel every card's words sit on (#15372A to #1F5C45). */
    val cardPanel = listOf(rgb(0.082, 0.216, 0.165), rgb(0.122, 0.361, 0.271))
    val cardWashGold = listOf(rgb(0.820, 0.612, 0.129), rgb(0.337, 0.220, 0.047))
    val cardPanelGold = listOf(rgb(0.337, 0.220, 0.047), rgb(0.502, 0.341, 0.071))
    val goldOnDark = rgb(0.937, 0.788, 0.439) // #EFC970
    val artPlaceholder = listOf(rgb(0.165, 0.420, 0.318), rgb(0.106, 0.282, 0.212))
    val tagPillNice = rgb(0.149, 0.420, 0.275)
    val tagPillDrama = rgb(0.620, 0.230, 0.160)
    val cornerRadius = 28.dp
}

object Spacing {
    val xs = 4.dp
    val sm = 8.dp
    val md = 12.dp
    val lg = 16.dp
    val xl = 20.dp
    val xxl = 28.dp
    val xxxl = 40.dp
}

val CardCornerRadius = 12.dp

/**
 * Type: a serif for headlines and eyebrows, the system sans for everything
 * else. Sizes are the iOS Dynamic Type defaults, in sp so they scale with the
 * user's font size like Dynamic Type does.
 */
object Type {
    private val sans = FontFamily.Default
    val serif = FontFamily.Serif

    private fun sans(size: TextUnit, weight: FontWeight = FontWeight.Normal, line: TextUnit = TextUnit.Unspecified) =
        TextStyle(fontFamily = sans, fontSize = size, fontWeight = weight, lineHeight = line)

    /** `SidelineTheme.display(_:)`: semibold serif at a deliberate size. */
    fun display(size: Float) = TextStyle(fontFamily = serif, fontSize = size.sp, fontWeight = FontWeight.SemiBold, lineHeight = (size * 1.2f).sp)

    /** `SidelineTheme.title`: title2 serif semibold. */
    val title = TextStyle(fontFamily = serif, fontSize = 22.sp, fontWeight = FontWeight.SemiBold, lineHeight = 28.sp)

    /** `SidelineTheme.eyebrow`: caption serif semibold, uppercased and tracked at call sites. */
    val eyebrow = TextStyle(fontFamily = serif, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.4.sp)

    val largeTitle = sans(34.sp, FontWeight.Bold, 41.sp)
    val title3 = sans(20.sp, line = 25.sp)
    val headline = sans(17.sp, FontWeight.SemiBold, 22.sp)
    val body = sans(17.sp, line = 22.sp)
    val callout = sans(16.sp, line = 21.sp)
    val subheadline = sans(15.sp, line = 20.sp)
    val footnote = sans(13.sp, line = 18.sp)
    val caption = sans(12.sp, line = 16.sp)
    val caption2 = sans(11.sp, line = 13.sp)
}

val TextStyle.semibold get() = copy(fontWeight = FontWeight.SemiBold)
val TextStyle.bold get() = copy(fontWeight = FontWeight.Bold)
val TextStyle.heavy get() = copy(fontWeight = FontWeight.ExtraBold)
val TextStyle.medium get() = copy(fontWeight = FontWeight.Medium)

private val LocalSidelineColors = staticCompositionLocalOf { SidelineColors.light }

object Sideline {
    val colors: SidelineColors
        @Composable @ReadOnlyComposable get() = LocalSidelineColors.current
}

@Composable
fun SidelineTheme(dark: Boolean, content: @Composable () -> Unit) {
    val colors = if (dark) SidelineColors.dark else SidelineColors.light
    val scheme = if (dark) {
        darkColorScheme(primary = colors.brandPrimary, background = colors.background, surface = colors.background, onSurface = colors.inkPrimary)
    } else {
        lightColorScheme(primary = colors.brandPrimary, background = colors.background, surface = colors.background, onSurface = colors.inkPrimary)
    }
    CompositionLocalProvider(LocalSidelineColors provides colors) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}
