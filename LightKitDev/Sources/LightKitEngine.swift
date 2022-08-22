//
//  CameraManager.swift
//  LightKitDev
//
//  Created by sukidhar on 31/07/22.
//

import AVFoundation
import ARKit
import Combine
import VideoToolbox
import MetalKit

class LightKitEngine : NSObject, ObservableObject {
    private var core : (any LKCore)?
    var currentCore : any LKCore  {
        get throws{
            if let core = core{
                return core
            }
            throw LKError.coreUnavailable
        }
    }
    
    @Published public private(set) var cameraTexture : MTLTexture?
    @Published var image: CGImage?
    private let context = CIContext()
    
    let metalDevice = MTLCreateSystemDefaultDevice()
    let metalView : MTKView
    private var textureCache : CVMetalTextureCache?
    private let _commandQueue : MTLCommandQueue?
    var commandQueue : MTLCommandQueue {
        get throws{
            if let commandQueue = _commandQueue {
                return commandQueue
            }
            throw LKError.failedToIntialiseViewProcessor
        }
    }
    private var viewProcessor : ViewProcessor?
    private var currentProcessor : ViewProcessor {
        get throws{
            if let viewProcessor = viewProcessor{
                return viewProcessor
            }
            throw LKError.failedToIntialiseViewProcessor
        }
    }
    static let instance = LightKitEngine()
    
    override private init() {
        metalView = .init(frame: .zero, device: metalDevice)
        metalView.backgroundColor = .clear
        metalView.framebufferOnly = false
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.contentScaleFactor = UIWindowScene.current?.screen.nativeScale ?? 1
        _commandQueue = metalDevice?.makeCommandQueue()
        super.init()
        do {
            try loadCore(with: .camera(position: .back))
        } catch {
            print(error)
        }
        
    }
    
    func loadCore(with coreType: LKCoreType) throws {
        core = try coreType.getCore()
        loadViewProcessor()
        try (currentCore as! LKCameraCore).$currentFrame
            .receive(on: RunLoop.main)
            .compactMap({ [unowned self] frame in
                switch frame {
                case .video(buffer: let buffer):
                    renderPixelBuffer(sampleBuffer: buffer)
                    return nil
                case .augmentedFrame(frame: _):
                    return nil
                case .none:
                    return nil
                }
            })
            .assign(to: &$image)
        try currentCore.run()
    }
    
    private func loadViewProcessor(){
        guard let core = try? currentCore else {
            preconditionFailure("Expected an object confirming to protocol LKCore to be loaded")
        }
        switch core.position {
        case .unspecified:
            viewProcessor = try? .init(device: metalDevice)
        case .back:
            viewProcessor = try? .init(device: metalDevice)
        case .front:
            viewProcessor = try? .init(device: metalDevice, metaDataType: .mirrored)
        @unknown default:
            viewProcessor = try? .init(device: metalDevice)
        }
    }
    
    func unloadCore() {
        core = nil
    }
    
    func renderPixelBuffer(sampleBuffer : CMSampleBuffer){
        _ = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard let cvbuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let sourceTexture = makeTexture(imageBuffer: cvbuffer) else { return }
        cameraTexture = makeEmptyTexture(width: sourceTexture.width, height: sourceTexture.height)
        autoreleasepool { [unowned self] in
            if let drawable = metalView.currentDrawable{
                do {
                    let commandBuffer = try commandQueue.makeCommandBuffer()
                    try currentProcessor.encode(commandBuffer: commandBuffer, targetDrawable: drawable, presentingTexture: sourceTexture)
                    commandBuffer?.present(drawable)
                    commandBuffer?.commit()
                    commandBuffer?.waitUntilCompleted()
                } catch {
                    print(error)
                }
            }
        }
    }
    
    func makeEmptyTexture(width: Int, height: Int) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: viewProcessor?.pixelFormat ?? .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [MTLTextureUsage.shaderWrite, .shaderRead]
        return metalDevice?.makeTexture(descriptor: textureDescriptor)
    }
    
    func makeTexture(imageBuffer : CVPixelBuffer) -> MTLTexture?{
        if textureCache == nil {
            makeTextureCache()
        }
        if let textureCache = textureCache{
            let width = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)
            var imageTexture: CVMetalTexture?
            let result =  CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault,
                textureCache,
                imageBuffer,
                nil,
                try! currentProcessor.pixelFormat,
                width,
                height,
                0,
                &imageTexture
            )
            if result == kCVReturnSuccess, let _imageTexture = imageTexture {
                return CVMetalTextureGetTexture(_imageTexture)
            }
        }
        return nil
    }
    
    func makeTextureCache() {
        guard let metalDevice = metalDevice else {
            return
        }
        CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            metalDevice,
            nil,
            &textureCache
        )
    }
}

extension LightKitEngine{
    private class ViewProcessor{
        private let vertexBuffer: MTLBuffer
        private let textureBuffer: MTLBuffer
        private let vertexIndexBuffer: MTLBuffer
        private let renderPipelineState: MTLRenderPipelineState
        public let pixelFormat: MTLPixelFormat
        private let metaDataType : ViewProcessorMetaDataType
        private let metaData : ViewProcessorMetaData
        
        init(device: MTLDevice?, pixelFormat: MTLPixelFormat = .bgra8Unorm, metaDataType: ViewProcessorMetaDataType = .normal) throws {
            self.pixelFormat = pixelFormat
            self.metaDataType = metaDataType
            self.metaData = self.metaDataType.value()
            
            guard let vertexBuffer = device?.makeBuffer(bytes: metaData.vertexData, length: metaData.vertexData.count * MemoryLayout.size(ofValue: metaData.vertexData[0]), options: .storageModeShared),
                  let textureBuffer = device?.makeBuffer(bytes: metaData.textureData, length: metaData.textureData.count * MemoryLayout.size(ofValue: metaData.textureData[0]), options: .storageModeShared),
                  let vertexIndexBuffer = device?.makeBuffer(bytes: metaData.vertexIndexData, length: metaData.textureData.count * MemoryLayout.size(ofValue: metaData.vertexIndexData[0]), options: .storageModeShared), let device = device, let library = device.makeDefaultLibrary()
            else {
                throw LKError.failedToIntialiseViewProcessor
            }
            
            
            
            let fragmentFunction = library.makeFunction(name: "graphics_fragment")
            let vertexFunction = library.makeFunction(name: "graphics_vertex")
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
            
            self.vertexBuffer = vertexBuffer
            self.textureBuffer = textureBuffer
            self.vertexIndexBuffer = vertexIndexBuffer
            self.renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }
        
        open func encode(commandBuffer: MTLCommandBuffer?, targetDrawable: CAMetalDrawable, presentingTexture: MTLTexture) {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = targetDrawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = .init(red: 0, green: 0, blue: 0, alpha: 1)
            
            let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            renderEncoder?.setRenderPipelineState(renderPipelineState)
            renderEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder?.setVertexBuffer(textureBuffer, offset: 0, index: 1)
            renderEncoder?.setFragmentTexture(presentingTexture, index: 0)
            renderEncoder?.drawIndexedPrimitives(
                type: .triangle,
                indexCount: metaData.vertexIndexData.count,
                indexType: .uint16,
                indexBuffer: vertexIndexBuffer,
                indexBufferOffset: 0
            )
            renderEncoder?.endEncoding()
        }
    }
    
    struct ViewProcessorMetaData {
        let vertexData : [Float]
        let textureData : [Float]
        let vertexIndexData : [UInt16]
    }
    
    enum ViewProcessorMetaDataType{
        case normal
        case mirrored
        case custom(viewProcessorMetaData : ViewProcessorMetaData)
        
        func value()->ViewProcessorMetaData{
            switch self {
            case .normal:
                return .init(vertexData: [
                    1.0, 1.0,
                    1.0, -1.0,
                    -1.0, 1.0,
                    -1.0, -1.0
                ],textureData:  [
                    1, 0,
                    1, 1,
                    0, 0,
                    0, 1
                ],vertexIndexData: [
                    0, 1, 2,
                    1, 2, 3
                ])
            case .mirrored:
                return .init(vertexData: [
                    1.0, 1.0,
                    1.0, -1.0,
                    -1.0, 1.0,
                    -1.0, -1.0
                ], textureData:  [
                    1, 1,
                    1, 0,
                    0, 1,
                    0, 0
                ], vertexIndexData: [
                    0, 1, 2,
                    1, 2, 3
                ])
            case .custom(viewProcessorMetaData: let viewProcessorMetaData):
                return viewProcessorMetaData
            }
        }
    }
}


