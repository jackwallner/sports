package com.jackwallner.sports.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.jackwallner.sports.AppGraph
import com.jackwallner.sports.ui.components.SheetController
import com.jackwallner.sports.ui.components.SheetHost
import com.jackwallner.sports.ui.screens.OnboardingScreen
import com.jackwallner.sports.ui.screens.SettingsScreen
import com.jackwallner.sports.ui.screens.TodayScreen
import com.jackwallner.sports.ui.theme.Sideline

/**
 * `TodayBriefingView.body`: a root swap between onboarding and the briefing
 * (never a cover sliding over it), with Settings pushed on top.
 */
@Composable
fun RootScreen(graph: AppGraph) {
    val sheets = remember { SheetController() }
    var showingSettings by rememberSaveable { mutableStateOf(false) }

    SheetHost(sheets) {
        Box(Modifier.fillMaxSize().background(Sideline.colors.background)) {
            AnimatedContent(
                graph.settings.hasCompletedOnboarding,
                transitionSpec = { fadeIn(tween(300)) togetherWith fadeOut(tween(300)) },
                label = "root",
            ) { onboarded ->
                if (!onboarded) {
                    OnboardingScreen()
                } else {
                    TodayScreen(isCovered = showingSettings, onOpenSettings = { showingSettings = true })
                }
            }
            AnimatedVisibility(
                showingSettings,
                enter = slideInHorizontally(tween(300)) { it },
                exit = slideOutHorizontally(tween(260)) { it },
            ) {
                BackHandler(enabled = sheets.isEmpty) { showingSettings = false }
                SettingsScreen(onBack = { showingSettings = false })
            }
        }
    }
}
