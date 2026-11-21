import XCTest
@testable import NullMothCore

final class MetalProbeTests: XCTestCase {
    func testStripsTranslatorPrefixAndBackendSuffix() {
        XCTAssertEqual(
            MetalProbe.cleanedName("NVMTL over NVIDIA GeForce RTX 3060 (NVK GA106-A)"),
            "NVIDIA GeForce RTX 3060"
        )
    }

    func testKeepsPlainName() {
        XCTAssertEqual(MetalProbe.cleanedName("NVIDIA GeForce RTX 3060"), "NVIDIA GeForce RTX 3060")
    }

    func testKeepsLegitimateParenthetical() {
        XCTAssertEqual(
            MetalProbe.cleanedName("NVIDIA GeForce RTX 3060 (LHR)"),
            "NVIDIA GeForce RTX 3060 (LHR)"
        )
    }

    func testFallsBackWhenNameBecomesEmpty() {
        XCTAssertEqual(MetalProbe.cleanedName(" over "), " over ")
    }

    func testFamilyPrefersMetal4() {
        XCTAssertEqual(
            MetalProbe.familyName(supportsMetal4: true, supportsMetal3: true),
            "Metal 4"
        )
    }

    func testFamilyFallsBackToMetal3() {
        XCTAssertEqual(
            MetalProbe.familyName(supportsMetal4: false, supportsMetal3: true),
            "Metal 3"
        )
    }

    func testFamilyIsNilWithoutMetal3() {
        XCTAssertNil(MetalProbe.familyName(supportsMetal4: false, supportsMetal3: false))
    }
}
