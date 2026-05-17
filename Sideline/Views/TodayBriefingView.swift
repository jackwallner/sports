import Shared
import SwiftUI

struct TodayBriefingView: View {
    @State private var viewModel: TodayBriefingViewModel
    @State private var sourceURL: PresentedURL?
    @State private var showingPaywall = false

    private let entitlement: any EntitlementProviding

    init(service: any BriefingServing, entitlement: any EntitlementProviding) {
        self.entitlement = entitlement
        _viewModel = State(wrappedValue: TodayBriefingViewModel(service: service, entitlement: entitlement))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PersonaRail(selected: viewModel.selectedPersona, isPro: entitlement.isPro) { persona in
                        Task {
                            let didSelect = await viewModel.select(persona)
                            if !didSelect {
                                showingPaywall = true
                            }
                        }
                    }

                    content
                        .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .background(Color.sidelineBackground)
            .navigationTitle("The Sideline")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView(entitlement: entitlement)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                if case .idle = viewModel.state {
                    await viewModel.load()
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(entitlement: entitlement)
            }
            #if canImport(SafariServices) && canImport(UIKit)
            .sheet(item: $sourceURL) { item in
                SafariView(url: item.url)
            }
            #endif
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            skeleton
        case .populated(let briefing, let isOffline):
            briefingView(briefing, isOffline: isOffline)
                .transition(.opacity)
        case .failed(let message):
            emptyState(message: message)
        case .refreshLimit:
            refreshLimitCard
            briefingView(.sample, isOffline: false)
        }
    }

    private func briefingView(_ briefing: Briefing, isOffline: Bool) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            if isOffline {
                offlineBanner
            }

            heroBlock(briefing: briefing)

            Divider()
                .padding(.vertical, 2)

            VStack(spacing: 0) {
                ForEach(Array(briefing.bullets.enumerated()), id: \.element.id) { index, bullet in
                    BulletCard(
                        bullet: bullet,
                        index: index + 1,
                        total: briefing.bullets.count
                    ) { url in
                        sourceURL = PresentedURL(url: url)
                    }

                    if index < briefing.bullets.count - 1 {
                        Divider()
                            .padding(.leading, 18)
                    }
                }
            }

            SuggestedQuestionCard(question: briefing.suggestedQuestion)

            FreshnessFooter(briefing: briefing, isOffline: isOffline)
                .padding(.top, 4)
        }
    }

    private func heroBlock(briefing: Briefing) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.selectedPersona.symbolName)
                    .font(.caption.weight(.bold))
                Text(contextHeader(for: viewModel.selectedPersona))
                    .font(.caption.weight(.heavy))
                    .tracking(1.2)
            }
            .foregroundStyle(SidelineTheme.brandPrimary)

            Text(briefing.headline)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(briefing.tlDR)
                .font(.title2.weight(.bold))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius)
                .fill(SidelineTheme.brandPrimary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius)
                .stroke(SidelineTheme.brandPrimary.opacity(0.18), lineWidth: 1)
        )
    }

    private func contextHeader(for persona: Persona) -> String {
        switch persona {
        case .cocktailParty: return "LEAD WITH THIS"
        case .sportsTalkForMoms: return "WHEN YOUR KID BRINGS IT UP"
        case .officeWatercooler: return "AT THE OFFICE TODAY"
        case .dateNight: return "FOR THE DINNER TABLE"
        case .localTeam: return "FOR YOUR LOCAL CROWD"
        }
    }

    private func emptyState(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "newspaper")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Nothing fresh yet")
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try again") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 24)
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 18) {
            RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius)
                .fill(Color.secondary.opacity(0.12))
                .frame(height: 140)

            ForEach(0..<3, id: \.self) { _ in
                HStack(alignment: .top, spacing: 14) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.secondary.opacity(0.18))
                        .frame(width: 4, height: 78)
                    VStack(alignment: .leading, spacing: 8) {
                        Capsule().fill(Color.secondary.opacity(0.16)).frame(width: 60, height: 10)
                        Capsule().fill(Color.secondary.opacity(0.12)).frame(height: 12)
                        Capsule().fill(Color.secondary.opacity(0.12)).frame(width: 220, height: 12)
                    }
                }
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityLabel("Loading briefing")
    }

    private var offlineBanner: some View {
        Label("Offline - showing the last update.", systemImage: "wifi.slash")
            .font(.callout)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var refreshLimitCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("You're caught up")
                .font(.headline)
            Text("Today's free briefing is already the latest. Pro refreshes 3× a day: morning, midday, and evening.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("See Pro") {
                showingPaywall = true
            }
            .buttonStyle(.borderedProminent)
            .tint(SidelineTheme.brandPrimary)
        }
        .padding(16)
        .background(Color.sidelineCard, in: RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius))
    }
}

private struct PresentedURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
