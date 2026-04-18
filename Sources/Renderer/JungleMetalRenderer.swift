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
    }

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
        float fog = saturate((distanceToCamera - visibilityDistance * 0.25f) / (visibilityDistance * 0.75f));
        float3 color = mix(in.color.rgb, uniforms.skyColorAndVisibility.rgb, fog);
        return float4(color, 1.0f);
    }
    """

    public let metalDevice: MTLDevice
    public var snapshot: JungleFrameSnapshot
    public var onMetricsUpdate: ((JungleRendererFrameMetrics) -> Void)?

    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let depthStencilState: MTLDepthStencilState
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

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "JungleTerrainPipeline"
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        guard let pipelineState = try? metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
            return nil
        }

        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.isDepthWriteEnabled = true
        depthDescriptor.depthCompareFunction = .less

        guard let depthStencilState = metalDevice.makeDepthStencilState(descriptor: depthDescriptor) else {
            return nil
        }

        self.metalDevice = metalDevice
        self.commandQueue = commandQueue
        self.pipelineState = pipelineState
        self.depthStencilState = depthStencilState
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

        if let terrainPayload = makeTerrainPayload(),
           let uniformBuffer = makeUniformBuffer(skyColor: skyColor) {
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
            encoder?.label = "JungleTerrainPass"
            encoder?.setRenderPipelineState(pipelineState)
            encoder?.setDepthStencilState(depthStencilState)
            encoder?.setVertexBuffer(terrainPayload.vertexBuffer, offset: 0, index: 0)
            encoder?.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
            encoder?.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
            encoder?.drawIndexedPrimitives(
                type: .triangle,
                indexCount: terrainPayload.indexCount,
                indexType: .uint16,
                indexBuffer: terrainPayload.indexBuffer,
                indexBufferOffset: 0
            )
            encoder?.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()

        renderedFrameCount += 1
        drawableWidth = view.drawableSize.width
        drawableHeight = view.drawableSize.height
        reportMetrics(force: renderedFrameCount == 1 || renderedFrameCount.isMultiple(of: 20))
    }

    private func makeTerrainPayload() -> (vertexBuffer: MTLBuffer, indexBuffer: MTLBuffer, indexCount: Int)? {
        let patch = snapshot.terrainPatch
        guard patch.sampleSide >= 2,
              patch.samples.count == patch.sampleSide * patch.sampleSide,
              let cachedIndex = indexBuffer(for: patch.sampleSide) else {
            return nil
        }

        let vertices = buildVertices(from: patch)
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

        return (
            vertexBuffer: vertexBuffer,
            indexBuffer: cachedIndex.buffer,
            indexCount: cachedIndex.indexCount
        )
    }

    private func buildVertices(from patch: JungleTerrainPatch) -> [TerrainVertex] {
        var vertices: [TerrainVertex] = []
        vertices.reserveCapacity(patch.samples.count)

        for sample in patch.samples {
            let color = vertexColor(for: sample)
            let motion =
                sample.groundCover * snapshot.groundCoverMaterial.motion +
                sample.waist * snapshot.waistMaterial.motion +
                sample.head * snapshot.headMaterial.motion +
                sample.canopy * snapshot.canopyMaterial.motion

            vertices.append(
                TerrainVertex(
                    position: SIMD3<Float>(
                        Float(sample.position.x),
                        Float(sample.position.y),
                        Float(sample.position.z)
                    ),
                    color: SIMD4<Float>(color.x, color.y, color.z, 1.0),
                    motion: motion
                )
            )
        }

        return vertices
    }

    private func vertexColor(for sample: JungleTerrainSample) -> SIMD3<Float> {
        let wetness = sample.wetness * Float(snapshot.ambientWetness)
        var color = materialColor(snapshot.groundMaterial, wetness: wetness)
        color = mix(
            color,
            materialColor(snapshot.groundCoverMaterial, wetness: wetness),
            t: sample.groundCover * snapshot.groundCoverMaterial.alpha
        )
        color = mix(
            color,
            materialColor(snapshot.waistMaterial, wetness: wetness),
            t: sample.waist * snapshot.waistMaterial.alpha
        )
        color = mix(
            color,
            materialColor(snapshot.headMaterial, wetness: wetness),
            t: sample.head * snapshot.headMaterial.alpha
        )
        color = mix(
            color,
            materialColor(snapshot.canopyMaterial, wetness: wetness),
            t: sample.canopy * snapshot.canopyMaterial.alpha
        )

        let relativeHeight = Float(sample.position.y - snapshot.cameraFloorHeight)
        let elevationLift = max(relativeHeight / Float(max(snapshot.canopyHeight, 1.0)), 0.0) * 0.08
        let canopyOcclusion = sample.canopy * 0.30 + sample.head * 0.16
        let wetShade = wetness * 0.10
        color *= max(0.24, 1.0 - canopyOcclusion - wetShade)
        color += SIMD3<Float>(repeating: elevationLift)

        return simd_clamp(color, SIMD3<Float>(repeating: 0.0), SIMD3<Float>(repeating: 1.0))
    }

    private func materialColor(_ channel: JungleMaterialChannel, wetness: Float) -> SIMD3<Float> {
        let base = SIMD3<Float>(channel.red, channel.green, channel.blue)
        let wetBoost = wetness * channel.wetnessResponse
        let tinted = base * (0.82 + wetBoost * 0.26) + SIMD3<Float>(repeating: wetBoost * 0.04)
        return simd_clamp(tinted, SIMD3<Float>(repeating: 0.0), SIMD3<Float>(repeating: 1.0))
    }

    private func makeUniformBuffer(skyColor: SIMD3<Float>) -> MTLBuffer? {
        let viewProjection = simd_mul(
            simdMatrix(from: snapshot.projectionMatrix),
            simdMatrix(from: snapshot.viewMatrix)
        )
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
            )
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

    private func mix(_ start: SIMD3<Float>, _ end: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        start + (end - start) * simd_clamp(t, 0.0, 1.0)
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
