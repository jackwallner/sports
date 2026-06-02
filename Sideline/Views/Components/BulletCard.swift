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
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(bullet.talkingPoint)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(SidelineTheme.inkPrimary)
                        .lineSpacing(3)
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
                            .font(.callout)
                            .foregroundStyle(tagFG(tag))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let tieIn = bullet.tieIn, !tieIn.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundStyle(SidelineTheme.brandAccent)
                                .padding(.top, 3)
                            Text(tieIn)
                                .font(.callout)
                                .foregroundStyle(SidelineTheme.inkSecondary)
                                .italic()
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 14)
            }

            sourceLink
                .padding(.top, 12)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.sidelineCard, in: RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius))
        .accessibilityElement(children: .contain)
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

            if let subject = bullet.subject, !subject.isEmpty {
                subjectChip(subject)
            }

            Spacer(minLength: 0)
        }
    }

    private func tagPill(_ tag: BriefingTag) -> some View {
        HStack(spacing: 4) {
            Image(systemName: tag.symbolName)
                .font(.caption2.weight(.bold))
            Text(tag.displayName.uppercased())
                .font(.system(.caption2, design: .rounded).weight(.heavy))
                .tracking(0.8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(tagFG(tag))
        .background(tagBG(tag), in: Capsule())
        .accessibilityLabel(tagAccessibility(tag: tag, reason: bullet.tagReason))
    }

    private func subjectChip(_ subject: String) -> some View {
        Text(subject)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(SidelineTheme.inkSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(SidelineTheme.rule, in: Capsule())
            .accessibilityLabel("About \(subject)")
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Source: \(bullet.sourceHeadline), link")
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
