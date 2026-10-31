import XCTest

final class PillPositionTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 3000, height: 1000)
    private let panel: CGFloat = 380

    func testTheMiddleOfThePillSitsAtTheChosenShareOfTheWidth() {
        XCTAssertEqual(PillPosition.right.originX(in: screen, panelWidth: panel) + panel / 2, 2000, accuracy: 0.5)
        XCTAssertEqual(PillPosition.center.originX(in: screen, panelWidth: panel) + panel / 2, 1500, accuracy: 0.5)
        XCTAssertEqual(PillPosition.left.originX(in: screen, panelWidth: panel) + panel / 2, 1000, accuracy: 0.5)
    }

    func testAScreenNotAtTheOriginCountsFromItsOwnLeftEdge() {
        let second = CGRect(x: 1440, y: 0, width: 3000, height: 1000)
        XCTAssertEqual(PillPosition.right.originX(in: second, panelWidth: panel) + panel / 2, 1440 + 2000, accuracy: 0.5)
    }

    func testThePanelStaysInsideAVeryNarrowArea() {
        let narrow = CGRect(x: 0, y: 0, width: 400, height: 800)
        for position in PillPosition.allCases {
            let x = position.originX(in: narrow, panelWidth: panel)
            XCTAssertGreaterThanOrEqual(x, 0)
            XCTAssertLessThanOrEqual(x + panel, 400)
        }
        let tiny = CGRect(x: 10, y: 0, width: 300, height: 800)
        XCTAssertEqual(PillPosition.right.originX(in: tiny, panelWidth: panel), 10, "wider than the area: left edge")
    }

    func testRightIsTheOnlyPositionRightOfTheMiddle() {
        XCTAssertGreaterThan(PillPosition.right.share, PillPosition.center.share)
        XCTAssertLessThan(PillPosition.left.share, PillPosition.center.share)
    }
}
