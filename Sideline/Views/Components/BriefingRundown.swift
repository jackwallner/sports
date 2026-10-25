import Shared
import SwiftUI

/// The whole briefing as one list, beside the deck on the unfolded iPhone Duo.
///
/// Rows follow the deck's order (the brief, each story, the question), so a
/// row and a card are the same thing seen two ways: the card on top of the
/// deck is the row that is open here, with its backstory showing, and tapping
/// a row brings that card to the top. Folded, the deck alone carries all of
/// this behind its swipes and flips.
struct BriefingRundown: View {
    let briefing: Briefing
    @Binding var index: Int
    let onOpenSource: (URL) -> Void

    private struct Row: Identifiable {
        let id: Int
        let kicker: String
        let line: String
        let detail: String?
        let tag: BriefingTag?
        let source: BriefingBullet?
        let isQuestion: Bool
    }

    private var rows: [Row] {
        var rows = [Row(
            id: 0,
            kicker: "The brief",
            line: briefing.tlDR,
            detail: briefing.leadBackstory,
            tag: nil,
            source: nil,
            isQuestion: false
        )]
        for (offset, bullet) in briefing.bullets.enumerated() {
            rows.append(Row(
                id: offset + 1,
                kicker: bullet.subject.flatMap { $0.isEmpty ? nil : $0 } ?? "Story \(offset + 1)",
                line: bullet.talkingPoint,
                detail: bullet.backstory ?? bullet.tieIn ?? bullet.tagReason,
                tag: bullet.tag == .neutral ? nil : bullet.tag,
                source: bullet,
                isQuestion: false
            ))
        }
        rows.append(Row(
            id: briefing.bullets.count + 1,
            kicker: "Ask this",
            line: briefing.suggestedQuestion,
            detail: "Toss it out and let them do the talking.",
            tag: nil,
            source: nil,
            isQuestion: true
        ))
        return rows
    }

    /// Header inset of the list. A row comes to rest this far down, which
    /// leaves the row above it scrolled out to its padding: no part of its
    /// text sits under the fade.
    private static let headerFade: CGFloat = 20
    private static let rowSpacing: CGFloat = 6
    private static let minimumBottom: CGFloat = 24

    @State private var rowHeights: [Int: CGFloat] = [:]
    @State private var listHeight: CGFloat = 0

    private var measuredHeights: [CGFloat] {
        rows.map { rowHeights[$0.id] ?? 0 }
    }

    private var listRoom: CGFloat { listHeight - Self.headerFade }

    private var restingTop: Int {
        RundownReveal.topRow(open: index, heights: measuredHeights, spacing: Self.rowSpacing, room: listRoom)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Pinned like the deck pane's title bar, so the pane keeps its
            // room and headline whichever row is open.
            header
                .padding(.horizontal, 18)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Self.rowSpacing) {
                        ForEach(rows) { row in
                            rowView(row)
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                                    rowHeights[row.id] = $0
                                }
                                // The scroll target reaches the header inset
                                // above the row, so resting on it leaves the
                                // row clear of the fade.
                                .background(alignment: .bottom) {
                                    Color.clear
                                        .padding(.top, -Self.headerFade)
                                        .id(row.id)
                                }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, Self.headerFade)
                    .padding(.bottom, RundownReveal.bottomPadding(
                        top: restingTop,
                        heights: measuredHeights,
                        spacing: Self.rowSpacing,
                        room: listRoom,
                        minimum: Self.minimumBottom
                    ))
                }
                .scrollIndicators(.hidden)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
                // Rows scrolled up dissolve into the page under the header
                // instead of showing a sliced line against it. An overlay,
                // not a mask, so the bottom still scrolls into the safe area.
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [Color.sidelineBackground, Color.sidelineBackground.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: Self.headerFade)
                    .allowsHitTesting(false)
                }
                // A launch or room link can open the deck past its first card
                // before the rundown exists, which no index change reports.
                .onAppear { reveal(with: proxy) }
                .onChange(of: index) {
                    withAnimation(.snappy) { reveal(with: proxy) }
                }
                // Opening a row changes its height, and with it where the
                // list should rest.
                .onChange(of: rowHeights) {
                    withAnimation(.snappy) { reveal(with: proxy) }
                }
                .onChange(of: listHeight) { reveal(with: proxy) }
            }
        }
    }

    /// Rests the list on whole rows with the open one fully in view
    /// (`RundownReveal`). Anchoring on the open row alone landed wherever the
    /// scroll happened to stop, often with a sliced line under the header.
    private func reveal(with proxy: ScrollViewProxy) {
        proxy.scrollTo(restingTop, anchor: .top)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(briefing.persona.contextHeader)
                .font(SidelineTheme.eyebrow)
                .tracking(1.4)
                .foregroundStyle(SidelineTheme.brandPrimary)
            Text(briefing.headline)
                .font(SidelineTheme.title)
                .foregroundStyle(SidelineTheme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("\(briefing.bullets.count) stories, \(briefing.sourceCount) sources. Tap a row to bring its card up.")
                .font(.caption)
                .foregroundStyle(SidelineTheme.inkTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 2)
    }

    private func rowView(_ row: Row) -> some View {
        let isOpen = row.id == index
        let accent = row.isQuestion ? SidelineTheme.amberText : SidelineTheme.brandPrimary
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy) { index = row.id }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(row.kicker.uppercased())
                            .font(SidelineTheme.eyebrow)
                            .tracking(1.4)
                            .foregroundStyle(accent)
                            .lineLimit(1)
                        if let tag = row.tag {
                            Label(tag.displayName, systemImage: tag.symbolName)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(SidelineTheme.inkTertiary)
                        }
                    }
                    Text(row.line)
                        .font(.system(.body, design: .serif).weight(isOpen ? .semibold : .regular))
                        .foregroundStyle(SidelineTheme.inkPrimary)
                        .lineLimit(isOpen ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                    if isOpen, let detail = row.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(SidelineTheme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOpen ? .isSelected : [])

            if isOpen, let bullet = row.source {
                sourceButton(bullet)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isOpen ? Color.sidelineDeckCard : .clear)
                .shadow(color: SidelineTheme.inkPrimary.opacity(isOpen ? 0.08 : 0), radius: 10, y: 4)
        }
        .overlay(alignment: .leading) {
            Capsule()
                .fill(accent)
                .frame(width: 3)
                .padding(.vertical, 16)
                .opacity(isOpen ? 1 : 0)
        }
    }

    /// The receipt, the same one the card's back links to.
    private func sourceButton(_ bullet: BriefingBullet) -> some View {
        Button {
            onOpenSource(bullet.sourceURL)
        } label: {
            HStack(spacing: 6) {
                Text(bullet.sourceHeadline)
                    .lineLimit(1)
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.bold))
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(SidelineTheme.brandPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Read the source: \(bullet.sourceHeadline)")
    }
}
