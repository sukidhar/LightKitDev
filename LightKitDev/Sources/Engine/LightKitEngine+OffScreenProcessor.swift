//
//  LightKitEngine+OffScreenProcessor.swift
//  LightKitDev
//
//  Created by sukidhar on 23/09/22.
//

import ARKit
import MetalKit
import SceneKit

// The max number of command buffers in flight
let kMaxBuffersInFlight: Int = 3

// The max number anchors our uniform buffer will hold
let kMaxAnchorInstanceCount: Int = 64

// The 16 byte aligned size of our uniform structures
let kAlignedSharedUniformsSize: Int = (MemoryLayout<SharedUniforms>.size & ~0xFF) + 0x100
let kAlignedInstanceUniformsSize: Int = ((MemoryLayout<InstanceUniforms>.size * kMaxAnchorInstanceCount) & ~0xFF) + 0x100

// Vertex data for an image plane
let kImagePlaneVertexData: [Float] = [
    -1.0, -1.0,  0.0, 1.0,
     1.0, -1.0,  1.0, 1.0,
     -1.0,  1.0,  0.0, 0.0,
     1.0,  1.0,  1.0, 0.0,
]


extension LightKitEngine{
    class OffScreenProcessor: NSObject{
        
        class Context{
            let commandBuffer : MTLCommandBuffer
            let sourceTexture : MTLTexture
            let targetTexture : MTLTexture
            
            init(commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture, targetTexture: MTLTexture) {
                self.commandBuffer = commandBuffer
                self.sourceTexture = sourceTexture
                self.targetTexture = targetTexture
            }
        }
        
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        let inFlightSemaphore = DispatchSemaphore(value: kMaxBuffersInFlight)
        
        var sharedUniformBuffer: MTLBuffer!
        var anchorUniformBuffer: MTLBuffer!
        var imagePlaneVertexBuffer: MTLBuffer!
        var capturedImagePipelineState: MTLRenderPipelineState!
        var capturedImageDepthState: MTLDepthStencilState!
        var anchorPipelineState: MTLRenderPipelineState!
        var anchorDepthState: MTLDepthStencilState!
        var capturedImageTextureY: CVMetalTexture?
        var capturedImageTextureCbCr: CVMetalTexture?
        var capturedImageTextureCache: CVMetalTextureCache!
        
        var currentViewPortSize = CGSize.zero
        var geometryVertexDescriptor: MTLVertexDescriptor!
        var model: LKModel?
        var uniformBufferIndex: Int = 0
        var sharedUniformBufferOffset: Int = 0
        var anchorUniformBufferOffset: Int = 0
        var sharedUniformBufferAddress: UnsafeMutableRawPointer!
        var anchorUniformBufferAddress: UnsafeMutableRawPointer!
        var anchorInstanceCount: Int = 0
        
        var sceneRenderer : SCNRenderer!
        
        init(device: MTLDevice, commandQueue: MTLCommandQueue){
            self.device = device
            self.commandQueue = commandQueue
            self.sceneRenderer = .init(device: device)
            
            let sharedUniformBufferSize = kAlignedSharedUniformsSize * kMaxBuffersInFlight
            let anchorUniformBufferSize = kAlignedInstanceUniformsSize * kMaxBuffersInFlight
            
            sharedUniformBuffer = device.makeBuffer(length: sharedUniformBufferSize, options: .storageModeShared)
            sharedUniformBuffer.label = "SharedUniformBuffer"
            
            anchorUniformBuffer = device.makeBuffer(length: anchorUniformBufferSize, options: .storageModeShared)
            anchorUniformBuffer.label = "AnchorUniformBuffer"
            
            let imagePlaneVertexDataCount = kImagePlaneVertexData.count * MemoryLayout<Float>.size
            imagePlaneVertexBuffer = device.makeBuffer(bytes: kImagePlaneVertexData, length: imagePlaneVertexDataCount, options: [])
            imagePlaneVertexBuffer.label = "ImagePlaneVertexBuffer"
            
            let defaultLibrary = device.makeDefaultLibrary()!
            
            let capturedImageVertexFunction = defaultLibrary.makeFunction(name: "graphics_vertex_ycbcr")!
            let capturedImageFragmentFunction = defaultLibrary.makeFunction(name: "graphics_fragment_ycbcr")!
            
            let imagePlaneVertexDescriptor = MTLVertexDescriptor()
            
            imagePlaneVertexDescriptor.attributes[0].format = .float2
            imagePlaneVertexDescriptor.attributes[0].offset = 0
            imagePlaneVertexDescriptor.attributes[0].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)
            
            imagePlaneVertexDescriptor.attributes[1].format = .float2
            imagePlaneVertexDescriptor.attributes[1].offset = 8
            imagePlaneVertexDescriptor.attributes[1].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)
            
            imagePlaneVertexDescriptor.layouts[0].stride = 16
            imagePlaneVertexDescriptor.layouts[0].stepRate = 1
            imagePlaneVertexDescriptor.layouts[0].stepFunction = .perVertex
            
            let capturedImagePipelineStateDescriptor = MTLRenderPipelineDescriptor()
            capturedImagePipelineStateDescriptor.label = "LKCapturedImagePipeline"
            capturedImagePipelineStateDescriptor.vertexFunction = capturedImageVertexFunction
            capturedImagePipelineStateDescriptor.fragmentFunction = capturedImageFragmentFunction
            capturedImagePipelineStateDescriptor.vertexDescriptor = imagePlaneVertexDescriptor
            capturedImagePipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            //            capturedImagePipelineStateDescriptor.depthAttachmentPixelFormat = .depth32Float_stencil8
            //            capturedImagePipelineStateDescriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8
            
            do {
                try capturedImagePipelineState = device.makeRenderPipelineState(descriptor: capturedImagePipelineStateDescriptor)
            } catch let error {
                print("Failed to created captured image pipeline state, error \(error)")
            }
            
//            let capturedImageDepthStateDescriptor = MTLDepthStencilDescriptor()
//            capturedImageDepthStateDescriptor.depthCompareFunction = .always
//            capturedImageDepthStateDescriptor.isDepthWriteEnabled = false
//            capturedImageDepthState = device.makeDepthStencilState(descriptor: capturedImageDepthStateDescriptor)
            
            var textureCache: CVMetalTextureCache?
            CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
            capturedImageTextureCache = textureCache
        }
        
        func render(viewportSize: CGSize, frame: ARFrame, drawable: CAMetalDrawable, callback: ((Context)->Void)? = nil){
            if currentViewPortSize != viewportSize{
                updateImagePlane(frame: frame, viewportSize: viewportSize)
            }
            currentViewPortSize = viewportSize
            updateCapturedImageTextures(frame: frame)
            if let commandBuffer = commandQueue.makeCommandBuffer(){
                
                let renderPassDescriptor = MTLRenderPassDescriptor()
                renderPassDescriptor.colorAttachments[0].texture = drawable.texture
                renderPassDescriptor.colorAttachments[0].loadAction = .load
                renderPassDescriptor.colorAttachments[0].clearColor = .init(red: 0, green: 0, blue: 0, alpha: 1)
                renderPassDescriptor.colorAttachments[0].storeAction = .store
                
                if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                    drawCapturedImage(renderEncoder: renderEncoder)
                    renderEncoder.endEncoding()
                }
                
                if let anchor = frame.anchors.first as? ARFaceAnchor{
                    let scene = SCNScene()
                    
                    let faceGeometry = ARSCNFaceGeometry(device: device)
                    let node = SCNNode(geometry: faceGeometry)
                    node.geometry?.firstMaterial?.diffuse.contents = UIColor.red
                    (node.geometry as? ARSCNFaceGeometry)?.update(from: anchor.geometry)
                    scene.rootNode.addChildNode(node)
                    node.simdTransform = anchor.transform
                    
                    let cameraNode = SCNNode()
                    let camera = SCNCamera()
                    cameraNode.camera = camera
                    cameraNode.simdTransform = frame.camera.viewMatrix(for: .portrait).inverse
                    camera.projectionTransform = SCNMatrix4(frame.camera.projectionMatrix(for: .landscapeRight, viewportSize: viewportSize, zNear: 0.005, zFar: 1000))
                    scene.rootNode.addChildNode(cameraNode)
                                        
                    sceneRenderer.scene = scene
                    sceneRenderer.pointOfView = cameraNode
                    sceneRenderer.render(atTime: 0, viewport: .init(origin: .init(x: 0, y: 0), size: .init(width: drawable.texture.width, height: drawable.texture.height)), commandBuffer: commandBuffer, passDescriptor: renderPassDescriptor)
                }
                
                
                commandBuffer.present(drawable)
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
            }
        }
        
        func updateImagePlane(frame: ARFrame, viewportSize: CGSize) {
            let displayToCameraTransform = frame.displayTransform(for: .portrait, viewportSize: viewportSize).inverted()
            
            let vertexData = imagePlaneVertexBuffer.contents().assumingMemoryBound(to: Float.self)
            for index in 0...3 {
                let textureCoordIndex = 4 * index + 2
                let textureCoord = CGPoint(x: CGFloat(kImagePlaneVertexData[textureCoordIndex]), y: CGFloat(kImagePlaneVertexData[textureCoordIndex + 1]))
                let transformedCoord = textureCoord.applying(displayToCameraTransform)
                vertexData[textureCoordIndex] = Float(transformedCoord.x)
                vertexData[textureCoordIndex + 1] = Float(transformedCoord.y)
            }
        }
        
        func drawCapturedImage(renderEncoder: MTLRenderCommandEncoder) {
            guard let textureY = capturedImageTextureY, let textureCbCr = capturedImageTextureCbCr else {
                return
            }
            
            // Push a debug group allowing us to identify render commands in the GPU Frame Capture tool
            renderEncoder.pushDebugGroup("DrawCapturedImage")
            
            // Set render command encoder state
            renderEncoder.setCullMode(.none)
            renderEncoder.setRenderPipelineState(capturedImagePipelineState)
//            renderEncoder.setDepthStencilState(capturedImageDepthState)
            
            // Set mesh's vertex buffers
            renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: Int(kBufferIndexMeshPositions.rawValue))
            
            // Set any textures read/sampled from our render pipeline
            renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureY), index: Int(kTextureIndexY.rawValue))
            renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureCbCr), index: Int(kTextureIndexCbCr.rawValue))
            
            // Draw each submesh of our mesh
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            
            renderEncoder.popDebugGroup()
        }
        
        func buildSamplerState(device: MTLDevice) -> MTLSamplerState {
            let samplerDescriptor = MTLSamplerDescriptor()
            samplerDescriptor.normalizedCoordinates = true
            samplerDescriptor.minFilter = .linear
            samplerDescriptor.magFilter = .linear
            samplerDescriptor.mipFilter = .linear
            return device.makeSamplerState(descriptor: samplerDescriptor)!
        }
        
        func updateCapturedImageTextures(frame: ARFrame) {
            // Create two textures (Y and CbCr) from the provided frame's captured image
            let pixelBuffer = frame.capturedImage
            
            if (CVPixelBufferGetPlaneCount(pixelBuffer) < 2) {
                return
            }
            
            capturedImageTextureY = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat:.r8Unorm, planeIndex:0)
            capturedImageTextureCbCr = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat:.rg8Unorm, planeIndex:1)
        }
        
        func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
            let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
            let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
            
            var texture: CVMetalTexture? = nil
            let status = CVMetalTextureCacheCreateTextureFromImage(nil, capturedImageTextureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)
            
            if status != kCVReturnSuccess {
                texture = nil
            }
            
            return texture
        }
    }
}
