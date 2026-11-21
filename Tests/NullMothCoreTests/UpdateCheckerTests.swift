import XCTest
@testable import NullMothCore

final class UpdateCheckerTests: XCTestCase {
    private let payload = """
    {
      "tag_name": "v3.1",
      "name": "1401 and NVIDIA driver 3.1",
      "published_at": "2026-12-01T10:00:00Z",
      "body": "### Fixes\\n- Something",
      "html_url": "https://github.com/nullmoth/nvidia-macos-driver/releases/tag/v3.1",
      "prerelease": false
    }
    """

    func testParsesReleasePayload() throws {
        let release = try XCTUnwrap(
            UpdateChecker.parseReleaseJSON(Data(payload.utf8))
        )

        XCTAssertEqual(release.tag, "v3.1")
        XCTAssertEqual(release.version, "3.1")
        XCTAssertEqual(release.name, "1401 and NVIDIA driver 3.1")
        XCTAssertEqual(release.url, "https://github.com/nullmoth/nvidia-macos-driver/releases/tag/v3.1")
        XCTAssertFalse(release.isPrerelease)
        XCTAssertNotNil(release.publishedAt)
    }

    func testRejectsPayloadWithoutTag() {
        let data = Data("{\"name\": \"no tag\"}".utf8)
        XCTAssertNil(UpdateChecker.parseReleaseJSON(data))
    }

    func testRejectsInvalidJSON() {
        XCTAssertNil(UpdateChecker.parseReleaseJSON(Data("not json".utf8)))
    }

    func testComparesVersions() {
        XCTAssertEqual(UpdateChecker.compare(installed: "3.0", latest: "v3.1"), .updateAvailable)
        XCTAssertEqual(UpdateChecker.compare(installed: "3.0", latest: "3.0"), .upToDate)
        XCTAssertEqual(UpdateChecker.compare(installed: "3.1", latest: "v3.0"), .upToDate)
        XCTAssertEqual(UpdateChecker.compare(installed: "3.0", latest: "3.0.1"), .updateAvailable)
        XCTAssertEqual(UpdateChecker.compare(installed: "3.0", latest: "3"), .upToDate)
    }

    func testUnknownVersionsCannotBeCompared() {
        XCTAssertEqual(UpdateChecker.compare(installed: "3.0", latest: "nightly"), .unknown)
        XCTAssertEqual(UpdateChecker.compare(installed: "", latest: "3.0"), .unknown)
    }

    func testNormalizesVersionPrefix() {
        XCTAssertEqual(UpdateChecker.normalizedVersion("v3.0"), "3.0")
        XCTAssertEqual(UpdateChecker.normalizedVersion("V3.0"), "3.0")
        XCTAssertEqual(UpdateChecker.normalizedVersion(" 3.0 "), "3.0")
    }
}
