public enum JungleBiomeKind: UInt32, Sendable {
    case grassland = 1
    case jungle = 2
    case beach = 3

    public init(cValue: UInt32) {
        self = JungleBiomeKind(rawValue: cValue) ?? .grassland
    }

    public var label: String {
        switch self {
        case .grassland:
            return "Grassland"
        case .jungle:
            return "Jungle"
        case .beach:
            return "Beach"
        }
    }
}

public enum JungleWeatherKind: UInt32, Sendable {
    case clearBreeze = 1
    case humidCanopy = 2
    case coastalHaze = 3

    public init(cValue: UInt32) {
        self = JungleWeatherKind(rawValue: cValue) ?? .clearBreeze
    }

    public var label: String {
        switch self {
        case .clearBreeze:
            return "Clear breeze"
        case .humidCanopy:
            return "Humid canopy"
        case .coastalHaze:
            return "Coastal haze"
        }
    }
}

public struct JungleMaterialChannel: Sendable {
    public static let zero = JungleMaterialChannel(
        red: 0,
        green: 0,
        blue: 0,
        alpha: 0,
        motion: 0,
        wetnessResponse: 0
    )

    public var red: Float
    public var green: Float
    public var blue: Float
    public var alpha: Float
    public var motion: Float
    public var wetnessResponse: Float

    public init(
        red: Float,
        green: Float,
        blue: Float,
        alpha: Float,
        motion: Float,
        wetnessResponse: Float
    ) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
        self.motion = motion
        self.wetnessResponse = wetnessResponse
    }
}

public struct JungleTerrainSample: Sendable {
    public var position: JungleVector3
    public var groundCover: Float
    public var waist: Float
    public var head: Float
    public var canopy: Float
    public var wetness: Float

    public init(
        position: JungleVector3,
        groundCover: Float,
        waist: Float,
        head: Float,
        canopy: Float,
        wetness: Float
    ) {
        self.position = position
        self.groundCover = groundCover
        self.waist = waist
        self.head = head
        self.canopy = canopy
        self.wetness = wetness
    }
}

public struct JungleTerrainPatch: Sendable {
    public static let empty = JungleTerrainPatch(
        sampleSide: 0,
        spacing: 0,
        center: .zero,
        samples: []
    )

    public var sampleSide: Int
    public var spacing: Double
    public var center: JungleVector3
    public var samples: [JungleTerrainSample]

    public init(
        sampleSide: Int,
        spacing: Double,
        center: JungleVector3,
        samples: [JungleTerrainSample]
    ) {
        self.sampleSide = sampleSide
        self.spacing = spacing
        self.center = center
        self.samples = samples
    }
}

public struct JungleMatrix4x4: Sendable {
    public static let identity = JungleMatrix4x4(elements: [
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    ])

    public var elements: [Float]

    public init(elements: [Float]) {
        if elements.count == 16 {
            self.elements = elements
        } else {
            self.elements = JungleMatrix4x4.identity.elements
        }
    }
}

public struct JungleFrameSnapshot: Sendable {
    public static let empty = JungleFrameSnapshot(
        engineFrameIndex: 0,
        cameraHeight: 0,
        cameraFloorHeight: 0,
        cameraPosition: .zero,
        cameraForward: JungleVector3(x: 0, y: 0, z: 1),
        cameraRight: JungleVector3(x: 1, y: 0, z: 0),
        cameraYawRadians: 0,
        cameraPitchRadians: 0,
        cameraAspectRatio: 16.0 / 9.0,
        verticalFieldOfViewRadians: .pi / 3.0,
        simulatedTimeSeconds: 0,
        lastStepSeconds: 0,
        rendererReady: false,
        currentBiome: .grassland,
        currentWeather: .clearBreeze,
        biomeBlend: 0,
        worldUnitsPerMeter: 1,
        eyeHeightUnits: 1.7,
        groundCoverHeight: 0.35,
        waistHeight: 1.1,
        headHeight: 1.8,
        canopyHeight: 4.8,
        visibilityDistance: 64,
        ambientWetness: 0.2,
        shorelineSpace: 0,
        terrainPatch: .empty,
        groundMaterial: .zero,
        groundCoverMaterial: .zero,
        waistMaterial: .zero,
        headMaterial: .zero,
        canopyMaterial: .zero,
        viewMatrix: .identity,
        projectionMatrix: .identity
    )

    public var engineFrameIndex: UInt64
    public var cameraHeight: Double
    public var cameraFloorHeight: Double
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
    public var currentBiome: JungleBiomeKind
    public var currentWeather: JungleWeatherKind
    public var biomeBlend: Double
    public var worldUnitsPerMeter: Double
    public var eyeHeightUnits: Double
    public var groundCoverHeight: Double
    public var waistHeight: Double
    public var headHeight: Double
    public var canopyHeight: Double
    public var visibilityDistance: Double
    public var ambientWetness: Double
    public var shorelineSpace: Double
    public var terrainPatch: JungleTerrainPatch
    public var groundMaterial: JungleMaterialChannel
    public var groundCoverMaterial: JungleMaterialChannel
    public var waistMaterial: JungleMaterialChannel
    public var headMaterial: JungleMaterialChannel
    public var canopyMaterial: JungleMaterialChannel
    public var viewMatrix: JungleMatrix4x4
    public var projectionMatrix: JungleMatrix4x4

    public init(
        engineFrameIndex: UInt64,
        cameraHeight: Double,
        cameraFloorHeight: Double,
        cameraPosition: JungleVector3,
        cameraForward: JungleVector3,
        cameraRight: JungleVector3,
        cameraYawRadians: Double,
        cameraPitchRadians: Double,
        cameraAspectRatio: Double,
        verticalFieldOfViewRadians: Double,
        simulatedTimeSeconds: Double,
        lastStepSeconds: Double,
        rendererReady: Bool,
        currentBiome: JungleBiomeKind,
        currentWeather: JungleWeatherKind,
        biomeBlend: Double,
        worldUnitsPerMeter: Double,
        eyeHeightUnits: Double,
        groundCoverHeight: Double,
        waistHeight: Double,
        headHeight: Double,
        canopyHeight: Double,
        visibilityDistance: Double,
        ambientWetness: Double,
        shorelineSpace: Double,
        terrainPatch: JungleTerrainPatch,
        groundMaterial: JungleMaterialChannel,
        groundCoverMaterial: JungleMaterialChannel,
        waistMaterial: JungleMaterialChannel,
        headMaterial: JungleMaterialChannel,
        canopyMaterial: JungleMaterialChannel,
        viewMatrix: JungleMatrix4x4,
        projectionMatrix: JungleMatrix4x4
    ) {
        self.engineFrameIndex = engineFrameIndex
        self.cameraHeight = cameraHeight
        self.cameraFloorHeight = cameraFloorHeight
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
        self.currentBiome = currentBiome
        self.currentWeather = currentWeather
        self.biomeBlend = biomeBlend
        self.worldUnitsPerMeter = worldUnitsPerMeter
        self.eyeHeightUnits = eyeHeightUnits
        self.groundCoverHeight = groundCoverHeight
        self.waistHeight = waistHeight
        self.headHeight = headHeight
        self.canopyHeight = canopyHeight
        self.visibilityDistance = visibilityDistance
        self.ambientWetness = ambientWetness
        self.shorelineSpace = shorelineSpace
        self.terrainPatch = terrainPatch
        self.groundMaterial = groundMaterial
        self.groundCoverMaterial = groundCoverMaterial
        self.waistMaterial = waistMaterial
        self.headMaterial = headMaterial
        self.canopyMaterial = canopyMaterial
        self.viewMatrix = viewMatrix
        self.projectionMatrix = projectionMatrix
    }
}
