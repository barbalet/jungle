import Foundation
import MetalKit
import JungleShared

@MainActor
public final class JungleMetalRenderer: NSObject, MTKViewDelegate {
    public let metalDevice: MTLDevice
    public var snapshot: JungleFrameSnapshot
    public var onMetricsUpdate: ((JungleRendererFrameMetrics) -> Void)?

    private let commandQueue: MTLCommandQueue
    private var renderedFrameCount: UInt64
    private var drawableWidth: Double
    private var drawableHeight: Double

    public init?(snapshot: JungleFrameSnapshot, device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
        guard let metalDevice = device,
              let commandQueue = metalDevice.makeCommandQueue() else {
            return nil
        }

        self.metalDevice = metalDevice
        self.commandQueue = commandQueue
        self.snapshot = snapshot
        renderedFrameCount = 0
        drawableWidth = 0
        drawableHeight = 0
        super.init()
    }

    public func attach(to view: MTKView) {
        view.device = metalDevice
        view.delegate = self
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.framebufferOnly = true
        view.autoResizeDrawable = true
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.06, green: 0.11, blue: 0.08, alpha: 1.0)
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        drawableWidth = size.width
        drawableHeight = size.height
        reportMetrics()
    }

    public func draw(in view: MTKView) {
        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        let pulse = (sin(snapshot.simulatedTimeSeconds * 1.8) + 1.0) * 0.5
        let canopyDepth = min(max(snapshot.cameraHeight / 2.0, 0.0), 1.0)
        let horizonBias = (snapshot.cameraForward.y + 1.0) * 0.5
        let lateralDrift = min(abs(snapshot.cameraPosition.x) * 0.03, 0.18)
        let mist = snapshot.rendererReady ? min(0.10 + snapshot.lastStepSeconds * 3.0, 0.18) : 0.04

        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0.05 + 0.05 * canopyDepth + lateralDrift * 0.3,
            green: 0.10 + 0.18 * pulse + mist + horizonBias * 0.06,
            blue: 0.08 + 0.20 * (1.0 - canopyDepth) + 0.06 * pulse + horizonBias * 0.12,
            alpha: 1.0
        )

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
            encoder.label = "JungleClearPass"
            encoder.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()

        renderedFrameCount += 1
        drawableWidth = view.drawableSize.width
        drawableHeight = view.drawableSize.height

        if renderedFrameCount == 1 || renderedFrameCount.isMultiple(of: 30) {
            reportMetrics()
        }
    }

    private func reportMetrics() {
        let metrics = JungleRendererFrameMetrics(
            renderedFrameCount: renderedFrameCount,
            drawableWidth: drawableWidth,
            drawableHeight: drawableHeight
        )

        onMetricsUpdate?(metrics)
    }
}
