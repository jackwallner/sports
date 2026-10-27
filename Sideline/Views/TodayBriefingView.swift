import Foundation
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
    @State private var reviewPromptShownThisSession = false
    /// The briefing whose last story card was reached, so finishing one deck
    /// counts as one positive moment however often the user swipes past it.
    @State private var finishedBriefingID: UUID?
    /// A source opened from the deck; its dismissal retries a blocked ask.
    @State private var isShowingSource = false
    /// The container's width and fold, measured so the unfolded iPhone Duo can
    /// put the deck and the rundown on opposite sides of the fold.
    @State private var paneGeometry = PaneGeometry(width: 0, fold: nil)
    /// The card a room link asked for, applied once that room's briefing lands.
    @State private var pendingDeckCard: Int?
    @State private var isShowingSettings = false

    private enum ActiveSheet: Identifiable {
        case proPreview(Persona)
        case paywall(Persona, String)
        case source(URL)

        var id: String {
            switch self {
            case .proPreview(let persona): return "preview-\(persona.rawValue)"
            case .paywall(let persona, let impressionId): return "paywall-\(persona.rawValue)-\(impressionId)"
            case .source(let url): return "source-\(url.absoluteString)"
            }
        }
    }

    @Environment(\.requestReview) private var requestReview
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @AppStorage("sideline.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("sideline.lastPersona") private var lastPersonaRaw = Persona.cocktailParty.rawValue

    private let entitlement: any EntitlementProviding
    private let store: StoreService
    private let isDemo: Bool

    private var showsDemoBanner: Bool {
        #if DEBUG
        return isDemo && !ProcessInfo.processInfo.arguments.contains("-SidelineSafeScreenshot")
        #else
        return isDemo
        #endif
    }

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

    /// Unused free trial still available for this Apple ID. Upsell copy leads
    /// with "try free" while this is true; "unlock"/"see Pro" once it's spent.
    private var trialAvailable: Bool {
        #if canImport(RevenueCat)
        if Purchases.isConfigured {
            return store.trialAvailable
        }
        #endif
        return false
    }

    var body: some View {
        // Root swap — not fullScreenCover. Cover animates up over the briefing
        // on cold launch and reads as a glitch (app visible behind onboarding).
        Group {
            if !hasCompletedOnboarding {
                OnboardingView(
                    hasCompletedOnboarding: $hasCompletedOnboarding,
                    lastPersona: $lastPersonaRaw,
                    isPro: isPro
                )
            } else {
                briefingRoot
            }
        }
        .onChange(of: hasCompletedOnboarding) { _, completed in
            guard completed else { return }
            applyUsablePersonaFromStorage()
            Task { await viewModel.load() }
        }
    }

    /// Unfolded, the rundown gets its own pane beside the deck.
    private var split: UnfoldedSplit? {
        UnfoldedSplit.make(
            width: paneGeometry.width,
            isRegularWidth: horizontalSizeClass == .regular,
            fold: paneGeometry.fold
        )
    }

    /// The briefing the deck is showing, which the rundown lists.
    private var shownBriefing: Briefing? {
        switch viewModel.state {
        case .populated(let briefing, _): return briefing
        case .refreshLimit: return viewModel.lastBriefing
        case .idle, .loading, .failed: return nil
        }
    }

    private var briefingRoot: some View {
        // Opening or closing the Duo only moves these frames, so neither pane
        // is rebuilt and the deck keeps its card, flip and navigation.
        ZStack(alignment: .topLeading) {
            briefingStack
                .environment(\.horizontalSizeClass, split == nil ? horizontalSizeClass : .compact)
                .horizontalToolbarInPane(split != nil)
                .frame(maxWidth: split?.primaryWidth ?? .infinity, maxHeight: .infinity)
            rundownPane
                .environment(\.horizontalSizeClass, .compact)
                .frame(maxWidth: split?.secondaryWidth ?? .infinity, maxHeight: .infinity)
                .padding(.leading, split?.secondaryX ?? 0)
                .opacity(split == nil ? 0 : 1)
                .allowsHitTesting(split != nil)
                .accessibilityHidden(split == nil)
        }
        // Fill the proposal first: unfolded, the background otherwise stopped
        // at the safe area and left the inner display's side insets white.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sidelineBackground.ignoresSafeArea())
        .onGeometryChange(for: PaneGeometry.self) { proxy in
            PaneGeometry(width: proxy.size.width, fold: proxy.verticalFold())
        } action: { paneGeometry = $0 }
        .onOpenURL(perform: handleRoute)
    }

    @ViewBuilder
    private var rundownPane: some View {
        if let briefing = shownBriefing {
            BriefingRundown(briefing: briefing, index: $deckIndex) { url in
                isShowingSource = true
                activeSheet = .source(url)
            }
        } else {
            Color.clear
        }
    }

    private var briefingStack: some View {
        NavigationStack {
            mainContent
                .background(Color.sidelineBackground)
                .navigationTitle(SidelineBrand.name)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    // Serif wordmark ties the chrome to the editorial cards.
                    ToolbarItem(placement: .principal) {
                        Text(SidelineBrand.name)
                            .font(.system(.headline, design: .serif).weight(.semibold))
                            .foregroundStyle(SidelineTheme.inkPrimary)
                            .accessibilityAddTraits(.isHeader)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Settings", systemImage: "gearshape") {
                            isShowingSettings = true
                        }
                        .labelStyle(.iconOnly)
                    }
                }
                .navigationDestination(isPresented: $isShowingSettings) {
                    SettingsView(
                        entitlement: entitlement,
                        store: store,
                        onManualRefresh: { Task { await viewModel.refresh() } }
                    )
                }
                .task {
                    if case .idle = viewModel.state {
                        applyUsablePersonaFromStorage()
                        await viewModel.load()
                        #if DEBUG
                        if let start = Self.debugDeckStart() ?? DuoScreen.current?.deckCard {
                            // Deck order: 0 = lead TL;DR, 1..n = stories, n+1 = "Your move".
                            deckIndex = min(start, (viewModel.lastBriefing?.bullets.count ?? 0) + 1)
                        }
                        if DuoScreen.current == .settings {
                            isShowingSettings = true
                        }
                        #endif
                    }
                }
                .sheet(item: $activeSheet, onDismiss: handleSheetDismiss) { sheet in
                    switch sheet {
                    case .proPreview(let persona):
                        ProPreviewSheet(
                            persona: persona,
                            trialAvailable: trialAvailable,
                            onSeePro: {
                                pendingPaywallContext = persona
                                activeSheet = nil
                            },
                            onDismiss: { activeSheet = nil }
                        )
                    case .paywall(let persona, let impressionId):
                        PaywallView(
                            entitlement: entitlement,
                            context: persona,
                            impressionId: impressionId
                        )
                    case .source(let url):
                        #if canImport(SafariServices) && canImport(UIKit)
                        SafariView(url: url)
                        #else
                        EmptyView()
                        #endif
                    }
                }
                // Entitlements load async: on a cold launch a Pro user's stored
                // room fails canUse before customerInfo arrives and selection
                // self-corrects to Cocktail Party. When Pro confirms, put them
                // back in the room they actually left off in.
                .onChange(of: isPro) { wasPro, nowPro in
                    guard !wasPro, nowPro else { return }
                    guard let stored = Persona(rawValue: lastPersonaRaw),
                          stored != viewModel.selectedPersona,
                          entitlement.canUse(persona: stored)
                    else { return }
                    viewModel.selectedPersona = stored
                    Task { await viewModel.load() }
                }
                .onReceive(NotificationCenter.default.publisher(for: .sidelinePositiveMomentForReview)) { _ in
                    scheduleReviewRequestAfterPositiveMoment()
                }
                .onChange(of: deckIndex) { _, _ in
                    recordFinishedBriefingIfNeeded()
                }
        }
    }

    // MARK: - Layout

    private var mainContent: some View {
        // At accessibility sizes the rail alone fills most of the screen, so
        // the deck keeps a card-sized box and the page scrolls around it.
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    VStack(spacing: 0) {
                        rail
                        stateContent.frame(height: 720)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    rail
                    stateContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private var rail: some View {
        PersonaRail(selected: viewModel.selectedPersona, isPro: isPro) { persona in
            Task {
                let didSelect = await viewModel.select(persona)
                if !didSelect {
                    activeSheet = .proPreview(persona)
                }
            }
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
            if showsDemoBanner {
                demoBanner.padding(.horizontal, 18)
            } else if caughtUp {
                caughtUpBanner.padding(.horizontal, 18)
            } else if isOffline {
                offlineBanner.padding(.horizontal, 18)
            }

            BriefingDeck(
                briefing: briefing,
                index: $deckIndex,
                isPro: isPro,
                trialAvailable: trialAvailable,
                onOpenSource: { url in
                    isShowingSource = true
                    activeSheet = .source(url)
                },
                onExploreRooms: {
                    activeSheet = .paywall(viewModel.selectedPersona, "sideline_free_deck_rooms_paywall")
                }
            )

            FreshnessFooter(briefing: briefing, isOffline: isOffline, isPro: isPro)
                .padding(.horizontal, 26)
                .padding(.bottom, 6)
        }
        .padding(.top, 4)
        // A room switch passes through loading, which rebuilds this view, so
        // a linked card is picked up on appear as well as on a change.
        .onAppear { applyPendingDeckCard(briefing) }
        .onChange(of: briefing.id) { _, _ in
            deckIndex = 0
            applyPendingDeckCard(briefing)
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

    // MARK: - Routes

    /// `sideline://room/<room>` switches rooms the way a rail tap does (a
    /// locked room opens its preview), and `?card=N` opens the deck on card N:
    /// 0 is the brief, 1...n the stories, n+1 the question.
    private func handleRoute(_ url: URL) {
        guard url.scheme == "sideline", url.host == "room",
              let persona = Persona(rawValue: url.lastPathComponent)
        else { return }
        let card = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "card" }?.value.flatMap(Int.init)
        activeSheet = nil
        Task {
            let previous = shownBriefing?.id
            pendingDeckCard = card
            guard await viewModel.select(persona) else {
                pendingDeckCard = nil
                activeSheet = .proPreview(persona)
                return
            }
            // Same briefing back and the deck never left: nothing else will
            // pick the card up.
            if let briefing = shownBriefing, briefing.id == previous {
                applyPendingDeckCard(briefing)
            }
        }
    }

    private func applyPendingDeckCard(_ briefing: Briefing) {
        guard let card = pendingDeckCard else { return }
        pendingDeckCard = nil
        deckIndex = min(max(card, 0), briefing.bullets.count + 1)
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

    /// Reaching the deck's "Your move" card means the briefing was read
    /// through: the core action done.
    private func recordFinishedBriefingIfNeeded() {
        guard !isDemo, let briefing = viewModel.lastBriefing,
              deckIndex == briefing.bullets.count + 1,
              finishedBriefingID != briefing.id
        else { return }
        finishedBriefingID = briefing.id
        ReviewPromptTracker.recordPositiveMoment()
    }

    /// The briefing is on screen with no sheet over it, and the deck is not
    /// on the free rooms pitch card.
    private var isBriefingClear: Bool {
        guard activeSheet == nil else { return false }
        guard case .populated(let briefing, _) = viewModel.state else { return false }
        return deckIndex <= briefing.bullets.count + 1
    }

    /// The rating ask after a positive moment: Apple's own prompt, no question
    /// in front of it. Waits for the moment to settle, then asks only if the
    /// briefing is still clear. A blocked ask keeps the moment pending in the
    /// tracker; a source sheet's dismissal or the next moment asks.
    private func scheduleReviewRequestAfterPositiveMoment() {
        guard !isDemo,
              hasCompletedOnboarding,
              ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: hasCompletedOnboarding),
              !reviewPromptShownThisSession,
              isBriefingClear
        else { return }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard isBriefingClear,
                  !reviewPromptShownThisSession,
                  ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: hasCompletedOnboarding)
            else { return }
            reviewPromptShownThisSession = true
            ReviewPromptTracker.markShown()
            requestReview()
        }
    }

    private func handleSheetDismiss() {
        if let persona = pendingPaywallContext {
            pendingPaywallContext = nil
            activeSheet = .paywall(persona, "sideline_locked_room_paywall_\(persona.rawValue)")
            return
        }
        // Only a source sheet retries a blocked ask. A paywall or Pro preview
        // dismissal never leads into a rating request.
        if isShowingSource {
            isShowingSource = false
            scheduleReviewRequestAfterPositiveMoment()
        }
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
            Button(trialAvailable ? "Try Pro Free" : "See Pro") {
                activeSheet = .paywall(viewModel.selectedPersona, "sideline_refresh_limit_paywall")
            }
            .buttonStyle(.borderedProminent)
            .tint(SidelineTheme.brandFill)
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
        Label("Offline. Showing your last saved briefing.", systemImage: "wifi.slash")
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
            Button(trialAvailable ? "Try Pro Free" : "See Pro") {
                activeSheet = .paywall(viewModel.selectedPersona, "sideline_refresh_limit_paywall")
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
