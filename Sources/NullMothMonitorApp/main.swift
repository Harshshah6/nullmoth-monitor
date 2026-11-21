import AppKit
import NullMothCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var store: MonitorStore!

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = MonitorStore()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "GPU …"
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 420, height: 640)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: RootView(store: store)
        )

        store.onUpdate = { [weak self] in
            self?.updateStatusItem()
        }
        store.start()

        // Debug aid: `NullMothMonitor --show-control` opens the popover on the
        // control panel tab, which makes screenshots and UI checks easier.
        if CommandLine.arguments.contains("--show-control") {
            store.selectedTab = .control
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.showPopover()
            }
        } else if CommandLine.arguments.contains("--show-monitor") {
            store.selectedTab = .monitor
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.showPopover()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.stop()
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else {
            return
        }

        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showMenu() {
        guard let button = statusItem.button else {
            return
        }

        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Open monitor",
                action: #selector(showMonitor),
                keyEquivalent: "m"
            )
        )
        menu.addItem(
            NSMenuItem(
                title: "Open control panel",
                action: #selector(showControlPanel),
                keyEquivalent: "c"
            )
        )
        menu.addItem(
            NSMenuItem(
                title: "Refresh now",
                action: #selector(refreshNow),
                keyEquivalent: "r"
            )
        )
        menu.addItem(
            NSMenuItem(
                title: "Copy report",
                action: #selector(copyReport),
                keyEquivalent: "k"
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit NullMoth Monitor",
                action: #selector(quit),
                keyEquivalent: "q"
            )
        )
        for item in menu.items {
            item.target = self
        }

        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: button.bounds.height + 4),
            in: button
        )
    }

    @objc private func showMonitor() {
        store.selectedTab = .monitor
        showPopover()
    }

    @objc private func showControlPanel() {
        store.selectedTab = .control
        showPopover()
    }

    @objc private func refreshNow() {
        store.refresh(force: true)
    }

    @objc private func copyReport() {
        guard let report = store.snapshot?.markdownReport() else {
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(report, forType: .string)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func updateStatusItem() {
        statusItem.button?.title = store.menuBarTitle
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
