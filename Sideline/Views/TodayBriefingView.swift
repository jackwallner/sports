import Shared
import StoreKit
import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif
#if canImport(UIKit)
import UIKit
#endif

struct TodayBriefingView: View {
    @State private var viewModel: TodayBriefingViewModel
    @State private var activeSheet: ActiveSheet?
    @State private var pendingPaywallContext: Persona?
    @State private var deckIndex = 0
    @StateObject private var reviewPromptCoordinator = ReviewPromptCoordinator.shared
    @State private var reviewPromptShownThisSession = false

    private enum ActiveSheet: Identifiable {
        case proPreview(Persona)
        case paywall(Persona)
        case onboardingPaywall
        case review(ReviewPromptSheet.Step)
        case source(URL)

        var id: String {
            switch self {
            case .proPreview(let persona): return "preview-\(persona.rawValue)"
            case .paywall(let persona): return "paywall-\(persona.rawValue)"
            case .onboardingPaywall: return "onboarding-paywall"
            case .review: return "review"
            case .source(let url): return "source-\(url.absoluteString)"
            }
        }
    }

    @Environment(\.requestReview) private var requestReview

    @AppStorage("sideline.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("sideline.hasSeenOnboardingPaywall") private var hasSeenOnboardingPaywall = false
    @AppStorage("sideline.lastPersona") private var lastPersonaRaw = Persona.cocktailParty.rawValue

    private let entitlement: any EntitlementProviding
    private let store: StoreService
    private let isDemo: Bool

    init(
        service: any BriefingServing,
        entitlement: any EntitlementProviding,
        store: StoreService = .shared,
        isDemo: Bool = false
    ) {
        self.entitlement = entitlement
        self.store = store
        self.isDemo = isDemo
        _viewModel = State(wrappedValue: TodayBriefingViewModel(service: service, entitlement: entitlement))
    }

    private var isPro: Bool {
        #if canImport(RevenueCat)
        if Purchases.isConfigured, entitlement is StoreService {
            return store.isPro
        }
        #endif
        return entitlement.isPro
    }

    var body: some View {
        NavigationStack {
            mainContent
                .background(Color.sidelineBackground)
                .navigationTitle("The Sideline")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    // Serif wordmark ties the chrome to the editorial cards.
                    ToolbarItem(placement: .principal) {
                        Text("The Sideline")
                            .font(.system(.headline, design: .serif).weight(.semibold))
                            .foregroundStyle(SidelineTheme.inkPrimary)
                            .accessibilityAddTraits(.isHeader)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            SettingsView(
                                entitlement: entitlement,
                                store: store,
                                onManualRefresh: { Task { await viewModel.refresh() } },
                                onTeamChanged: { Task { await viewModel.reloadAfterPreferenceChange() } }
                            )
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }
                }
                .task {
                    if case .idle = viewModel.state {
                        applyUsablePersonaFromStorage()
                        await viewModel.load()
                        #if DEBUG
                        if let start = Self.debugDeckStart() {
                            // Deck order: 0 = lead TL;DR, 1..n = stories, n+1 = "Your move".
                            deckIndex = min(start, (viewModel.lastBriefing?.bullets.count ?? 0) + 1)
                        }
                        #endif
                    }
                }
                .sheet(item: $activeSheet, onDismiss: handleSheetDismiss) { sheet in
                    switch sheet {
                    case .proPreview(let persona):
                        ProPreviewSheet(
                            persona: persona,
                            onSeePro: {
                                pendingPaywallContext = persona
                                activeSheet = nil
                            },
                            onDismiss: { activeSheet = nil }
                        )
                    case .paywall(let persona):
                        PaywallView(
                            entitlement: entitlement,
                            context: persona,
                            impressionId: "sideline_paywall_sheet"
                        )
                    case .onboardingPaywall:
                        PaywallView(
                            entitlement: entitlement,
                            impressionId: "sideline_onboarding_paywall"
                        )
                    case .review(let step):
                        ReviewPromptSheet(initialStep: step, onFinish: handleReviewPromptFinish)
                    case .source(let url):
                        #if canImport(SafariServices) && canImport(UIKit)
                        SafariView(url: url)
                        #else
                        EmptyView()
                        #endif
                    }
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
                            isPro: isPro
                        )
                    }
                ))
                // Post-onboarding work hangs off the persisted flag, not the
                // cover's onDisappear — SwiftUI doesn't reliably call
                // onDisappear on fullScreenCover content torn down by a state
                // change, which silently dropped the one-time Pro framing.
                .onChange(of: hasCompletedOnboarding) { _, completed in
                    guard completed else { return }
                    applyUsablePersonaFromStorage()
                    Task { await viewModel.load() }
                    presentOnboardingPaywallIfNeeded()
                }
                .onReceive(NotificationCenter.default.publisher(for: .sidelinePositiveMomentForReview)) { _ in
                    scheduleReviewPromptAfterPositiveMoment()
                }
                .onChange(of: reviewPromptCoordinator.pendingPresentation) { _, presentation in
                    guard let presentation else { return }
                    defer { reviewPromptCoordinator.clear() }
                    guard activeSheet == nil else { return }
                    switch presentation {
                    case .rateOrFeedback:
                        presentReviewPrompt(step: .choose)
                    case .feedbackOnly:
                        presentReviewPrompt(step: .feedback)
                    }
                }
        }
    }

    // MARK: - Layout

    private var mainContent: some View {
        VStack(spacing: 0) {
            PersonaRail(selected: viewModel.selectedPersona, isPro: isPro) { persona in
                Task {
                    let didSelect = await viewModel.select(persona)
                    if !didSelect {
                        activeSheet = .proPreview(persona)
                    }
                }
            }

            stateContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            skeletonCard
        case .populated(let briefing, let isOffline):
            deckArea(briefing, isOffline: isOffline)
                .transition(.opacity)
        case .failed(let message):
            emptyState(message: message)
        case .refreshLimit:
            refreshLimitArea
        }
    }

    private func deckArea(_ briefing: Briefing, isOffline: Bool, caughtUp: Bool = false) -> some View {
        VStack(spacing: 12) {
            if isDemo {
                demoBanner.padding(.horizontal, 18)
            } else if caughtUp {
                caughtUpBanner.padding(.horizontal, 18)
            } else if isOffline {
                offlineBanner.padding(.horizontal, 18)
            }

            BriefingDeck(briefing: briefing, index: $deckIndex) { url in
                activeSheet = .source(url)
            }

            FreshnessFooter(briefing: briefing, isOffline: isOffline, isPro: isPro)
                .padding(.horizontal, 26)
                .padding(.bottom, 6)
        }
        .padding(.top, 4)
        .onChange(of: briefing.id) { _, _ in
            deckIndex = 0
        }
    }

    @ViewBuilder
    private var refreshLimitArea: some View {
        if let briefing = viewModel.lastBriefing {
            deckArea(briefing, isOffline: false, caughtUp: true)
        } else {
            caughtUpEmptyState
        }
    }

    // MARK: - Persona restore

    /// Restore the last persona, but only if the user can still use it. A free
    /// user whose stored persona is a Pro room (e.g. picked during onboarding)
    /// self-corrects back to Cocktail Party instead of loading a locked room.
    private func applyUsablePersonaFromStorage() {
        if let persona = Persona(rawValue: lastPersonaRaw), entitlement.canUse(persona: persona) {
            viewModel.selectedPersona = persona
        } else if !entitlement.canUse(persona: viewModel.selectedPersona) {
            viewModel.selectedPersona = .cocktailParty
        }
    }

    // MARK: - Review prompt

    private func scheduleReviewPromptAfterPositiveMoment() {
        guard !isDemo,
              hasCompletedOnboarding,
              ReviewPromptTracker.shouldShowAfterPositiveMoment(hasCompletedSetup: hasCompletedOnboarding),
              !reviewPromptShownThisSession,
              activeSheet == nil
        else { return }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard activeSheet == nil,
                  ReviewPromptTracker.shouldShowAfterPositiveMoment(hasCompletedSetup: hasCompletedOnboarding)
            else { return }
            // Guideline 1.1.7: ask everyone who reaches the engagement
            // thresholds via Apple's native, rate-limited prompt. No sentiment
            // pre-screen that would hide the rating from dissatisfied users.
            reviewPromptShownThisSession = true
            ReviewPromptTracker.consumePendingPositiveMoment()
            ReviewPromptTracker.markShown()
            requestReview()
        }
    }

    private func presentOnboardingPaywallIfNeeded(attempt: Int = 0) {
        guard !hasSeenOnboardingPaywall, !isDemo, !isPro else { return }
        // Frame Pro/trial once before the free experience. Only burn the
        // one-time flag at the moment the sheet actually presents; if another
        // sheet is up, retry a few times rather than dropping it forever.
        // The wait must outlast the onboarding cover's dismissal animation or
        // the sheet presentation is silently swallowed.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !hasSeenOnboardingPaywall, !isPro else { return }
            guard activeSheet == nil else {
                if attempt < 3 { presentOnboardingPaywallIfNeeded(attempt: attempt + 1) }
                return
            }
            hasSeenOnboardingPaywall = true
            activeSheet = .onboardingPaywall
        }
    }

    private func handleSheetDismiss() {
        if let persona = pendingPaywallContext {
            pendingPaywallContext = nil
            activeSheet = .paywall(persona)
            return
        }
    }

    private func handleReviewPromptFinish(_ outcome: ReviewPromptDismissOutcome) {
        activeSheet = nil
    }

    #if DEBUG
    /// Screenshot helper: `-SidelineDeckStart N` opens the deck on card N
    /// (0 = lead TL;DR, 1..n = stories, n+1 = "Your move"). DEBUG only.
    private static func debugDeckStart() -> Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-SidelineDeckStart"), i + 1 < args.count else { return nil }
        return Int(args[i + 1])
    }
    #endif

    private func presentReviewPrompt(step: ReviewPromptSheet.Step) {
        reviewPromptShownThisSession = true
        activeSheet = .review(step)
    }

    // MARK: - States

    private func emptyState(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "newspaper")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(SidelineTheme.inkTertiary)
            Text("Can't reach today's briefing")
                .font(.title3.weight(.semibold))
                .foregroundStyle(SidelineTheme.inkPrimary)
            Text(message)
                .font(.callout)
                .foregroundStyle(SidelineTheme.inkSecondary)
                .multilineTextAlignment(.center)
            Button("Try again") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private var caughtUpEmptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(SidelineTheme.brandPrimary)
            Text("You're caught up")
                .font(.title3.weight(.semibold))
                .foregroundStyle(SidelineTheme.inkPrimary)
            Text("Today's free briefing is the latest. Pro refreshes 3 times a day.")
                .font(.callout)
                .foregroundStyle(SidelineTheme.inkSecondary)
                .multilineTextAlignment(.center)
            Button("See Pro") {
                activeSheet = .paywall(viewModel.selectedPersona)
            }
            .buttonStyle(.borderedProminent)
            .tint(SidelineTheme.brandPrimary)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    /// Mirrors the deck card's two-zone anatomy (art above, panel below) so
    /// loading resolves into the real card without a visual jump.
    private var skeletonCard: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: SidelineTheme.artPlaceholder,
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 14) {
                Capsule().fill(.white.opacity(0.22)).frame(width: 110, height: 12)
                Capsule().fill(.white.opacity(0.22)).frame(height: 22)
                Capsule().fill(.white.opacity(0.22)).frame(width: 220, height: 22)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: SidelineTheme.cardPanel, startPoint: .top, endPoint: .bottom)
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: SidelineTheme.deckCornerRadius, style: .continuous))
        .shadow(color: SidelineTheme.inkPrimary.opacity(0.16), radius: 22, x: 0, y: 12)
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 30)
        .redacted(reason: .placeholder)
        .accessibilityLabel("Loading briefing")
    }

    private var offlineBanner: some View {
        Label("Offline. Showing yesterday's update.", systemImage: "wifi.slash")
            .font(.footnote)
            .foregroundStyle(SidelineTheme.inkSecondary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SidelineTheme.tagFill(SidelineTheme.inkPrimary), in: RoundedRectangle(cornerRadius: 12))
    }

    private var caughtUpBanner: some View {
        HStack(spacing: 10) {
            Label("You're caught up. Pro refreshes 3 times a day.", systemImage: "checkmark.circle")
                .font(.footnote)
                .foregroundStyle(SidelineTheme.inkSecondary)
            Spacer(minLength: 8)
            Button("See Pro") {
                activeSheet = .paywall(viewModel.selectedPersona)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(SidelineTheme.brandPrimary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SidelineTheme.brandAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var demoBanner: some View {
        Label {
            Text("Preview briefing. Not today's news.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(SidelineTheme.inkSecondary)
        } icon: {
            Image(systemName: "eye")
                .foregroundStyle(SidelineTheme.amberText)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SidelineTheme.brandAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
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
