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
                VStack(alignment: .leading, spacing: 18) {
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
                .padding(.bottom, 28)
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
            ContentUnavailableView(
                "No briefing yet",
                systemImage: "newspaper",
                description: Text(message)
            )
            .padding(.top, 80)
        case .refreshLimit:
            refreshLimitCard
            briefingView(.sample, isOffline: false)
        }
    }

    private func briefingView(_ briefing: Briefing, isOffline: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if isOffline {
                offlineBanner
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(briefing.headline)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(briefing.tlDR)
                    .font(.title3.weight(.semibold))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                ForEach(briefing.bullets) { bullet in
                    BulletCard(bullet: bullet) { url in
                        sourceURL = PresentedURL(url: url)
                    }
                }
            }

            SuggestedQuestionCard(question: briefing.suggestedQuestion)
            FreshnessFooter(briefing: briefing, isOffline: isOffline)
        }
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 220, height: 18)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.16))
                .frame(height: 92)

            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius)
                    .fill(Color.secondary.opacity(0.13))
                    .frame(height: 132)
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
