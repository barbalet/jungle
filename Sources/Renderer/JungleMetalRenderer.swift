import Foundation
import MetalKit
import QuartzCore
import simd
import JungleShared

@MainActor
public final class JungleMetalRenderer: NSObject, MTKViewDelegate {
    private struct TerrainVertex {
        var position: SIMD3<Float>
        var color: SIMD4<Float>
        var motion: Float
    }

    private struct TerrainUniforms {
        var viewProjectionMatrix: simd_float4x4
        var cameraPositionAndTime: SIMD4<Float>
        var skyColorAndVisibility: SIMD4<Float>
        var atmosphereControls: SIMD4<Float>
    }

    private enum TerrainLayerKind {
        case ground
        case understory
        case midstory
        case canopy
    }

    private struct TerrainLayerDefinition {
        var kind: TerrainLayerKind
        var isOpaque: Bool
        var heightScale: Float
        var parallaxDepth: Float
        var lateralDrift: Float
        var alphaScale: Float
    }

    private struct TerrainPayload {
        var layer: TerrainLayerDefinition
        var vertexBuffer: MTLBuffer
        var indexBuffer: MTLBuffer
        var indexCount: Int
    }

    private static let terrainLayers: [TerrainLayerDefinition] = [
        TerrainLayerDefinition(
            kind: .ground,
            isOpaque: true,
            heightScale: 0.0,
            parallaxDepth: 0.0,
            lateralDrift: 0.0,
            alphaScale: 1.0
        ),
        TerrainLayerDefinition(
            kind: .understory,
            isOpaque: false,
            heightScale: 0.74,
            parallaxDepth: 0.10,
            lateralDrift: 0.05,
            alphaScale: 0.44
        ),
        TerrainLayerDefinition(
            kind: .midstory,
            isOpaque: false,
            heightScale: 0.58,
            parallaxDepth: 0.22,
            lateralDrift: 0.09,
            alphaScale: 0.34
        ),
        TerrainLayerDefinition(
            kind: .canopy,
            isOpaque: false,
            heightScale: 0.46,
            parallaxDepth: 0.36,
            lateralDrift: 0.14,
            alphaScale: 0.28
        ),
    ]

    private static let debugLayerLiftMultiplier: Float = 5.0

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct TerrainVertexIn {
        float3 position [[attribute(0)]];
        float4 color [[attribute(1)]];
        float motion [[attribute(2)]];
    };

    struct TerrainUniforms {
        float4x4 viewProjectionMatrix;
        float4 cameraPositionAndTime;
        float4 skyColorAndVisibility;
        float4 atmosphereControls;
    };

    struct TerrainRasterizerData {
        float4 position [[position]];
        float4 color;
        float3 worldPosition;
    };

    vertex TerrainRasterizerData jungleTerrainVertex(
        TerrainVertexIn in [[stage_in]],
        constant TerrainUniforms &uniforms [[buffer(1)]]
    ) {
        TerrainRasterizerData out;
        float time = uniforms.cameraPositionAndTime.w;
        float wind = sin((in.position.x * 0.05f) + (in.position.z * 0.04f) + time * 0.9f);
        float3 animatedPosition = in.position;
        animatedPosition.y += wind * in.motion * 0.06f;
        out.position = uniforms.viewProjectionMatrix * float4(animatedPosition, 1.0f);
        out.color = in.color;
        out.worldPosition = animatedPosition;
        return out;
    }

    fragment float4 jungleTerrainFragment(
        TerrainRasterizerData in [[stage_in]],
        constant TerrainUniforms &uniforms [[buffer(0)]]
    ) {
        float visibilityDistance = max(uniforms.skyColorAndVisibility.w, 1.0f);
        float distanceToCamera = distance(in.worldPosition, uniforms.cameraPositionAndTime.xyz);
        float fogStart = visibilityDistance * clamp(uniforms.atmosphereControls.x, 0.05f, 0.9f);
        float fogRange = max(visibilityDistance - fogStart, 1.0f);
        float fogProgress = saturate((distanceToCamera - fogStart) / fogRange);
        fogProgress = smoothstep(0.0f, 1.0f, fogProgress);
        float fog = pow(fogProgress, max(uniforms.atmosphereControls.y, 0.35f));
        float contrastAmount = mix(1.0f, uniforms.atmosphereControls.z, fogProgress);
        float3 contrastPivot = float3(0.42f);
        float3 contrasted = saturate((in.color.rgb - contrastPivot) * contrastAmount + contrastPivot);
        float3 atmosphereColor = mix(
            uniforms.skyColorAndVisibility.rgb * 0.84f,
            uniforms.skyColorAndVisibility.rgb,
            saturate(uniforms.atmosphereControls.w)
        );
        float3 color = mix(contrasted, atmosphereColor, fog);
        float alpha = saturate(in.color.a * mix(1.0f, 0.74f, fogProgress));
        return float4(color, alpha);
    }
    """

    private static func makePipelineState(
        device: MTLDevice,
        vertexFunction: MTLFunction,
        fragmentFunction: MTLFunction,
        vertexDescriptor: MTLVertexDescriptor,
        blendingEnabled: Bool
    ) -> MTLRenderPipelineState? {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = blendingEnabled ? "JungleTerrainAlphaPipeline" : "JungleTerrainSolidPipeline"
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.vertexDescriptor = vertexDescriptor
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.depthAttachmentPixelFormat = .depth32Float

        if blendingEnabled {
            let attachment = descriptor.colorAttachments[0]
            attachment?.isBlendingEnabled = true
            attachment?.rgbBlendOperation = .add
            attachment?.alphaBlendOperation = .add
            attachment?.sourceRGBBlendFactor = .sourceAlpha
            attachment?.sourceAlphaBlendFactor = .one
            attachment?.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }

        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }

    private static func makeDepthStencilState(
        device: MTLDevice,
        writeEnabled: Bool
    ) -> MTLDepthStencilState? {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.isDepthWriteEnabled = writeEnabled
        descriptor.depthCompareFunction = writeEnabled ? .less : .lessEqual
        return device.makeDepthStencilState(descriptor: descriptor)
    }

    public let metalDevice: MTLDevice
    public var snapshot: JungleFrameSnapshot
    public var onMetricsUpdate: ((JungleRendererFrameMetrics) -> Void)?

    private let commandQueue: MTLCommandQueue
    private let solidPipelineState: MTLRenderPipelineState
    private let alphaPipelineState: MTLRenderPipelineState
    private let solidDepthStencilState: MTLDepthStencilState
    private let alphaDepthStencilState: MTLDepthStencilState
    private var renderedFrameCount: UInt64
    private var drawableWidth: Double
    private var drawableHeight: Double
    private var framesPerSecond: Double
    private var lastMetricsTimestamp: CFTimeInterval
    private var lastMetricsFrameCount: UInt64
    private var cachedIndexBuffers: [Int: (buffer: MTLBuffer, indexCount: Int)] = [:]

    public init?(snapshot: JungleFrameSnapshot, device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
        guard let metalDevice = device,
              let commandQueue = metalDevice.makeCommandQueue(),
              let library = try? metalDevice.makeLibrary(source: Self.shaderSource, options: nil),
              let vertexFunction = library.makeFunction(name: "jungleTerrainVertex"),
              let fragmentFunction = library.makeFunction(name: "jungleTerrainFragment") else {
            return nil
        }

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[2].format = .float
        vertexDescriptor.attributes[2].offset =
            MemoryLayout<SIMD3<Float>>.stride + MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.attributes[2].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<TerrainVertex>.stride

        guard let solidPipelineState = Self.makePipelineState(
                device: metalDevice,
                vertexFunction: vertexFunction,
                fragmentFunction: fragmentFunction,
                vertexDescriptor: vertexDescriptor,
                blendingEnabled: false
              ),
              let alphaPipelineState = Self.makePipelineState(
                device: metalDevice,
                vertexFunction: vertexFunction,
                fragmentFunction: fragmentFunction,
                vertexDescriptor: vertexDescriptor,
                blendingEnabled: true
              ) else {
            return nil
        }

        guard let solidDepthStencilState = Self.makeDepthStencilState(device: metalDevice, writeEnabled: true),
              let alphaDepthStencilState = Self.makeDepthStencilState(device: metalDevice, writeEnabled: false) else {
            return nil
        }

        self.metalDevice = metalDevice
        self.commandQueue = commandQueue
        self.solidPipelineState = solidPipelineState
        self.alphaPipelineState = alphaPipelineState
        self.solidDepthStencilState = solidDepthStencilState
        self.alphaDepthStencilState = alphaDepthStencilState
        self.snapshot = snapshot
        renderedFrameCount = 0
        drawableWidth = 0
        drawableHeight = 0
        framesPerSecond = 0
        lastMetricsTimestamp = CACurrentMediaTime()
        lastMetricsFrameCount = 0
        super.init()
    }

    public func attach(to view: MTKView) {
        view.device = metalDevice
        view.delegate = self
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.framebufferOnly = true
        view.autoResizeDrawable = true
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor = MTLClearColor(red: 0.06, green: 0.11, blue: 0.08, alpha: 1.0)
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        drawableWidth = size.width
        drawableHeight = size.height
        reportMetrics(force: true)
    }

    public func draw(in view: MTKView) {
        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        let skyColor = skyColor(for: snapshot)
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: Double(skyColor.x),
            green: Double(skyColor.y),
            blue: Double(skyColor.z),
            alpha: 1.0
        )
        descriptor.depthAttachment.loadAction = .clear
        descriptor.depthAttachment.storeAction = .dontCare
        descriptor.depthAttachment.clearDepth = 1.0

        if let terrainPayloads = makeTerrainPayloads(),
           let uniformBuffer = makeUniformBuffer(skyColor: skyColor) {
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
            encoder?.label = "JungleTerrainLayerPass"
            encoder?.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
            encoder?.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)

            for terrainPayload in terrainPayloads {
                if terrainPayload.layer.isOpaque {
                    encoder?.setRenderPipelineState(solidPipelineState)
                    encoder?.setDepthStencilState(solidDepthStencilState)
                } else {
                    encoder?.setRenderPipelineState(alphaPipelineState)
                    encoder?.setDepthStencilState(alphaDepthStencilState)
                }

                encoder?.setVertexBuffer(terrainPayload.vertexBuffer, offset: 0, index: 0)
                encoder?.drawIndexedPrimitives(
                    type: .triangle,
                    indexCount: terrainPayload.indexCount,
                    indexType: .uint16,
                    indexBuffer: terrainPayload.indexBuffer,
                    indexBufferOffset: 0
                )
            }
            encoder?.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()

        renderedFrameCount += 1
        drawableWidth = view.drawableSize.width
        drawableHeight = view.drawableSize.height
        reportMetrics(force: renderedFrameCount == 1 || renderedFrameCount.isMultiple(of: 20))
    }

    private func makeTerrainPayloads() -> [TerrainPayload]? {
        let patch = snapshot.terrainPatch
        guard patch.sampleSide >= 2,
              patch.samples.count == patch.sampleSide * patch.sampleSide,
              let cachedIndex = indexBuffer(for: patch.sampleSide) else {
            return nil
        }

        var payloads: [TerrainPayload] = []

        for layer in Self.terrainLayers {
            let vertices = buildVertices(from: patch, layer: layer)
            guard let vertexBuffer = vertices.withUnsafeBytes({ bytes -> MTLBuffer? in
                guard let baseAddress = bytes.baseAddress else {
                    return nil
                }

                return metalDevice.makeBuffer(
                    bytes: baseAddress,
                    length: bytes.count,
                    options: .storageModeShared
                )
            }) else {
                return nil
            }

            payloads.append(
                TerrainPayload(
                    layer: layer,
                    vertexBuffer: vertexBuffer,
                    indexBuffer: cachedIndex.buffer,
                    indexCount: cachedIndex.indexCount
                )
            )
        }

        return payloads
    }

    private func buildVertices(from patch: JungleTerrainPatch, layer: TerrainLayerDefinition) -> [TerrainVertex] {
        var vertices: [TerrainVertex] = []
        vertices.reserveCapacity(patch.samples.count)

        for row in 0..<patch.sampleSide {
            for column in 0..<patch.sampleSide {
                let index = row * patch.sampleSide + column
                let sample = patch.samples[index]
                let normal = terrainNormal(row: row, column: column, in: patch)
                let relief = terrainRelief(row: row, column: column, in: patch)
                let layerDensity = density(for: sample, layer: layer.kind)
                let layerColor = vertexColor(for: sample, layer: layer, density: layerDensity)
                let color = applyTerrainLighting(
                    to: SIMD3<Float>(layerColor.x, layerColor.y, layerColor.z),
                    normal: normal,
                    relief: relief,
                    sample: sample,
                    layer: layer
                )
                let position = layerPosition(
                    for: sample,
                    layer: layer,
                    density: layerDensity,
                    relief: relief
                )
                let motion = layerMotion(for: sample, layer: layer, density: layerDensity)

                vertices.append(
                    TerrainVertex(
                        position: position,
                        color: SIMD4<Float>(color.x, color.y, color.z, layerColor.w),
                        motion: motion
                    )
                )
            }
        }

        return vertices
    }

    private func density(for sample: JungleTerrainSample, layer: TerrainLayerKind) -> Float {
        switch layer {
        case .ground:
            return 1.0
        case .understory:
            return simd_clamp(
                sample.groundCover * snapshot.groundCoverMaterial.alpha +
                    sample.waist * snapshot.waistMaterial.alpha * 0.26,
                0.0,
                1.0
            )
        case .midstory:
            return simd_clamp(
                sample.waist * snapshot.waistMaterial.alpha * 0.82 +
                    sample.head * snapshot.headMaterial.alpha * 0.42,
                0.0,
                1.0
            )
        case .canopy:
            return simd_clamp(
                sample.head * snapshot.headMaterial.alpha * 0.36 +
                    sample.canopy * snapshot.canopyMaterial.alpha,
                0.0,
                1.0
            )
        }
    }

    private func vertexColor(
        for sample: JungleTerrainSample,
        layer: TerrainLayerDefinition,
        density: Float
    ) -> SIMD4<Float> {
        let wetness = sample.wetness * Float(snapshot.ambientWetness)

        switch layer.kind {
        case .ground:
            var color = materialColor(snapshot.groundMaterial, wetness: wetness)
            color = mix(
                color,
                materialColor(snapshot.groundCoverMaterial, wetness: wetness),
                t: sample.groundCover * 0.18
            )
            color = mix(
                color,
                materialColor(snapshot.waistMaterial, wetness: wetness),
                t: sample.waist * 0.08
            )

            let relativeHeight = Float(sample.position.y - snapshot.cameraFloorHeight)
            let elevationLift = max(relativeHeight / Float(max(snapshot.canopyHeight, 1.0)), 0.0) * 0.06
            let surfaceShade = wetness * 0.08 + sample.canopy * 0.10 + sample.head * 0.06
            color *= max(0.38, 1.0 - surfaceShade)
            color += SIMD3<Float>(repeating: elevationLift)
            color = applyContrast(color, amount: 1.04, pivot: 0.42)
            color = simd_clamp(color, SIMD3<Float>(repeating: 0.0), SIMD3<Float>(repeating: 1.0))
            return SIMD4<Float>(color.x, color.y, color.z, 1.0)
        case .understory:
            let lowColor = materialColor(snapshot.groundCoverMaterial, wetness: wetness)
            let highColor = materialColor(snapshot.waistMaterial, wetness: wetness)
            let blend = blendFactor(
                primary: sample.waist * snapshot.waistMaterial.alpha,
                within: density
            )
            var color = mix(lowColor, highColor, t: blend * 0.55)
            color = applyContrast(color, amount: 1.10 + density * 0.18, pivot: 0.41)
            let alpha = layerAlpha(for: sample, layer: layer.kind, density: density)
            return SIMD4<Float>(color.x, color.y, color.z, alpha)
        case .midstory:
            let lowColor = materialColor(snapshot.waistMaterial, wetness: wetness)
            let highColor = materialColor(snapshot.headMaterial, wetness: wetness)
            let blend = blendFactor(
                primary: sample.head * snapshot.headMaterial.alpha,
                within: density
            )
            var color = mix(lowColor, highColor, t: blend * 0.72)
            color = applyContrast(color, amount: 1.14 + density * 0.20, pivot: 0.40)
            let alpha = layerAlpha(for: sample, layer: layer.kind, density: density)
            return SIMD4<Float>(color.x, color.y, color.z, alpha)
        case .canopy:
            let lowColor = materialColor(snapshot.headMaterial, wetness: wetness)
            let highColor = materialColor(snapshot.canopyMaterial, wetness: wetness)
            let blend = blendFactor(
                primary: sample.canopy * snapshot.canopyMaterial.alpha,
                within: density
            )
            var color = mix(lowColor, highColor, t: 0.32 + blend * 0.68)
            color = applyContrast(color, amount: 1.18 + density * 0.22, pivot: 0.39)
            let alpha = layerAlpha(for: sample, layer: layer.kind, density: density)
            return SIMD4<Float>(color.x, color.y, color.z, alpha)
        }
    }

    private func layerMotion(
        for sample: JungleTerrainSample,
        layer: TerrainLayerDefinition,
        density: Float
    ) -> Float {
        switch layer.kind {
        case .ground:
            return max(
                0.0,
                sample.groundCover * snapshot.groundCoverMaterial.motion * 0.16 +
                    sample.waist * snapshot.waistMaterial.motion * 0.05
            )
        case .understory:
            return max(
                0.02,
                density * (
                    sample.groundCover * snapshot.groundCoverMaterial.motion * 1.08 +
                        sample.waist * snapshot.waistMaterial.motion * 0.34
                )
            )
        case .midstory:
            return max(
                0.03,
                density * (
                    sample.waist * snapshot.waistMaterial.motion * 0.92 +
                        sample.head * snapshot.headMaterial.motion * 0.42
                )
            )
        case .canopy:
            return max(
                0.04,
                density * (
                    sample.head * snapshot.headMaterial.motion * 0.52 +
                        sample.canopy * snapshot.canopyMaterial.motion * 0.96
                )
            )
        }
    }

    private func layerPosition(
        for sample: JungleTerrainSample,
        layer: TerrainLayerDefinition,
        density: Float,
        relief: Float
    ) -> SIMD3<Float> {
        var position = simdPosition(for: sample)

        guard !layer.isOpaque else {
            return position
        }

        let forward = horizontalCameraForward()
        let right = horizontalCameraRight()
        let sampleDirection = normalize(
            SIMD3<Float>(
                position.x - Float(snapshot.cameraPosition.x),
                0.0,
                position.z - Float(snapshot.cameraPosition.z)
            ),
            fallback: forward
        )
        let lateralAmount = simd_dot(sampleDirection, right)
        let baseHeight = layerBaseHeight(for: layer.kind) * layer.heightScale
        let verticalLift =
            (
                baseHeight * (0.38 + density * 0.62) +
                    max(relief, -0.35) * baseHeight * 0.12
            ) * Self.debugLayerLiftMultiplier
        let depthOffset = -forward * layer.parallaxDepth * (0.24 + density * 0.76)
        let lateralOffset = right * lateralAmount * layer.lateralDrift * (0.20 + density * 0.80)

        position += depthOffset + lateralOffset
        position.y += verticalLift
        return position
    }

    private func layerBaseHeight(for layer: TerrainLayerKind) -> Float {
        switch layer {
        case .ground:
            return 0.0
        case .understory:
            return Float(snapshot.groundCoverHeight)
        case .midstory:
            return Float(snapshot.waistHeight * 0.78 + snapshot.headHeight * 0.14)
        case .canopy:
            return Float(snapshot.headHeight * 0.46 + snapshot.canopyHeight * 0.30)
        }
    }

    private func horizontalCameraForward() -> SIMD3<Float> {
        normalize(
            SIMD3<Float>(
                Float(snapshot.cameraForward.x),
                0.0,
                Float(snapshot.cameraForward.z)
            ),
            fallback: SIMD3<Float>(0.0, 0.0, 1.0)
        )
    }

    private func horizontalCameraRight() -> SIMD3<Float> {
        normalize(
            SIMD3<Float>(
                Float(snapshot.cameraRight.x),
                0.0,
                Float(snapshot.cameraRight.z)
            ),
            fallback: SIMD3<Float>(1.0, 0.0, 0.0)
        )
    }

    private func blendFactor(primary: Float, within total: Float) -> Float {
        guard total > 0.000_1 else {
            return 0.0
        }

        return simd_clamp(primary / total, 0.0, 1.0)
    }

    private func layerAlpha(for sample: JungleTerrainSample, layer: TerrainLayerKind, density: Float) -> Float {
        guard density > 0.000_1 else {
            return 0.0
        }

        let broadNoise = layerNoise(for: sample, layer: layer, seed: 17.0, scale: 0.85)
        let breakupNoise = layerNoise(for: sample, layer: layer, seed: 43.0, scale: 2.4)
        let grainNoise = layerNoise(for: sample, layer: layer, seed: 79.0, scale: 6.4)
        let microNoise = layerNoise(for: sample, layer: layer, seed: 131.0, scale: 12.0)
        let coverageNoise = simd_clamp(
            broadNoise * 0.28 + breakupNoise * 0.30 + grainNoise * 0.24 + microNoise * 0.18,
            0.0,
            1.0
        )
        let coverageThreshold = simd_clamp(
            density * (0.58 + breakupNoise * 0.18 + grainNoise * 0.12 + microNoise * 0.10),
            0.0,
            1.0
        )
        let breakupBoost = simd_clamp(abs(grainNoise - microNoise) * 1.3, 0.0, 1.0)

        guard coverageNoise <= coverageThreshold * (0.90 + breakupBoost * 0.10) else {
            return 0.0
        }

        let opacityNoise = simd_clamp(
            broadNoise * 0.08 + breakupNoise * 0.28 + grainNoise * 0.34 + microNoise * 0.30,
            0.0,
            1.0
        )
        let edgeNoise = simd_clamp(
            (coverageThreshold - coverageNoise) * 4.2 +
                grainNoise * 0.16 +
                microNoise * 0.24 +
                breakupBoost * 0.18,
            0.0,
            1.0
        )
        let (minimumAlpha, range): (Float, Float)

        switch layer {
        case .ground:
            return 1.0
        case .understory:
            (minimumAlpha, range) = (0.6, 0.3)
        case .midstory:
            (minimumAlpha, range) = (0.3, 0.3)
        case .canopy:
            (minimumAlpha, range) = (0.0, 0.3)
        }

        return simd_clamp(
            minimumAlpha + opacityNoise * range * (0.58 + edgeNoise * 0.42),
            minimumAlpha,
            minimumAlpha + range
        )
    }

    private func layerNoise(
        for sample: JungleTerrainSample,
        layer: TerrainLayerKind,
        seed: Float,
        scale: Float
    ) -> Float {
        let layerOffset: Float

        switch layer {
        case .ground:
            layerOffset = 0.0
        case .understory:
            layerOffset = 11.0
        case .midstory:
            layerOffset = 23.0
        case .canopy:
            layerOffset = 37.0
        }

        let value =
            sin(
                Float(sample.position.x) * (0.173 * scale) + layerOffset * 0.31 + seed
            ) +
            sin(
                Float(sample.position.z) * (0.197 * scale) +
                    Float(sample.position.y) * (0.123 * scale) +
                    layerOffset * 0.19 +
                    seed * 1.7
            ) +
            sin(
                Float(sample.position.x + sample.position.z) * (0.091 * scale) +
                    layerOffset * 0.13 +
                    seed * 0.7
            ) +
            sin(
                Float(sample.position.x - sample.position.z) * (0.141 * scale) +
                    Float(sample.position.y) * (0.087 * scale) +
                    layerOffset * 0.11 +
                    seed * 0.5
            )

        return simd_clamp(value * 0.18 + 0.5, 0.0, 1.0)
    }

    private func materialColor(_ channel: JungleMaterialChannel, wetness: Float) -> SIMD3<Float> {
        let base = SIMD3<Float>(channel.red, channel.green, channel.blue)
        let wetBoost = wetness * channel.wetnessResponse
        let tinted = base * (0.82 + wetBoost * 0.26) + SIMD3<Float>(repeating: wetBoost * 0.04)
        return simd_clamp(tinted, SIMD3<Float>(repeating: 0.0), SIMD3<Float>(repeating: 1.0))
    }

    private func terrainNormal(row: Int, column: Int, in patch: JungleTerrainPatch) -> SIMD3<Float> {
        let left = simdPosition(for: patchSample(row: row, column: column - 1, in: patch))
        let right = simdPosition(for: patchSample(row: row, column: column + 1, in: patch))
        let up = simdPosition(for: patchSample(row: row - 1, column: column, in: patch))
        let down = simdPosition(for: patchSample(row: row + 1, column: column, in: patch))
        let horizontal = right - left
        let vertical = down - up
        return normalize(simd_cross(vertical, horizontal), fallback: SIMD3<Float>(0.0, 1.0, 0.0))
    }

    private func terrainRelief(row: Int, column: Int, in patch: JungleTerrainPatch) -> Float {
        let center = Float(patchSample(row: row, column: column, in: patch).position.y)
        let left = Float(patchSample(row: row, column: column - 1, in: patch).position.y)
        let right = Float(patchSample(row: row, column: column + 1, in: patch).position.y)
        let up = Float(patchSample(row: row - 1, column: column, in: patch).position.y)
        let down = Float(patchSample(row: row + 1, column: column, in: patch).position.y)
        let curvature = center * 4.0 - left - right - up - down
        let spacing = Float(max(patch.spacing, 0.001))
        let normalizedRelief = curvature / max(spacing * 1.4, 0.001)
        return simd_clamp(normalizedRelief, -1.0, 1.0)
    }

    private func applyTerrainLighting(
        to color: SIMD3<Float>,
        normal: SIMD3<Float>,
        relief: Float,
        sample: JungleTerrainSample,
        layer: TerrainLayerDefinition
    ) -> SIMD3<Float> {
        let lightDirection = terrainLightDirection(for: snapshot)
        let humidity = Float(snapshot.ambientWetness)
        let vegetationPresence = simd_clamp(
            sample.groundCover * 0.20 +
                sample.waist * 0.34 +
                sample.head * 0.5 +
                sample.canopy * 0.66,
            0.0,
            1.0
        )
        let diffuse = simd_clamp(simd_dot(normal, lightDirection), 0.0, 1.0)
        let wrappedDiffuse = simd_clamp((diffuse + 0.28) / 1.28, 0.0, 1.0)
        let slope = 1.0 - simd_clamp(normal.y, 0.0, 1.0)
        let ridge = simd_clamp(relief, 0.0, 1.0)
        let hollow = simd_clamp(-relief, 0.0, 1.0)
        let translucencyLift: Float = layer.isOpaque ? 0.0 : 0.06 + layer.alphaScale * 0.12
        let shadowWeight: Float = layer.isOpaque ? 1.0 : 0.58
        let lighting = 0.66 + wrappedDiffuse * 0.34 - humidity * 0.03 + translucencyLift
        var lit = color * lighting
        lit += SIMD3<Float>(0.020, 0.024, 0.016) * wrappedDiffuse
        lit -= SIMD3<Float>(0.018, 0.012, 0.010) * slope * shadowWeight
        lit += SIMD3<Float>(0.026, 0.023, 0.017) * ridge * (0.65 + slope * 0.35)
        lit -= SIMD3<Float>(0.030, 0.024, 0.022) * hollow * (0.72 + vegetationPresence * 0.28) * shadowWeight
        let contourContrast =
            1.0 +
            slope * (0.24 + vegetationPresence * 0.10) +
            (ridge + hollow) * 0.22 +
            (layer.isOpaque ? 0.0 : 0.04)
        lit = applyContrast(lit, amount: contourContrast, pivot: 0.40)
        return simd_clamp(lit, SIMD3<Float>(repeating: 0.0), SIMD3<Float>(repeating: 1.0))
    }

    private func terrainLightDirection(for snapshot: JungleFrameSnapshot) -> SIMD3<Float> {
        let shoreline = Float(snapshot.shorelineSpace)
        let baseDirection: SIMD3<Float>

        switch snapshot.currentBiome {
        case .grassland:
            baseDirection = SIMD3<Float>(0.46, 0.83, -0.31)
        case .jungle:
            baseDirection = SIMD3<Float>(0.32, 0.88, -0.34)
        case .beach:
            baseDirection = SIMD3<Float>(0.52, 0.78, -0.22)
        }

        let weatherOffset: SIMD3<Float>

        switch snapshot.currentWeather {
        case .clearBreeze:
            weatherOffset = SIMD3<Float>(0.02, 0.02, 0.0)
        case .humidCanopy:
            weatherOffset = SIMD3<Float>(-0.03, 0.05, -0.04)
        case .coastalHaze:
            weatherOffset = SIMD3<Float>(0.01, -0.02, 0.03)
        }

        return normalize(
            baseDirection + weatherOffset + SIMD3<Float>(shoreline * 0.04, 0.0, shoreline * 0.02),
            fallback: SIMD3<Float>(0.0, 1.0, 0.0)
        )
    }

    private func patchSample(row: Int, column: Int, in patch: JungleTerrainPatch) -> JungleTerrainSample {
        let clampedRow = Swift.min(Swift.max(row, 0), patch.sampleSide - 1)
        let clampedColumn = Swift.min(Swift.max(column, 0), patch.sampleSide - 1)
        return patch.samples[clampedRow * patch.sampleSide + clampedColumn]
    }

    private func simdPosition(for sample: JungleTerrainSample) -> SIMD3<Float> {
        SIMD3<Float>(
            Float(sample.position.x),
            Float(sample.position.y),
            Float(sample.position.z)
        )
    }

    private func normalize(_ vector: SIMD3<Float>, fallback: SIMD3<Float>) -> SIMD3<Float> {
        let lengthSquared = simd_length_squared(vector)
        guard lengthSquared > 0.000_001 else {
            return fallback
        }

        return simd_normalize(vector)
    }

    private func applyContrast(_ color: SIMD3<Float>, amount: Float, pivot: Float) -> SIMD3<Float> {
        let midpoint = SIMD3<Float>(repeating: pivot)
        return simd_clamp(
            (color - midpoint) * max(amount, 0.0) + midpoint,
            SIMD3<Float>(repeating: 0.0),
            SIMD3<Float>(repeating: 1.0)
        )
    }

    private func makeUniformBuffer(skyColor: SIMD3<Float>) -> MTLBuffer? {
        let viewProjection = simd_mul(
            simdMatrix(from: snapshot.projectionMatrix),
            simdMatrix(from: snapshot.viewMatrix)
        )
        let atmosphereControls = atmosphereControls(for: snapshot)
        var uniforms = TerrainUniforms(
            viewProjectionMatrix: viewProjection,
            cameraPositionAndTime: SIMD4<Float>(
                Float(snapshot.cameraPosition.x),
                Float(snapshot.cameraPosition.y),
                Float(snapshot.cameraPosition.z),
                Float(snapshot.simulatedTimeSeconds)
            ),
            skyColorAndVisibility: SIMD4<Float>(
                skyColor.x,
                skyColor.y,
                skyColor.z,
                Float(snapshot.visibilityDistance)
            ),
            atmosphereControls: atmosphereControls
        )

        return withUnsafeBytes(of: &uniforms) { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return nil
            }

            return metalDevice.makeBuffer(
                bytes: baseAddress,
                length: bytes.count,
                options: .storageModeShared
            )
        }
    }

    private func indexBuffer(for sampleSide: Int) -> (buffer: MTLBuffer, indexCount: Int)? {
        if let cached = cachedIndexBuffers[sampleSide] {
            return cached
        }

        guard sampleSide >= 2 else {
            return nil
        }

        var indices: [UInt16] = []
        indices.reserveCapacity((sampleSide - 1) * (sampleSide - 1) * 6)

        for row in 0..<(sampleSide - 1) {
            for column in 0..<(sampleSide - 1) {
                let topLeft = UInt16(row * sampleSide + column)
                let topRight = UInt16(row * sampleSide + column + 1)
                let bottomLeft = UInt16((row + 1) * sampleSide + column)
                let bottomRight = UInt16((row + 1) * sampleSide + column + 1)

                indices.append(topLeft)
                indices.append(bottomLeft)
                indices.append(topRight)
                indices.append(topRight)
                indices.append(bottomLeft)
                indices.append(bottomRight)
            }
        }

        guard let buffer = indices.withUnsafeBytes({ bytes -> MTLBuffer? in
            guard let baseAddress = bytes.baseAddress else {
                return nil
            }

            return metalDevice.makeBuffer(
                bytes: baseAddress,
                length: bytes.count,
                options: .storageModeShared
            )
        }) else {
            return nil
        }

        let cached = (buffer: buffer, indexCount: indices.count)
        cachedIndexBuffers[sampleSide] = cached
        return cached
    }

    private func simdMatrix(from matrix: JungleMatrix4x4) -> simd_float4x4 {
        let elements = matrix.elements

        guard elements.count == 16 else {
            return matrix_identity_float4x4
        }

        return simd_float4x4(columns: (
            SIMD4<Float>(elements[0], elements[1], elements[2], elements[3]),
            SIMD4<Float>(elements[4], elements[5], elements[6], elements[7]),
            SIMD4<Float>(elements[8], elements[9], elements[10], elements[11]),
            SIMD4<Float>(elements[12], elements[13], elements[14], elements[15])
        ))
    }

    private func skyColor(for snapshot: JungleFrameSnapshot) -> SIMD3<Float> {
        let biome = Float(snapshot.biomeBlend)
        let humidity = Float(snapshot.ambientWetness)
        let shoreline = Float(snapshot.shorelineSpace)
        let horizon = Float((snapshot.cameraForward.y + 1.0) * 0.5)
        let grasslandSky = SIMD3<Float>(0.52, 0.71, 0.78)
        let jungleSky = SIMD3<Float>(0.18, 0.32, 0.24)
        let beachSky = SIMD3<Float>(0.72, 0.78, 0.82)
        let hazeColor = SIMD3<Float>(0.88, 0.82, 0.70)
        let targetSky: SIMD3<Float>

        switch snapshot.currentBiome {
        case .grassland:
            targetSky = grasslandSky
        case .jungle:
            targetSky = jungleSky
        case .beach:
            targetSky = beachSky
        }

        var color = mix(grasslandSky, targetSky, t: biome)

        switch snapshot.currentWeather {
        case .clearBreeze:
            color += SIMD3<Float>(0.01, 0.02, 0.02)
        case .humidCanopy:
            color = mix(color, jungleSky, t: 0.25)
        case .coastalHaze:
            color = mix(color, hazeColor, t: 0.16 + shoreline * 0.28)
        }

        color *= 0.82 + horizon * 0.18 + shoreline * 0.04
        color += SIMD3<Float>(0.03, 0.05, 0.06) * humidity
        color += SIMD3<Float>(0.08, 0.06, 0.03) * shoreline
        return simd_clamp(color, SIMD3<Float>(repeating: 0.0), SIMD3<Float>(repeating: 1.0))
    }

    private func atmosphereControls(for snapshot: JungleFrameSnapshot) -> SIMD4<Float> {
        let humidity = Float(snapshot.ambientWetness)
        let shoreline = Float(snapshot.shorelineSpace)
        var controls: SIMD4<Float>

        switch snapshot.currentBiome {
        case .grassland:
            controls = SIMD4<Float>(0.34, 1.36, 1.12, 0.86)
        case .jungle:
            controls = SIMD4<Float>(0.29, 1.48, 1.18, 0.78)
        case .beach:
            controls = SIMD4<Float>(0.38, 1.30, 1.08, 0.90)
        }

        switch snapshot.currentWeather {
        case .clearBreeze:
            controls.x += 0.03
            controls.z += 0.02
        case .humidCanopy:
            controls.x -= 0.02
            controls.y += 0.10
            controls.z += 0.03
            controls.w -= 0.05
        case .coastalHaze:
            controls.x -= 0.01
            controls.y += 0.05
            controls.z += 0.02
            controls.w += 0.03
        }

        controls.x = clamp(controls.x - humidity * 0.04 + shoreline * 0.02, min: 0.22, max: 0.48)
        controls.y = clamp(controls.y + humidity * 0.14, min: 1.10, max: 1.75)
        controls.z = clamp(controls.z + humidity * 0.06, min: 1.04, max: 1.26)
        controls.w = clamp(controls.w - humidity * 0.05 + shoreline * 0.04, min: 0.68, max: 0.94)

        return controls
    }

    private func mix(_ start: SIMD3<Float>, _ end: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        start + (end - start) * simd_clamp(t, 0.0, 1.0)
    }

    private func clamp(_ value: Float, min minimum: Float, max maximum: Float) -> Float {
        Swift.min(Swift.max(value, minimum), maximum)
    }

    private func reportMetrics(force: Bool) {
        let now = CACurrentMediaTime()
        let elapsed = now - lastMetricsTimestamp

        if force || elapsed >= 0.5 {
            let renderedFrames = renderedFrameCount - lastMetricsFrameCount
            if elapsed > 0 {
                framesPerSecond = Double(renderedFrames) / elapsed
            }

            lastMetricsTimestamp = now
            lastMetricsFrameCount = renderedFrameCount
        }

        let metrics = JungleRendererFrameMetrics(
            renderedFrameCount: renderedFrameCount,
            drawableWidth: drawableWidth,
            drawableHeight: drawableHeight,
            framesPerSecond: framesPerSecond
        )

        onMetricsUpdate?(metrics)
    }
}
