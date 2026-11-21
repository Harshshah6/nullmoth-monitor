import Foundation

public enum DriverProbe {
    private static let expectedKexts = [
        "com.nullmoth.NVRM",
        "com.nullmoth.NVAccel",
        "com.nullmoth.NVRMFB",
        "com.nullmoth.NVRMAGDC",
    ]
    private static let requiredBootArguments = [
        "nvfb=1",
        "nvaccel=1",
        "nvfbheads=4",
        "-nvkmsnosmooth",
        "amfi_get_out_of_my_way=0x1",
        "amfi=0x80",
        "ipc_control_port_options=0",
    ]
    private static let forbiddenBootArguments = [
        "nv_disable=1",
        "-wegnoegpu",
    ]

    private static var cachedKexts: [KextInfo] = []
    private static var lastKextRead = Date.distantPast
    private static var cachedSIP: String?
    private static var lastSIPRead = Date.distantPast
    private static var cachedBootArgs: String?
    private static var lastBootArgsRead = Date.distantPast

    public static func info() -> DriverInfo {
        let nvrm = IOKitProbe.properties(ofServiceNamed: "NVRM")
        let bootArguments = bootArgs()
        let diagnostics = bootArgumentDiagnostics(bootArguments)

        return DriverInfo(
            driverVersion: IOKitProbe.string(nvrm, "nvrm-kext-version"),
            pluginInstalled: FileManager.default.fileExists(
                atPath: "/Library/GPUBundles/NVMTLDriver.bundle"
            ),
            pluginVersion: pluginVersion(),
            kexts: kexts(),
            bootArgs: bootArguments,
            missingBootArgs: diagnostics.missing,
            forbiddenBootArgs: diagnostics.forbidden,
            sipStatus: sipStatus(),
            secureBootModel: nil
        )
    }

    static func bootArgumentDiagnostics(
        _ bootArguments: String
    ) -> (missing: [String], forbidden: [String]) {
        let tokens = Set(bootArguments.split(whereSeparator: \.isWhitespace).map(String.init))
        return (
            requiredBootArguments.filter { !tokens.contains($0) },
            forbiddenBootArguments.filter { tokens.contains($0) }
        )
    }

    private static func pluginVersion() -> String? {
        let path = "/Library/GPUBundles/NVMTLDriver.bundle"
        guard let bundle = Bundle(path: path) else {
            return nil
        }
        return bundle.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    private static func bootArgs() -> String {
        if Date().timeIntervalSince(lastBootArgsRead) < 60, let cachedBootArgs {
            return cachedBootArgs
        }

        let result = Shell.run("/usr/sbin/nvram", ["boot-args"])
        var value = ""
        if result.status == 0 {
            let line = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if let range = line.range(of: "boot-args\t") {
                value = String(line[range.upperBound...])
            } else if let range = line.range(of: "boot-args ") {
                value = String(line[range.upperBound...])
            } else {
                value = line
            }
        }

        cachedBootArgs = value
        lastBootArgsRead = Date()
        return value
    }

    private static func sipStatus() -> String {
        if Date().timeIntervalSince(lastSIPRead) < 60, let cachedSIP {
            return cachedSIP
        }

        let result = Shell.run("/usr/bin/csrutil", ["status"])
        let status = parseSIPStatus(result.stdout)

        cachedSIP = status
        lastSIPRead = Date()
        return status
    }

    static func parseSIPStatus(_ output: String) -> String {
        let line = output
            .split(separator: "\n")
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !line.isEmpty else {
            return "unknown"
        }

        if let open = line.lastIndex(of: "("),
           let close = line.lastIndex(of: ")"),
           open < close {
            let inner = line[line.index(after: open)..<close]
                .trimmingCharacters(in: .whitespaces)
            if !inner.isEmpty {
                return inner
            }
        }

        var value = line
        if let range = value.range(of: "status:") {
            value = String(value[range.upperBound...])
        }
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: " ."))
        return value.isEmpty ? "unknown" : value
    }

    private static func kexts() -> [KextInfo] {
        if Date().timeIntervalSince(lastKextRead) < 30, !cachedKexts.isEmpty {
            return cachedKexts
        }

        let result = Shell.run("/usr/bin/kmutil", ["showloaded"])
        var loaded: [String: String] = [:]

        if result.status == 0 {
            let pattern = #"(?m)^\s*\d+\s+\d+\s+0x[0-9a-fA-F]+\s+0x[0-9a-fA-F]+\s+0x[0-9a-fA-F]+\s+(com\.nullmoth\.[A-Za-z0-9_.-]+)\s+\(([^)]*)\)"#
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let text = result.stdout as NSString
                let range = NSRange(location: 0, length: text.length)
                for match in regex.matches(in: result.stdout, range: range) where match.numberOfRanges >= 3 {
                    let identifier = text.substring(with: match.range(at: 1))
                    let version = text.substring(with: match.range(at: 2))
                    loaded[identifier] = version
                }
            }
        }

        let infos = expectedKexts.map { identifier in
            KextInfo(
                identifier: identifier,
                version: loaded[identifier],
                loaded: loaded[identifier] != nil
            )
        }

        cachedKexts = infos
        lastKextRead = Date()
        return infos
    }
}
