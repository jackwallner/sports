import CoreGraphics
import Shared
import XCTest

/// The unfolded iPhone Duo puts the deck and the rundown on opposite sides of
/// the fold; everything narrower keeps the phone's single column.
final class UnfoldedSplitTests: XCTestCase {
    /// The inner display, landscape: 951 pt wide.
    private let innerWidth: CGFloat = 951

    func testCompactWidthNeverSplits() {
        XCTAssertNil(UnfoldedSplit.make(width: innerWidth, isRegularWidth: false, fold: nil))
        // The folded outer display.
        XCTAssertNil(UnfoldedSplit.make(width: 466, isRegularWidth: false, fold: nil))
    }

    func testRegularWidthTooNarrowForTwoPanesStaysSingle() {
        // The unfolded display held in portrait: 669 pt is under two 360 pt panes.
        XCTAssertNil(UnfoldedSplit.make(width: 669, isRegularWidth: true, fold: nil))
        XCTAssertNil(UnfoldedSplit.make(width: 719, isRegularWidth: true, fold: nil))
    }

    func testPanesMeetTheFoldEdges() throws {
        let split = try XCTUnwrap(UnfoldedSplit.make(width: innerWidth, isRegularWidth: true, fold: 470...481))
        XCTAssertEqual(split.primaryWidth, 470)
        XCTAssertEqual(split.secondaryX, 481)
        XCTAssertEqual(split.secondaryWidth, 470)
    }

    func testZeroWidthFoldSplitsAtTheLine() throws {
        let split = try XCTUnwrap(UnfoldedSplit.make(width: innerWidth, isRegularWidth: true, fold: 475.5...475.5))
        XCTAssertEqual(split.primaryWidth, 475.5)
        XCTAssertEqual(split.secondaryX, 475.5)
        XCTAssertEqual(split.secondaryWidth, 475.5)
    }

    func testNoFoldSplitsEvenly() throws {
        let split = try XCTUnwrap(UnfoldedSplit.make(width: innerWidth, isRegularWidth: true, fold: nil))
        XCTAssertEqual(split.primaryWidth, 475)
        XCTAssertEqual(split.secondaryX, 475)
        XCTAssertEqual(split.secondaryWidth, 476)
        XCTAssertEqual(split.primaryWidth + split.secondaryWidth, innerWidth)
    }

    func testFoldLeavingANarrowPaneFallsBackToAnEvenSplit() throws {
        // A fold that would leave the leading pane under 360 pt is ignored.
        let leading = try XCTUnwrap(UnfoldedSplit.make(width: innerWidth, isRegularWidth: true, fold: 300...310))
        XCTAssertEqual(leading.primaryWidth, 475)
        let trailing = try XCTUnwrap(UnfoldedSplit.make(width: innerWidth, isRegularWidth: true, fold: 640...650))
        XCTAssertEqual(trailing.secondaryX, 475)
    }

    func testEveryPaneIsAtLeastTheMinimum() {
        for width in stride(from: CGFloat(720), through: 1400, by: 37) {
            guard let split = UnfoldedSplit.make(width: width, isRegularWidth: true, fold: nil) else {
                return XCTFail("no split at \(width)")
            }
            XCTAssertGreaterThanOrEqual(split.primaryWidth, UnfoldedSplit.minimumPaneWidth)
            XCTAssertGreaterThanOrEqual(split.secondaryWidth, UnfoldedSplit.minimumPaneWidth)
            XCTAssertLessThanOrEqual(split.secondaryX + split.secondaryWidth, width)
        }
    }
}
