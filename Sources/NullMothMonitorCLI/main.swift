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

private func printDoctor() {
    let report = DriverProbe.settingsReport()

    print("NullMoth Monitor — driver setup")
    print("  csr-active-config: \(report.csrActiveConfig ?? "unreadable")")
    print("  WhateverGreen:     \(report.whateverGreenLoaded ? "loaded" : "not loaded")")
    print("")

    for finding in report.findings {
        let marker: String
        switch finding.severity {
        case .ok: marker = "ok      "
        case .info: marker = "info    "
        case .warning: marker = "warning "
        case .critical: marker = "critical"
        }
        print("  [\(marker)] \(finding.title)")
        print("            \(finding.detail)")
    }

    print("")
    print("  Current boot-args:")
    print("    \(report.bootArgs.isEmpty ? "(empty)" : report.bootArgs)")
    if report.suggestedBootArgs != report.bootArgs {
        print("  Suggested boot-args:")
        print("    \(report.suggestedBootArgs)")
    }
}

private func printModes() {
    let catalogs = DisplayModeProbe.catalogs()

    if catalogs.isEmpty {
        print("No online displays were reported.")
        return
    }

    for catalog in catalogs {
        let refresh = catalog.currentRefreshRate.map { String(format: "%.0f Hz", $0) } ?? "unknown"
        print("\(catalog.displayName)\(catalog.isMain ? " (main)" : "") — \(catalog.currentWidth)×\(catalog.currentHeight) @ \(refresh)")
        for mode in catalog.modes {
            let marker = mode.isCurrent ? "*" : " "
            print("  \(marker) \(mode.label)")
        }
    }
}

private func printCapabilities() {
    let capabilities = CapabilityProbe.capabilities()

    print("NullMoth Monitor — driver capabilities")
    for item in capabilities.items {
        print("  \(item.name): \(item.value)")
        if let detail = item.detail, !detail.isEmpty {
            print("      \(detail)")
        }
    }
}

private func checkForUpdate() {
    let snapshot = MonitorProbe.snapshot()
    let installed = snapshot.gpu.driverVersion ?? snapshot.driver.driverVersion

    print("Checking the NullMoth release feed…")
    let semaphore = DispatchSemaphore(value: 0)
    var result: UpdateCheckResult = .failed("The check did not finish.")

    Task {
        result = await UpdateChecker.checkDriver(installedVersion: installed)
        semaphore.signal()
    }
    semaphore.wait()

    switch result {
    case .upToDate(let release):
        print("Installed driver \(release.version) is up to date.")
        if let published = release.publishedAt {
            print("Published \(published).")
        }
        print(release.url)
    case .updateAvailable(let installed, let release):
        print("Driver \(installed) is installed; \(release.version) is available.")
        print(release.url)
    case .failed(let message):
        fail("The update check failed: \(message)")
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
      nullmoth-mon --doctor     Audit the driver setup against the NullMoth docs
      nullmoth-mon --modes      List the display modes macOS offers
      nullmoth-mon --capabilities  Report what the driver supports
      nullmoth-mon --check-update  Ask GitHub for the latest driver release
      nullmoth-mon --help       Show this help

    The tool reads IOKit, CoreGraphics, CoreAudio, Metal, SMC, and read-only
    system commands. It never changes OpenCore, kexts, or NVRAM. The only
    network request is the update check, which happens when you ask for it.
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

case "--doctor":
    printDoctor()

case "--modes":
    printModes()

case "--capabilities":
    printCapabilities()

case "--check-update":
    checkForUpdate()

case "--help", "-h":
    printHelp()

case "--summary":
    printSummary(MonitorProbe.snapshot())

default:
    fail("Unknown option: \(mode)\nRun nullmoth-mon --help for usage.")
}
