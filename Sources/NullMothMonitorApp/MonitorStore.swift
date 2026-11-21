import AppKit
import Combine
import Foundation
import NullMothCore

final class MonitorStore: ObservableObject {
    enum PanelTab: String, CaseIterable, Identifiable {
        case monitor = "Monitor"
        case control = "Control"

        var id: String { rawValue }
    }

    @Published private(set) var snapshot: MonitorSnapshot?
    @Published private(set) var history: [GPUSample] = []
    @Published private(set) var lastError: String?
    @Published var isPaused = false
    @Published var selectedTab: PanelTab = .monitor

    var onUpdate: (() -> Void)?

    private var timer: Timer?
    private var lastRefresh = Date.distantPast
    private let maxHistory = 300
    private let probeQueue = DispatchQueue(
        label: "io.github.nullmothmonitor.probe",
        qos: .utility
    )
    private var isSampling = false

    func start() {
        refresh(force: true)
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh(force: Bool) {
        let now = Date()
        if !force, now.timeIntervalSince(lastRefresh) < 0.8 {
            return
        }
        guard !isSampling else {
            return
        }
        lastRefresh = now
        isSampling = true

        probeQueue.async { [weak self] in
            let fresh = MonitorProbe.snapshot()
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.isSampling = false
                self.snapshot = fresh
                self.lastError = nil

                self.history.append(fresh.gpu.sample)
                if self.history.count > self.maxHistory {
                    self.history.removeFirst(self.history.count - self.maxHistory)
                }

                self.onUpdate?()
            }
        }
    }

    var menuBarTitle: String {
        guard let gpu = snapshot?.gpu else {
            return "GPU …"
        }

        var parts: [String] = []
        if let utilization = gpu.coreUtilization ?? gpu.utilization {
            parts.append(String(format: "GPU %.0f%%", utilization))
        } else {
            parts.append("GPU —")
        }
        if let temperature = gpu.temperatureC {
            parts.append(String(format: "%.0f°", temperature))
        }
        return parts.joined(separator: " · ")
    }

    private func tick() {
        guard !isPaused else {
            return
        }
        refresh(force: false)
    }
}
