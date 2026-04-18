public struct JungleFrameSnapshot: Sendable {
    public static let empty = JungleFrameSnapshot(
        engineFrameIndex: 0,
        cameraHeight: 0,
        cameraPosition: .zero,
        cameraForward: JungleVector3(x: 0, y: 0, z: 1),
        cameraRight: JungleVector3(x: 1, y: 0, z: 0),
        cameraYawRadians: 0,
        cameraPitchRadians: 0,
        cameraAspectRatio: 16.0 / 9.0,
        verticalFieldOfViewRadians: .pi / 3.0,
        simulatedTimeSeconds: 0,
        lastStepSeconds: 0,
        rendererReady: false
    )

    public var engineFrameIndex: UInt64
    public var cameraHeight: Double
    public var cameraPosition: JungleVector3
    public var cameraForward: JungleVector3
    public var cameraRight: JungleVector3
    public var cameraYawRadians: Double
    public var cameraPitchRadians: Double
    public var cameraAspectRatio: Double
    public var verticalFieldOfViewRadians: Double
    public var simulatedTimeSeconds: Double
    public var lastStepSeconds: Double
    public var rendererReady: Bool

    public init(
        engineFrameIndex: UInt64,
        cameraHeight: Double,
        cameraPosition: JungleVector3,
        cameraForward: JungleVector3,
        cameraRight: JungleVector3,
        cameraYawRadians: Double,
        cameraPitchRadians: Double,
        cameraAspectRatio: Double,
        verticalFieldOfViewRadians: Double,
        simulatedTimeSeconds: Double,
        lastStepSeconds: Double,
        rendererReady: Bool
    ) {
        self.engineFrameIndex = engineFrameIndex
        self.cameraHeight = cameraHeight
        self.cameraPosition = cameraPosition
        self.cameraForward = cameraForward
        self.cameraRight = cameraRight
        self.cameraYawRadians = cameraYawRadians
        self.cameraPitchRadians = cameraPitchRadians
        self.cameraAspectRatio = cameraAspectRatio
        self.verticalFieldOfViewRadians = verticalFieldOfViewRadians
        self.simulatedTimeSeconds = simulatedTimeSeconds
        self.lastStepSeconds = lastStepSeconds
        self.rendererReady = rendererReady
    }
}
