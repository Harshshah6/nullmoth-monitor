import XCTest
@testable import NullMothCore

final class DriverProbeTests: XCTestCase {
    private let complete = """
    debug=0x100 -dbgenhdbg keepsyms=1 -amfipassbeta revpatch=sbvmm nvfb=1 nvaccel=1 \
    nvfbheads=4 -nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 \
    ipc_control_port_options=0 gfxrst=4 -v
    """

    func testCompleteBootArgumentsProduceNoProblems() {
        let diagnostics = DriverProbe.bootArgumentDiagnostics(complete)
        XCTAssertTrue(diagnostics.missing.isEmpty)
        XCTAssertTrue(diagnostics.forbidden.isEmpty)
    }

    func testDetectsMissingEnableArguments() {
        let diagnostics = DriverProbe.bootArgumentDiagnostics("-amfipassbeta")
        XCTAssertEqual(diagnostics.missing, ["nvfb=1", "nvaccel=1"])
    }

    func testDetectsMissingAMFIBypass() {
        let diagnostics = DriverProbe.bootArgumentDiagnostics("nvfb=1 nvaccel=1")
        XCTAssertEqual(diagnostics.missing.count, 1)
        XCTAssertTrue(diagnostics.missing[0].hasPrefix("AMFI bypass"))
    }

    func testAnyAMFIBypassArgumentIsAccepted() {
        for bypass in ["amfi_get_out_of_my_way=0x1", "amfi=0x80", "-amfipassbeta"] {
            let diagnostics = DriverProbe.bootArgumentDiagnostics("nvfb=1 nvaccel=1 \(bypass)")
            XCTAssertTrue(diagnostics.missing.isEmpty, "\(bypass) should satisfy AMFI check")
        }
    }

    func testDetectsForbiddenArguments() {
        let diagnostics = DriverProbe.bootArgumentDiagnostics(
            "nvfb=1 nvaccel=1 -amfipassbeta nv_disable=1 -wegnoegpu"
        )
        XCTAssertEqual(diagnostics.forbidden, ["nv_disable=1", "-wegnoegpu"])
    }

    func testDoesNotMatchSubstrings() {
        let diagnostics = DriverProbe.bootArgumentDiagnostics(
            "nvfb=10 nvaccel=10 -amfipassbeta"
        )
        XCTAssertTrue(diagnostics.missing.contains("nvfb=1"))
        XCTAssertTrue(diagnostics.missing.contains("nvaccel=1"))
    }

    func testIgnoresExtraWhitespace() {
        let padded = "  nvfb=1   nvaccel=1\n-amfipassbeta  "
        let diagnostics = DriverProbe.bootArgumentDiagnostics(padded)
        XCTAssertTrue(diagnostics.missing.isEmpty)
    }

    func testEmptyBootArgumentsReportEverythingMissing() {
        let diagnostics = DriverProbe.bootArgumentDiagnostics("")
        XCTAssertEqual(diagnostics.missing.count, 3)
        XCTAssertTrue(diagnostics.forbidden.isEmpty)
    }

    func testParsesCustomSIPStatus() {
        let output = "System Integrity Protection status: unknown (Custom Configuration).\n"
        XCTAssertEqual(DriverProbe.parseSIPStatus(output), "Custom Configuration")
    }

    func testParsesEnabledSIPStatus() {
        XCTAssertEqual(
            DriverProbe.parseSIPStatus("System Integrity Protection status: enabled."),
            "enabled"
        )
    }

    func testParsesDisabledSIPStatus() {
        XCTAssertEqual(
            DriverProbe.parseSIPStatus("System Integrity Protection status: disabled."),
            "disabled"
        )
    }

    func testParsesEmptySIPStatus() {
        XCTAssertEqual(DriverProbe.parseSIPStatus(""), "unknown")
    }
}
