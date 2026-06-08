import Shared
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The briefing as a small deck of swipeable cards: one self-contained story
/// per card, then a single "Your move" question to keep the conversation going.
///
/// Each story card leads with a generated art band (a tag-keyed gradient and a
/// big faded sport glyph) so it reads as a visual, not a wall of text, then the
/// line to say, one beat of backup, and a Learn-more link to the source. The
/// deck swipes with depth: cards scale, tilt, and the art parallaxes as you go.
struct BriefingDeck: View {
    let briefing: Briefing
    @Binding var index: Int
    let onOpenSource: (URL) -> Void

    @ScaledMetric(relativeTo: .footnote) private var dotSize: CGFloat = 7
    @ScaledMetric(relativeTo: .footnote) private var activeDotWidth: CGFloat = 22

    private var cards: [DeckCard] {
        briefing.bullets.map(DeckCard.point)
            + [.question(briefing.suggestedQuestion)]
    }

    var body: some View {
        let cards = self.cards
        VStack(spacing: 14) {
            GeometryReader { container in
                let containerMidX = container.frame(in: .global).midX
                let width = max(container.size.width, 1)
                TabView(selection: $index) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { position, card in
                        GeometryReader { geo in
                            // How far this page is from dead-center, ~[-1, 1].
                            // Drives the depth transform and the art parallax.
                            let delta = (geo.frame(in: .global).midX - containerMidX) / width
                            DeckCardView(
                                card: card,
                                position: position,
                                storyCount: briefing.bullets.count,
                                parallax: delta,
                                onOpenSource: onOpenSource
                            )
                            .scaleEffect(1 - min(abs(delta), 1) * 0.07)
                            .rotation3DEffect(
                                .degrees(Double(delta) * 7),
                                axis: (x: 0, y: 1, z: 0),
                                perspective: 0.6
                            )
                            .opacity(1 - min(abs(delta), 1) * 0.35)
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                        .tag(position)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .accessibilityElement(children: .contain)
                .accessibilityValue("Card \(min(index, cards.count - 1) + 1) of \(cards.count)")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: if index < cards.count - 1 { index += 1 }
                    case .decrement: if index > 0 { index -= 1 }
                    default: break
                    }
                }
            }

            pageDots(count: cards.count)
        }
    }

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
    let position: Int
    let storyCount: Int
    let parallax: CGFloat
    let onOpenSource: (URL) -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var heroHeight: CGFloat = 150

    var body: some View {
        VStack(spacing: 0) {
            hero
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.sidelineDeckCard)
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(SidelineTheme.rule, lineWidth: 1)
        )
        .shadow(color: SidelineTheme.inkPrimary.opacity(0.10), radius: 18, x: 0, y: 10)
        .accessibilityElement(children: .contain)
    }

    // MARK: Hero (generated art band)

    @ViewBuilder
    private var hero: some View {
        switch card {
        case .point(let bullet):
            heroBand(colors: heroColors(for: bullet.tag), glyph: sportSymbol(for: bullet)) {
                HStack(alignment: .top, spacing: 8) {
                    if let tag = bullet.tag, tag != .neutral {
                        lightTagPill(tag)
                    }
                    Spacer(minLength: 0)
                    Text("\(position + 1) / \(storyCount)")
                        .font(.caption2.weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(.white.opacity(0.85))
                        .accessibilityLabel("Story \(position + 1) of \(storyCount)")
                }
                Spacer(minLength: 0)
                if let subject = bullet.subject, !subject.isEmpty {
                    Text(subject)
                        .font(SidelineTheme.display(26))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 2)
                }
            }
        case .question:
            heroBand(colors: SidelineTheme.heroGold, glyph: "bubble.left.and.bubble.right.fill") {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.caption2.weight(.bold))
                    Text("YOUR MOVE")
                        .font(SidelineTheme.eyebrow)
                        .tracking(1.4)
                }
                .foregroundStyle(.white.opacity(0.95))
                Spacer(minLength: 0)
                Text("\u{201C}")
                    .font(.system(size: 56, weight: .black, design: .serif))
                    .foregroundStyle(.white)
                    .offset(y: 14)
                    .accessibilityHidden(true)
            }
        }
    }

    private func heroBand<Overlay: View>(
        colors: [Color],
        glyph: String,
        @ViewBuilder overlay: () -> Overlay
    ) -> some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)

            // Oversized, faded sport glyph. Drifts with the swipe for depth.
            Image(systemName: glyph)
                .font(.system(size: 150, weight: .black))
                .foregroundStyle(.white.opacity(0.14))
                .rotationEffect(.degrees(-14))
                .offset(x: 52 + parallax * 30, y: 26)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                overlay()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(18)
        }
        .frame(height: heroHeight)
        .clipped()
    }

    // MARK: Content (the line + one beat of backup)

    @ViewBuilder
    private var content: some View {
        switch card {
        case .point(let bullet):
            VStack(alignment: .leading, spacing: 14) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        // The line to say — the hero of the text.
                        Text(bullet.talkingPoint)
                            .font(SidelineTheme.display(22))
                            .foregroundStyle(SidelineTheme.inkPrimary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .copyable(bullet.talkingPoint)

                        // One beat of backup so you sound in-the-know. Prefer
                        // the spicy tie-in; fall back to why it's a story.
                        if let backup = backupDetail(for: bullet) {
                            Text(backup)
                                .font(.callout)
                                .foregroundStyle(SidelineTheme.inkSecondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)

                learnMore(bullet)
            }
            .padding(22)

        case .question(let question):
            VStack(alignment: .leading, spacing: 14) {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(question)
                        .font(SidelineTheme.display(24))
                        .foregroundStyle(SidelineTheme.inkPrimary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .copyable(question)
                }
                .frame(maxHeight: .infinity)

                Text("Ask a fan to keep it going.")
                    .font(.caption)
                    .foregroundStyle(SidelineTheme.inkTertiary)
                    .accessibilityHidden(true)
            }
            .padding(22)
        }
    }

    /// The supporting beat for a story: the gossipy tie-in if we have one,
    /// otherwise the reason it earned its tag. Nil when the line stands alone.
    private func backupDetail(for bullet: BriefingBullet) -> String? {
        if let tieIn = bullet.tieIn, !tieIn.isEmpty { return tieIn }
        if let reason = bullet.tagReason, !reason.isEmpty { return reason }
        return nil
    }

    private func learnMore(_ bullet: BriefingBullet) -> some View {
        Button {
            onOpenSource(bullet.sourceURL)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: "link")
                        .font(.caption2)
                    Text("Learn more")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SidelineTheme.brandPrimary)

                Text(bullet.sourceHeadline)
                    .font(.caption)
                    .foregroundStyle(SidelineTheme.inkTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Learn more. Source: \(bullet.sourceHeadline)")
        .accessibilityHint("Opens the original story")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Art helpers

    /// Tag-keyed gradient for the hero band. Drama runs hot, good news runs
    /// green, everything else stays on the brand navy.
    private func heroColors(for tag: BriefingTag?) -> [Color] {
        switch tag {
        case .niceGuy, .redemption: return SidelineTheme.heroGreen
        case .jerk, .drama:         return SidelineTheme.heroRed
        default:                    return SidelineTheme.heroNavy
        }
    }

    /// Best-effort sport glyph from the subject/headline. Never blank: falls
    /// back to a tag-flavored mark, then a generic court.
    private func sportSymbol(for bullet: BriefingBullet) -> String {
        let hay = ((bullet.subject ?? "") + " " + bullet.sourceHeadline).lowercased()
        func has(_ words: [String]) -> Bool { words.contains { hay.contains($0) } }

        if has(["nfl", "football", "quarterback", "touchdown", "super bowl", " qb"]) { return "football.fill" }
        if has(["nba", "wnba", "basketball", "dunk", "three-pointer"]) { return "basketball.fill" }
        if has(["mlb", "baseball", "pitcher", "home run", "world series"]) { return "baseball.fill" }
        if has(["soccer", "fifa", "premier league", "la liga", " mls", "world cup", "messi", "ronaldo"]) { return "soccerball" }
        if has(["tennis", "wimbledon", "grand slam", "djokovic", "serena", "alcaraz"]) { return "tennis.racket" }
        if has(["nhl", "hockey", "stanley cup"]) { return "figure.hockey" }
        if has(["golf", "pga", "masters", "mcilroy"]) { return "figure.golf" }
        if has(["olympic", "medal"]) { return "trophy.fill" }

        switch bullet.tag {
        case .drama, .jerk:          return "flame.fill"
        case .niceGuy, .redemption:  return "star.fill"
        default:                     return "sportscourt.fill"
        }
    }

    /// White-on-glass tag pill that reads on the dark art band.
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
