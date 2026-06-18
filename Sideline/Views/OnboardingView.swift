import Shared
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Binding var lastPersona: String
    var isPro: Bool = false

    @State private var page = 0
    @State private var pickedPersona: Persona = .cocktailParty

    private func isLocked(_ persona: Persona) -> Bool {
        !persona.isFree && !isPro
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                valueProp.tag(0)
                personaPick.tag(1)
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .always))
            #endif
            .background(Color.sidelineBackground)
            .safeAreaInset(edge: .bottom) {
                actionBar
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    .background(
                        Color.sidelineBackground
                            .overlay(
                                Rectangle()
                                    .fill(SidelineTheme.rule)
                                    .frame(height: 1)
                                    .frame(maxHeight: .infinity, alignment: .top)
                            )
                    )
            }
        }
        .onAppear {
            if let persona = Persona(rawValue: lastPersona) {
                pickedPersona = persona
            }
            #if os(iOS)
            let control = UIPageControl.appearance()
            control.currentPageIndicatorTintColor = UIColor(SidelineTheme.brandPrimary)
            control.pageIndicatorTintColor = UIColor(SidelineTheme.brandPrimary.opacity(0.25))
            #endif
        }
    }

    private var valueProp: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer(minLength: 24)
            Image(systemName: "quote.bubble.fill")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(SidelineTheme.brandPrimary)
            Text("Sound like you follow sports.")
                .font(SidelineTheme.display(30))
                .foregroundStyle(SidelineTheme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("A few things to say and one question to ask, in under 20 seconds, before you walk into the room.")
                .font(.body)
                .foregroundStyle(SidelineTheme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var personaPick: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer(minLength: 12)
            Text("Pick the room you'll use this in")
                .font(SidelineTheme.title)
                .foregroundStyle(SidelineTheme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Each room is its own daily briefing, with stories picked for that crowd. Cocktail Party is free; the rest unlock with Pro.")
                .font(.callout)
                .foregroundStyle(SidelineTheme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Persona.allCases) { persona in
                        personaRow(persona)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func personaRow(_ persona: Persona) -> some View {
        let locked = isLocked(persona)
        let isSelected = persona == pickedPersona && !locked
        return Button {
            // A free user can't start in a Pro room. Locked rows preview what
            // Pro unlocks (the paywall is framed right after onboarding) but
            // don't become the start room, so the choice is never silently lost.
            guard !locked else { return }
            pickedPersona = persona
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: persona.symbolName)
                    .font(.title3)
                    .foregroundStyle(locked ? SidelineTheme.inkTertiary : SidelineTheme.brandPrimary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(persona.displayName)
                            .font(.headline)
                            .foregroundStyle(SidelineTheme.inkPrimary)
                        if locked {
                            Label("Pro", systemImage: "lock.fill")
                                .labelStyle(.titleAndIcon)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(SidelineTheme.brandAccent.opacity(0.2), in: Capsule())
                                .foregroundStyle(SidelineTheme.amberText)
                        }
                    }
                    Text(persona.shortPitch)
                        .font(.footnote)
                        .foregroundStyle(SidelineTheme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(SidelineTheme.brandPrimary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius)
                    .fill(isSelected ? SidelineTheme.brandPrimary.opacity(0.10) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius)
                    .stroke(isSelected ? SidelineTheme.brandPrimary.opacity(0.45) : SidelineTheme.rule, lineWidth: isSelected ? 1.5 : 1)
            )
            .opacity(locked ? 0.85 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locked ? "\(persona.displayName), Pro, unlocks with Gist Pro" : persona.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var actionBar: some View {
        HStack {
            if page > 0 {
                Button("Back") { withAnimation { page -= 1 } }
                    .buttonStyle(.plain)
                    .foregroundStyle(SidelineTheme.inkSecondary)
            }
            Spacer()
            Button(primaryLabel) {
                advance()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(SidelineTheme.brandPrimary)
        }
    }

    private var primaryLabel: String {
        page == 0 ? "Start" : "Use this room"
    }

    private func advance() {
        if page == 0 {
            withAnimation { page = 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        // Never persist a locked Pro room as the start room for a free user.
        lastPersona = isLocked(pickedPersona) ? Persona.cocktailParty.rawValue : pickedPersona.rawValue
        hasCompletedOnboarding = true
    }
}
