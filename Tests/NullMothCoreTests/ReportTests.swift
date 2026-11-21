import XCTest
@testable import NullMothCore

final class ReportTests: XCTestCase {
    private func makeSnapshot() -> MonitorSnapshot {
        MonitorSnapshot(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            gpu: GPUInfo(
                name: "NVIDIA GeForce RTX 3060",
                driverVersion: "3.0",
                utilization: 12,
                coreUtilization: 13,
                memoryUtilization: 2,
                videoEncodeUtilization: 0,
                videoDecodeUtilization: 0,
                temperatureC: 50,
                vramUsedBytes: 467_000_000,
                vramTotalBytes: 12 * 1024 * 1024 * 1024,
                gpuMemoryWindowBytes: 11_453_247_488,
                bar0: "bar0@0x10:0xfb000000+0x1000000",
                bar1: "bar1@0x14:0x7c00000000+0x200000000",
                metalFamily: "Metal 4",
                supportsRaytracing: true,
                recommendedMaxWorkingSetBytes: 9 * 1024 * 1024 * 1024
            ),
            displays: [
                DisplayInfo(
                    id: 1,
                    name: "MSI MP223",
                    width: 1920,
                    height: 1080,
                    refreshRate: 100,
                    isMain: true
                ),
                DisplayInfo(
                    id: 2,
                    name: "LCD-MONITOR",
                    width: 1366,
                    height: 768,
                    refreshRate: 60,
                    isMain: false
                ),
            ],
            audio: [
                AudioDeviceInfo(
                    id: 90,
                    name: "NVIDIA (0x009f) (HDMI/DP 8ch)",
                    manufacturer: "NullMoth",
                    outputChannels: 2,
                    isDefaultOutput: false,
                    isNVIDIA: true
                ),
                AudioDeviceInfo(
                    id: 114,
                    name: "USB PnP Audio Device",
                    manufacturer: "Solid State System Co.,Ltd.",
                    outputChannels: 2,
                    isDefaultOutput: true,
                    isNVIDIA: false
                ),
            ],
            driver: DriverInfo(
                driverVersion: "3.0",
                pluginInstalled: true,
                pluginVersion: "0.1",
                kexts: [
                    KextInfo(identifier: "com.nullmoth.NVRM", version: "3.0", loaded: true),
                    KextInfo(identifier: "com.nullmoth.NVAccel", version: "3.0", loaded: true),
                    KextInfo(identifier: "com.nullmoth.NVRMFB", version: "3.0", loaded: true),
                    KextInfo(identifier: "com.nullmoth.NVRMAGDC", version: "3.0", loaded: true),
                ],
                bootArgs: "nvfb=1 nvaccel=1",
                missingBootArgs: ["nvfbheads=4"],
                forbiddenBootArgs: [],
                sipStatus: "Custom configuration",
                secureBootModel: "Default"
            ),
            system: SystemInfo(
                macOSVersion: "26.7.3",
                build: "25G342",
                architecture: "x86_64",
                modelIdentifier: "MacPro7,1",
                cpu: "AMD Ryzen 5 5600X",
                memoryBytes: 32 * 1024 * 1024 * 1024
            ),
            fans: []
        )
    }

    func testReportContainsCoreSections() {
        let report = makeSnapshot().markdownReport()
        for section in ["## System", "## GPU", "## Displays", "## Audio", "## Driver", "## Fans"] {
            XCTAssertTrue(report.contains(section), "Missing \(section)")
        }
    }

    func testReportIncludesMeasuredValues() {
        let report = makeSnapshot().markdownReport()
        XCTAssertTrue(report.contains("NVIDIA GeForce RTX 3060"))
        XCTAssertTrue(report.contains("Metal 4"))
        XCTAssertTrue(report.contains("50 C"))
        XCTAssertTrue(report.contains("MSI MP223"))
        XCTAssertTrue(report.contains("1920x1080"))
        XCTAssertTrue(report.contains("100.00 Hz"))
        XCTAssertTrue(report.contains("Missing: nvfbheads=4"))
        XCTAssertTrue(report.contains("4/4"))
    }

    func testReportExplainsMissingFans() {
        let report = makeSnapshot().markdownReport()
        XCTAssertTrue(report.contains("No fan sensors were exposed"))
    }

    func testReportStatesPrivacyGuarantee() {
        let report = makeSnapshot().markdownReport()
        XCTAssertTrue(report.contains("contains no serial numbers, UUIDs, or EDIDs"))

        let uuidPattern = #"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"#
        XCTAssertNil(report.range(of: uuidPattern, options: .regularExpression))
    }

    func testReportIsDeterministic() {
        let snapshot = makeSnapshot()
        XCTAssertEqual(snapshot.markdownReport(), snapshot.markdownReport())
    }
}
