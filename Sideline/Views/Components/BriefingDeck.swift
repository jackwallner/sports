import Shared
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The briefing as a Tinder-style deck: one self-contained story per card, then
/// a single "Your move" question to keep the conversation going.
///
/// You fling the top card off in either direction and the next card — already
/// peeking and rising live behind it — takes its place. The deck is a loop:
/// the discarded card drops to the back, so on a 4-card deck you just keep
/// swiping and everything comes back around. No dead ends, no buttons.
///
/// Each card leads with generated art and ONE line to say. Everything else —
/// the gossipy tie-in, why it earned its tag, the source — lives on the back
/// of the card, a tap-to-flip away. Front = say this; back = in case they
/// ask. No wall of text on either face.
struct BriefingDeck: View {
    let briefing: Briefing
    @Binding var index: Int
    let onOpenSource: (URL) -> Void

    @State private var drag: CGSize = .zero
    @State private var isFlinging = false
    @State private var crossedThreshold = false
    @State private var didHint = false
    /// Which deck position is showing its back. Only the front card can flip,
    /// and any swipe puts it face-up again.
    @State private var flippedPosition: Int?

    /// Flips true the first time the user actually swipes, ever. Gates the
    /// one-time "here's how this works" nudge.
    @AppStorage("sideline.hasSwipedDeck") private var hasSwipedDeck = false

    @ScaledMetric(relativeTo: .footnote) private var dotSize: CGFloat = 7
    @ScaledMetric(relativeTo: .footnote) private var activeDotWidth: CGFloat = 22

    private var cards: [DeckCard] {
        [.lead(briefing)]
            + briefing.bullets.map(DeckCard.point)
            + [.question(briefing.suggestedQuestion)]
    }

    /// How many cards are mounted in the peek stack at once (front + up to two
    /// behind). Capped to the deck size so a tiny deck doesn't render dupes.
    private var slotCount: Int { min(3, cards.count) }

    var body: some View {
        let cards = self.cards
        let count = cards.count
        VStack(spacing: 14) {
            GeometryReader { geo in
                let size = geo.size
                ZStack {
                    ForEach(visiblePositions(count: count), id: \.self) { position in
                        let slot = (position - index + count) % count
                        DeckCardView(
                            card: cards[position],
                            isFlipped: flippedPosition == position,
                            onOpenSource: onOpenSource
                        )
                            .scaleEffect(scale(forSlot: slot))
                            .offset(y: yOffset(forSlot: slot))
                            .offset(slot == 0 ? drag : .zero)
                            .rotationEffect(slot == 0 ? topRotation : .zero, anchor: .bottom)
                            .zIndex(Double(count - slot))
                            .allowsHitTesting(slot == 0)
                            .gesture(dragGesture(size: size, count: count))
                            .onTapGesture { flip(position: position, card: cards[position]) }
                            .accessibilityActions {
                                if cards[position].hasBack {
                                    Button(flippedPosition == position ? "Show the talking point" : "Show the backstory") {
                                        flip(position: position, card: cards[position])
                                    }
                                }
                            }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 18)
                .padding(.top, 4)
                // Room below the front card for the stacked edges to peek.
                .padding(.bottom, 30)
                .accessibilityElement(children: .contain)
                .accessibilityValue("Card \(index + 1) of \(count)")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: index = (index + 1) % count
                    case .decrement: index = (index - 1 + count) % count
                    default: break
                    }
                }
                .onAppear {
                    maybeHintSwipe()
                    prefetchArt()
                }
            }

            pageDots(count: count)
        }
        .onChange(of: index) { _, _ in
            flippedPosition = nil
        }
    }

    // MARK: - Flip

    private func flip(position: Int, card: DeckCard) {
        guard card.hasBack, !isFlinging else { return }
        impact(.soft, intensity: 0.5)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            flippedPosition = flippedPosition == position ? nil : position
        }
    }

    private func prefetchArt() {
        #if canImport(UIKit)
        var urls = [CardArt.leadImageURL(for: briefing)]
        urls += briefing.bullets.map(CardArt.imageURL(for:))
        CardArtStore.prefetch(urls.compactMap { $0 })
        #endif
    }

    // MARK: - Stack geometry

    /// Drag travel (points) that counts as a full swipe. Past this the card
    /// flings; the behind cards are fully risen by the time you get here.
    private func dismissDistance(_ size: CGSize) -> CGFloat {
        max(90, size.width * 0.30)
    }

    /// 0 at rest, 1 when the top card has been dragged a full swipe. Drives the
    /// behind cards rising as you pull the front one away.
    private var progress: CGFloat {
        min(1, abs(drag.width) / 110)
    }

    private func restingScale(_ slot: Int) -> CGFloat { 1 - CGFloat(slot) * 0.04 }
    private func restingY(_ slot: Int) -> CGFloat { CGFloat(slot) * 26 }

    /// A behind card interpolates toward the slot in front of it as the top
    /// card leaves, so the next card grows into place instead of snapping.
    private func scale(forSlot slot: Int) -> CGFloat {
        guard slot > 0 else { return 1 }
        return restingScale(slot) + (restingScale(slot - 1) - restingScale(slot)) * progress
    }

    private func yOffset(forSlot slot: Int) -> CGFloat {
        guard slot > 0 else { return 0 }
        return restingY(slot) + (restingY(slot - 1) - restingY(slot)) * progress
    }

    private var topRotation: Angle {
        .degrees(Double(max(-12, min(12, drag.width / 14))))
    }

    private func visiblePositions(count: Int) -> [Int] {
        (0..<min(slotCount, count)).map { (index + $0) % count }
    }

    // MARK: - Swipe

    private func dragGesture(size: CGSize, count: Int) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !isFlinging else { return }
                drag = value.translation
                // Light tick the moment the card crosses into "let go and it
                // flies" territory, so the threshold is felt, not guessed.
                let past = abs(value.translation.width) > dismissDistance(size)
                if past != crossedThreshold {
                    crossedThreshold = past
                    if past { impact(.soft, intensity: 0.6) }
                }
            }
            .onEnded { value in
                guard !isFlinging else { return }
                crossedThreshold = false
                let dx = value.translation.width
                let flung = abs(dx) > dismissDistance(size)
                    || abs(value.predictedEndTranslation.width) > size.width * 0.75
                if flung {
                    fling(direction: dx >= 0 ? 1 : -1, size: size, count: count)
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        drag = .zero
                    }
                }
            }
    }

    /// Throw the top card off-screen, then drop it to the back of the loop. The
    /// behind cards finish rising during the throw, so when we swap `index` (with
    /// animation suppressed) nothing jumps — the risen card is already in place.
    private func fling(direction: CGFloat, size: CGSize, count: Int) {
        isFlinging = true
        hasSwipedDeck = true
        impact(.rigid, intensity: 0.7)
        let exit = CGSize(
            width: direction * size.width * 1.5,
            height: drag.height * 1.1
        )
        withAnimation(.easeIn(duration: 0.26)) {
            drag = exit
        } completion: {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                index = (index + 1) % count
                drag = .zero
                isFlinging = false
                flippedPosition = nil
            }
        }
    }

    /// One-time teaching beat: on the very first deck the top card eases over
    /// and springs back, which both shows the gesture and previews the card
    /// rising behind it. Never fires again once the user has actually swiped.
    private func maybeHintSwipe() {
        guard !hasSwipedDeck, !didHint, cards.count > 1 else { return }
        didHint = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 750_000_000)
            guard !hasSwipedDeck, !isFlinging, drag == .zero else { return }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.6)) {
                drag = CGSize(width: 52, height: 0)
            }
            try? await Task.sleep(nanoseconds: 430_000_000)
            guard !isFlinging else { return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                drag = .zero
            }
        }
    }

    private func impact(_ style: ImpactStyle, intensity: CGFloat) {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: style.uiStyle)
        generator.impactOccurred(intensity: intensity)
        #endif
    }

    // MARK: - Page dots

    private func pageDots(count: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? SidelineTheme.brandPrimary : SidelineTheme.rule)
                    .frame(width: i == index ? activeDotWidth : dotSize, height: dotSize)
                    .animation(.snappy(duration: 0.22), value: index)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

enum DeckCard {
    case lead(Briefing)
    case point(BriefingBullet)
    case question(String)

    /// Story cards carry their detail on the back. Lead and question cards are
    /// single-faced; tapping them does nothing.
    var hasBack: Bool {
        if case .point = self { return true }
        return false
    }
}

/// Thin wrapper so the deck can ask for haptics without leaking UIKit types
/// into call sites (and so it no-ops cleanly on non-UIKit platforms).
private enum ImpactStyle {
    case soft, rigid
    #if canImport(UIKit)
    var uiStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .soft:  return .soft
        case .rigid: return .rigid
        }
    }
    #endif
}

private struct DeckCardView: View {
    let card: DeckCard
    let isFlipped: Bool
    let onOpenSource: (URL) -> Void

    var body: some View {
        ZStack {
            front
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 0 : 1)
                .allowsHitTesting(!isFlipped)
                .accessibilityHidden(isFlipped)
            if case .point(let bullet) = card {
                back(bullet)
                    .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                    .opacity(isFlipped ? 1 : 0)
                    // The hidden face must never steal touches — its source
                    // button sits right where flip taps land.
                    .allowsHitTesting(isFlipped)
                    .accessibilityHidden(!isFlipped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sidelineDeckCard)
        .clipShape(RoundedRectangle(cornerRadius: SidelineTheme.deckCornerRadius, style: .continuous))
        .shadow(color: SidelineTheme.inkPrimary.opacity(0.16), radius: 22, x: 0, y: 12)
        .accessibilityElement(children: .contain)
    }

    // MARK: Front — art on top, words on one solid panel below
    //
    // Two zones give the eye one place to read: the art stays clean (pills
    // only), and every word sits on the same deep green panel at the bottom.
    // No text-over-art, no per-card scrim tuning, no competing gradients.

    @ViewBuilder
    private var front: some View {
        switch card {
        case .lead(let briefing):
            VStack(spacing: 0) {
                artZone(imageURL: CardArt.leadImageURL(for: briefing)) { EmptyView() }
                panel {
                    eyebrow(icon: "quote.opening", text: "Lead with this")
                    line(briefing.tlDR, size: 25, limit: 7)
                        .copyable(briefing.tlDR)
                    hint(icon: "hand.draw.fill", text: "Say this first. Swipe for the stories behind it.")
                }
            }
        case .point(let bullet):
            VStack(spacing: 0) {
                artZone(imageURL: CardArt.imageURL(for: bullet)) {
                    HStack(alignment: .top, spacing: 8) {
                        if let tag = bullet.tag, tag != .neutral {
                            tagPill(tag)
                        }
                        Spacer(minLength: 0)
                        sportChip(for: bullet)
                    }
                }
                panel {
                    eyebrow(icon: nil, text: kicker(for: bullet))
                    line(bullet.talkingPoint, size: 23, limit: 5)
                        .copyable(bullet.talkingPoint)
                    hint(icon: "hand.tap.fill", text: "Tap for the backstory")
                }
            }
        case .question(let question):
            // No art: the gold full-stop card. Same anatomy, one accent.
            ZStack {
                LinearGradient(
                    colors: SidelineTheme.cardPanelGold,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(alignment: .leading, spacing: 12) {
                    eyebrow(icon: "arrow.turn.down.right", text: "Your move", color: .white.opacity(0.92))
                    line(question, size: 25, limit: 6)
                        .copyable(question)
                    hint(icon: "person.2.fill", text: "Ask a fan to keep it going.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(22)
            }
        }
    }

    // MARK: Card anatomy

    /// The art zone: placeholder gradient floor, generated art on top, a light
    /// scrim up top for the pills, and a fade into the panel color below so
    /// the art settles into the words instead of butting against them.
    private func artZone<Chips: View>(imageURL: URL?, @ViewBuilder chips: () -> Chips) -> some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: SidelineTheme.artPlaceholder,
                startPoint: .top,
                endPoint: .bottom
            )

            CardArtImage(url: imageURL)

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.28), location: 0),
                    .init(color: .clear, location: 0.30),
                    .init(color: SidelineTheme.cardPanel[0].opacity(0), location: 0.62),
                    .init(color: SidelineTheme.cardPanel[0], location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            chips()
                .frame(maxWidth: .infinity)
                .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    /// The solid panel every card's words sit on.
    private func panel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(
                LinearGradient(colors: SidelineTheme.cardPanel, startPoint: .top, endPoint: .bottom)
            )
    }

    private func eyebrow(icon: String?, text: String, color: Color = SidelineTheme.goldOnDark) -> some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
            }
            Text(text.uppercased())
                .font(SidelineTheme.eyebrow)
                .tracking(1.4)
                .lineLimit(1)
        }
        .foregroundStyle(color)
    }

    /// The one line to say — white serif on the solid panel, no shadows needed.
    private func line(_ text: String, size: CGFloat, limit: Int) -> some View {
        Text(text)
            .font(SidelineTheme.display(size))
            .foregroundStyle(.white)
            .lineSpacing(2)
            .lineLimit(limit)
            .minimumScaleFactor(0.7)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Quiet, uniform affordance row at the foot of every card.
    private func hint(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(text)
                .font(.footnote.weight(.medium))
        }
        .foregroundStyle(.white.opacity(0.65))
        .padding(.top, 2)
        .accessibilityHidden(true)
    }

    /// Story kicker: the subject when we have one, the sport otherwise.
    private func kicker(for bullet: BriefingBullet) -> String {
        if let subject = bullet.subject, !subject.isEmpty { return subject }
        let name = CardArt.sport(for: bullet).name
        return name.isEmpty ? "Worth mentioning" : name
    }

    // MARK: Back — the backstory, in case they ask

    private func back(_ bullet: BriefingBullet) -> some View {
        ZStack {
            // The same panel green as every front, so the back reads as the
            // card's reverse side, not a different card.
            LinearGradient(
                colors: SidelineTheme.cardPanel,
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 16) {
                eyebrow(icon: "text.bubble.fill", text: "The backstory")

                if let tieIn = bullet.tieIn, !tieIn.isEmpty {
                    Text(tieIn)
                        .font(SidelineTheme.display(20))
                        .foregroundStyle(.white)
                        .lineSpacing(2)
                        .lineLimit(6)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                        .copyable(tieIn)
                }

                if let reason = bullet.tagReason, !reason.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: (bullet.tag ?? .neutral).symbolName)
                            .font(.footnote.weight(.bold))
                            .padding(.top, 2)
                        Text(reason)
                            .font(.callout)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(.white.opacity(0.88))
                }

                Spacer(minLength: 12)

                learnMore(bullet)

                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.caption2)
                    Text("Tap to flip back")
                        .font(.footnote.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white.opacity(0.7))
                .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(22)
        }
    }

    private func learnMore(_ bullet: BriefingBullet) -> some View {
        Button {
            onOpenSource(bullet.sourceURL)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.caption2.weight(.bold))
                Text(bullet.sourceHeadline)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.18), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Learn more. Source: \(bullet.sourceHeadline)")
        .accessibilityHint("Opens the original story")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Art-zone pills

    /// A real, legible chip that names the sport. Falls back to a tag-flavored,
    /// icon-only chip when we can't tell.
    private func sportChip(for bullet: BriefingBullet) -> some View {
        let sport = CardArt.sport(for: bullet)
        return HStack(spacing: 5) {
            Image(systemName: sport.symbol)
                .font(.caption2.weight(.bold))
            if !sport.name.isEmpty {
                Text(sport.name)
                    .font(.system(.caption2, design: .rounded).weight(.heavy))
                    .tracking(0.6)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .foregroundStyle(.white)
        .background(.white.opacity(0.20), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.30), lineWidth: 1))
        .accessibilityHidden(true)
    }

    /// Solid color-coded tag pill — the tag color now lives here, in one small
    /// dose, instead of repainting the whole card.
    private func tagPill(_ tag: BriefingTag) -> some View {
        HStack(spacing: 4) {
            Image(systemName: tag.symbolName)
                .font(.caption2.weight(.bold))
            Text(tag.displayName.uppercased())
                .font(.system(.caption2, design: .rounded).weight(.heavy))
                .tracking(0.6)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .foregroundStyle(.white)
        .background(tagPillColor(tag).opacity(0.92), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
    }

    private func tagPillColor(_ tag: BriefingTag) -> Color {
        switch tag {
        case .niceGuy, .redemption: return SidelineTheme.tagPillNice
        case .jerk, .drama:         return SidelineTheme.tagPillDrama
        default:                    return SidelineTheme.cardPanel[1]
        }
    }
}

// MARK: - Copy affordance

private extension View {
    /// Long-press to copy the card's line. Kept tiny so a card stays one idea.
    @ViewBuilder
    func copyable(_ text: String) -> some View {
        self.contextMenu {
            Button {
                #if canImport(UIKit)
                UIPasteboard.general.string = text
                #endif
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
    }
}
