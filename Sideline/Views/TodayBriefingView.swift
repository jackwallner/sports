import Shared
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct TodayBriefingView: View {
    @State private var viewModel: TodayBriefingViewModel
    @State private var sourceURL: PresentedURL?
    @State private var showingPaywall = false
    @State private var pendingLockedPersona: Persona?

    @AppStorage("sideline.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("sideline.lastPersona") private var lastPersonaRaw = Persona.cocktailParty.rawValue
    @AppStorage("favoriteTeam") private var favoriteTeam = ""

    private let entitlement: any EntitlementProviding
    private let isDemo: Bool

    init(service: any BriefingServing, entitlement: any EntitlementProviding, isDemo: Bool = false) {
        self.entitlement = entitlement
        self.isDemo = isDemo
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
                                pendingLockedPersona = persona
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
                        SettingsView(
                            entitlement: entitlement,
                            onManualRefresh: { Task { await viewModel.refresh() } },
                            onTeamChanged: { Task { await viewModel.reloadAfterPreferenceChange() } }
                        )
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
                    if let persona = Persona(rawValue: lastPersonaRaw),
                       entitlement.canUse(persona: persona) {
                        viewModel.selectedPersona = persona
                    }
                    await viewModel.load()
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(entitlement: entitlement, context: viewModel.selectedPersona)
            }
            .sheet(item: $pendingLockedPersona) { persona in
                ProPreviewSheet(
                    persona: persona,
                    onSeePro: {
                        pendingLockedPersona = nil
                        showingPaywall = true
                    },
                    onDismiss: { pendingLockedPersona = nil }
                )
            }
            .modifier(OnboardingPresenter(
                isPresented: Binding(
                    get: { !hasCompletedOnboarding },
                    set: { newValue in hasCompletedOnboarding = !newValue }
                ),
                content: {
                    OnboardingView(
                        hasCompletedOnboarding: $hasCompletedOnboarding,
                        lastPersona: $lastPersonaRaw,
                        favoriteTeam: $favoriteTeam
                    )
                    .onDisappear {
                        if let persona = Persona(rawValue: lastPersonaRaw),
                           entitlement.canUse(persona: persona) {
                            viewModel.selectedPersona = persona
                        }
                        Task { await viewModel.load() }
                    }
                }
            ))
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
            if let briefing = viewModel.lastBriefing {
                briefingView(briefing, isOffline: false, suppressOfflineBanner: true)
                    .transition(.opacity)
            }
        }
    }

    private func briefingView(_ briefing: Briefing, isOffline: Bool, suppressOfflineBanner: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            if isDemo {
                demoBanner
            } else if isOffline && !suppressOfflineBanner {
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

            FreshnessFooter(briefing: briefing, isOffline: isOffline, isPro: entitlement.isPro)
                .padding(.top, 4)
        }
    }

    private func heroBlock(briefing: Briefing) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.selectedPersona.symbolName)
                    .font(.caption.weight(.bold))
                Text(viewModel.selectedPersona.contextHeader)
                    .font(.caption.weight(.heavy))
                    .tracking(1.2)
            }
            .foregroundStyle(SidelineTheme.brandPrimary)

            Text(briefing.tlDR)
                .font(.title2.weight(.bold))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .contextMenu {
                    Button {
                        copyToClipboard(briefing.tlDR)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }

            Text(briefing.headline)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
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

    private func emptyState(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "newspaper")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Can't reach today's briefing")
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
        Label("Offline — showing yesterday's update.", systemImage: "wifi.slash")
            .font(.callout)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var demoBanner: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("Preview briefing").font(.callout.weight(.semibold))
                Text("Not today's news — for demo only.").font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "eye")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SidelineTheme.brandAccent.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
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

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}

private struct PresentedURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct OnboardingPresenter<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> SheetContent

    func body(content base: Content) -> some View {
        #if os(iOS)
        base.fullScreenCover(isPresented: $isPresented, content: content)
        #else
        base.sheet(isPresented: $isPresented, content: content)
        #endif
    }
}
