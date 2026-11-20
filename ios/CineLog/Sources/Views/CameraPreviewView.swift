import SwiftUI
import MetalKit

public struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    public init(cameraManager: CameraManager) {
        self.cameraManager = cameraManager
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(metalPipeline: cameraManager.metalPipeline)
    }
    
    public func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = cameraManager.metalPipeline.device
        mtkView.delegate = context.coordinator
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.preferredFramesPerSecond = 60
        mtkView.framebufferOnly = false
        mtkView.contentMode = .scaleAspectFill
        mtkView.backgroundColor = .black
        
        cameraManager.onPreviewTextureUpdated = { texture in
            context.coordinator.currentTexture = texture
        }
        
        return mtkView
    }
    
    public func updateUIView(_ uiView: MTKView, context: Context) {}
    
    public final class Coordinator: NSObject, MTKViewDelegate {
        var currentTexture: MTLTexture?
        let metalPipeline: MetalLogPipeline
        
        init(metalPipeline: MetalLogPipeline) {
            self.metalPipeline = metalPipeline
        }
        
        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        public func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let texture = currentTexture,
                  let cmdBuffer = metalPipeline.commandQueue.makeCommandBuffer() else {
                return
            }
            
            // Blit current preview texture to MTKView drawable
            if let blitEncoder = cmdBuffer.makeBlitCommandEncoder() {
                let origin = MTLOrigin(x: 0, y: 0, z: 0)
                let size = MTLSize(
                    width: min(texture.width, drawable.texture.width),
                    height: min(texture.height, drawable.texture.height),
                    depth: 1
                )
                blitEncoder.copy(
                    from: texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: origin, sourceSize: size,
                    to: drawable.texture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: origin
                )
                blitEncoder.endEncoding()
            }
            
            cmdBuffer.present(drawable)
            cmdBuffer.commit()
        }
    }
}
