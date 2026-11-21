import Foundation

extension MonitorSnapshot {
    public func markdownReport() -> String {
        var lines: [String] = []
        lines.append("# NullMoth Monitor report")
        lines.append("")
        lines.append("Generated: \(Self.isoFormatter.string(from: timestamp))")
        lines.append("")
        lines.append("This report was generated locally. It contains no serial numbers, UUIDs, or EDIDs.")
        lines.append("")

        lines.append("## System")
        lines.append("")
        lines.append("- macOS: \(system.macOSVersion) (\(system.build))")
        lines.append("- Model: \(system.modelIdentifier)")
        lines.append("- CPU: \(system.cpu)")
        lines.append("- Architecture: \(system.architecture)")
        lines.append("- Memory: \(formatBytes(system.memoryBytes))")
        lines.append("")

        lines.append("## GPU")
        lines.append("")
        lines.append("- Name: \(gpu.name)")
        lines.append("- Driver: \(gpu.driverVersion ?? "unknown")")
        lines.append("- Metal: \(gpu.metalFamily ?? "unknown")")
        lines.append("- Ray tracing: \(gpu.supportsRaytracing.map { $0 ? "yes" : "no" } ?? "unknown")")
        lines.append("- Core utilization: \(formatPercent(gpu.coreUtilization))")
        lines.append("- Memory utilization: \(formatPercent(gpu.memoryUtilization))")
        lines.append("- Video encode: \(formatPercent(gpu.videoEncodeUtilization))")
        lines.append("- Video decode: \(formatPercent(gpu.videoDecodeUtilization))")
        lines.append("- Temperature: \(formatTemperature(gpu.temperatureC))")
        lines.append("- VRAM in use: \(formatBytes(gpu.vramUsedBytes))")
        lines.append("- VRAM total: \(formatBytes(gpu.vramTotalBytes))")
        lines.append("- GPU memory window: \(formatBytes(gpu.gpuMemoryWindowBytes))")
        if let bar0 = gpu.bar0 {
            lines.append("- BAR0: \(bar0)")
        }
        if let bar1 = gpu.bar1 {
            lines.append("- BAR1: \(bar1)")
        }
        lines.append("")

        lines.append("## Displays")
        lines.append("")
        if displays.isEmpty {
            lines.append("No online displays were reported.")
        } else {
            lines.append("| # | Name | Resolution | Refresh | Main |")
            lines.append("|---|---|---|---|---|")
            for (index, display) in displays.enumerated() {
                let refresh = display.refreshRate.map { String(format: "%.2f Hz", $0) } ?? "unknown"
                lines.append(
                    "| \(index + 1) | \(display.name) | \(display.width)x\(display.height) | \(refresh) | \(display.isMain ? "yes" : "no") |"
                )
            }
        }
        lines.append("")

        lines.append("## Audio")
        lines.append("")
        let nvidiaAudio = audio.filter(\.isNVIDIA)
        lines.append("- NVIDIA HDMI/DP outputs: \(nvidiaAudio.count)")
        if let defaultOutput = audio.first(where: \.isDefaultOutput) {
            lines.append("- Default output: \(defaultOutput.name)")
        } else {
            lines.append("- Default output: unknown")
        }
        for device in nvidiaAudio.prefix(8) {
            lines.append("- \(device.name) (\(device.outputChannels) ch)")
        }
        lines.append("")

        lines.append("## Driver")
        lines.append("")
        lines.append("- Kexts loaded: \(driver.kexts.filter(\.loaded).count)/\(driver.kexts.count)")
        for kext in driver.kexts {
            lines.append("  - \(kext.loaded ? "OK" : "MISSING") \(kext.identifier) \(kext.version ?? "")")
        }
        lines.append("- Metal plugin installed: \(driver.pluginInstalled ? "yes" : "no") (\(driver.pluginVersion ?? "unknown"))")
        lines.append("- SIP: \(driver.sipStatus)")
        if let secureBootModel = driver.secureBootModel {
            lines.append("- SecureBootModel: \(secureBootModel)")
        }
        lines.append("")
        lines.append("### Boot arguments")
        lines.append("")
        lines.append("```")
        lines.append(driver.bootArgs.isEmpty ? "(empty)" : driver.bootArgs)
        lines.append("```")
        if !driver.missingBootArgs.isEmpty {
            lines.append("")
            lines.append("Missing: \(driver.missingBootArgs.joined(separator: ", "))")
        }
        if !driver.forbiddenBootArgs.isEmpty {
            lines.append("")
            lines.append("Should be removed: \(driver.forbiddenBootArgs.joined(separator: ", "))")
        }
        lines.append("")

        lines.append("## Fans")
        lines.append("")
        if fans.isEmpty {
            lines.append("No fan sensors were exposed by the SMC on this machine.")
        } else {
            for fan in fans {
                lines.append("- Fan \(fan.index): \(String(format: "%.0f rpm", fan.rpm))")
            }
        }
        lines.append("")

        return lines.joined(separator: "\n")
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private func formatPercent(_ value: Double?) -> String {
        guard let value else { return "unknown" }
        return String(format: "%.0f%%", value)
    }

    private func formatTemperature(_ value: Double?) -> String {
        guard let value else { return "unknown" }
        return String(format: "%.0f C", value)
    }

    private func formatBytes(_ value: UInt64?) -> String {
        guard let value else { return "unknown" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(value))
    }
}
