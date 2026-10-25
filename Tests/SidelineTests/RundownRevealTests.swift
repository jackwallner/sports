import CoreGraphics
import Shared
import XCTest

/// The rundown rests on whole rows, with the open one fully in view.
final class RundownRevealTests: XCTestCase {
    private let heights: [CGFloat] = [120, 80, 80, 200, 80, 90]

    func testOpeningTheFirstRowRestsAtTheTop() {
        XCTAssertEqual(RundownReveal.topRow(open: 0, heights: heights, spacing: 6, room: 500), 0)
    }

    func testKeepsEveryRowAboveThatFits() {
        // 120 + 80 + 80 + 200 + 3 gaps = 498.
        XCTAssertEqual(RundownReveal.topRow(open: 3, heights: heights, spacing: 6, room: 500), 0)
        XCTAssertEqual(RundownReveal.topRow(open: 3, heights: heights, spacing: 6, room: 497), 1)
    }

    func testDropsRowsAboveUntilTheOpenRowFits() {
        // Rows 3...5: 200 + 80 + 90 + 2 gaps = 382.
        XCTAssertEqual(RundownReveal.topRow(open: 5, heights: heights, spacing: 6, room: 390), 3)
        XCTAssertEqual(RundownReveal.topRow(open: 5, heights: heights, spacing: 6, room: 300), 4)
    }

    func testAnOpenRowTallerThanTheListRestsAtItsOwnTop() {
        XCTAssertEqual(RundownReveal.topRow(open: 3, heights: heights, spacing: 6, room: 150), 3)
    }

    func testAnUnmeasuredRowFallsBackToTheTop() {
        XCTAssertEqual(RundownReveal.topRow(open: 9, heights: heights, spacing: 6, room: 500), 0)
        XCTAssertEqual(RundownReveal.topRow(open: 2, heights: [], spacing: 6, room: 500), 0)
    }

    func testBottomPaddingLetsTheTopRowReachTheTop() {
        // Rows 4...5: 80 + 6 + 90 = 176.
        XCTAssertEqual(RundownReveal.bottomPadding(top: 4, heights: heights, spacing: 6, room: 500, minimum: 24), 324)
    }

    func testBottomPaddingNeverDropsBelowTheMinimum() {
        XCTAssertEqual(RundownReveal.bottomPadding(top: 0, heights: heights, spacing: 6, room: 500, minimum: 24), 24)
        XCTAssertEqual(RundownReveal.bottomPadding(top: 7, heights: heights, spacing: 6, room: 500, minimum: 24), 24)
    }
}
