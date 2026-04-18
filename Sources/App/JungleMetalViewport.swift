import AppKit
import MetalKit
import SwiftUI
import JungleRenderer
import JungleShared

@MainActor
struct JungleMetalViewport: NSViewRepresentable {
    var snapshot: JungleFrameSnapshot
    var preferredFramesPerSecond: Int
    var onMetricsUpdate: (JungleRendererFrameMetrics) -> Void
    var onKeyChange: (UInt16, Bool) -> Void
    var onLookDelta: (Double, Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            snapshot: snapshot,
            onMetricsUpdate: onMetricsUpdate,
            onKeyChange: onKeyChange,
            onLookDelta: onLookDelta
        )
    }

    func makeNSView(context: Context) -> JungleInteractiveMetalView {
        let view = JungleInteractiveMetalView(
            frame: .zero,
            device: context.coordinator.renderer.metalDevice
        )
        context.coordinator.attach(to: view)
        view.preferredFramesPerSecond = preferredFramesPerSecond
        view.onKeyChange = onKeyChange
        view.onLookDelta = onLookDelta
        return view
    }

    func updateNSView(_ nsView: JungleInteractiveMetalView, context: Context) {
        context.coordinator.onMetricsUpdate = onMetricsUpdate
        context.coordinator.onKeyChange = onKeyChange
        context.coordinator.onLookDelta = onLookDelta
        context.coordinator.renderer.snapshot = snapshot
        nsView.preferredFramesPerSecond = preferredFramesPerSecond
        nsView.onKeyChange = onKeyChange
        nsView.onLookDelta = onLookDelta
        context.coordinator.bindMetrics()
    }

    @MainActor
    final class Coordinator {
        let renderer: JungleMetalRenderer
        var onMetricsUpdate: (JungleRendererFrameMetrics) -> Void
        var onKeyChange: (UInt16, Bool) -> Void
        var onLookDelta: (Double, Double) -> Void

        init(
            snapshot: JungleFrameSnapshot,
            onMetricsUpdate: @escaping (JungleRendererFrameMetrics) -> Void,
            onKeyChange: @escaping (UInt16, Bool) -> Void,
            onLookDelta: @escaping (Double, Double) -> Void
        ) {
            guard let renderer = JungleMetalRenderer(snapshot: snapshot) else {
                fatalError("Metal renderer requires a compatible Metal device")
            }

            self.renderer = renderer
            self.onMetricsUpdate = onMetricsUpdate
            self.onKeyChange = onKeyChange
            self.onLookDelta = onLookDelta
            bindMetrics()
        }

        func attach(to view: JungleInteractiveMetalView) {
            renderer.attach(to: view)
            view.onKeyChange = onKeyChange
            view.onLookDelta = onLookDelta
            bindMetrics()
        }

        func bindMetrics() {
            renderer.onMetricsUpdate = onMetricsUpdate
        }
    }
}

@MainActor
final class JungleInteractiveMetalView: MTKView {
    var onKeyChange: ((UInt16, Bool) -> Void)?
    var onLookDelta: ((Double, Double) -> Void)?

    private var previousDragLocation: NSPoint?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        previousDragLocation = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        if let previousDragLocation {
            onLookDelta?(
                Double(location.x - previousDragLocation.x),
                Double(location.y - previousDragLocation.y)
            )
        }

        previousDragLocation = location
    }

    override func mouseUp(with event: NSEvent) {
        previousDragLocation = nil
    }

    override func keyDown(with event: NSEvent) {
        if !event.isARepeat {
            onKeyChange?(event.keyCode, true)
        }
    }

    override func keyUp(with event: NSEvent) {
        onKeyChange?(event.keyCode, false)
    }
}
