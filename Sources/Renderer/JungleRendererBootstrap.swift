import Metal
import JungleShared

public enum JungleRendererBootstrap {
    public static func detectHardware() -> JungleRendererDiagnostics {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return JungleRendererDiagnostics(
                backend: "Metal",
                deviceName: "No compatible device detected",
                isAvailable: false
            )
        }

        return JungleRendererDiagnostics(
            backend: "Metal",
            deviceName: device.name,
            isAvailable: true
        )
    }
}
