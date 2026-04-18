public struct JungleLaunchConfiguration: Sendable {
    public static let `default` = JungleLaunchConfiguration()

    public var seed: UInt64
    public var initialCameraHeight: Double

    public init(seed: UInt64 = 1, initialCameraHeight: Double = 1.7) {
        self.seed = seed
        self.initialCameraHeight = initialCameraHeight
    }
}
