import XCTest
@testable import NullMothCore

final class DisplayModeInfoTests: XCTestCase {
    func testLabelShowsResolutionAndRefreshRate() {
        let mode = DisplayModeInfo(
            id: 1,
            width: 1920,
            height: 1080,
            pointWidth: 1920,
            pointHeight: 1080,
            refreshRate: 100,
            isCurrent: true,
            isHiDPI: false
        )

        XCTAssertEqual(mode.label, "1920×1080 @ 100 Hz")
    }

    func testLabelMarksScaledDisplays() {
        let mode = DisplayModeInfo(
            id: 2,
            width: 3840,
            height: 2160,
            pointWidth: 1920,
            pointHeight: 1080,
            refreshRate: 60,
            isCurrent: false,
            isHiDPI: true
        )

        XCTAssertEqual(mode.label, "3840×2160 (HiDPI) @ 60 Hz")
    }

    func testCatalogKeepsItsDisplayIdentifier() {
        let catalog = DisplayModeCatalog(
            displayID: 7,
            displayName: "Test display",
            isMain: true,
            currentWidth: 1920,
            currentHeight: 1080,
            currentRefreshRate: 60,
            modes: []
        )

        XCTAssertEqual(catalog.id, 7)
    }
}
