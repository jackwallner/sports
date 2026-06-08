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
/// Each card is a full-bleed, tag-keyed gradient that leads with the line to
/// say (white, editorial), a sport chip that actually tells you the sport, and
/// a clean footer with one beat of backup and the source. No wall of text, no
/// decorative graphic that does nothing.
struct BriefingDeck: View {
    let briefing: Briefing
    @Binding var index: Int
    let onOpenSource: (URL) -> Void

    @State private var drag: CGSize = .zero
    @State private var isFlinging = false

    @ScaledMetric(relativeTo: .footnote) private var dotSize: CGFloat = 7
    @ScaledMetric(relativeTo: .footnote) private var activeDotWidth: CGFloat = 22

    private var cards: [DeckCard] {
        briefing.bullets.map(DeckCard.point)
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
                            onOpenSource: onOpenSource
                        )
                            .scaleEffect(scale(forSlot: slot))
                            .offset(y: yOffset(forSlot: slot))
                            .offset(slot == 0 ? drag : .zero)
                            .rotationEffect(slot == 0 ? topRotation : .zero)
                            .zIndex(Double(count - slot))
                            .allowsHitTesting(slot == 0)
                            .gesture(dragGesture(size: size, count: count))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .accessibilityElement(children: .contain)
                .accessibilityValue("Card \(index + 1) of \(count)")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: index = (index + 1) % count
                    case .decrement: index = (index - 1 + count) % count
                    default: break
                    }
                }
            }

            pageDots(count: count)
        }
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

    private func restingScale(_ slot: Int) -> CGFloat { 1 - CGFloat(slot) * 0.05 }
    private func restingY(_ slot: Int) -> CGFloat { CGFloat(slot) * 22 }

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
            }
            .onEnded { value in
                guard !isFlinging else { return }
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
            }
        }
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
    case point(BriefingBullet)
    case question(String)
}

private struct DeckCardView: View {
    let card: DeckCard
    /// Tiny horizontal drift of the gradient sheen, tied to the live drag, so
    /// the top card feels like it has depth as you push it.
    let parallax: CGFloat
    let onOpenSource: (URL) -> Void

    var body: some View {
        VStack(spacing: 0) {
            hero
            footer
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

    // MARK: Hero — the full-bleed gradient that carries the line

    @ViewBuilder
    private var hero: some View {
        switch card {
        case .point(let bullet):
            heroBand(colors: heroColors(for: bullet.tag)) {
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
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                    }

                    // The line to say — the hero of the whole card.
                    Text(bullet.talkingPoint)
                        .font(SidelineTheme.display(23))
                        .foregroundStyle(.white)
                        .lineSpacing(2)
                        .lineLimit(5)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 3)
                        .padding(.top, 6)
                        .copyable(bullet.talkingPoint)
                }
            }
        case .question(let question):
            heroBand(colors: SidelineTheme.heroGold, alignment: .leading) {
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
                }
            }
        }
    }

    private func heroBand<Overlay: View>(
        colors: [Color],
        alignment: Alignment = .bottomLeading,
        @ViewBuilder overlay: () -> Overlay
    ) -> some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)

            // Soft sheen for depth — ambient, not a "graphic." Drifts with the swipe.
            RadialGradient(
                colors: [.white.opacity(0.22), .clear],
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

    // MARK: Footer — one beat of backup + the source

    @ViewBuilder
    private var footer: some View {
        switch card {
        case .point(let bullet):
            VStack(alignment: .leading, spacing: 12) {
                if let backup = backupDetail(for: bullet) {
                    Text(backup)
                        .font(.callout)
                        .foregroundStyle(SidelineTheme.inkSecondary)
                        .lineSpacing(2)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                learnMore(bullet)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

        case .question:
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.footnote)
                    .foregroundStyle(SidelineTheme.brandPrimary)
                Text("Ask a fan to keep it going.")
                    .font(.subheadline)
                    .foregroundStyle(SidelineTheme.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .accessibilityHidden(true)
        }
    }

    /// The supporting beat: the gossipy tie-in if we have one, otherwise the
    /// reason it earned its tag. Nil when the line stands on its own.
    private func backupDetail(for bullet: BriefingBullet) -> String? {
        if let tieIn = bullet.tieIn, !tieIn.isEmpty { return tieIn }
        if let reason = bullet.tagReason, !reason.isEmpty { return reason }
        return nil
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
            .foregroundStyle(SidelineTheme.brandPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(SidelineTheme.brandPrimary.opacity(0.10), in: Capsule())
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

    /// A real, legible chip that names the sport — the graphic that earns its
    /// place. Falls back to a tag-flavored, icon-only chip when we can't tell.
    private func sportChip(for bullet: BriefingBullet) -> some View {
        let sport = sport(for: bullet)
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

    private func sport(for bullet: BriefingBullet) -> (symbol: String, name: String) {
        let hay = ((bullet.subject ?? "") + " " + bullet.sourceHeadline).lowercased()
        func has(_ words: [String]) -> Bool { words.contains { hay.contains($0) } }

        // League keywords first, then a curated set of league-unique team
        // nicknames (no cross-league collisions) so the chip names the league
        // even when the story only mentions the team.
        if has(["nfl", "football", "quarterback", "touchdown", "super bowl", " qb",
                "cowboys", "eagles", "chiefs", "packers", "steelers", "49ers", "niners",
                "patriots", "bills", "ravens", "dolphins", "bengals", "broncos", "raiders",
                "browns", "seahawks", "vikings", "buccaneers", "commanders"]) { return ("football.fill", "NFL") }
        if has(["wnba"]) { return ("basketball.fill", "WNBA") }
        if has(["nba", "basketball", "dunk", "three-pointer",
                "knicks", "lakers", "celtics", "warriors", "bulls", "mavericks", "nuggets",
                "bucks", "sixers", "76ers", "timberwolves", "cavaliers", "thunder"]) { return ("basketball.fill", "NBA") }
        if has(["mlb", "baseball", "pitcher", "home run", "world series",
                "yankees", "dodgers", "red sox", "mets", "cubs", "astros", "braves",
                "phillies", "orioles"]) { return ("baseball.fill", "MLB") }
        if has(["soccer", "fifa", "premier league", "la liga", " mls", "world cup", "messi", "ronaldo"]) { return ("soccerball", "SOCCER") }
        if has(["tennis", "wimbledon", "grand slam", "djokovic", "serena", "alcaraz"]) { return ("tennis.racket", "TENNIS") }
        if has(["nhl", "hockey", "stanley cup",
                "bruins", "oilers", "maple leafs", "canadiens", "blackhawks", "penguins"]) { return ("figure.hockey", "NHL") }
        if has(["golf", "pga", "masters", "mcilroy"]) { return ("figure.golf", "GOLF") }
        if has(["olympic", "medal"]) { return ("trophy.fill", "OLYMPICS") }

        switch bullet.tag {
        case .drama, .jerk:         return ("flame.fill", "")
        case .niceGuy, .redemption: return ("star.fill", "")
        default:                    return ("sportscourt.fill", "")
        }
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
