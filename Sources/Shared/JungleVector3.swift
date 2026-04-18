public struct JungleVector3: Sendable {
    public static let zero = JungleVector3(x: 0, y: 0, z: 0)

    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}
