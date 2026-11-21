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

    func testDetectsMissingArguments() {
        let diagnostics = DriverProbe.bootArgumentDiagnostics("nvfb=1 nvaccel=1")
        XCTAssertEqual(
            diagnostics.missing,
            [
                "nvfbheads=4",
                "-nvkmsnosmooth",
                "amfi_get_out_of_my_way=0x1",
                "amfi=0x80",
                "ipc_control_port_options=0",
            ]
        )
    }

    func testDetectsForbiddenArguments() {
        let diagnostics = DriverProbe.bootArgumentDiagnostics("nvfb=1 nv_disable=1 -wegnoegpu")
        XCTAssertEqual(diagnostics.forbidden, ["nv_disable=1", "-wegnoegpu"])
    }

    func testDoesNotMatchSubstrings() {
        let diagnostics = DriverProbe.bootArgumentDiagnostics("nvfb=10 nvaccel=10")
        XCTAssertTrue(diagnostics.missing.contains("nvfb=1"))
        XCTAssertTrue(diagnostics.missing.contains("nvaccel=1"))
    }

    func testIgnoresExtraWhitespace() {
        let padded = "  nvfb=1   nvaccel=1\nnvfbheads=4  "
        let diagnostics = DriverProbe.bootArgumentDiagnostics(padded)
        XCTAssertFalse(diagnostics.missing.contains("nvfb=1"))
        XCTAssertFalse(diagnostics.missing.contains("nvaccel=1"))
        XCTAssertFalse(diagnostics.missing.contains("nvfbheads=4"))
    }

    func testEmptyBootArgumentsReportEverythingMissing() {
        let diagnostics = DriverProbe.bootArgumentDiagnostics("")
        XCTAssertEqual(diagnostics.missing.count, 7)
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
