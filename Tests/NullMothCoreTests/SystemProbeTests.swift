import XCTest
@testable import NullMothCore

final class SystemProbeTests: XCTestCase {
    func testParsesGigabytes() {
        XCTAssertEqual(SystemProbe.parseMemoryString("12 GB"), 12 * 1024 * 1024 * 1024)
    }

    func testParsesMegabytes() {
        XCTAssertEqual(SystemProbe.parseMemoryString("512 MB"), 512 * 1024 * 1024)
    }

    func testParsesBytes() {
        XCTAssertEqual(SystemProbe.parseMemoryString("1024 B"), 1024)
    }

    func testParsesCaseInsensitiveUnits() {
        XCTAssertEqual(SystemProbe.parseMemoryString("8 gb"), 8 * 1024 * 1024 * 1024)
    }

    func testRejectsUnknownUnit() {
        XCTAssertNil(SystemProbe.parseMemoryString("12 furlongs"))
    }

    func testRejectsMalformedInput() {
        XCTAssertNil(SystemProbe.parseMemoryString("GB"))
        XCTAssertNil(SystemProbe.parseMemoryString(""))
    }
}
