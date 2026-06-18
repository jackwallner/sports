import Shared
import StoreKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(RevenueCat)
import RevenueCat
#endif

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingPaywall = false
    @State private var isRestoring = false
    @State private var restoreResultMessage: String?
    @AppStorage("sideline.appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue

    private var appearanceBinding: Binding<AppearanceMode> {
        Binding(
            get: { AppearanceMode(rawValue: appearanceModeRaw) ?? .system },
            set: { appearanceModeRaw = $0.rawValue }
        )
    }

    let entitlement: any EntitlementProviding
    let store: StoreService
    var onManualRefresh: () -> Void = {}

    private var isPro: Bool {
        #if canImport(RevenueCat)
        if Purchases.isConfigured, entitlement is StoreService {
            return store.isPro
        }
        #endif
        return entitlement.isPro
    }

    var body: some View {
        List {
            Section {
                Button {
                    showingPaywall = true
                } label: {
                    SettingsProRow(isPro: isPro)
                }
            }

            Section("Appearance") {
                Picker(selection: appearanceBinding) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                } label: {
                    Label("Theme", systemImage: "circle.lefthalf.filled")
                }
                .pickerStyle(.menu)
            }

            Section("Briefing") {
                Button {
                    if isPro {
                        dismiss()
                        onManualRefresh()
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    HStack {
                        Label("Manual refresh", systemImage: "arrow.clockwise")
                        Spacer()
                        Text(isPro ? "Refresh now" : "Pro")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if isPro, store.hasActiveSubscription {
                Section {
                    Button("Manage Subscription") {
                        Task { await openManageSubscriptions() }
                    }
                } footer: {
                    Text("Change or cancel your subscription in your Apple ID settings.")
                }
            }

            Section {
                Button(isRestoring ? "Restoring…" : "Restore Purchases") {
                    Task { await runRestore() }
                }
                .disabled(isRestoring)
            } footer: {
                Text("Already subscribed? Restore to unlock Pro on this device.")
            }

            Section("Help") {
                Button {
                    ReviewPromptCoordinator.shared.requestRateOrFeedback()
                } label: {
                    Label("Rate or Send Feedback", systemImage: "star.bubble")
                }
            }

            Section("About") {
                Link("Privacy Policy", destination: URL(string: "https://jackwallner.github.io/sports/privacy-policy.html")!)
                Link("Terms of Use", destination: URL(string: "https://jackwallner.github.io/sports/terms.html")!)
                LabeledContent("Version", value: versionString)
            }
        }
        .navigationTitle("Settings")
        .alert(
            "Restore Purchases",
            isPresented: Binding(
                get: { restoreResultMessage != nil },
                set: { if !$0 { restoreResultMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreResultMessage ?? "")
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(
                entitlement: entitlement,
                impressionId: "sideline_settings_paywall_sheet"
            )
        }
    }

    private func runRestore() async {
        isRestoring = true
        defer { isRestoring = false }
        #if canImport(RevenueCat)
        if Purchases.isConfigured, entitlement is StoreService {
            await store.restorePurchases()
            restoreResultMessage = store.isPro
                ? "Gist Pro is active on this device."
                : store.lastError ?? "No active Gist Pro purchase was found for this Apple ID."
            return
        }
        #endif
        await entitlement.refresh()
        restoreResultMessage = entitlement.isPro
            ? "Gist Pro is active on this device."
            : "No active Gist Pro purchase was found for this Apple ID."
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    @MainActor
    private func openManageSubscriptions() async {
        #if canImport(UIKit)
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        try? await AppStore.showManageSubscriptions(in: scene)
        #endif
    }
}

private struct SettingsProRow: View {
    let isPro: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Gist Pro", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Text(isPro ? "Active" : "See Pro")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isPro ? .secondary : SidelineTheme.brandPrimary)
            }

            Text(isPro ? "All contexts and fresher briefings are on." : "All contexts, fresh 3\u{00D7}/day.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
