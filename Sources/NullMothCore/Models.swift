import Foundation

public struct GPUSample: Codable, Equatable, Sendable {
    public var timestamp: Date
    public var utilization: Double?
    public var memoryUtilization: Double?
    public var videoEncodeUtilization: Double?
    public var videoDecodeUtilization: Double?
    public var temperatureC: Double?
    public var vramUsedBytes: UInt64?

    public init(
        timestamp: Date = Date(),
        utilization: Double? = nil,
        memoryUtilization: Double? = nil,
        videoEncodeUtilization: Double? = nil,
        videoDecodeUtilization: Double? = nil,
        temperatureC: Double? = nil,
        vramUsedBytes: UInt64? = nil
    ) {
        self.timestamp = timestamp
        self.utilization = utilization
        self.memoryUtilization = memoryUtilization
        self.videoEncodeUtilization = videoEncodeUtilization
        self.videoDecodeUtilization = videoDecodeUtilization
        self.temperatureC = temperatureC
        self.vramUsedBytes = vramUsedBytes
    }
}

public struct GPUInfo: Codable, Equatable, Sendable {
    public var name: String
    public var driverVersion: String?
    public var utilization: Double?
    public var coreUtilization: Double?
    public var memoryUtilization: Double?
    public var videoEncodeUtilization: Double?
    public var videoDecodeUtilization: Double?
    public var temperatureC: Double?
    public var vramUsedBytes: UInt64?
    public var vramTotalBytes: UInt64?
    public var gpuMemoryWindowBytes: UInt64?
    public var bar0: String?
    public var bar1: String?
    public var metalFamily: String?
    public var supportsRaytracing: Bool?
    public var recommendedMaxWorkingSetBytes: UInt64?

    public init(
        name: String,
        driverVersion: String? = nil,
        utilization: Double? = nil,
        coreUtilization: Double? = nil,
        memoryUtilization: Double? = nil,
        videoEncodeUtilization: Double? = nil,
        videoDecodeUtilization: Double? = nil,
        temperatureC: Double? = nil,
        vramUsedBytes: UInt64? = nil,
        vramTotalBytes: UInt64? = nil,
        gpuMemoryWindowBytes: UInt64? = nil,
        bar0: String? = nil,
        bar1: String? = nil,
        metalFamily: String? = nil,
        supportsRaytracing: Bool? = nil,
        recommendedMaxWorkingSetBytes: UInt64? = nil
    ) {
        self.name = name
        self.driverVersion = driverVersion
        self.utilization = utilization
        self.coreUtilization = coreUtilization
        self.memoryUtilization = memoryUtilization
        self.videoEncodeUtilization = videoEncodeUtilization
        self.videoDecodeUtilization = videoDecodeUtilization
        self.temperatureC = temperatureC
        self.vramUsedBytes = vramUsedBytes
        self.vramTotalBytes = vramTotalBytes
        self.gpuMemoryWindowBytes = gpuMemoryWindowBytes
        self.bar0 = bar0
        self.bar1 = bar1
        self.metalFamily = metalFamily
        self.supportsRaytracing = supportsRaytracing
        self.recommendedMaxWorkingSetBytes = recommendedMaxWorkingSetBytes
    }

    public var sample: GPUSample {
        GPUSample(
            timestamp: Date(),
            utilization: utilization,
            memoryUtilization: memoryUtilization,
            videoEncodeUtilization: videoEncodeUtilization,
            videoDecodeUtilization: videoDecodeUtilization,
            temperatureC: temperatureC,
            vramUsedBytes: vramUsedBytes
        )
    }
}

public struct DisplayInfo: Codable, Equatable, Identifiable, Sendable {
    public var id: UInt32
    public var name: String
    public var width: Int
    public var height: Int
    public var refreshRate: Double?
    public var isMain: Bool
    public var isOnline: Bool

    public init(
        id: UInt32,
        name: String,
        width: Int,
        height: Int,
        refreshRate: Double? = nil,
        isMain: Bool = false,
        isOnline: Bool = true
    ) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.refreshRate = refreshRate
        self.isMain = isMain
        self.isOnline = isOnline
    }
}

public struct AudioDeviceInfo: Codable, Equatable, Identifiable, Sendable {
    public var id: UInt32
    public var name: String
    public var manufacturer: String?
    public var outputChannels: Int
    public var isDefaultOutput: Bool
    public var isNVIDIA: Bool

    public init(
        id: UInt32,
        name: String,
        manufacturer: String? = nil,
        outputChannels: Int = 0,
        isDefaultOutput: Bool = false,
        isNVIDIA: Bool = false
    ) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.outputChannels = outputChannels
        self.isDefaultOutput = isDefaultOutput
        self.isNVIDIA = isNVIDIA
    }
}

public struct KextInfo: Codable, Equatable, Identifiable, Sendable {
    public var identifier: String
    public var version: String?
    public var loaded: Bool

    public var id: String { identifier }

    public init(identifier: String, version: String? = nil, loaded: Bool) {
        self.identifier = identifier
        self.version = version
        self.loaded = loaded
    }
}

public struct DriverInfo: Codable, Equatable, Sendable {
    public var driverVersion: String?
    public var pluginInstalled: Bool
    public var pluginVersion: String?
    public var kexts: [KextInfo]
    public var bootArgs: String
    public var missingBootArgs: [String]
    public var forbiddenBootArgs: [String]
    public var sipStatus: String
    public var secureBootModel: String?

    public init(
        driverVersion: String? = nil,
        pluginInstalled: Bool = false,
        pluginVersion: String? = nil,
        kexts: [KextInfo] = [],
        bootArgs: String = "",
        missingBootArgs: [String] = [],
        forbiddenBootArgs: [String] = [],
        sipStatus: String = "unknown",
        secureBootModel: String? = nil
    ) {
        self.driverVersion = driverVersion
        self.pluginInstalled = pluginInstalled
        self.pluginVersion = pluginVersion
        self.kexts = kexts
        self.bootArgs = bootArgs
        self.missingBootArgs = missingBootArgs
        self.forbiddenBootArgs = forbiddenBootArgs
        self.sipStatus = sipStatus
        self.secureBootModel = secureBootModel
    }

    public var allKextsLoaded: Bool {
        !kexts.isEmpty && kexts.allSatisfy(\.loaded)
    }

    public var hasBootArgProblems: Bool {
        !missingBootArgs.isEmpty || !forbiddenBootArgs.isEmpty
    }
}

public struct SystemInfo: Codable, Equatable, Sendable {
    public var macOSVersion: String
    public var build: String
    public var architecture: String
    public var modelIdentifier: String
    public var cpu: String
    public var memoryBytes: UInt64

    public init(
        macOSVersion: String,
        build: String,
        architecture: String,
        modelIdentifier: String,
        cpu: String,
        memoryBytes: UInt64
    ) {
        self.macOSVersion = macOSVersion
        self.build = build
        self.architecture = architecture
        self.modelIdentifier = modelIdentifier
        self.cpu = cpu
        self.memoryBytes = memoryBytes
    }
}

public struct FanInfo: Codable, Equatable, Identifiable, Sendable {
    public var index: Int
    public var rpm: Double

    public var id: Int { index }

    public init(index: Int, rpm: Double) {
        self.index = index
        self.rpm = rpm
    }
}

public struct MonitorSnapshot: Codable, Equatable, Sendable {
    public var timestamp: Date
    public var gpu: GPUInfo
    public var displays: [DisplayInfo]
    public var audio: [AudioDeviceInfo]
    public var driver: DriverInfo
    public var system: SystemInfo
    public var fans: [FanInfo]

    public init(
        timestamp: Date = Date(),
        gpu: GPUInfo,
        displays: [DisplayInfo] = [],
        audio: [AudioDeviceInfo] = [],
        driver: DriverInfo,
        system: SystemInfo,
        fans: [FanInfo] = []
    ) {
        self.timestamp = timestamp
        self.gpu = gpu
        self.displays = displays
        self.audio = audio
        self.driver = driver
        self.system = system
        self.fans = fans
    }
}
