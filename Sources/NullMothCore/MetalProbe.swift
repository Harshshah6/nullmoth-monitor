import Foundation
import Metal

struct MetalInfo {
    let name: String
    let family: String?
    let supportsRaytracing: Bool?
    let recommendedMaxWorkingSetBytes: UInt64?
}

enum MetalProbe {
    static func info() -> MetalInfo? {
        let devices = MTLCopyAllDevices()
        guard let device = devices.first(where: {
            $0.name.localizedCaseInsensitiveContains("NVIDIA")
        }) else {
            return nil
        }

        let family: String?
        if #available(macOS 26.0, *), device.supportsFamily(.metal4) {
            family = "Metal 4"
        } else if device.supportsFamily(.metal3) {
            family = "Metal 3"
        } else {
            family = nil
        }

        let workingSet = device.recommendedMaxWorkingSetSize

        return MetalInfo(
            name: cleanedName(device.name),
            family: family,
            supportsRaytracing: device.supportsRaytracing,
            recommendedMaxWorkingSetBytes: workingSet > 0 ? workingSet : nil
        )
    }

    /// The Metal name reported through the NullMoth translator looks like
    /// "NVMTL over NVIDIA GeForce RTX 3060 (NVK GA106-A)". Keep the card name
    /// and drop the translator/backend decoration.
    static func cleanedName(_ raw: String) -> String {
        var name = raw

        if let range = name.range(of: " over ") {
            name = String(name[range.upperBound...])
        }
        if let range = name.range(of: " (NVK", options: .backwards) {
            name = String(name[..<range.lowerBound])
        }

        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? raw : trimmed
    }
}
