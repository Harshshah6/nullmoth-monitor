import CoreMedia
import Foundation
import Metal
import NullMothOpenGL
import VideoToolbox

/// One capability the driver exposes, and how to read it.
public struct CapabilityItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var value: String
    public var detail: String?

    public init(id: String, name: String, value: String, detail: String? = nil) {
        self.id = id
        self.name = name
        self.value = value
        self.detail = detail
    }
}

/// What the NullMoth driver actually supports on this machine.
public struct CapabilitiesInfo: Codable, Equatable, Sendable {
    public var items: [CapabilityItem]
    public var firmwareVersion: String?

    public init(items: [CapabilityItem] = [], firmwareVersion: String? = nil) {
        self.items = items
        self.firmwareVersion = firmwareVersion
    }
}

/// Reads the capabilities the driver exposes: Metal features, hardware video
/// codecs, OpenGL through Apple's GL-on-Metal, and the GSP firmware version.
public enum CapabilityProbe {
    private static let firmwareRoot = "/Library/NullMoth/nvfw/nvidia"

    public static func capabilities() -> CapabilitiesInfo {
        var items: [CapabilityItem] = []

        if let device = nvidiaDevice() {
            items.append(contentsOf: metalItems(device))
        } else {
            items.append(
                CapabilityItem(
                    id: "metal",
                    name: "Metal device",
                    value: "not found",
                    detail: "No NVIDIA Metal device is registered."
                )
            )
        }

        items.append(
            CapabilityItem(
                id: "opengl",
                name: "OpenGL",
                value: acceleratedRendererAvailable() ? "available" : "unavailable",
                detail: "Apple's GL-on-Metal layer runs OpenGL on the NVIDIA device."
            )
        )

        items.append(contentsOf: videoToolboxItems())

        let firmware = firmwareVersion()
        items.append(
            CapabilityItem(
                id: "firmware",
                name: "GSP firmware",
                value: firmware ?? "not found",
                detail: "The GPU firmware the driver loaded."
            )
        )

        return CapabilitiesInfo(items: items, firmwareVersion: firmware)
    }

    private static func nvidiaDevice() -> MTLDevice? {
        MTLCopyAllDevices().first(where: {
            $0.name.localizedCaseInsensitiveContains("NVIDIA")
        })
    }

    private static func metalItems(_ device: MTLDevice) -> [CapabilityItem] {
        var items: [CapabilityItem] = []

        items.append(
            CapabilityItem(
                id: "metal.device",
                name: "Metal device",
                value: MetalProbe.cleanedName(device.name),
                detail: device.architecture.name
            )
        )

        let tier = device.argumentBuffersSupport == .tier2 ? "tier 2" : "tier 1"
        items.append(
            CapabilityItem(
                id: "metal.argumentBuffers",
                name: "Argument buffers",
                value: tier,
                detail: "Tier 2 enables argument buffer support for all stages."
            )
        )

        items.append(
            CapabilityItem(
                id: "metal.raytracing",
                name: "Ray tracing",
                value: device.supportsRaytracing ? "supported" : "not supported",
                detail: nil
            )
        )

        items.append(
            CapabilityItem(
                id: "metal.mps",
                name: "Metal Performance Shaders",
                value: device.supportsFamily(.metal3) ? "supported" : "not supported",
                detail: "MPS needs the Metal 3 family."
            )
        )

        let location: String
        switch device.location {
        case .builtIn: location = "built in"
        case .slot: location = "PCIe slot"
        case .external: location = "external"
        default: location = "unspecified"
        }
        items.append(
            CapabilityItem(
                id: "metal.location",
                name: "GPU location",
                value: location,
                detail: device.hasUnifiedMemory ? "unified memory" : "dedicated memory"
            )
        )

        items.append(
            CapabilityItem(
                id: "metal.maxBuffer",
                name: "Maximum buffer",
                value: ByteCountFormatter.string(fromByteCount: Int64(device.maxBufferLength), countStyle: .memory),
                detail: nil
            )
        )

        return items
    }

    private static func videoToolboxItems() -> [CapabilityItem] {
        let codecs: [(String, CMVideoCodecType)] = [
            ("H.264", kCMVideoCodecType_H264),
            ("HEVC", kCMVideoCodecType_HEVC),
        ]

        let encoders = hardwareEncoders()

        var items: [CapabilityItem] = []
        for (name, codec) in codecs {
            let decode = VTIsHardwareDecodeSupported(codec)
            let encode = encoders.contains(codec)
            items.append(
                CapabilityItem(
                    id: "video.\(name)",
                    name: "Video \(name)",
                    value: "decode \(decode ? "yes" : "no"), encode \(encode ? "yes" : "no")",
                    detail: "VideoToolbox hardware codecs on the NVIDIA device."
                )
            )
        }
        return items
    }

    private static func hardwareEncoders() -> Set<CMVideoCodecType> {
        var result = Set<CMVideoCodecType>()
        var list: CFArray?
        guard VTCopyVideoEncoderList(nil, &list) == noErr,
              let entries = list as? [[String: Any]] else {
            return result
        }

        for entry in entries {
            let accelerated = (entry[kVTVideoEncoderList_IsHardwareAccelerated as String] as? Bool) ?? false
            guard accelerated,
                  let codec = entry[kVTVideoEncoderList_CodecType as String] as? NSNumber else {
                continue
            }
            result.insert(CMVideoCodecType(codec.uint32Value))
        }
        return result
    }

    private static func acceleratedRendererAvailable() -> Bool {
        nmm_has_accelerated_renderer()
    }

    public static func firmwareVersion() -> String? {
        let contents = try? FileManager.default.contentsOfDirectory(atPath: firmwareRoot)
        guard let versions = contents, !versions.isEmpty else {
            return nil
        }
        return versions.sorted().joined(separator: ", ")
    }
}
