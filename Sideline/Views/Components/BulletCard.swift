import Shared
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct BulletCard: View {
    let bullet: BriefingBullet
    let index: Int
    let total: Int
    let onOpenSource: (URL) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            accentEdge

            VStack(alignment: .leading, spacing: 10) {
                header

                Text(bullet.talkingPoint)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(SidelineTheme.inkPrimary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .contextMenu {
                        Button {
                            copyToClipboard(bullet.talkingPoint)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }

                if let tag = bullet.tag, tag != .neutral, let reason = bullet.tagReason, !reason.isEmpty {
                    Text(reason)
                        .font(.footnote)
                        .foregroundStyle(tagFG(tag))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let tieIn = bullet.tieIn, !tieIn.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(SidelineTheme.brandAccent)
                            .padding(.top, 3)
                        Text(tieIn)
                            .font(.footnote)
                            .foregroundStyle(SidelineTheme.inkSecondary)
                            .italic()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                sourceLink
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .contain)
    }

    private var accentEdge: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(accentColor)
            .frame(width: 4)
            .frame(maxHeight: .infinity)
            .accessibilityHidden(true)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("\(index) of \(total)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(SidelineTheme.inkTertiary)
                .tracking(0.5)

            if let tag = bullet.tag, tag != .neutral {
                tagPill(tag)
            }

            Spacer(minLength: 0)
        }
    }

    private func tagPill(_ tag: BriefingTag) -> some View {
        HStack(spacing: 4) {
            Image(systemName: tag.symbolName)
                .font(.caption2.weight(.bold))
            Text(tag.displayName.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(tagFG(tag))
        .background(tagBG(tag), in: Capsule())
        .accessibilityLabel(tagAccessibility(tag: tag, reason: bullet.tagReason))
    }

    private var sourceLink: some View {
        Button {
            onOpenSource(bullet.sourceURL)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "link")
                    .font(.caption2)
                Text(bullet.sourceHeadline)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(SidelineTheme.inkTertiary)
            .padding(.top, 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Source: \(bullet.sourceHeadline), link")
    }

    private var accentColor: Color {
        guard let tag = bullet.tag else { return SidelineTheme.rule }
        switch tag {
        case .niceGuy, .redemption: return SidelineTheme.tagNiceGuy
        case .jerk, .drama: return SidelineTheme.tagJerk
        case .neutral: return SidelineTheme.inkTertiary
        }
    }

    private func tagBG(_ tag: BriefingTag) -> Color {
        switch tag {
        case .niceGuy, .redemption: return SidelineTheme.tagFill(SidelineTheme.tagNiceGuy)
        case .jerk, .drama: return SidelineTheme.tagFill(SidelineTheme.tagJerk)
        case .neutral: return SidelineTheme.rule
        }
    }

    private func tagFG(_ tag: BriefingTag) -> Color {
        switch tag {
        case .niceGuy, .redemption: return SidelineTheme.tagNiceGuy
        case .jerk, .drama: return SidelineTheme.tagJerk
        case .neutral: return SidelineTheme.inkSecondary
        }
    }

    private func tagAccessibility(tag: BriefingTag, reason: String?) -> String {
        if let reason {
            return "Tagged: \(tag.displayName), \(reason)"
        }
        return "Tagged: \(tag.displayName)"
    }

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}
