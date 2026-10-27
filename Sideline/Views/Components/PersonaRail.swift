import Shared
import SwiftUI

struct PersonaRail: View {
    let selected: Persona
    let isPro: Bool
    let onSelect: (Persona) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The chips alone read as ambiguous filters. Frame the choice the
            // way the user actually makes it: who am I about to talk to?
            HStack(spacing: 6) {
                Text("ROOMS")
                    .font(SidelineTheme.eyebrow)
                    .tracking(1.4)
                    .foregroundStyle(SidelineTheme.brandPrimary)
                Text("Pick who you'll be talking to")
                    .font(.caption)
                    .foregroundStyle(SidelineTheme.inkTertiary)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            chips

            // The selected room's pitch, so switching rooms visibly changes
            // what the briefing below is for.
            Text(selected.shortPitch)
                .font(.caption)
                .foregroundStyle(SidelineTheme.inkTertiary)
                .lineLimit(1)
                .padding(.horizontal)
                .padding(.bottom, 6)
                .animation(nil, value: selected)
                .accessibilityLabel("\(selected.displayName): \(selected.shortPitch)")
        }
    }

    /// Every room in one row when it fits, the selected one named and the
    /// rest as icons, so no chip is ever cut by the screen edge or the fold.
    /// Narrower screens scroll the full chips.
    private var chips: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ForEach(visiblePersonas) { persona in
                    chip(persona, showsName: persona == selected)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .animation(.snappy, value: selected)

            ScrollViewReader { proxy in
                rail
                    // Keep the selected room in view: a restored or linked room
                    // past the first two otherwise sat off the edge.
                    .task(id: selected) {
                        withAnimation(.snappy) { proxy.scrollTo(selected, anchor: .center) }
                    }
            }
        }
    }

    private var rail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(visiblePersonas) { persona in
                    chip(persona, showsName: true)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        // A horizontal scroll view draws past its frame into the safe area,
        // which put the chips under the status bar in the outer display's
        // vertical bar and against the fold. Stop them at the frame, fading
        // over the trailing padding so a partly scrolled chip reads as more.
        .mask {
            HStack(spacing: 0) {
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 16)
            }
        }
    }

    private func chip(_ persona: Persona, showsName: Bool) -> some View {
        Button {
            onSelect(persona)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: persona.symbolName)
                if showsName {
                    Text(persona.displayName)
                        .lineLimit(1)
                        .fixedSize()
                }
                if !persona.isFree && !isPro {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .accessibilityLabel("Pro")
                }
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, showsName ? 14 : 12)
            .padding(.vertical, 9)
            .foregroundStyle(foreground(for: persona))
            .background(
                Capsule().fill(persona == selected ? SidelineTheme.brandPrimary : Color.clear)
            )
            .overlay(
                Capsule().stroke(persona == selected ? Color.clear : SidelineTheme.rule, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: persona))
        .id(persona)
    }

    private var visiblePersonas: [Persona] {
        guard isScreenshotMode && !isPro else { return Persona.allCases }
        return Persona.allCases.filter { $0.isFree }
    }

    private var isScreenshotMode: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-SidelineSafeScreenshot")
        #else
        return false
        #endif
    }

    private func foreground(for persona: Persona) -> some ShapeStyle {
        persona == selected
            ? AnyShapeStyle(Color.white)
            : AnyShapeStyle(SidelineTheme.inkPrimary)
    }

    private func accessibilityLabel(for persona: Persona) -> String {
        if !persona.isFree && !isPro {
            return "\(persona.displayName), Pro context"
        }

        if persona == selected {
            return "\(persona.displayName), selected"
        }

        return persona.displayName
    }
}
