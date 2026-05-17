import Shared
import SwiftUI

struct SettingsView: View {
    @State private var showingPaywall = false
    @AppStorage("favoriteTeam") private var favoriteTeam = ""

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
                if entitlement.isPro {
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
                        HStack {
                            Label("Local team", systemImage: "mappin.and.ellipse")
                            Spacer()
                            Text("Pro")
                                .foregroundStyle(.secondary)
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
                LabeledContent("Version", value: versionString)
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingPaywall) {
            PaywallView(entitlement: entitlement)
        }
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private struct TeamPickerView: View {
    @Binding var selectedTeam: String
    @Environment(\.dismiss) private var dismiss

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

    var body: some View {
        List {
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

            ForEach(teams, id: \.self) { team in
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
