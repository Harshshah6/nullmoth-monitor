import AppKit
import NullMothCore
import SwiftUI

struct MonitorView: View {
    @ObservedObject var store: MonitorStore

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                if let snapshot = store.snapshot {
                    HeaderView(gpu: snapshot.gpu, system: snapshot.system)
                    GPUCard(gpu: snapshot.gpu, history: store.history)
                    DisplaysCard(displays: snapshot.displays)
                    AudioCard(audio: snapshot.audio)
                    DriverCard(driver: snapshot.driver)
                    FooterView(snapshot: snapshot, store: store)
                } else {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Reading the GPU…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                }
            }
            .padding(14)
        }
        .frame(width: 390)
        .frame(maxHeight: 620)
        .background(.regularMaterial)
    }
}

private struct HeaderView: View {
    let gpu: GPUInfo
    let system: SystemInfo

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "memorychip")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)
                .background(
                    .tint.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(gpu.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("Driver \(gpu.driverVersion ?? "—")  ·  macOS \(system.macOSVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Circle()
                .fill(Color.green)
                .frame(width: 7, height: 7)
                .padding(.top, 5)
                .help("Driver is loaded")
        }
    }
}

private struct Card<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.7)
                .foregroundStyle(.secondary)
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .quaternary.opacity(0.45),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

private struct Metric: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }
}

private struct MiniStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.medium))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GPUCard: View {
    let gpu: GPUInfo
    let history: [GPUSample]

    var body: some View {
        Card("GPU") {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(percent(gpu.coreUtilization ?? gpu.utilization))
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("core utilization")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Metric(
                    title: "Temp",
                    value: temperature(gpu.temperatureC),
                    icon: "thermometer.medium",
                    color: temperatureColor(gpu.temperatureC)
                )
                Metric(
                    title: "VRAM",
                    value: bytes(gpu.vramUsedBytes),
                    icon: "memorychip"
                )
            }

            Sparkline(values: history.map { $0.utilization ?? 0 })
                .frame(height: 44)

            HStack(spacing: 8) {
                MiniStat(title: "Memory", value: percent(gpu.memoryUtilization))
                MiniStat(title: "Encode", value: percent(gpu.videoEncodeUtilization))
                MiniStat(title: "Decode", value: percent(gpu.videoDecodeUtilization))
                MiniStat(title: "Metal", value: gpu.metalFamily ?? "—")
            }
        }
    }
}

private struct DisplaysCard: View {
    let displays: [DisplayInfo]

    var body: some View {
        Card("Displays") {
            if displays.isEmpty {
                Text("No online displays")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(displays) { display in
                    HStack(spacing: 8) {
                        Image(systemName: "display")
                            .foregroundStyle(.secondary)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(display.name)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                            Text("\(display.width)×\(display.height) · \(refreshText(display.refreshRate))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 4)

                        if display.isMain {
                            Text("MAIN")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tint)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.tint.opacity(0.12), in: Capsule())
                        }
                    }
                }
            }
        }
    }
}

private struct AudioCard: View {
    let audio: [AudioDeviceInfo]

    var body: some View {
        let nvidia = audio.filter(\.isNVIDIA)
        let defaultOutput = audio.first(where: \.isDefaultOutput)

        Card("Audio") {
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2")
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(nvidia.count) NVIDIA HDMI/DP output(s)")
                        .font(.callout.weight(.medium))
                    Text("Default: \(defaultOutput?.name ?? "unknown")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }

            if nvidia.isEmpty {
                Text("No NVIDIA audio device found")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DriverCard: View {
    let driver: DriverInfo

    var body: some View {
        let loaded = driver.kexts.filter(\.loaded).count

        Card("Driver") {
            HStack {
                Text("Kexts")
                    .font(.callout)
                Spacer()
                Text("\(loaded)/\(driver.kexts.count) loaded")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(loaded == driver.kexts.count ? Color.green : Color.orange)
            }

            ForEach(driver.kexts) { kext in
                HStack(spacing: 6) {
                    Circle()
                        .fill(kext.loaded ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    Text(kext.identifier.replacingOccurrences(of: "com.nullmoth.", with: ""))
                        .font(.caption)
                    Spacer()
                    Text(kext.version ?? "—")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider().opacity(0.4)

            HStack {
                Text("Plugin")
                    .font(.callout)
                Spacer()
                Text(driver.pluginInstalled ? "installed \(driver.pluginVersion ?? "")" : "missing")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(driver.pluginInstalled ? Color.green : Color.red)
            }

            HStack {
                Text("SIP")
                    .font(.callout)
                Spacer()
                Text(driver.sipStatus)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if driver.missingBootArgs.isEmpty && driver.forbiddenBootArgs.isEmpty {
                Label("Boot arguments look complete", systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    if !driver.missingBootArgs.isEmpty {
                        Label(
                            "Missing: \(driver.missingBootArgs.joined(separator: ", "))",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    }
                    if !driver.forbiddenBootArgs.isEmpty {
                        Label(
                            "Remove: \(driver.forbiddenBootArgs.joined(separator: ", "))",
                            systemImage: "xmark.octagon.fill"
                        )
                        .font(.caption2)
                        .foregroundStyle(.red)
                    }
                }
            }
        }
    }
}

private struct FooterView: View {
    let snapshot: MonitorSnapshot
    @ObservedObject var store: MonitorStore

    var body: some View {
        HStack(spacing: 10) {
            Text("Updated \(relative(snapshot.timestamp))")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                store.refresh(force: true)
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh now")

            Button {
                copyReport()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .help("Copy redacted report")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .help("Quit")
        }

        Text("Read-only · no telemetry")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func copyReport() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(snapshot.markdownReport(), forType: .string)
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private func percent(_ value: Double?) -> String {
    guard let value else { return "—" }
    return String(format: "%.0f%%", value)
}

private func temperature(_ value: Double?) -> String {
    guard let value else { return "—" }
    return String(format: "%.0f°", value)
}

private func bytes(_ value: UInt64?) -> String {
    guard let value else { return "—" }
    let formatter = ByteCountFormatter()
    formatter.countStyle = .memory
    return formatter.string(fromByteCount: Int64(value))
}

private func refreshText(_ value: Double?) -> String {
    guard let value else { return "unknown refresh" }
    return String(format: "%.0f Hz", value)
}

private func temperatureColor(_ value: Double?) -> Color {
    guard let value else { return .secondary }
    if value >= 85 { return .red }
    if value >= 70 { return .orange }
    return .green
}
