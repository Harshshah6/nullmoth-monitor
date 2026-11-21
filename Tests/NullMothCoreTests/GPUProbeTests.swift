import XCTest
@testable import NullMothCore

final class GPUProbeTests: XCTestCase {
    private let bars = "bar0@0x10:0xfb000000+0x1000000 bar1@0x14:0x7c00000000+0x200000000 bar2@0x1c:0x7e00000000+0x2000000"

    func testExtractsBAR0() {
        XCTAssertEqual(
            GPUProbe.barValue(named: "bar0", in: bars),
            "bar0@0x10:0xfb000000+0x1000000"
        )
    }

    func testExtractsBAR1() {
        XCTAssertEqual(
            GPUProbe.barValue(named: "bar1", in: bars),
            "bar1@0x14:0x7c00000000+0x200000000"
        )
    }

    func testReturnsNilForUnknownBAR() {
        XCTAssertNil(GPUProbe.barValue(named: "bar9", in: bars))
    }

    func testReturnsNilForEmptyString() {
        XCTAssertNil(GPUProbe.barValue(named: "bar0", in: ""))
    }
}
