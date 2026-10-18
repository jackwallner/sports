package com.jackwallner.sports.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.outlined.Email
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Contrast
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.UnfoldMore
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.jackwallner.sports.BuildConfig
import com.jackwallner.sports.data.AppearanceMode
import com.jackwallner.sports.data.Membership
import com.jackwallner.sports.data.StoreLinks
import com.jackwallner.sports.model.Persona
import com.jackwallner.sports.ui.LocalGraph
import com.jackwallner.sports.ui.components.GroupRow
import com.jackwallner.sports.ui.components.GroupSection
import com.jackwallner.sports.ui.components.LocalSheets
import com.jackwallner.sports.ui.components.RowDivider
import com.jackwallner.sports.ui.components.T
import com.jackwallner.sports.ui.components.TopBar
import com.jackwallner.sports.ui.openLink
import com.jackwallner.sports.ui.theme.Sideline
import com.jackwallner.sports.ui.theme.Type
import com.jackwallner.sports.ui.theme.semibold
import kotlinx.coroutines.launch

/** `SettingsView`: Pro, theme, manual refresh, restore, help and about. */
@Composable
fun SettingsScreen(onBack: () -> Unit) {
    val graph = LocalGraph.current
    val store = graph.store
    val sheets = LocalSheets.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val colors = Sideline.colors
    val isPro = store.isPro
    var isRestoring by remember { mutableStateOf(false) }
    var restoreResult by remember { mutableStateOf<String?>(null) }
    var showReviewerCode by remember { mutableStateOf(false) }
    var themeMenu by remember { mutableStateOf(false) }

    fun showPaywall() = sheets.presentPaywall(Persona.COCKTAIL_PARTY, "sideline_settings_paywall_sheet")

    Column(Modifier.fillMaxSize().background(colors.background).testTag("settings")) {
        TopBar("Settings", leading = {
            IconButton(onClick = onBack, modifier = Modifier.testTag("settings.back").semantics { contentDescription = "Back" }) {
                Icon(Icons.AutoMirrored.Rounded.ArrowBack, null, tint = colors.brandPrimary)
            }
        })
        Column(
            Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).navigationBarsPadding().padding(top = 8.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(28.dp),
        ) {
            GroupSection {
                GroupRow(onClick = ::showPaywall, tag = "settings.pro") {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Rounded.AutoAwesome, null, tint = colors.brandPrimary, modifier = Modifier.size(20.dp))
                            Spacer(Modifier.width(10.dp))
                            T(Membership.PRO, Type.headline, modifier = Modifier.weight(1f))
                            T(if (isPro) "Active" else "See Pro", Type.subheadline.semibold, if (isPro) colors.inkSecondary else colors.brandPrimary)
                        }
                        T(if (isPro) "All contexts and fresher briefings are on." else "All contexts, fresh 3×/day.", Type.callout, colors.inkSecondary)
                    }
                }
            }

            GroupSection(header = "Appearance") {
                Box {
                    GroupRow(onClick = { themeMenu = true }, tag = "settings.theme") {
                        RowIcon(Icons.Rounded.Contrast)
                        T("Theme", Type.body, modifier = Modifier.weight(1f))
                        T(graph.settings.appearance.label, Type.body, colors.inkSecondary)
                        Icon(Icons.Rounded.UnfoldMore, null, tint = colors.inkSecondary, modifier = Modifier.padding(start = 4.dp).size(16.dp))
                    }
                    DropdownMenu(themeMenu, onDismissRequest = { themeMenu = false }, modifier = Modifier.align(Alignment.TopEnd)) {
                        AppearanceMode.entries.forEach { mode ->
                            DropdownMenuItem(
                                text = { T(mode.label, Type.body) },
                                onClick = {
                                    graph.settings.updateAppearance(mode)
                                    themeMenu = false
                                },
                                modifier = Modifier.testTag("settings.theme.${mode.raw}"),
                            )
                        }
                    }
                }
            }

            GroupSection(header = "Briefing") {
                GroupRow(
                    onClick = {
                        if (isPro) {
                            onBack()
                            scope.launch { graph.viewModel.refresh() }
                        } else {
                            showPaywall()
                        }
                    },
                    tag = "settings.refresh",
                ) {
                    RowIcon(Icons.Rounded.Refresh)
                    T("Manual refresh", Type.body, colors.brandPrimary, Modifier.weight(1f))
                    T(if (isPro) "Refresh now" else "Pro", Type.body, colors.inkSecondary)
                }
            }

            if (isPro && store.hasActiveSubscription) {
                GroupSection(footer = "Change or cancel your subscription in Google Play.") {
                    GroupRow(onClick = { openLink(context, StoreLinks.manageSubscriptionURL(store.activeProductId)) }, tag = "settings.manage") {
                        T("Manage Subscription", Type.body, colors.brandPrimary)
                    }
                }
            }

            GroupSection(footer = "Already subscribed? Restore to unlock Pro on this device.") {
                GroupRow(
                    onClick = {
                        if (isRestoring) return@GroupRow
                        isRestoring = true
                        scope.launch {
                            store.restore()
                            restoreResult = if (store.isPro) "${Membership.PRO} is active on this device."
                            else store.lastError ?: "No active ${Membership.PRO} purchase was found for this Google account."
                            isRestoring = false
                        }
                    },
                    tag = "settings.restore",
                ) {
                    T(if (isRestoring) "Restoring…" else "Restore Purchases", Type.body, if (isRestoring) colors.inkTertiary else colors.brandPrimary)
                }
            }

            // Two separate rows, with no question in front of either.
            GroupSection(header = "Help") {
                LinkRow(Icons.Outlined.Email, "Send Feedback", "settings.feedback") { openLink(context, StoreLinks.FEEDBACK_MAIL_URI) }
                RowDivider()
                LinkRow(Icons.Outlined.StarOutline, "Rate Gist", "settings.rate") {
                    graph.review.markOpenedWriteReview()
                    val market = Intent(Intent.ACTION_VIEW, Uri.parse(StoreLinks.PLAY_MARKET_URI)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    if (runCatching { context.startActivity(market) }.isFailure) openLink(context, StoreLinks.PLAY_LISTING_URL)
                }
            }

            GroupSection(header = "About") {
                LinkRow(null, "Privacy Policy", "settings.privacy") { openLink(context, StoreLinks.PRIVACY_URL) }
                RowDivider()
                LinkRow(null, "Terms of Use", "settings.terms") { openLink(context, StoreLinks.TERMS_URL) }
                RowDivider()
                // Long-press opens the reviewer code entry for Play review.
                GroupRow(onLongClick = { showReviewerCode = true }, tag = "settings.version") {
                    T("Version", Type.body, modifier = Modifier.weight(1f))
                    T("${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})", Type.body, colors.inkSecondary)
                }
            }
        }
    }

    restoreResult?.let { message ->
        AlertDialog(
            onDismissRequest = { restoreResult = null },
            containerColor = if (colors.isDark) colors.deckCard else Color.White,
            title = { T("Restore Purchases", Type.headline) },
            text = { T(message, Type.subheadline, colors.inkSecondary, Modifier.testTag("settings.restore.message")) },
            confirmButton = { TextButton(onClick = { restoreResult = null }) { T("OK", Type.headline, colors.brandPrimary) } },
        )
    }
    if (showReviewerCode) ReviewerCodeDialog { showReviewerCode = false }
}

@Composable
private fun RowIcon(icon: ImageVector) {
    Icon(icon, null, tint = Sideline.colors.brandPrimary, modifier = Modifier.size(20.dp))
    Spacer(Modifier.width(12.dp))
}

@Composable
private fun LinkRow(icon: ImageVector?, title: String, tag: String, onClick: () -> Unit) {
    GroupRow(onClick = onClick, tag = tag) {
        icon?.let { RowIcon(it) }
        T(title, Type.body, Sideline.colors.brandPrimary)
    }
}

/** Play review access: a code from the review notes opens the paid boundary on this device. */
@Composable
private fun ReviewerCodeDialog(onDismiss: () -> Unit) {
    val store = LocalGraph.current.store
    val colors = Sideline.colors
    var code by remember { mutableStateOf("") }
    var failed by remember { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = if (colors.isDark) colors.deckCard else Color.White,
        title = { T("Reviewer Access", Type.headline) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                T("Enter the reviewer code provided with this app's review notes.", Type.subheadline, colors.inkSecondary)
                OutlinedTextField(
                    code, { code = it; failed = false }, singleLine = true,
                    textStyle = Type.body.copy(color = colors.inkPrimary),
                    colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = colors.brandPrimary, unfocusedBorderColor = colors.rule, cursorColor = colors.brandPrimary),
                    modifier = Modifier.testTag("reviewer.code"),
                )
                if (failed) T("That code isn't valid.", Type.caption, Color(0xFFD93025))
                Spacer(Modifier.height(2.dp))
            }
        },
        confirmButton = {
            TextButton(onClick = { if (store.activateReviewAccess(code)) onDismiss() else failed = true }, modifier = Modifier.testTag("reviewer.unlock")) {
                T("Unlock", Type.headline, colors.brandPrimary)
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { T("Cancel", Type.body, colors.inkSecondary) } },
    )
}
