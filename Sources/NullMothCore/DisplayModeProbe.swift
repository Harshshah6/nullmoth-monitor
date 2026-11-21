import AppKit
import CoreGraphics
import Foundation

/// One selectable mode of a display.
public struct DisplayModeInfo: Codable, Equatable, Identifiable, Sendable {
    /// CoreGraphics mode identifier. Can be `0` for modes that are not part of
    /// the IODisplayMode set, in which case the pixel size and refresh rate
    /// identify the mode.
    public var id: UInt32
    /// Pixel width of the rendered image.
    public var width: Int
    /// Pixel height of the rendered image.
    public var height: Int
    /// Logical width in points, which differs from the pixel width on scaled
    /// (HiDPI) displays.
    public var pointWidth: Int
    /// Logical height in points.
    public var pointHeight: Int
    public var refreshRate: Double
    public var isCurrent: Bool
    public var isHiDPI: Bool

    public init(
        id: UInt32,
        width: Int,
        height: Int,
        pointWidth: Int,
        pointHeight: Int,
        refreshRate: Double,
        isCurrent: Bool,
        isHiDPI: Bool
    ) {
        self.id = id
        self.width = width
        self.height = height
        self.pointWidth = pointWidth
        self.pointHeight = pointHeight
        self.refreshRate = refreshRate
        self.isCurrent = isCurrent
        self.isHiDPI = isHiDPI
    }

    public var label: String {
        var text = "\(width)×\(height)"
        if isHiDPI {
            text += " (HiDPI)"
        }
        if refreshRate > 0 {
            text += String(format: " @ %.0f Hz", refreshRate)
        }
        return text
    }
}

/// Every mode the system offers for one online display.
public struct DisplayModeCatalog: Codable, Equatable, Identifiable, Sendable {
    public var displayID: UInt32
    public var displayName: String
    public var isMain: Bool
    public var currentWidth: Int
    public var currentHeight: Int
    public var currentRefreshRate: Double?
    public var modes: [DisplayModeInfo]

    public var id: UInt32 { displayID }

    public init(
        displayID: UInt32,
        displayName: String,
        isMain: Bool,
        currentWidth: Int,
        currentHeight: Int,
        currentRefreshRate: Double?,
        modes: [DisplayModeInfo]
    ) {
        self.displayID = displayID
        self.displayName = displayName
        self.isMain = isMain
        self.currentWidth = currentWidth
        self.currentHeight = currentHeight
        self.currentRefreshRate = currentRefreshRate
        self.modes = modes
    }
}

public enum DisplayModeApplyResult: Equatable, Sendable {
    case applied
    case failed(String)

    public var errorMessage: String? {
        if case .failed(let message) = self {
            return message
        }
        return nil
    }
}

/// Reads the modes macOS offers for each connected display and applies one on
/// request. Changing a display mode is a user-visible session setting: it
/// needs no administrator rights and is reverted by the system on logout.
public enum DisplayModeProbe {
    public static func catalogs() -> [DisplayModeCatalog] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else {
            return []
        }

        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else {
            return []
        }

        let names = screenNames()
        let mainDisplay = CGMainDisplayID()

        return ids.prefix(Int(count)).map { id in
            let current = CGDisplayCopyDisplayMode(id)
            let currentWidth = current?.pixelWidth ?? 0
            let currentHeight = current?.pixelHeight ?? 0
            let currentRefresh = current?.refreshRate ?? 0

            return DisplayModeCatalog(
                displayID: id,
                displayName: names[id] ?? "Display \(id)",
                isMain: id == mainDisplay,
                currentWidth: currentWidth,
                currentHeight: currentHeight,
                currentRefreshRate: currentRefresh > 0 ? currentRefresh : nil,
                modes: modes(for: id, current: current)
            )
        }
    }

    /// Applies a mode to a display. The mode is looked up again in the live
    /// mode list, because CoreGraphics mode objects are only valid while the
    /// list they came from is alive.
    public static func apply(displayID: UInt32, modeID: UInt32) -> DisplayModeApplyResult {
        guard let modes = CGDisplayCopyAllDisplayModes(displayID, nil) as? [CGDisplayMode] else {
            return .failed("The display mode list could not be read.")
        }

        guard let mode = modes.first(where: { UInt32(bitPattern: $0.ioDisplayModeID) == modeID }) else {
            return .failed("That mode is no longer available. Refresh and try again.")
        }

        let error = CGDisplaySetDisplayMode(displayID, mode, nil)
        if error == .success {
            return .applied
        }

        return .failed(describe(error))
    }

    private static func modes(for displayID: CGDirectDisplayID, current: CGDisplayMode?) -> [DisplayModeInfo] {
        guard let rawModes = CGDisplayCopyAllDisplayModes(displayID, nil) as? [CGDisplayMode] else {
            return []
        }

        let currentModeID = current.map { UInt32(bitPattern: $0.ioDisplayModeID) } ?? 0
        let currentWidth = current?.pixelWidth ?? 0
        let currentHeight = current?.pixelHeight ?? 0
        let currentRefresh = current?.refreshRate ?? 0

        var seen = Set<String>()
        var result: [DisplayModeInfo] = []

        for mode in rawModes {
            let pixelWidth = mode.pixelWidth
            let pixelHeight = mode.pixelHeight
            let refresh = mode.refreshRate
            let key = "\(pixelWidth)x\(pixelHeight)@\(String(format: "%.3f", refresh))"

            guard seen.insert(key).inserted else {
                continue
            }

            let isCurrent: Bool
            if currentModeID != 0 {
                isCurrent = UInt32(bitPattern: mode.ioDisplayModeID) == currentModeID
            } else {
                isCurrent = pixelWidth == currentWidth
                    && pixelHeight == currentHeight
                    && abs(refresh - currentRefresh) < 0.001
            }

            result.append(
                DisplayModeInfo(
                    id: UInt32(bitPattern: mode.ioDisplayModeID),
                    width: pixelWidth,
                    height: pixelHeight,
                    pointWidth: mode.width,
                    pointHeight: mode.height,
                    refreshRate: refresh,
                    isCurrent: isCurrent,
                    isHiDPI: mode.pixelWidth != mode.width
                )
            )
        }

        return result.sorted { lhs, rhs in
            if lhs.width != rhs.width { return lhs.width > rhs.width }
            if lhs.height != rhs.height { return lhs.height > rhs.height }
            if lhs.refreshRate != rhs.refreshRate { return lhs.refreshRate < rhs.refreshRate }
            return lhs.id < rhs.id
        }
    }

    private static func screenNames() -> [CGDirectDisplayID: String] {
        var result: [CGDirectDisplayID: String] = [:]
        let key = NSDeviceDescriptionKey("NSScreenNumber")

        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[key] as? NSNumber else {
                continue
            }
            result[number.uint32Value] = screen.localizedName
        }

        return result
    }

    private static func describe(_ error: CGError) -> String {
        switch error.rawValue {
        case 0:
            return "The mode was applied."
        case 1000:
            return "macOS refused to apply that mode."
        case 1001:
            return "The mode was rejected as invalid."
        case 1004:
            return "The mode could not be applied right now."
        case 1006:
            return "That mode cannot be set through this API."
        default:
            return "The mode could not be applied (code \(error.rawValue))."
        }
    }
}
