package com.jackwallner.sports.ui

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Undo
import androidx.compose.material.icons.rounded.Circle
import androidx.compose.material.icons.rounded.Coffee
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.FamilyRestroom
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.SportsBaseball
import androidx.compose.material.icons.rounded.SportsBasketball
import androidx.compose.material.icons.rounded.SportsFootball
import androidx.compose.material.icons.rounded.SportsGolf
import androidx.compose.material.icons.rounded.SportsHockey
import androidx.compose.material.icons.rounded.SportsSoccer
import androidx.compose.material.icons.rounded.SportsTennis
import androidx.compose.material.icons.rounded.Stadium
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.ThumbDown
import androidx.compose.material.icons.rounded.ThumbUp
import androidx.compose.material.icons.rounded.WineBar
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.vector.ImageVector
import com.jackwallner.sports.AppGraph
import com.jackwallner.sports.model.BriefingTag
import com.jackwallner.sports.model.Persona
import java.time.Instant

val LocalGraph = staticCompositionLocalOf<AppGraph> { error("No graph") }

tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

/** Web links open in a Custom Tab (the `SFSafariViewController` of Android); mail and market links go to their apps. */
fun openLink(context: Context, url: String) {
    val uri = Uri.parse(url)
    runCatching {
        if (uri.scheme == "http" || uri.scheme == "https") {
            CustomTabsIntent.Builder().setShowTitle(true).build().launchUrl(context, uri)
        } else {
            context.startActivity(Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }
}

/** SF Symbols in the iOS source, as Material icons. */
object Symbols {
    fun persona(persona: Persona): ImageVector = when (persona) {
        Persona.COCKTAIL_PARTY -> Icons.Rounded.WineBar
        Persona.SPORTS_TALK_FOR_MOMS -> Icons.Rounded.FamilyRestroom
        Persona.OFFICE_WATERCOOLER -> Icons.Rounded.Coffee
        Persona.DATE_NIGHT -> Icons.Rounded.Favorite
    }

    fun tag(tag: BriefingTag): ImageVector = when (tag) {
        BriefingTag.NICE_GUY -> Icons.Rounded.ThumbUp
        BriefingTag.JERK -> Icons.Rounded.ThumbDown
        BriefingTag.REDEMPTION -> Icons.AutoMirrored.Rounded.Undo
        BriefingTag.DRAMA -> Icons.Rounded.LocalFireDepartment
        BriefingTag.NEUTRAL -> Icons.Rounded.Circle
    }

    /** `CardArt.Sport.symbol`. */
    fun sport(symbol: String): ImageVector = when (symbol) {
        "football.fill" -> Icons.Rounded.SportsFootball
        "basketball.fill" -> Icons.Rounded.SportsBasketball
        "baseball.fill" -> Icons.Rounded.SportsBaseball
        "soccerball" -> Icons.Rounded.SportsSoccer
        "tennis.racket" -> Icons.Rounded.SportsTennis
        "figure.hockey" -> Icons.Rounded.SportsHockey
        "figure.golf" -> Icons.Rounded.SportsGolf
        "trophy.fill" -> Icons.Rounded.EmojiEvents
        "flame.fill" -> Icons.Rounded.LocalFireDepartment
        "star.fill" -> Icons.Rounded.Star
        else -> Icons.Rounded.Stadium
    }
}

object Formats {
    /** `RelativeDateTimeFormatter` with full units: "in 3 hours", "2 days ago". */
    fun relative(target: Instant, now: Instant = Instant.now()): String {
        val seconds = target.epochSecond - now.epochSecond
        val future = seconds > 0
        val abs = kotlin.math.abs(seconds)
        val (value, unit) = when {
            abs < 60 -> abs to "second"
            abs < 3_600 -> abs / 60 to "minute"
            abs < 86_400 -> abs / 3_600 to "hour"
            abs < 7 * 86_400 -> abs / 86_400 to "day"
            abs < 30 * 86_400 -> abs / (7 * 86_400) to "week"
            abs < 365 * 86_400 -> abs / (30 * 86_400) to "month"
            else -> abs / (365 * 86_400) to "year"
        }
        val phrase = "$value $unit${if (value == 1L) "" else "s"}"
        return if (future) "in $phrase" else "$phrase ago"
    }
}
