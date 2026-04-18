public struct JungleTimingPolicy: Sendable {
    public static let `default` = JungleTimingPolicy(
        targetFramesPerSecond: 60,
        fixedStepSeconds: 1.0 / 60.0,
        maximumFrameDeltaSeconds: 0.1,
        maximumCatchUpSteps: 3
    )

    public var targetFramesPerSecond: Int
    public var fixedStepSeconds: Double
    public var maximumFrameDeltaSeconds: Double
    public var maximumCatchUpSteps: Int
    public var maximumRetainedLagSeconds: Double

    public init(
        targetFramesPerSecond: Int,
        fixedStepSeconds: Double,
        maximumFrameDeltaSeconds: Double,
        maximumCatchUpSteps: Int,
        maximumRetainedLagSeconds: Double? = nil
    ) {
        self.targetFramesPerSecond = max(targetFramesPerSecond, 1)
        self.fixedStepSeconds = max(fixedStepSeconds, 1.0 / 240.0)
        self.maximumFrameDeltaSeconds = max(maximumFrameDeltaSeconds, self.fixedStepSeconds)
        self.maximumCatchUpSteps = max(maximumCatchUpSteps, 1)
        self.maximumRetainedLagSeconds = max(maximumRetainedLagSeconds ?? self.fixedStepSeconds, 0)
    }

    public var pacingIntervalNanoseconds: UInt64 {
        UInt64((1_000_000_000.0 / Double(targetFramesPerSecond)).rounded())
    }
}
