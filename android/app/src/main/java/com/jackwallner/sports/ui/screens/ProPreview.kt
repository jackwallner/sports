package com.jackwallner.sports.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.LockOpen
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.sports.model.Persona
import com.jackwallner.sports.ui.Symbols
import com.jackwallner.sports.ui.components.Detent
import com.jackwallner.sports.ui.components.ProminentButton
import com.jackwallner.sports.ui.components.SheetController
import com.jackwallner.sports.ui.components.T
import com.jackwallner.sports.ui.components.TextLink
import com.jackwallner.sports.ui.components.TopBar
import com.jackwallner.sports.ui.theme.Sideline
import com.jackwallner.sports.ui.theme.Type
import com.jackwallner.sports.ui.theme.heavy
import com.jackwallner.sports.ui.theme.semibold

/**
 * The locked room's preview. "See Pro" closes it and opens the paywall once it
 * is gone, as iOS does from `handleSheetDismiss`.
 */
fun SheetController.presentProPreview(persona: Persona, trialAvailable: Boolean, onSeePro: () -> Unit) {
    var wantsPaywall = false
    present("preview", Detent.LARGE, onDismiss = { if (wantsPaywall) onSeePro() }) { dismiss ->
        ProPreviewSheet(
            persona = persona,
            trialAvailable = trialAvailable,
            onSeePro = {
                wantsPaywall = true
                dismiss()
            },
            onDismiss = dismiss,
        )
    }
}

/** `ProPreviewSheet`. */
@Composable
fun ProPreviewSheet(persona: Persona, trialAvailable: Boolean, onSeePro: () -> Unit, onDismiss: () -> Unit) {
    val colors = Sideline.colors
    Column(Modifier.fillMaxSize().testTag("preview")) {
        TopBar(persona.paywallHook, statusBarPadding = false, leading = { TextLink("Not now", tag = "preview.notNow", onClick = onDismiss) })
        Column(
            Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(22.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Symbols.persona(persona), null, tint = colors.brandPrimary, modifier = Modifier.size(14.dp))
                    T(persona.contextHeader, Type.caption.heavy.copy(letterSpacing = 1.2.sp), colors.brandPrimary)
                }
                T(persona.displayName, Type.display(34f))
                T(persona.shortPitch, Type.title3, colors.inkSecondary)
            }
            T("Here's how this room sounds", Type.caption.heavy.copy(letterSpacing = 1.0.sp), colors.inkTertiary)
            val shape = RoundedCornerShape(12.dp)
            T(
                persona.proPreviewTeaser,
                Type.title3.semibold.copy(lineHeight = 29.sp),
                modifier = Modifier.fillMaxWidth().clip(shape).background(colors.brandPrimary.copy(alpha = 0.08f))
                    .border(1.dp, colors.brandPrimary.copy(alpha = 0.18f), shape).padding(18.dp).testTag("preview.teaser"),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Rounded.LockOpen, null, tint = colors.inkSecondary, modifier = Modifier.padding(top = 1.dp).size(15.dp))
                T(
                    "This room gets its own stories every day, separate from the free briefing. Pro opens it, refreshed up to 3× a day.",
                    Type.footnote, colors.inkSecondary,
                )
            }
        }
        ProminentButton(
            if (trialAvailable) "Try ${persona.displayName} Free" else "Unlock ${persona.displayName}",
            modifier = Modifier.fillMaxWidth().padding(start = 24.dp, end = 24.dp, bottom = 24.dp),
            tag = "preview.seePro",
            onClick = onSeePro,
        )
    }
}
