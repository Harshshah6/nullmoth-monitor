import AppKit
import Combine
import Foundation
import NullMothCore

/// Holds the state of the control panel: display modes, the driver setup
/// audit, the capability report, and the result of an update check.
final class ControlStore: ObservableObject {
    enum UpdateState: Equatable {
        case idle
        case checking
        case finished(UpdateCheckResult)
    }

    @Published private(set) var catalogs: [DisplayModeCatalog] = []
    @Published private(set) var settings: DriverSettingsReport?
    @Published private(set) var capabilities: CapabilitiesInfo?
    @Published private(set) var updateState: UpdateState = .idle
    @Published var statusMessage: String?

    private let queue = DispatchQueue(
        label: "io.github.nullmothmonitor.control",
        qos: .userInitiated
    )

    func load() {
        queue.async { [weak self] in
            let catalogs = DisplayModeProbe.catalogs()
            let settings = DriverProbe.settingsReport()
            let capabilities = CapabilityProbe.capabilities()

            DispatchQueue.main.async {
                guard let self else { return }
                self.catalogs = catalogs
                self.settings = settings
                self.capabilities = capabilities
            }
        }
    }

    func refreshDisplays() {
        queue.async { [weak self] in
            let catalogs = DisplayModeProbe.catalogs()
            DispatchQueue.main.async { [weak self] in
                self?.catalogs = catalogs
            }
        }
    }

    func apply(mode: DisplayModeInfo, to display: DisplayModeCatalog) {
        let result = DisplayModeProbe.apply(displayID: display.displayID, modeID: mode.id)

        switch result {
        case .applied:
            statusMessage = "\(display.displayName) is now \(mode.label)."
        case .failed(let message):
            statusMessage = message
        }

        refreshDisplays()
    }

    func checkForUpdates(installedVersion: String?) {
        updateState = .checking

        Task { [weak self] in
            let result = await UpdateChecker.checkDriver(installedVersion: installedVersion)
            await MainActor.run { [weak self] in
                self?.updateState = .finished(result)
            }
        }
    }

    func copySuggestedBootArgs() {
        guard let settings, !settings.suggestedBootArgs.isEmpty else {
            statusMessage = "There is nothing to copy."
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(settings.suggestedBootArgs, forType: .string)
        statusMessage = "The suggested boot-args are on the clipboard."
    }

    func open(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
