import CoreGraphics
#if os(iOS)
import SwiftUI
#endif

/// Pane frames for the unfolded iPhone Duo: the briefing deck on the leading
/// side of the fold, the rundown of the same briefing on the trailing side,
/// so no card straddles the crease. `nil` keeps the single column (every
/// ordinary iPhone, the folded Duo, and the unfolded Duo held in portrait,
/// where each half would be too narrow).
public struct UnfoldedSplit: Equatable, Sendable {
    public var primaryWidth: CGFloat
    public var secondaryX: CGFloat
    public var secondaryWidth: CGFloat

    /// Narrowest pane that still fits the phone layout of the deck.
    public static let minimumPaneWidth: CGFloat = 360

    /// - Parameters:
    ///   - width: the container's width.
    ///   - fold: the vertical fold's leading and trailing edge in the same
    ///     coordinate space, or `nil` when the system reports none.
    public static func make(width: CGFloat, isRegularWidth: Bool, fold: ClosedRange<CGFloat>?) -> UnfoldedSplit? {
        guard isRegularWidth, width >= minimumPaneWidth * 2 else { return nil }
        if let fold,
           fold.lowerBound >= minimumPaneWidth,
           width - fold.upperBound >= minimumPaneWidth {
            return UnfoldedSplit(
                primaryWidth: fold.lowerBound,
                secondaryX: fold.upperBound,
                secondaryWidth: width - fold.upperBound
            )
        }
        let half = (width / 2).rounded(.down)
        return UnfoldedSplit(primaryWidth: half, secondaryX: half, secondaryWidth: width - half)
    }
}

/// What the split is measured from: the container's width and its fold.
public struct PaneGeometry: Equatable, Sendable {
    public var width: CGFloat
    public var fold: ClosedRange<CGFloat>?

    public init(width: CGFloat, fold: ClosedRange<CGFloat>?) {
        self.width = width
        self.fold = fold
    }
}

#if os(iOS)
public extension GeometryProxy {
    /// The vertical fold's horizontal extent in this proxy's space. Inactive
    /// folds count too, so the panes don't jump while the device opens.
    func verticalFold() -> ClosedRange<CGFloat>? {
        guard #available(iOS 27.1, *) else { return nil }
        let fold = reservedRegions(kind: .division, options: .includeInactive)
            .map(\.frame)
            .first { $0.height > $0.width && $0.minX > 0 && $0.maxX < size.width }
        guard let fold else { return nil }
        return fold.minX...fold.maxX
    }
}

public extension View {
    /// iOS 27.1 can move a stack's toolbar into a vertical bar on its trailing
    /// edge, which in the leading pane lands beside the fold. A pane keeps the
    /// phone's horizontal bar. Folded, the system default is unchanged.
    @ViewBuilder
    func horizontalToolbarInPane(_ isPane: Bool) -> some View {
        if #available(iOS 27.1, *) {
            toolbarVerticalBehavior(isPane ? .disabled : .automatic)
        } else {
            self
        }
    }
}
#endif
