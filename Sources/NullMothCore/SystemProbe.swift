import Foundation
import Darwin

public enum SystemProbe {
    private static var didReadVRAM = false
    private static var cachedVRAM: UInt64?

    public static func info() -> SystemInfo {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let macOSVersion = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

        return SystemInfo(
            macOSVersion: macOSVersion,
            build: sysctlString("kern.osversion") ?? "unknown",
            architecture: sysctlString("hw.machine") ?? "unknown",
            modelIdentifier: sysctlString("hw.model") ?? "unknown",
            cpu: sysctlString("machdep.cpu.brand_string") ?? "unknown",
            memoryBytes: ProcessInfo.processInfo.physicalMemory
        )
    }

    public static func vramTotalBytes() -> UInt64? {
        if didReadVRAM {
            return cachedVRAM
        }
        didReadVRAM = true
        cachedVRAM = readVRAMFromSystemProfiler()
        return cachedVRAM
    }

    static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
            return nil
        }

        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else {
            return nil
        }
        return String(cString: buffer)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func readVRAMFromSystemProfiler() -> UInt64? {
        let result = Shell.run("/usr/sbin/system_profiler", ["SPDisplaysDataType", "-json"])
        guard result.status == 0,
              let data = result.stdout.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = root["SPDisplaysDataType"] as? [[String: Any]]
        else {
            return nil
        }

        let entry = entries.first(where: {
            ($0["sppci_model"] as? String)?.localizedCaseInsensitiveContains("NVIDIA") == true
        }) ?? entries.first

        guard let value = entry?["spdisplays_vram"] as? String else {
            return nil
        }
        return parseMemoryString(value)
    }

    static func parseMemoryString(_ value: String) -> UInt64? {
        let parts = value.split(whereSeparator: { $0 == " " || $0 == "\t" })
        guard parts.count >= 2, let amount = Double(parts[0]) else {
            return nil
        }

        switch parts[1].uppercased() {
        case "GB":
            return UInt64(amount * 1024 * 1024 * 1024)
        case "MB":
            return UInt64(amount * 1024 * 1024)
        case "KB":
            return UInt64(amount * 1024)
        case "B":
            return UInt64(amount)
        default:
            return nil
        }
    }
}
