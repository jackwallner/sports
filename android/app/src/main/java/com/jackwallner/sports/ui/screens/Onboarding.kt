package com.jackwallner.sports.ui.screens

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ChatBubble
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.jackwallner.sports.model.Persona
import com.jackwallner.sports.ui.LocalGraph
import com.jackwallner.sports.ui.Symbols
import com.jackwallner.sports.ui.components.Pill
import com.jackwallner.sports.ui.components.ProminentButton
import com.jackwallner.sports.ui.components.T
import com.jackwallner.sports.ui.components.TextLink
import com.jackwallner.sports.ui.theme.Sideline
import com.jackwallner.sports.ui.theme.Type
import com.jackwallner.sports.ui.theme.bold
import kotlinx.coroutines.launch

/** `OnboardingView`: the value prop, then the free room with the Pro rooms shown locked. */
@Composable
fun OnboardingScreen() {
    val graph = LocalGraph.current
    val colors = Sideline.colors
    val pager = rememberPagerState { 2 }
    val scope = rememberCoroutineScope()
    var picked by remember { mutableStateOf(Persona.from(graph.settings.lastPersonaRaw) ?: Persona.COCKTAIL_PARTY) }
    fun isLocked(persona: Persona) = !graph.store.canUse(persona)

    fun finish() {
        graph.settings.updateLastPersona(if (isLocked(picked)) Persona.COCKTAIL_PARTY.raw else picked.raw)
        graph.settings.updateOnboarded(true)
    }

    Column(Modifier.fillMaxSize().background(colors.background).statusBarsPadding().testTag("onboarding")) {
        HorizontalPager(pager, Modifier.weight(1f).fillMaxWidth()) { page ->
            if (page == 0) ValueProp() else PersonaPick(picked, ::isLocked) { picked = it }
        }
        // `UIPageControl`, tinted brand green.
        Row(Modifier.fillMaxWidth().padding(bottom = 10.dp), horizontalArrangement = Arrangement.Center) {
            repeat(2) { i ->
                Box(
                    Modifier.padding(horizontal = 4.dp).size(8.dp).clip(CircleShape)
                        .background(if (pager.currentPage == i) colors.brandPrimary else colors.brandPrimary.copy(alpha = 0.25f)),
                )
            }
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(colors.rule))
        Row(
            Modifier.fillMaxWidth().navigationBarsPadding().padding(start = 24.dp, end = 24.dp, top = 10.dp, bottom = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (pager.currentPage > 0) {
                TextLink("Back", color = colors.inkSecondary, tag = "onboarding.back") {
                    scope.launch { pager.animateScrollToPage(pager.currentPage - 1) }
                }
            }
            Spacer(Modifier.weight(1f))
            ProminentButton(if (pager.currentPage == 0) "Start" else "See today's briefing", tag = "onboarding.primary") {
                if (pager.currentPage == 0) scope.launch { pager.animateScrollToPage(1) } else finish()
            }
        }
    }
}

@Composable
private fun ValueProp() {
    val colors = Sideline.colors
    Column(
        Modifier.fillMaxSize().padding(horizontal = 28.dp, vertical = 24.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp, Alignment.CenterVertically),
    ) {
        Icon(Icons.Rounded.ChatBubble, null, tint = colors.brandPrimary, modifier = Modifier.size(56.dp))
        T("Sports, made simple.", Type.display(30f))
        T("What happened, why it matters, and one thing to say. Catch up in five minutes.", Type.body, colors.inkSecondary)
    }
}

@Composable
private fun PersonaPick(picked: Persona, isLocked: (Persona) -> Boolean, onPick: (Persona) -> Unit) {
    val colors = Sideline.colors
    Column(
        Modifier.fillMaxSize().padding(horizontal = 28.dp).padding(top = 12.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        T("Start with your free briefing", Type.title)
        T(
            "Cocktail Party gives you today's essential stories. Gist Pro adds briefings made for work, family, and date night.",
            Type.callout, colors.inkSecondary,
        )
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(top = 4.dp, bottom = 12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Persona.entries.forEach { persona -> PersonaRow(persona, isLocked(persona), persona == picked && !isLocked(persona)) { onPick(persona) } }
        }
    }
}

@Composable
private fun PersonaRow(persona: Persona, locked: Boolean, selected: Boolean, onClick: () -> Unit) {
    val colors = Sideline.colors
    val shape = RoundedCornerShape(12.dp)
    val stroke by animateDpAsState(if (selected) 1.5.dp else 1.dp, label = "stroke")
    Row(
        Modifier.fillMaxWidth().alpha(if (locked) 0.85f else 1f).clip(shape)
            .background(if (selected) colors.brandPrimary.copy(alpha = 0.10f) else androidx.compose.ui.graphics.Color.Transparent)
            .border(stroke, if (selected) colors.brandPrimary.copy(alpha = 0.45f) else colors.rule, shape)
            .clickable(role = Role.Button) { if (!locked) onClick() }
            .semantics {
                contentDescription = if (locked) "${persona.displayName}, unlocks with Gist Pro" else persona.displayName
                this.selected = selected
            }
            .testTag("onboarding.persona.${persona.raw}")
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.width(28.dp), contentAlignment = Alignment.Center) {
            Icon(Symbols.persona(persona), null, tint = if (locked) colors.inkTertiary else colors.brandPrimary, modifier = Modifier.size(24.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                T(persona.displayName, Type.headline)
                if (locked) {
                    Pill("Pro", colors.brandAccent.copy(alpha = 0.2f), colors.amberText, Type.caption2.bold) {
                        Icon(Icons.Rounded.Lock, null, tint = colors.amberText, modifier = Modifier.size(10.dp))
                    }
                }
            }
            T(persona.shortPitch, Type.footnote, colors.inkSecondary)
        }
        if (selected) Icon(Icons.Rounded.CheckCircle, null, tint = colors.brandPrimary, modifier = Modifier.size(22.dp))
    }
}
