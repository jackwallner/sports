import CoreGraphics

/// Where the rundown beside the deck rests once a row opens.
///
/// The list always comes to rest on a whole row: the open row is fully in
/// view, and as many rows above it as fit with it, so a tap moves the list as
/// little as it can without leaving part of a row under the pane's header.
public enum RundownReveal {
    /// The row to rest at the top of the list.
    /// - Parameters:
    ///   - open: the open row's index.
    ///   - heights: every row's height, in order.
    ///   - spacing: the gap between rows.
    ///   - room: the list's height below its header inset.
    public static func topRow(open: Int, heights: [CGFloat], spacing: CGFloat, room: CGFloat) -> Int {
        guard heights.indices.contains(open) else { return 0 }
        var top = open
        var span = heights[open]
        while top > 0 {
            let grown = span + spacing + heights[top - 1]
            if grown > room { break }
            span = grown
            top -= 1
        }
        return top
    }

    /// Space under the last row, enough that the list can rest with `top` at
    /// the top instead of stopping at its end with a row cut by the header.
    public static func bottomPadding(top: Int, heights: [CGFloat], spacing: CGFloat, room: CGFloat, minimum: CGFloat) -> CGFloat {
        guard heights.indices.contains(top) else { return minimum }
        let rest = heights[top...]
        let span = rest.reduce(0, +) + spacing * CGFloat(rest.count - 1)
        return max(minimum, room - span)
    }
}
