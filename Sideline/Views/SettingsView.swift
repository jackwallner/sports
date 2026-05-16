import Shared
import SwiftUI

struct SettingsView: View {
    @State private var showingPaywall = false
    @State private var favoriteTeam = "Pick your team"

    let entitlement: any EntitlementProviding

    var body: some View {
        List {
            Section {
                Button {
                    showingPaywall = true
                } label: {
                    SettingsProRow(isPro: entitlement.isPro)
                }
            }

            Section("Personalization") {
                Button {
                    if entitlement.isPro {
                        favoriteTeam = favoriteTeam == "Pick your team" ? "New York" : "Pick your team"
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    HStack {
                        Label("Local team", systemImage: "mappin.and.ellipse")
                        Spacer()
                        Text(entitlement.isPro ? favoriteTeam : "Pro")
                            .foregroundStyle(.secondary)
                        if !entitlement.isPro {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Briefing") {
                Button {
                    if !entitlement.isPro {
                        showingPaywall = true
                    }
                } label: {
                    HStack {
                        Label("Manual refresh", systemImage: "arrow.clockwise")
                        Spacer()
                        Text(entitlement.isPro ? "Available" : "Pro")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("About") {
                Link("Privacy Policy", destination: URL(string: "https://jackwallner.github.io/sports/privacy-policy.html")!)
                Link("Terms of Use", destination: URL(string: "https://jackwallner.github.io/sports/terms.html")!)
                Button("Restore Purchases") {
                    Task {
                        await entitlement.refresh()
                    }
                }
                LabeledContent("Version", value: "0.1.0")
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingPaywall) {
            PaywallView(entitlement: entitlement)
        }
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

            Text(isPro ? "All contexts, fresher briefings, and local team are on." : "All contexts, fresh 3×/day, and Local Team.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
