import Foundation
import NullMothCore

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

private func percent(_ value: Double?) -> String {
    guard let value else { return "—" }
    return String(format: "%.0f%%", value)
}

private func temperature(_ value: Double?) -> String {
    guard let value else { return "—" }
    return String(format: "%.0f°C", value)
}

private func bytes(_ value: UInt64?) -> String {
    guard let value else { return "—" }
    let formatter = ByteCountFormatter()
    formatter.countStyle = .memory
    return formatter.string(fromByteCount: Int64(value))
}

private func printSummary(_ snapshot: MonitorSnapshot) {
    let gpu = snapshot.gpu
    let driver = snapshot.driver

    print("NullMoth Monitor")
    print("  GPU:          \(gpu.name)")
    print("  Driver:       \(gpu.driverVersion ?? driver.driverVersion ?? "unknown")")
    print("  Metal:        \(gpu.metalFamily ?? "unknown")")
    print("  Utilization:  \(percent(gpu.coreUtilization)) core, \(percent(gpu.memoryUtilization)) memory, \(percent(gpu.videoEncodeUtilization)) encode, \(percent(gpu.videoDecodeUtilization)) decode")
    print("  Temperature:  \(temperature(gpu.temperatureC))")
    print("  VRAM:         \(bytes(gpu.vramUsedBytes)) used / \(bytes(gpu.vramTotalBytes))")
    print("  Displays:     \(snapshot.displays.count)")

    for (index, display) in snapshot.displays.enumerated() {
        let refresh = display.refreshRate.map { String(format: "%.0f Hz", $0) } ?? "unknown refresh"
        print("    \(index + 1). \(display.name) — \(display.width)x\(display.height) @ \(refresh)\(display.isMain ? " (main)" : "")")
    }

    let nvidiaAudio = snapshot.audio.filter(\.isNVIDIA)
    let defaultOutput = snapshot.audio.first(where: \.isDefaultOutput)
    print("  Audio:        \(nvidiaAudio.count) NVIDIA HDMI/DP output(s); default: \(defaultOutput?.name ?? "unknown")")
    print("  Kexts:        \(driver.kexts.filter(\.loaded).count)/\(driver.kexts.count) loaded")
    print("  Plugin:       \(driver.pluginInstalled ? "installed" : "missing") \(driver.pluginVersion ?? "")")
    print("  SIP:          \(driver.sipStatus)")

    if driver.missingBootArgs.isEmpty && driver.forbiddenBootArgs.isEmpty {
        print("  Boot args:    OK")
    } else {
        if !driver.missingBootArgs.isEmpty {
            print("  Boot args:    missing \(driver.missingBootArgs.joined(separator: ", "))")
        }
        if !driver.forbiddenBootArgs.isEmpty {
            print("  Boot args:    remove \(driver.forbiddenBootArgs.joined(separator: ", "))")
        }
    }

    if snapshot.fans.isEmpty {
        print("  Fans:         not exposed by the SMC")
    } else {
        let text = snapshot.fans
            .map { "\($0.index):\(String(format: "%.0f", $0.rpm))rpm" }
            .joined(separator: ", ")
        print("  Fans:         \(text)")
    }
}

private func watch() {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"

    while true {
        let snapshot = MonitorProbe.snapshot()
        let gpu = snapshot.gpu
        let display = snapshot.displays.first(where: \.isMain) ?? snapshot.displays.first
        let displayText = display.map {
            "\($0.width)x\($0.height)@\(String(format: "%.0f", $0.refreshRate ?? 0))"
        } ?? "no display"

        let line = [
            formatter.string(from: Date()),
            "GPU \(percent(gpu.coreUtilization))",
            temperature(gpu.temperatureC),
            bytes(gpu.vramUsedBytes),
            displayText,
            "driver \(gpu.driverVersion ?? "?")",
        ].joined(separator: "  ")

        print(line)
        fflush(stdout)
        Thread.sleep(forTimeInterval: 1.0)
    }
}

private func printHelp() {
    print("""
    nullmoth-mon — read-only monitor for the NullMoth NVIDIA driver

    Usage:
      nullmoth-mon              Human-readable summary
      nullmoth-mon --json       Full snapshot as JSON
      nullmoth-mon --report     Redacted Markdown report
      nullmoth-mon --watch      One compact line per second
      nullmoth-mon --help       Show this help

    The tool only reads IOKit, CoreGraphics, CoreAudio, Metal, SMC, and
    read-only system commands. It never changes OpenCore, kexts, or NVRAM.
    """)
}

let arguments = Array(CommandLine.arguments.dropFirst())
let mode = arguments.first ?? "--summary"

switch mode {
case "--json":
    let snapshot = MonitorProbe.snapshot()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    do {
        let data = try encoder.encode(snapshot)
        guard let text = String(data: data, encoding: .utf8) else {
            fail("Could not encode the snapshot as UTF-8.")
        }
        print(text)
    } catch {
        fail("Could not encode the snapshot: \(error)")
    }

case "--report":
    print(MonitorProbe.snapshot().markdownReport())

case "--watch":
    watch()

case "--help", "-h":
    printHelp()

case "--summary":
    printSummary(MonitorProbe.snapshot())

default:
    fail("Unknown option: \(mode)\nRun nullmoth-mon --help for usage.")
}
