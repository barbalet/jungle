public struct JungleRendererFrameMetrics: Sendable {
    public static let empty = JungleRendererFrameMetrics(
        renderedFrameCount: 0,
        drawableWidth: 0,
        drawableHeight: 0,
        framesPerSecond: 0
    )

    public var renderedFrameCount: UInt64
    public var drawableWidth: Double
    public var drawableHeight: Double
    public var framesPerSecond: Double

    public init(
        renderedFrameCount: UInt64,
        drawableWidth: Double,
        drawableHeight: Double,
        framesPerSecond: Double
    ) {
        self.renderedFrameCount = renderedFrameCount
        self.drawableWidth = drawableWidth
        self.drawableHeight = drawableHeight
        self.framesPerSecond = framesPerSecond
    }
}
