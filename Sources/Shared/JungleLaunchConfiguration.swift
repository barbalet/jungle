public enum JungleGraphicsQuality: UInt32, CaseIterable, Sendable {
    case low = 0
    case medium = 1
    case high = 2

    public var label: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }
}

public enum JungleBiomeSelection: UInt32, CaseIterable, Sendable {
    case automatic = 0
    case grassland = 1
    case jungle = 2
    case beach = 3

    public var label: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .grassland:
            return "Grassland"
        case .jungle:
            return "Jungle"
        case .beach:
            return "Beach"
        }
    }
}

public struct JungleDebugConfiguration: Sendable {
    public static let `default` = JungleDebugConfiguration()

    public var detachedPanelsEnabled: Bool
    public var emphasizeBiomeBlend: Bool
    public var showScaleReference: Bool

    public init(
        detachedPanelsEnabled: Bool = true,
        emphasizeBiomeBlend: Bool = false,
        showScaleReference: Bool = false
    ) {
        self.detachedPanelsEnabled = detachedPanelsEnabled
        self.emphasizeBiomeBlend = emphasizeBiomeBlend
        self.showScaleReference = showScaleReference
    }
}

public struct JungleLaunchConfiguration: Sendable {
    public static let `default` = JungleLaunchConfiguration()

    public var seed: UInt64
    public var initialCameraHeight: Double
    public var graphicsQuality: JungleGraphicsQuality
    public var startingBiome: JungleBiomeSelection
    public var debug: JungleDebugConfiguration

    public init(
        seed: UInt64 = 1,
        initialCameraHeight: Double = 1.7,
        graphicsQuality: JungleGraphicsQuality = .medium,
        startingBiome: JungleBiomeSelection = .automatic,
        debug: JungleDebugConfiguration = .default
    ) {
        self.seed = seed
        self.initialCameraHeight = initialCameraHeight
        self.graphicsQuality = graphicsQuality
        self.startingBiome = startingBiome
        self.debug = debug
    }
}
