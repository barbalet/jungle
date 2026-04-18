import Combine
import Foundation
import JungleCore
import JungleRenderer
import JungleShared

@MainActor
final class JungleEngineCoordinator: ObservableObject {
    private struct JungleControlState {
        var moveForwardPressed = false
        var moveBackwardPressed = false
        var moveLeftPressed = false
        var moveRightPressed = false
        var lookLeftPressed = false
        var lookRightPressed = false
        var lookUpPressed = false
        var lookDownPressed = false
        var accumulatedLookDeltaX = 0.0
        var accumulatedLookDeltaY = 0.0
        var viewportWidth = 1280.0
        var viewportHeight = 720.0

        mutating func setKey(code: UInt16, isPressed: Bool) {
            switch code {
            case 13:
                moveForwardPressed = isPressed
            case 1:
                moveBackwardPressed = isPressed
            case 0:
                moveLeftPressed = isPressed
            case 2:
                moveRightPressed = isPressed
            case 123:
                lookLeftPressed = isPressed
            case 124:
                lookRightPressed = isPressed
            case 126:
                lookUpPressed = isPressed
            case 125:
                lookDownPressed = isPressed
            default:
                break
            }
        }

        mutating func addLookDelta(x: Double, y: Double) {
            accumulatedLookDeltaX += x
            accumulatedLookDeltaY += y
        }

        mutating func updateViewportSize(width: Double, height: Double) {
            guard width > 0, height > 0 else {
                return
            }

            viewportWidth = width
            viewportHeight = height
        }

        mutating func makeInputTemplate(
            appliedSteps: Int,
            fixedStepSeconds: Double,
            keyboardLookSpeedRadiansPerSecond: Double,
            pointerLookRadiansPerPoint: Double
        ) -> jungle_input_state {
            let stepCount = max(appliedSteps, 1)
            let moveForwardAxis = Float(
                (moveForwardPressed ? 1.0 : 0.0) -
                (moveBackwardPressed ? 1.0 : 0.0)
            )
            let moveRightAxis = Float(
                (moveRightPressed ? 1.0 : 0.0) -
                (moveLeftPressed ? 1.0 : 0.0)
            )
            let lookYawAxis =
                (lookRightPressed ? 1.0 : 0.0) -
                (lookLeftPressed ? 1.0 : 0.0)
            let lookPitchAxis =
                (lookUpPressed ? 1.0 : 0.0) -
                (lookDownPressed ? 1.0 : 0.0)
            let keyboardYawPerStep = lookYawAxis *
                keyboardLookSpeedRadiansPerSecond *
                fixedStepSeconds
            let keyboardPitchPerStep = lookPitchAxis *
                keyboardLookSpeedRadiansPerSecond *
                fixedStepSeconds
            let pointerYawPerStep =
                accumulatedLookDeltaX * pointerLookRadiansPerPoint / Double(stepCount)
            let pointerPitchPerStep =
                accumulatedLookDeltaY * pointerLookRadiansPerPoint / Double(stepCount)

            accumulatedLookDeltaX = 0
            accumulatedLookDeltaY = 0

            var input = jungle_input_state()
            input.move_forward = moveForwardAxis
            input.move_right = moveRightAxis
            input.look_yaw = Float(keyboardYawPerStep + pointerYawPerStep)
            input.look_pitch = Float(keyboardPitchPerStep + pointerPitchPerStep)
            input.viewport_width = UInt32(max(Int(viewportWidth.rounded()), 1))
            input.viewport_height = UInt32(max(Int(viewportHeight.rounded()), 1))
            return input
        }
    }

    private final class JungleEngineHandle {
        let pointer: OpaquePointer?

        init(pointer: OpaquePointer?) {
            self.pointer = pointer
        }

        deinit {
            if let pointer {
                jungle_engine_destroy(pointer)
            }
        }
    }

    private final class SimulationLoopHandle {
        var task: Task<Void, Never>?

        deinit {
            task?.cancel()
        }
    }

    @Published private(set) var launchConfiguration: JungleLaunchConfiguration
    @Published private(set) var rendererDiagnostics: JungleRendererDiagnostics
    @Published private(set) var engineVersion: String
    @Published private(set) var engineSnapshot: JungleFrameSnapshot
    @Published private(set) var rendererMetrics: JungleRendererFrameMetrics
    @Published private(set) var timingPolicy: JungleTimingPolicy
    @Published private(set) var timingState: JungleTimingState

    private let engineHandle: JungleEngineHandle
    private let simulationLoopHandle: SimulationLoopHandle
    private let keyboardLookSpeedRadiansPerSecond = Double.pi * 0.8
    private let pointerLookRadiansPerPoint = 0.0035
    private var controlState = JungleControlState()

    private var engine: OpaquePointer? {
        engineHandle.pointer
    }

    init(configuration: JungleLaunchConfiguration = .default) {
        let diagnostics = JungleRendererBootstrap.detectHardware()
        let timingPolicy = JungleTimingPolicy.default
        var config = jungle_engine_config()
        config.seed = configuration.seed
        config.initial_camera_height = configuration.initialCameraHeight

        engineHandle = JungleEngineHandle(pointer: jungle_engine_create(&config))
        simulationLoopHandle = SimulationLoopHandle()
        launchConfiguration = configuration
        rendererDiagnostics = diagnostics
        engineVersion = "unavailable"
        engineSnapshot = .empty
        rendererMetrics = .empty
        self.timingPolicy = timingPolicy
        timingState = .initial

        bootstrapEngine()
        startSimulationLoop()
    }

    private func bootstrapEngine() {
        guard let engine else {
            return
        }

        engineVersion = String(cString: jungle_engine_version())
        refreshSnapshot(using: engine)
    }

    func recordRendererMetrics(_ metrics: JungleRendererFrameMetrics) {
        rendererMetrics = metrics
        controlState.updateViewportSize(
            width: metrics.drawableWidth,
            height: metrics.drawableHeight
        )
    }

    func setKeyPressed(_ keyCode: UInt16, isPressed: Bool) {
        controlState.setKey(code: keyCode, isPressed: isPressed)
    }

    func applyLookDelta(x: Double, y: Double) {
        controlState.addLookDelta(x: x, y: y)
    }

    private func startSimulationLoop() {
        guard simulationLoopHandle.task == nil else {
            return
        }

        let pacingNanoseconds = timingPolicy.pacingIntervalNanoseconds

        simulationLoopHandle.task = Task { [weak self] in
            let clock = ContinuousClock()
            var previous = clock.now

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: pacingNanoseconds)

                guard let self else {
                    return
                }

                let now = clock.now
                let elapsedSeconds = Self.seconds(from: previous.duration(to: now))
                previous = now

                self.advanceSimulation(elapsedSeconds: elapsedSeconds)
            }
        }
    }

    private func advanceSimulation(elapsedSeconds: Double) {
        guard let engine else {
            return
        }

        let plan = JungleTimingPlanner.makePlan(
            policy: timingPolicy,
            currentLagSeconds: timingState.accumulatedLagSeconds,
            elapsedSeconds: elapsedSeconds
        )

        if plan.appliedSteps > 0 {
            let inputTemplate = controlState.makeInputTemplate(
                appliedSteps: plan.appliedSteps,
                fixedStepSeconds: timingPolicy.fixedStepSeconds,
                keyboardLookSpeedRadiansPerSecond: keyboardLookSpeedRadiansPerSecond,
                pointerLookRadiansPerPoint: pointerLookRadiansPerPoint
            )

            for _ in 0..<plan.appliedSteps {
                var input = inputTemplate
                jungle_engine_step(engine, &input, timingPolicy.fixedStepSeconds)
            }

            refreshSnapshot(using: engine)
        }

        timingState = JungleTimingState(
            lastFrameDeltaSeconds: plan.clampedFrameDeltaSeconds,
            accumulatedLagSeconds: plan.remainingLagSeconds,
            appliedStepsLastTick: plan.appliedSteps,
            totalStepCount: timingState.totalStepCount + UInt64(plan.appliedSteps),
            totalSimulatedSeconds: timingState.totalSimulatedSeconds + plan.appliedSimulationSeconds,
            droppedSimulationSeconds: timingState.droppedSimulationSeconds + plan.discardedLagSeconds
        )
    }

    private func refreshSnapshot(using engine: OpaquePointer) {
        var snapshot = jungle_frame_snapshot()
        jungle_engine_snapshot_copy(engine, &snapshot)

        engineSnapshot = JungleFrameSnapshot(
            engineFrameIndex: snapshot.frame_index,
            cameraHeight: snapshot.camera_height,
            cameraPosition: JungleVector3(
                x: snapshot.camera_position.x,
                y: snapshot.camera_position.y,
                z: snapshot.camera_position.z
            ),
            cameraForward: JungleVector3(
                x: snapshot.camera_forward.x,
                y: snapshot.camera_forward.y,
                z: snapshot.camera_forward.z
            ),
            cameraRight: JungleVector3(
                x: snapshot.camera_right.x,
                y: snapshot.camera_right.y,
                z: snapshot.camera_right.z
            ),
            cameraYawRadians: snapshot.camera_yaw_radians,
            cameraPitchRadians: snapshot.camera_pitch_radians,
            cameraAspectRatio: snapshot.camera_aspect_ratio,
            verticalFieldOfViewRadians: snapshot.vertical_field_of_view_radians,
            simulatedTimeSeconds: snapshot.simulated_time_seconds,
            lastStepSeconds: snapshot.last_delta_seconds,
            rendererReady: snapshot.renderer_ready
        )
    }

    private static func seconds(from duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) +
            Double(components.attoseconds) / 1_000_000_000_000_000_000.0
    }
}
