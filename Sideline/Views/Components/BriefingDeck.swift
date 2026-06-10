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
                            parallax: slot == 0 ? drag.width / 60 : 0,
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
    /// Tiny horizontal drift of the gradient sheen, tied to the live drag, so
    /// the top card feels like it has depth as you push it.
    let parallax: CGFloat
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
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(SidelineTheme.rule, lineWidth: 1)
        )
        .shadow(color: SidelineTheme.inkPrimary.opacity(0.16), radius: 22, x: 0, y: 12)
        .accessibilityElement(children: .contain)
    }

    // MARK: Front — full-bleed art carrying the one line to say

    @ViewBuilder
    private var front: some View {
        switch card {
        case .lead(let briefing):
            artBand(colors: SidelineTheme.heroNavy, imageURL: CardArt.leadImageURL(for: briefing)) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 6) {
                        Image(systemName: "quote.opening")
                            .font(.caption2.weight(.bold))
                        Text("LEAD WITH THIS")
                            .font(SidelineTheme.eyebrow)
                            .tracking(1.4)
                    }
                    .foregroundStyle(.white.opacity(0.95))

                    Text(briefing.tlDR)
                        .font(SidelineTheme.display(25))
                        .foregroundStyle(.white)
                        .lineSpacing(2)
                        .lineLimit(7)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 3)
                        .copyable(briefing.tlDR)

                    HStack(spacing: 6) {
                        Image(systemName: "hand.draw.fill")
                            .font(.caption2)
                        Text("Say this first. Swipe for the stories behind it.")
                            .font(.footnote.weight(.medium))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                }
            }
        case .point(let bullet):
            artBand(
                colors: heroColors(for: bullet.tag),
                imageURL: CardArt.imageURL(for: bullet)
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 8) {
                        if let tag = bullet.tag, tag != .neutral {
                            lightTagPill(tag)
                        }
                        Spacer(minLength: 0)
                        sportChip(for: bullet)
                    }

                    Spacer(minLength: 16)

                    if let subject = bullet.subject, !subject.isEmpty {
                        Text(subject.uppercased())
                            .font(.caption.weight(.heavy))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 1)
                    }

                    // The line to say — the only words the front carries.
                    Text(bullet.talkingPoint)
                        .font(SidelineTheme.display(23))
                        .foregroundStyle(.white)
                        .lineSpacing(2)
                        .lineLimit(5)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 3)
                        .padding(.top, 6)
                        .copyable(bullet.talkingPoint)

                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .font(.caption2)
                        Text("Tap for the backstory")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.16), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
                    .padding(.top, 14)
                    .accessibilityHidden(true)
                }
            }
        case .question(let question):
            artBand(colors: SidelineTheme.heroGold, imageURL: nil) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.caption2.weight(.bold))
                        Text("YOUR MOVE")
                            .font(SidelineTheme.eyebrow)
                            .tracking(1.4)
                    }
                    .foregroundStyle(.white.opacity(0.95))

                    Text(question)
                        .font(SidelineTheme.display(25))
                        .foregroundStyle(.white)
                        .lineSpacing(2)
                        .lineLimit(6)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 3)
                        .copyable(question)

                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text("Ask a fan to keep it going.")
                            .font(.footnote.weight(.medium))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                }
            }
        }
    }

    // MARK: Back — the backstory, in case they ask

    private func back(_ bullet: BriefingBullet) -> some View {
        ZStack {
            LinearGradient(
                colors: heroColors(for: bullet.tag),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Darken the same gradient so the back reads as the card's reverse
            // side, not a different card.
            Color.black.opacity(0.30)

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble.fill")
                        .font(.caption2.weight(.bold))
                    Text("THE BACKSTORY")
                        .font(SidelineTheme.eyebrow)
                        .tracking(1.4)
                }
                .foregroundStyle(.white.opacity(0.95))

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

    /// The card's visual floor: tag-keyed gradient immediately, generated art
    /// fading in on top once it lands, then a scrim so white type always reads
    /// no matter what the art came back as.
    private func artBand<Overlay: View>(
        colors: [Color],
        imageURL: URL?,
        alignment: Alignment = .bottomLeading,
        @ViewBuilder overlay: () -> Overlay
    ) -> some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)

            CardArtImage(url: imageURL)

            // Legibility scrim: stronger at the bottom where the line sits.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.30), location: 0),
                    .init(color: .black.opacity(0.05), location: 0.35),
                    .init(color: .black.opacity(0.62), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // Soft sheen for depth — ambient, not a "graphic." Drifts with the swipe.
            RadialGradient(
                colors: [.white.opacity(0.18), .clear],
                center: .init(x: 0.82 + parallax * 0.02, y: 0.12),
                startRadius: 0,
                endRadius: 240
            )
            .blendMode(.softLight)
            .allowsHitTesting(false)

            overlay()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: Art helpers

    /// Tag-keyed gradient. Drama runs hot, good news runs green, the rest stays
    /// on brand navy.
    private func heroColors(for tag: BriefingTag?) -> [Color] {
        switch tag {
        case .niceGuy, .redemption: return SidelineTheme.heroGreen
        case .jerk, .drama:         return SidelineTheme.heroRed
        default:                    return SidelineTheme.heroNavy
        }
    }

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

    /// White-on-glass tag pill that reads on the dark gradient.
    private func lightTagPill(_ tag: BriefingTag) -> some View {
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
        .background(.white.opacity(0.22), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
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
