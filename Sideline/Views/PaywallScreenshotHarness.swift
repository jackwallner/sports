#if DEBUG
import SwiftUI
import Shared

struct PaywallScreenshotHarness: View {
    let mode: PaywallScreenshotMode
    @State private var store = StoreService.shared

    var body: some View {
        Group {
            if mode == .trial {
                // Mirror the real trial door: the compact ProPreviewSheet ("Try … Free"),
                // not a cropped full paywall. Persona-keyed pitch, no store dependency.
                trialBackdrop {
                    ProPreviewSheet(
                        persona: .officeWatercooler,
                        trialAvailable: true,
                        onSeePro: {},
                        onDismiss: {}
                    )
                }
            } else {
                NavigationStack {
                    PaywallView(entitlement: store, displayCloseButton: false, impressionId: "snapshot")
                }
            }
        }
        .environment(store)
        .task {
            if store.products.isEmpty { await store.fetchProducts() }
        }
    }

    private func trialBackdrop<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.sidelineBackground.ignoresSafeArea()
            Color.black.opacity(0.12).ignoresSafeArea()
            VStack {
                Spacer()
                content()
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.68)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
            }
        }
    }
}
#endif
