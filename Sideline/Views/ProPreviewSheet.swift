import Shared
import SwiftUI

struct ProPreviewSheet: View {
    let persona: Persona
    /// When the user still has an unused free trial, every door into Pro
    /// should say "try free", not "unlock". Free beats locked.
    var trialAvailable: Bool = false
    let onSeePro: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: persona.symbolName)
                            .font(.caption.weight(.bold))
                        Text(persona.contextHeader)
                            .font(.caption.weight(.heavy))
                            .tracking(1.2)
                    }
                    .foregroundStyle(SidelineTheme.brandPrimary)

                    Text(persona.displayName)
                        .font(SidelineTheme.display(34))
                        .foregroundStyle(SidelineTheme.inkPrimary)
                    Text(persona.shortPitch)
                        .font(.title3)
                        .foregroundStyle(SidelineTheme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Here's how this room sounds")
                    .font(.caption.weight(.heavy))
                    .tracking(1.0)
                    .foregroundStyle(SidelineTheme.inkTertiary)

                Text(persona.proPreviewTeaser)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(SidelineTheme.inkPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius)
                            .fill(SidelineTheme.brandPrimary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius)
                            .stroke(SidelineTheme.brandPrimary.opacity(0.18), lineWidth: 1)
                    )

                Label("This room gets its own stories every day, separate from the free briefing. Pro opens it, refreshed up to 3× a day.", systemImage: "lock.open.fill")
                    .font(.footnote)
                    .foregroundStyle(SidelineTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button {
                    onSeePro()
                } label: {
                    Text(trialAvailable ? "Try \(persona.displayName) Free" : "Unlock \(persona.displayName)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(SidelineTheme.brandPrimary)
            }
            .padding(24)
            .navigationTitle(persona.paywallHook)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { onDismiss() }
                }
            }
        }
    }
}
