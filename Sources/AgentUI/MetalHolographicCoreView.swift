#if os(macOS)
import MetalKit
import SwiftUI

struct MetalHolographicCoreView: NSViewRepresentable {
    let phase: HolographicCorePhase
    let audioLevel: Float
    let expansion: Double
    let rotation: CGSize
    let reduceMotion: Bool

    func makeCoordinator() -> Renderer? {
        Renderer.make()
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = context.coordinator?.device
        view.delegate = context.coordinator
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0, 0, 0, 0)
        view.framebufferOnly = true
        view.isPaused = reduceMotion
        view.enableSetNeedsDisplay = reduceMotion
        view.preferredFramesPerSecond = 60
        context.coordinator?.update(
            phase: phase,
            audioLevel: audioLevel,
            expansion: expansion,
            rotation: rotation,
            reduceMotion: reduceMotion
        )
        return view
    }

    func updateNSView(_ view: MTKView, context: Context) {
        context.coordinator?.update(
            phase: phase,
            audioLevel: audioLevel,
            expansion: expansion,
            rotation: rotation,
            reduceMotion: reduceMotion
        )
        view.isPaused = reduceMotion
        view.enableSetNeedsDisplay = reduceMotion
        if reduceMotion {
            view.setNeedsDisplay(view.bounds)
        }
    }
}

extension MetalHolographicCoreView {
    final class Renderer: NSObject, MTKViewDelegate, @unchecked Sendable {
        struct Uniforms {
            var resolution = SIMD2<Float>(1, 1)
            var time: Float = 0
            var thermalShift: Float = 0
            var energy: Float = 0
            var expansion: Float = 0
            var rotationX: Float = 0
            var rotationY: Float = 0
            var shockwave: Float = 1
            var turbulence: Float = 0
        }

        let device: MTLDevice
        private let commandQueue: MTLCommandQueue
        private let pipeline: MTLRenderPipelineState
        private let lock = NSLock()
        private let startedAt = CACurrentMediaTime()
        private var phase = HolographicCorePhase.idle
        private var audioLevel: Float = 0
        private var expansion = 0.0
        private var rotation = CGSize.zero
        private var reduceMotion = false
        private var shockwaveStartedAt = CACurrentMediaTime() - 2

        static func make() -> Renderer? {
            guard let device = MTLCreateSystemDefaultDevice(),
                  let commandQueue = device.makeCommandQueue(),
                  let library = try? device.makeLibrary(source: HolographicMetalShader.source, options: nil),
                  let vertex = library.makeFunction(name: "holographicVertex"),
                  let fragment = library.makeFunction(name: "holographicFragment") else {
                return nil
            }

            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

            guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else {
                return nil
            }

            return Renderer(device: device, commandQueue: commandQueue, pipeline: pipeline)
        }

        private init(
            device: MTLDevice,
            commandQueue: MTLCommandQueue,
            pipeline: MTLRenderPipelineState
        ) {
            self.device = device
            self.commandQueue = commandQueue
            self.pipeline = pipeline
            super.init()
        }

        func update(
            phase: HolographicCorePhase,
            audioLevel: Float,
            expansion: Double,
            rotation: CGSize,
            reduceMotion: Bool
        ) {
            lock.lock()
            if self.phase != phase {
                shockwaveStartedAt = CACurrentMediaTime()
            }
            self.phase = phase
            self.audioLevel = audioLevel
            self.expansion = expansion
            self.rotation = rotation
            self.reduceMotion = reduceMotion
            lock.unlock()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let descriptor = view.currentRenderPassDescriptor,
                  let drawable = view.currentDrawable,
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                return
            }

            let snapshot = currentUniforms(for: view.drawableSize)
            var uniforms = snapshot
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }

        private func currentUniforms(for size: CGSize) -> Uniforms {
            lock.lock()
            defer { lock.unlock() }

            let dynamics = HolographicCoreDynamics(
                phase: phase,
                audioLevel: audioLevel,
                gestureScale: expansion
            )
            let now = CACurrentMediaTime()
            let elapsed = reduceMotion ? 0 : now - startedAt
            let shockwave = reduceMotion ? 1 : min(max((now - shockwaveStartedAt) / 1.15, 0), 1)

            return Uniforms(
                resolution: SIMD2(Float(size.width), Float(size.height)),
                time: Float(elapsed) * phase.rotationSpeed,
                thermalShift: phase.thermalShift,
                energy: dynamics.energy,
                expansion: dynamics.expansion,
                rotationX: Float(rotation.height / 500),
                rotationY: Float(rotation.width / 500),
                shockwave: Float(shockwave),
                turbulence: phase.turbulence
            )
        }
    }
}
#endif
