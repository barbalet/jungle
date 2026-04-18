public struct JungleFixedStepPlan: Sendable {
    public var clampedFrameDeltaSeconds: Double
    public var appliedSteps: Int
    public var appliedSimulationSeconds: Double
    public var remainingLagSeconds: Double
    public var discardedLagSeconds: Double

    public init(
        clampedFrameDeltaSeconds: Double,
        appliedSteps: Int,
        appliedSimulationSeconds: Double,
        remainingLagSeconds: Double,
        discardedLagSeconds: Double
    ) {
        self.clampedFrameDeltaSeconds = clampedFrameDeltaSeconds
        self.appliedSteps = appliedSteps
        self.appliedSimulationSeconds = appliedSimulationSeconds
        self.remainingLagSeconds = remainingLagSeconds
        self.discardedLagSeconds = discardedLagSeconds
    }
}

public enum JungleTimingPlanner {
    public static func makePlan(
        policy: JungleTimingPolicy,
        currentLagSeconds: Double,
        elapsedSeconds: Double
    ) -> JungleFixedStepPlan {
        let clampedFrameDeltaSeconds = min(
            max(elapsedSeconds, 0),
            policy.maximumFrameDeltaSeconds
        )
        var lagSeconds = max(currentLagSeconds, 0) + clampedFrameDeltaSeconds
        var appliedSteps = 0

        while lagSeconds + 0.000_000_001 >= policy.fixedStepSeconds &&
                appliedSteps < policy.maximumCatchUpSteps {
            lagSeconds -= policy.fixedStepSeconds
            appliedSteps += 1
        }

        let retainedLagSeconds = min(max(lagSeconds, 0), policy.maximumRetainedLagSeconds)
        let discardedLagSeconds = max(lagSeconds - retainedLagSeconds, 0)

        return JungleFixedStepPlan(
            clampedFrameDeltaSeconds: clampedFrameDeltaSeconds,
            appliedSteps: appliedSteps,
            appliedSimulationSeconds: Double(appliedSteps) * policy.fixedStepSeconds,
            remainingLagSeconds: retainedLagSeconds,
            discardedLagSeconds: discardedLagSeconds
        )
    }
}
