import Foundation
import SwiftUI
import JungleShared

struct JungleRootView: View {
    @ObservedObject var coordinator: JungleEngineCoordinator

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.08, blue: 0.05),
                    Color(red: 0.12, green: 0.17, blue: 0.10),
                    Color(red: 0.19, green: 0.25, blue: 0.17),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("jungle")
                        .font(.system(size: 44, weight: .bold, design: .rounded))

                    Text("Cycle 7: first-person camera online")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.82))
                }

                ZStack(alignment: .topLeading) {
                    viewportSurface

                    VStack(alignment: .leading, spacing: 10) {
                        Text("engine shell")
                            .font(.caption)
                            .fontWeight(.bold)
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.7))

                        Text("The C core now owns a first-person camera with yaw, pitch, movement, and projection state flowing back into the app snapshot.")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text("Use `W A S D` to move, arrow keys to look, and drag inside the viewport for mouse-look.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    .padding(18)
                    .frame(maxWidth: 360, alignment: .leading)
                    .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(18)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(alignment: .top, spacing: 18) {
                    statusCard(
                        title: "Camera",
                        rows: [
                            ("Position", vectorString(coordinator.engineSnapshot.cameraPosition)),
                            ("Forward", vectorString(coordinator.engineSnapshot.cameraForward)),
                            ("Yaw", degreesString(coordinator.engineSnapshot.cameraYawRadians)),
                            ("Pitch", degreesString(coordinator.engineSnapshot.cameraPitchRadians)),
                        ]
                    )

                    statusCard(
                        title: "Projection",
                        rows: [
                            ("Renderer", coordinator.rendererDiagnostics.summary),
                            ("Aspect", String(format: "%.2f", coordinator.engineSnapshot.cameraAspectRatio)),
                            ("FOV", degreesString(coordinator.engineSnapshot.verticalFieldOfViewRadians)),
                            ("Drawable", drawableDescription),
                            ("Rendered", String(coordinator.rendererMetrics.renderedFrameCount)),
                        ]
                    )

                    statusCard(
                        title: "Engine",
                        rows: [
                            ("Version", coordinator.engineVersion),
                            ("Seed", String(coordinator.launchConfiguration.seed)),
                            ("Height", String(format: "%.2f", coordinator.engineSnapshot.cameraHeight)),
                            ("Engine frame", String(coordinator.engineSnapshot.engineFrameIndex)),
                            ("Sim time", secondsString(coordinator.engineSnapshot.simulatedTimeSeconds)),
                            ("Last step", millisecondsString(coordinator.engineSnapshot.lastStepSeconds)),
                            ("Fixed step", millisecondsString(coordinator.timingPolicy.fixedStepSeconds)),
                        ]
                    )
                }
            }
            .padding(26)
        }
        .frame(minWidth: 940, minHeight: 620, alignment: .topLeading)
    }

    private var viewportSurface: some View {
        Group {
            if coordinator.rendererDiagnostics.isAvailable {
                JungleMetalViewport(
                    snapshot: coordinator.engineSnapshot,
                    preferredFramesPerSecond: coordinator.timingPolicy.targetFramesPerSecond,
                    onMetricsUpdate: { metrics in
                        coordinator.recordRendererMetrics(metrics)
                    },
                    onKeyChange: { keyCode, isPressed in
                        coordinator.setKeyPressed(keyCode, isPressed: isPressed)
                    },
                    onLookDelta: { x, y in
                        coordinator.applyLookDelta(x: x, y: y)
                    }
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Metal unavailable")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("A compatible device is required before the viewport can come online.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(24)
                .background(.ultraThinMaterial)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var drawableDescription: String {
        let width = Int(coordinator.rendererMetrics.drawableWidth.rounded())
        let height = Int(coordinator.rendererMetrics.drawableHeight.rounded())

        guard width > 0, height > 0 else {
            return "measuring"
        }

        return "\(width) x \(height)"
    }

    private func millisecondsString(_ seconds: Double) -> String {
        String(format: "%.2f ms", seconds * 1_000.0)
    }

    private func secondsString(_ seconds: Double) -> String {
        String(format: "%.2f s", seconds)
    }

    private func degreesString(_ radians: Double) -> String {
        String(format: "%.1f deg", radians * 180.0 / .pi)
    }

    private func vectorString(_ vector: JungleVector3) -> String {
        String(format: "%.2f, %.2f, %.2f", vector.x, vector.y, vector.z)
    }

    @ViewBuilder
    private func statusCard(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(rows, id: \.0) { label, value in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(label)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.78))

                    Spacer(minLength: 8)

                    Text(value)
                        .foregroundStyle(.white.opacity(0.94))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
