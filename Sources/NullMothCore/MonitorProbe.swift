import Foundation

public enum MonitorProbe {
    public static func snapshot() -> MonitorSnapshot {
        MonitorSnapshot(
            gpu: GPUProbe.gpuInfo(),
            displays: DisplayProbe.displays(),
            audio: AudioProbe.devices(),
            driver: DriverProbe.info(),
            system: SystemProbe.info(),
            fans: SMCProbe.fans()
        )
    }
}
