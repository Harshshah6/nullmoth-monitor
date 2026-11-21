import XCTest
@testable import NullMothCore

final class DriverSettingsAuditTests: XCTestCase {
    private let complete = [
        "debug=0x100",
        "keepsyms=1",
        "nvfb=1",
        "nvaccel=1",
        "nvfbheads=4",
        "-nvkmsnosmooth",
        "amfi_get_out_of_my_way=0x1",
        "amfi=0x80",
        "ipc_control_port_options=0",
    ].joined(separator: " ")

    func testCompleteSetupHasNoProblems() {
        let report = DriverSettingsAudit.audit(
            bootArgs: complete,
            csrActiveConfig: "0x430a0000",
            whateverGreenLoaded: false,
            kextsLoaded: 4,
            kextsTotal: 4
        )

        XCTAssertFalse(report.hasProblems)
        XCTAssertEqual(report.suggestedBootArgs, complete)
        XCTAssertEqual(report.csrSatisfied, true)
    }

    func testMissingFramebufferIsReportedAndSuggested() {
        let report = DriverSettingsAudit.audit(bootArgs: "nvaccel=1")

        let finding = report.findings.first { $0.id == "required.nvfb" }
        XCTAssertEqual(finding?.severity, .warning)
        XCTAssertTrue(report.suggestedBootArgs.contains("nvfb=1"))
        XCTAssertTrue(report.hasProblems)
    }

    func testMissingAMFIBypassIsReported() {
        let report = DriverSettingsAudit.audit(bootArgs: "nvfb=1 nvaccel=1")

        let finding = report.findings.first { $0.id == "required.amfi" }
        XCTAssertEqual(finding?.severity, .warning)
    }

    func testOneAMFIBypassIsEnough() {
        let report = DriverSettingsAudit.audit(bootArgs: "nvfb=1 nvaccel=1 -amfipassbeta")

        let finding = report.findings.first { $0.id == "required.amfi" }
        XCTAssertEqual(finding?.severity, .ok)
    }

    func testForbiddenArgumentIsCriticalAndRemovedFromSuggestion() {
        let report = DriverSettingsAudit.audit(bootArgs: "nvfb=1 nvaccel=1 nv_disable=1")

        let finding = report.findings.first { $0.id == "forbidden.nv_disable" }
        XCTAssertEqual(finding?.severity, .critical)
        XCTAssertFalse(report.suggestedBootArgs.contains("nv_disable=1"))
        XCTAssertTrue(report.suggestedBootArgs.contains("nvfb=1"))
    }

    func testWhateverGreenNeedsGfxrst() {
        let report = DriverSettingsAudit.audit(
            bootArgs: complete,
            whateverGreenLoaded: true
        )

        let finding = report.findings.first { $0.id == "conditional.gfxrst" }
        XCTAssertEqual(finding?.severity, .warning)
        XCTAssertTrue(report.suggestedBootArgs.contains("gfxrst=4"))
    }

    func testWhateverGreenCheckIsSkippedWhenNotLoaded() {
        let report = DriverSettingsAudit.audit(
            bootArgs: complete,
            whateverGreenLoaded: false
        )

        XCTAssertNil(report.findings.first { $0.id == "conditional.gfxrst" })
    }

    func testSuggestedBootArgsKeepsUnrelatedArguments() {
        let report = DriverSettingsAudit.audit(bootArgs: "debug=0x100 -v nvfb=1")

        XCTAssertTrue(report.suggestedBootArgs.contains("debug=0x100"))
        XCTAssertTrue(report.suggestedBootArgs.contains("-v"))
    }

    func testParsesLittleEndianCSRValue() {
        XCTAssertEqual(DriverSettingsAudit.parseCSRValue("430a0000"), 0x0000_0A43)
        XCTAssertEqual(DriverSettingsAudit.parseCSRValue("0x430a0000"), 0x0000_0A43)
        XCTAssertEqual(DriverSettingsAudit.parseCSRValue("430A0000"), 0x0000_0A43)
    }

    func testRejectsInvalidCSRValue() {
        XCTAssertNil(DriverSettingsAudit.parseCSRValue(""))
        XCTAssertNil(DriverSettingsAudit.parseCSRValue("430a00"))
        XCTAssertNil(DriverSettingsAudit.parseCSRValue("zzzzzzzz"))
    }

    func testCSRSatisfiesNeedsEveryTestedBit() {
        XCTAssertTrue(DriverSettingsAudit.csrSatisfies(0x0000_0A43))
        XCTAssertFalse(DriverSettingsAudit.csrSatisfies(0x0000_0A40))
        XCTAssertFalse(DriverSettingsAudit.csrSatisfies(0x0000_0000))
    }

    func testUnreadableCSRIsOnlyInformational() {
        let report = DriverSettingsAudit.audit(bootArgs: complete, csrActiveConfig: nil)

        let finding = report.findings.first { $0.id == "csr" }
        XCTAssertEqual(finding?.severity, .info)
        XCTAssertNil(report.csrSatisfied)
    }
}
