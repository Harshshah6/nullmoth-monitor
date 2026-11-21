import AppKit
import CoreGraphics
import Foundation

public enum DisplayProbe {
    public static func displays() -> [DisplayInfo] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else {
            return []
        }

        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else {
            return []
        }

        let mainDisplay = CGMainDisplayID()
        let names = screenNames()

        return ids.prefix(Int(count)).enumerated().map { index, id in
            let mode = CGDisplayCopyDisplayMode(id)
            let width = mode?.pixelWidth ?? 0
            let height = mode?.pixelHeight ?? 0
            let refresh = mode?.refreshRate ?? 0

            return DisplayInfo(
                id: id,
                name: names[id] ?? "Display \(index + 1)",
                width: width,
                height: height,
                refreshRate: refresh > 0 ? refresh : nil,
                isMain: id == mainDisplay,
                isOnline: CGDisplayIsOnline(id) != 0
            )
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
}
