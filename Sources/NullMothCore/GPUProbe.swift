import Foundation

public enum GPUProbe {
    public static func gpuInfo() -> GPUInfo {
        let accelerator = IOKitProbe.properties(ofServiceNamed: "NVAccel")
        let nvrm = IOKitProbe.properties(ofServiceNamed: "NVRM")
        let performance = accelerator["PerformanceStatistics"] as? [String: Any] ?? [:]
        let accumulated = accelerator["PerformanceStatisticsAccum"] as? [String: Any] ?? [:]
        let metal = MetalProbe.info()
        let bars = IOKitProbe.string(nvrm, "nvrm-bars") ?? ""

        return GPUInfo(
            name: metal?.name ?? "NVIDIA GPU",
            driverVersion: IOKitProbe.string(nvrm, "nvrm-kext-version"),
            utilization: IOKitProbe.number(performance, "Device Utilization %"),
            coreUtilization: IOKitProbe.number(performance, "GPU Core Utilization %"),
            memoryUtilization: IOKitProbe.number(performance, "GPU Memory Utilization %"),
            videoEncodeUtilization: IOKitProbe.number(performance, "GPU Video Engine Utilization %"),
            videoDecodeUtilization: IOKitProbe.number(performance, "GPU Video Decode Utilization %"),
            temperatureC: IOKitProbe.number(performance, "Temperature(C)"),
            vramUsedBytes: IOKitProbe.uint64(accumulated, "inUseVidMemoryBytes"),
            vramTotalBytes: SystemProbe.vramTotalBytes(),
            gpuMemoryWindowBytes: IOKitProbe.uint64(accumulated, "gartSizeBytes"),
            bar0: barValue(named: "bar0", in: bars),
            bar1: barValue(named: "bar1", in: bars),
            metalFamily: metal?.family,
            supportsRaytracing: metal?.supportsRaytracing,
            recommendedMaxWorkingSetBytes: metal?.recommendedMaxWorkingSetBytes
        )
    }

    static func barValue(named name: String, in bars: String) -> String? {
        bars
            .split(separator: " ")
            .first(where: { $0.hasPrefix("\(name)@") })
            .map(String.init)
    }
}
