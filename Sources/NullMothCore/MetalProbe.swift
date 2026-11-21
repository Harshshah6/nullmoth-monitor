import Foundation
import Metal

struct MetalInfo {
    let name: String
    let family: String?
    let supportsRaytracing: Bool?
    let recommendedMaxWorkingSetBytes: UInt64?
}

enum MetalProbe {
    /// `MTLGPUFamily.metal4` only exists in the macOS 26 SDK. The raw value is
    /// part of the Metal ABI, so build against older SDKs and still detect
    /// Metal 4 at runtime on a newer OS.
    private static let metal4Family = MTLGPUFamily(rawValue: 5002)

    static func info() -> MetalInfo? {
        let devices = MTLCopyAllDevices()
        guard let device = devices.first(where: {
            $0.name.localizedCaseInsensitiveContains("NVIDIA")
        }) else {
            return nil
        }

        let supportsMetal4: Bool
        if #available(macOS 26.0, *), let metal4 = metal4Family {
            supportsMetal4 = device.supportsFamily(metal4)
        } else {
            supportsMetal4 = false
        }

        let family = familyName(
            supportsMetal4: supportsMetal4,
            supportsMetal3: device.supportsFamily(.metal3)
        )

        let workingSet = device.recommendedMaxWorkingSetSize

        return MetalInfo(
            name: cleanedName(device.name),
            family: family,
            supportsRaytracing: device.supportsRaytracing,
            recommendedMaxWorkingSetBytes: workingSet > 0 ? workingSet : nil
        )
    }

    /// Map the supported families to the label shown in the app and report.
    static func familyName(supportsMetal4: Bool, supportsMetal3: Bool) -> String? {
        if supportsMetal4 { return "Metal 4" }
        if supportsMetal3 { return "Metal 3" }
        return nil
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
