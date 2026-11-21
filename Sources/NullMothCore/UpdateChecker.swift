import Foundation

/// A published release of the NullMoth driver.
public struct DriverReleaseInfo: Codable, Equatable, Sendable {
    public var tag: String
    public var version: String
    public var name: String?
    public var publishedAt: Date?
    public var notes: String?
    public var url: String
    public var isPrerelease: Bool

    public init(
        tag: String,
        version: String,
        name: String? = nil,
        publishedAt: Date? = nil,
        notes: String? = nil,
        url: String,
        isPrerelease: Bool = false
    ) {
        self.tag = tag
        self.version = version
        self.name = name
        self.publishedAt = publishedAt
        self.notes = notes
        self.url = url
        self.isPrerelease = isPrerelease
    }
}

public enum UpdateCheckResult: Codable, Equatable, Sendable {
    case upToDate(DriverReleaseInfo)
    case updateAvailable(installed: String, latest: DriverReleaseInfo)
    case failed(String)
}

/// Checks whether a newer NullMoth driver has been published.
///
/// The check is always explicit: the app and the CLI only reach the network
/// when the user asks for it. Nothing is downloaded, installed, or written.
/// The only request is a read-only call to the public GitHub releases API.
public enum UpdateChecker {
    public static let driverRepository = "nullmoth/nvidia-macos-driver"
    public static let monitorRepository = "Harshshah6/nullmoth-monitor"

    public enum Comparison: Equatable, Sendable {
        case upToDate
        case updateAvailable
        case unknown
    }

    public static func checkDriver(
        installedVersion: String?,
        session: URLSession = .shared
    ) async -> UpdateCheckResult {
        await check(
            repository: driverRepository,
            installedVersion: installedVersion,
            session: session
        )
    }

    public static func check(
        repository: String,
        installedVersion: String?,
        session: URLSession = .shared
    ) async -> UpdateCheckResult {
        do {
            let release = try await latestRelease(repository: repository, session: session)
            guard let installed = installedVersion, !installed.isEmpty else {
                return .failed("The installed version could not be read.")
            }

            switch compare(installed: installed, latest: release.version) {
            case .updateAvailable:
                return .updateAvailable(installed: installed, latest: release)
            case .upToDate:
                return .upToDate(release)
            case .unknown:
                return .failed("The installed version \(installed) could not be compared with \(release.version).")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    public static func latestRelease(
        repository: String,
        session: URLSession = .shared
    ) async throws -> DriverReleaseInfo {
        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            throw UpdateError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("NullMothMonitor", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw UpdateError.httpStatus(http.statusCode)
        }

        guard let release = parseReleaseJSON(data) else {
            throw UpdateError.unreadableResponse
        }

        return release
    }

    /// Reads the fields the app needs from a GitHub release payload.
    public static func parseReleaseJSON(_ data: Data, repository: String = driverRepository) -> DriverReleaseInfo? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        guard let tag = object["tag_name"] as? String, !tag.isEmpty else {
            return nil
        }

        let version = normalizedVersion(tag)

        return DriverReleaseInfo(
            tag: tag,
            version: version,
            name: object["name"] as? String,
            publishedAt: parseDate(object["published_at"] as? String),
            notes: object["body"] as? String,
            url: object["html_url"] as? String ?? "https://github.com/\(repository)",
            isPrerelease: object["prerelease"] as? Bool ?? false
        )
    }

    /// Compares two version strings such as `3.0` and `v3.1`.
    public static func compare(installed: String, latest: String) -> Comparison {
        let installedParts = versionParts(installed)
        let latestParts = versionParts(latest)

        guard !installedParts.isEmpty, !latestParts.isEmpty else {
            return .unknown
        }

        let count = max(installedParts.count, latestParts.count)
        for index in 0..<count {
            let left = index < installedParts.count ? installedParts[index] : 0
            let right = index < latestParts.count ? latestParts[index] : 0
            if left != right {
                return right > left ? .updateAvailable : .upToDate
            }
        }

        return .upToDate
    }

    public static func normalizedVersion(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("v") || value.hasPrefix("V") {
            value.removeFirst()
        }
        return value
    }

    private static func versionParts(_ raw: String) -> [Int] {
        let value = normalizedVersion(raw)
        let core = value.split(separator: "-").first.map(String.init) ?? value
        return core.split(separator: ".").compactMap { Int($0) }
    }

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }

    public enum UpdateError: LocalizedError {
        case invalidURL
        case httpStatus(Int)
        case unreadableResponse

        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "The GitHub URL could not be built."
            case .httpStatus(let code):
                return "GitHub answered with status \(code)."
            case .unreadableResponse:
                return "The release information could not be read."
            }
        }
    }
}
