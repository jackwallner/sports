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
    @AppStorage("favoriteTeam") private var favoriteTeam = ""
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
    var onTeamChanged: () -> Void = {}

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

            Section("Personalization") {
                if isPro {
                    NavigationLink {
                        TeamPickerView(selectedTeam: $favoriteTeam)
                    } label: {
                        HStack {
                            Label("Local team", systemImage: "mappin.and.ellipse")
                            Spacer()
                            Text(favoriteTeam.isEmpty ? "Pick your team" : favoriteTeam)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Button {
                        showingPaywall = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Label("Local team", systemImage: "mappin.and.ellipse")
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Pro biases briefings toward your market.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onChange(of: favoriteTeam) { _, _ in
                onTeamChanged()
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
                ? "The Sideline Pro is active on this device."
                : store.lastError ?? "No active The Sideline Pro purchase was found for this Apple ID."
            return
        }
        #endif
        await entitlement.refresh()
        restoreResultMessage = entitlement.isPro
            ? "The Sideline Pro is active on this device."
            : "No active The Sideline Pro purchase was found for this Apple ID."
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

private struct TeamPickerView: View {
    @Binding var selectedTeam: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private let teams = [
        "Arizona Cardinals", "Atlanta Falcons", "Baltimore Ravens", "Buffalo Bills",
        "Carolina Panthers", "Chicago Bears", "Cincinnati Bengals", "Cleveland Browns",
        "Dallas Cowboys", "Denver Broncos", "Detroit Lions", "Green Bay Packers",
        "Houston Texans", "Indianapolis Colts", "Jacksonville Jaguars", "Kansas City Chiefs",
        "Las Vegas Raiders", "Los Angeles Chargers", "Los Angeles Rams", "Miami Dolphins",
        "Minnesota Vikings", "New England Patriots", "New Orleans Saints", "New York Giants",
        "New York Jets", "Philadelphia Eagles", "Pittsburgh Steelers", "San Francisco 49ers",
        "Seattle Seahawks", "Tampa Bay Buccaneers", "Tennessee Titans", "Washington Commanders"
    ]

    private var filteredTeams: [String] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return teams }
        return teams.filter { $0.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        List {
            if query.isEmpty {
                Button {
                    selectedTeam = ""
                    dismiss()
                } label: {
                    HStack {
                        Text("None")
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedTeam.isEmpty {
                            Image(systemName: "checkmark")
                                .foregroundStyle(SidelineTheme.brandPrimary)
                        }
                    }
                }
            }

            ForEach(filteredTeams, id: \.self) { team in
                Button {
                    selectedTeam = team
                    dismiss()
                } label: {
                    HStack {
                        Text(team)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedTeam == team {
                            Image(systemName: "checkmark")
                                .foregroundStyle(SidelineTheme.brandPrimary)
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search teams")
        .navigationTitle("Local Team")
    }
}

private struct SettingsProRow: View {
    let isPro: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("The Sideline Pro", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Text(isPro ? "Active" : "See Pro")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isPro ? .secondary : SidelineTheme.brandPrimary)
            }

            Text(isPro ? "All contexts, fresher briefings, and local team are on." : "All contexts, fresh 3\u{00D7}/day, and Local Team.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
