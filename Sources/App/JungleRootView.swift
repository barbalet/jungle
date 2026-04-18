import Foundation
import SwiftUI
import JungleShared

struct JungleRootView: View {
    @ObservedObject var coordinator: JungleEngineCoordinator

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            viewportSurface
                .ignoresSafeArea()
        }
        .frame(minWidth: 960, minHeight: 680, alignment: .topLeading)
    }

    @ViewBuilder
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
    }
}

struct JungleOverviewPanelView: View {
    @ObservedObject var coordinator: JungleEngineCoordinator

    var body: some View {
        JunglePanelSurface(
            title: "Overview",
            eyebrow: "Cycle 18",
            summary: "The world foundation now reaches the coast: grassland, jungle, and the first beach biome all run behind the clean render window with shoreline state exposed in the detached panels.",
            accent: [
                Color(red: 0.09, green: 0.15, blue: 0.10),
                Color(red: 0.15, green: 0.26, blue: 0.16),
            ]
        ) {
            JunglePanelMessage(text: "Move east to transition from open grassland into denser jungle terrain and eventually flatter beach ground with longer visibility and coastal haze.")
            JunglePanelMessage(text: "Controls: `W A S D` moves, arrow keys look, and dragging in the render window does mouse-look.")
            JunglePanelKeyValueRow(
                label: "Current biome",
                value: coordinator.engineSnapshot.currentBiome.label
            )
            JunglePanelKeyValueRow(
                label: "Weather",
                value: coordinator.engineSnapshot.currentWeather.label
            )
            JunglePanelKeyValueRow(
                label: "Biome blend",
                value: JungleMetricsFormatter.percentString(coordinator.engineSnapshot.biomeBlend)
            )
            JunglePanelKeyValueRow(
                label: "FPS",
                value: String(format: "%.1f", coordinator.rendererMetrics.framesPerSecond)
            )
            JunglePanelKeyValueRow(
                label: "Panels menu",
                value: "Option-Command-1...4"
            )
        }
    }
}

struct JungleCameraPanelView: View {
    @ObservedObject var coordinator: JungleEngineCoordinator

    var body: some View {
        JunglePanelSurface(
            title: "Camera",
            eyebrow: "Traversal + Collision",
            summary: "The camera now rides the procedural terrain floor instead of a fixed flat plane.",
            accent: [
                Color(red: 0.13, green: 0.10, blue: 0.06),
                Color(red: 0.25, green: 0.18, blue: 0.11),
            ]
        ) {
            JunglePanelKeyValueRow(
                label: "Position",
                value: JungleMetricsFormatter.vectorString(coordinator.engineSnapshot.cameraPosition)
            )
            JunglePanelKeyValueRow(
                label: "Forward",
                value: JungleMetricsFormatter.vectorString(coordinator.engineSnapshot.cameraForward)
            )
            JunglePanelKeyValueRow(
                label: "Right",
                value: JungleMetricsFormatter.vectorString(coordinator.engineSnapshot.cameraRight)
            )
            JunglePanelKeyValueRow(
                label: "Yaw",
                value: JungleMetricsFormatter.degreesString(coordinator.engineSnapshot.cameraYawRadians)
            )
            JunglePanelKeyValueRow(
                label: "Pitch",
                value: JungleMetricsFormatter.degreesString(coordinator.engineSnapshot.cameraPitchRadians)
            )
            JunglePanelKeyValueRow(
                label: "Eye height",
                value: String(format: "%.2f u", coordinator.engineSnapshot.eyeHeightUnits)
            )
            JunglePanelKeyValueRow(
                label: "Terrain floor",
                value: String(format: "%.2f u", coordinator.engineSnapshot.cameraFloorHeight)
            )
            JunglePanelKeyValueRow(
                label: "Camera height",
                value: String(format: "%.2f u", coordinator.engineSnapshot.cameraHeight)
            )
        }
    }
}

struct JungleProjectionPanelView: View {
    @ObservedObject var coordinator: JungleEngineCoordinator

    var body: some View {
        JunglePanelSurface(
            title: "Projection",
            eyebrow: "Terrain Patch",
            summary: "The renderer now draws seeded terrain with biome material channels, wetness response, and a brighter coastal atmosphere when shoreline space opens up.",
            accent: [
                Color(red: 0.06, green: 0.12, blue: 0.15),
                Color(red: 0.09, green: 0.21, blue: 0.24),
            ]
        ) {
            JunglePanelKeyValueRow(
                label: "Renderer",
                value: coordinator.rendererDiagnostics.summary
            )
            JunglePanelKeyValueRow(
                label: "Aspect",
                value: String(format: "%.2f", coordinator.engineSnapshot.cameraAspectRatio)
            )
            JunglePanelKeyValueRow(
                label: "FOV",
                value: JungleMetricsFormatter.degreesString(
                    coordinator.engineSnapshot.verticalFieldOfViewRadians
                )
            )
            JunglePanelKeyValueRow(
                label: "Drawable",
                value: JungleMetricsFormatter.drawableDescription(coordinator.rendererMetrics)
            )
            JunglePanelKeyValueRow(
                label: "Rendered",
                value: String(coordinator.rendererMetrics.renderedFrameCount)
            )
            JunglePanelKeyValueRow(
                label: "Visibility",
                value: String(format: "%.1f u", coordinator.engineSnapshot.visibilityDistance)
            )
            JunglePanelKeyValueRow(
                label: "Shoreline",
                value: JungleMetricsFormatter.percentString(coordinator.engineSnapshot.shorelineSpace)
            )
            JunglePanelKeyValueRow(
                label: "Patch",
                value: JungleMetricsFormatter.patchDescription(coordinator.engineSnapshot.terrainPatch)
            )
            JunglePanelKeyValueRow(
                label: "Ambient wetness",
                value: JungleMetricsFormatter.percentString(coordinator.engineSnapshot.ambientWetness)
            )
        }
    }
}

struct JungleEnginePanelView: View {
    @ObservedObject var coordinator: JungleEngineCoordinator

    var body: some View {
        JunglePanelSurface(
            title: "Engine",
            eyebrow: "Config + Simulation",
            summary: "Launch options now include beach starts, while the frame snapshot carries world-scale, terrain-layer, and shoreline data for debugging.",
            accent: [
                Color(red: 0.15, green: 0.08, blue: 0.09),
                Color(red: 0.24, green: 0.12, blue: 0.14),
            ]
        ) {
            JunglePanelKeyValueRow(label: "Version", value: coordinator.engineVersion)
            JunglePanelKeyValueRow(
                label: "Seed",
                value: String(coordinator.launchConfiguration.seed)
            )
            JunglePanelKeyValueRow(
                label: "Graphics",
                value: coordinator.launchConfiguration.graphicsQuality.label
            )
            JunglePanelKeyValueRow(
                label: "Start biome",
                value: coordinator.launchConfiguration.startingBiome.label
            )
            JunglePanelKeyValueRow(
                label: "Detached panels",
                value: JungleMetricsFormatter.toggleString(
                    coordinator.launchConfiguration.debug.detachedPanelsEnabled
                )
            )
            JunglePanelKeyValueRow(
                label: "World scale",
                value: String(format: "%.1f u/m", coordinator.engineSnapshot.worldUnitsPerMeter)
            )
            JunglePanelKeyValueRow(
                label: "Layer heights",
                value: JungleMetricsFormatter.layerHeightDescription(coordinator.engineSnapshot)
            )
            JunglePanelKeyValueRow(
                label: "Sim time",
                value: JungleMetricsFormatter.secondsString(
                    coordinator.engineSnapshot.simulatedTimeSeconds
                )
            )
            JunglePanelKeyValueRow(
                label: "Last step",
                value: JungleMetricsFormatter.millisecondsString(
                    coordinator.engineSnapshot.lastStepSeconds
                )
            )
            JunglePanelKeyValueRow(
                label: "Fixed step",
                value: JungleMetricsFormatter.millisecondsString(
                    coordinator.timingPolicy.fixedStepSeconds
                )
            )
            JunglePanelKeyValueRow(
                label: "Dropped lag",
                value: JungleMetricsFormatter.millisecondsString(
                    coordinator.timingState.droppedSimulationSeconds
                )
            )
        }
    }
}

private struct JunglePanelSurface<Content: View>: View {
    let title: String
    let eyebrow: String
    let summary: String
    let accent: [Color]
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(eyebrow)
                    .font(.caption)
                    .fontWeight(.bold)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.72))

                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
            }

            Divider()
                .overlay(.white.opacity(0.14))

            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: accent,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        )
        .padding(18)
        .frame(minWidth: 320, alignment: .topLeading)
    }
}

private struct JunglePanelMessage: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.9))
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct JunglePanelKeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.78))

            Spacer(minLength: 8)

            Text(value)
                .foregroundStyle(.white.opacity(0.94))
                .multilineTextAlignment(.trailing)
        }
    }
}

private enum JungleMetricsFormatter {
    static func millisecondsString(_ seconds: Double) -> String {
        String(format: "%.2f ms", seconds * 1_000.0)
    }

    static func secondsString(_ seconds: Double) -> String {
        String(format: "%.2f s", seconds)
    }

    static func degreesString(_ radians: Double) -> String {
        String(format: "%.1f deg", radians * 180.0 / .pi)
    }

    static func vectorString(_ vector: JungleVector3) -> String {
        String(format: "%.2f, %.2f, %.2f", vector.x, vector.y, vector.z)
    }

    static func percentString(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100.0)
    }

    static func toggleString(_ value: Bool) -> String {
        value ? "On" : "Off"
    }

    static func drawableDescription(_ metrics: JungleRendererFrameMetrics) -> String {
        let width = Int(metrics.drawableWidth.rounded())
        let height = Int(metrics.drawableHeight.rounded())

        guard width > 0, height > 0 else {
            return "measuring"
        }

        return "\(width) x \(height)"
    }

    static func patchDescription(_ patch: JungleTerrainPatch) -> String {
        guard patch.sampleSide > 0 else {
            return "unavailable"
        }

        return "\(patch.sampleSide)x\(patch.sampleSide) @ \(String(format: "%.1f", patch.spacing))u"
    }

    static func layerHeightDescription(_ snapshot: JungleFrameSnapshot) -> String {
        String(
            format: "%.2f / %.2f / %.2f / %.2f u",
            snapshot.groundCoverHeight,
            snapshot.waistHeight,
            snapshot.headHeight,
            snapshot.canopyHeight
        )
    }
}
