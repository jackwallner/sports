package com.jackwallner.sports

import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import com.jackwallner.sports.data.AppearanceMode
import com.jackwallner.sports.ui.LocalGraph
import com.jackwallner.sports.ui.RootScreen
import com.jackwallner.sports.ui.theme.SidelineTheme
import kotlinx.coroutines.launch

@OptIn(ExperimentalComposeUiApi::class)
class MainActivity : ComponentActivity() {
    private val graph: AppGraph get() = (application as GistApplication).graph

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) {
            DebugLaunchOptions.apply(graph, intent)
            graph.review.recordAppLaunch()
            graph.diagnostics.recordAppOpen()
            graph.store.start(graph.scope)
        }
        setContent {
            val dark = when (graph.settings.appearance) {
                AppearanceMode.SYSTEM -> isSystemInDarkTheme()
                AppearanceMode.LIGHT -> false
                AppearanceMode.DARK -> true
            }
            LaunchedEffect(dark) {
                val bars = if (dark) SystemBarStyle.dark(Color.TRANSPARENT) else SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT)
                enableEdgeToEdge(statusBarStyle = bars, navigationBarStyle = bars)
            }
            CompositionLocalProvider(LocalGraph provides graph) {
                SidelineTheme(dark) {
                    // Test tags double as resource ids so UI Automator and screenshot scripts can find controls.
                    Box(Modifier.semantics { testTagsAsResourceId = true }) {
                        RootScreen(graph)
                    }
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        graph.resumeTick += 1
        // A Play purchase can take a moment to reach RevenueCat.
        if (graph.store.isConfiguredForPurchases) graph.scope.launch { graph.store.refresh() }
    }
}
