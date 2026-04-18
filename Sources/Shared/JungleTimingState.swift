public struct JungleTimingState: Sendable {
    public static let initial = JungleTimingState(
        lastFrameDeltaSeconds: 0,
        accumulatedLagSeconds: 0,
        appliedStepsLastTick: 0,
        totalStepCount: 0,
        totalSimulatedSeconds: 0,
        droppedSimulationSeconds: 0
    )

    public var lastFrameDeltaSeconds: Double
    public var accumulatedLagSeconds: Double
    public var appliedStepsLastTick: Int
    public var totalStepCount: UInt64
    public var totalSimulatedSeconds: Double
    public var droppedSimulationSeconds: Double

    public init(
        lastFrameDeltaSeconds: Double,
        accumulatedLagSeconds: Double,
        appliedStepsLastTick: Int,
        totalStepCount: UInt64,
        totalSimulatedSeconds: Double,
        droppedSimulationSeconds: Double
    ) {
        self.lastFrameDeltaSeconds = lastFrameDeltaSeconds
        self.accumulatedLagSeconds = accumulatedLagSeconds
        self.appliedStepsLastTick = appliedStepsLastTick
        self.totalStepCount = totalStepCount
        self.totalSimulatedSeconds = totalSimulatedSeconds
        self.droppedSimulationSeconds = droppedSimulationSeconds
    }
}
