public struct JungleRendererDiagnostics: Sendable {
    public var backend: String
    public var deviceName: String
    public var isAvailable: Bool

    public init(backend: String, deviceName: String, isAvailable: Bool) {
        self.backend = backend
        self.deviceName = deviceName
        self.isAvailable = isAvailable
    }

    public var summary: String {
        if isAvailable {
            return "\(backend) on \(deviceName)"
        }

        return "\(backend) unavailable"
    }
}
