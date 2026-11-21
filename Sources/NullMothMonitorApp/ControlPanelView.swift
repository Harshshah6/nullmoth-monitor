import AppKit
import NullMothCore
import SwiftUI

/// The control panel tab: display modes, the driver setup audit, the
/// capability report, and the driver update check.
struct ControlPanelView: View {
    @ObservedObject var store: ControlStore
    @ObservedObject var monitor: MonitorStore

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                DisplaysSection(store: store)
                DriverSetupSection(store: store)
                CapabilitiesSection(store: store)
                UpdatesSection(store: store, monitor: monitor)

                if let message = store.statusMessage {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct DisplaysSection: View {
    @ObservedObject var store: ControlStore

    var body: some View {
        SectionCard("Displays") {
            if store.catalogs.isEmpty {
                Text("No online displays were reported.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.catalogs) { catalog in
                    DisplayModeControl(catalog: catalog, store: store)
                    if catalog.id != store.catalogs.last?.id {
                        Divider().opacity(0.4)
                    }
                }

                Text("Changing a mode is a session setting. No administrator rights are needed and nothing is written to disk.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct DisplayModeControl: View {
    let catalog: DisplayModeCatalog
    @ObservedObject var store: ControlStore
    @State private var selection: UInt32?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "display")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                Text(catalog.displayName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)

                if catalog.isMain {
                    Text("MAIN")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.tint.opacity(0.12), in: Capsule())
                }

                Spacer(minLength: 0)
            }

            Picker("Mode", selection: Binding(
                get: { selection ?? catalog.modes.first(where: \.isCurrent)?.id },
                set: { newValue in
                    selection = newValue
                    guard let newValue,
                          let mode = catalog.modes.first(where: { $0.id == newValue }),
                          !mode.isCurrent else {
                        return
                    }
                    store.apply(mode: mode, to: catalog)
                }
            )) {
                ForEach(catalog.modes) { mode in
                    Text(mode.label).tag(Optional(mode.id))
                }
            }
            .labelsHidden()
            .controlSize(.small)

            Text("Now: \(catalog.currentWidth)×\(catalog.currentHeight) · \(refreshText(catalog.currentRefreshRate))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            selection = catalog.modes.first(where: \.isCurrent)?.id
        }
        .onChange(of: catalog.currentWidth) { _, _ in
            selection = catalog.modes.first(where: \.isCurrent)?.id
        }
    }
}

private struct DriverSetupSection: View {
    @ObservedObject var store: ControlStore

    var body: some View {
        SectionCard("Driver setup") {
            if let report = store.settings {
                ForEach(report.findings) { finding in
                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: icon(for: finding.severity))
                            .foregroundStyle(color(for: finding.severity))
                            .frame(width: 14)
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(finding.title)
                                .font(.caption.weight(.medium))
                            Text(finding.detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                }

                if report.suggestedBootArgs != report.bootArgs {
                    Button {
                        store.copySuggestedBootArgs()
                    } label: {
                        Label("Copy suggested boot-args", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Text("The audit only reads. Edit your OpenCore config to apply any change.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                ProgressView().controlSize(.small)
            }
        }
    }

    private func icon(for severity: SettingsFinding.Severity) -> String {
        switch severity {
        case .ok: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }

    private func color(for severity: SettingsFinding.Severity) -> Color {
        switch severity {
        case .ok: return .green
        case .info: return .secondary
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

private struct CapabilitiesSection: View {
    @ObservedObject var store: ControlStore

    var body: some View {
        SectionCard("Capabilities") {
            if let capabilities = store.capabilities {
                ForEach(capabilities.items) { item in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let detail = item.detail, !detail.isEmpty {
                                Text(detail)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Spacer(minLength: 8)

                        Text(item.value)
                            .font(.caption.weight(.medium))
                            .multilineTextAlignment(.trailing)
                    }
                }
            } else {
                ProgressView().controlSize(.small)
            }
        }
    }
}

private struct UpdatesSection: View {
    @ObservedObject var store: ControlStore
    @ObservedObject var monitor: MonitorStore

    private var installedVersion: String? {
        monitor.snapshot?.gpu.driverVersion ?? monitor.snapshot?.driver.driverVersion
    }

    var body: some View {
        SectionCard("Driver updates") {
            HStack {
                Text("Installed")
                    .font(.callout)
                Spacer()
                Text(installedVersion ?? "unknown")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            switch store.updateState {
            case .idle:
                Button {
                    store.checkForUpdates(installedVersion: installedVersion)
                } label: {
                    Label("Check for updates", systemImage: "arrow.down.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

            case .checking:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Asking GitHub…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

            case .finished(let result):
                switch result {
                case .upToDate(let release):
                    Label("Up to date (\(release.version))", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Button {
                        store.open(release.url)
                    } label: {
                        Label("Open release page", systemImage: "safari")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                case .updateAvailable(let installed, let release):
                    Label(
                        "Version \(release.version) is available (installed: \(installed))",
                        systemImage: "arrow.up.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                    Button {
                        store.open(release.url)
                    } label: {
                        Label("Open release page", systemImage: "safari")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Text("The 1401 app installs driver updates. This app never downloads or installs anything.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                case .failed(let message):
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        store.checkForUpdates(installedVersion: installedVersion)
                    } label: {
                        Label("Try again", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Text("The check only asks GitHub for the latest release. Nothing is downloaded, and nothing else is sent.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

private struct SectionCard<Content: View>: View {
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

private func refreshText(_ value: Double?) -> String {
    guard let value else { return "unknown refresh" }
    return String(format: "%.0f Hz", value)
}
