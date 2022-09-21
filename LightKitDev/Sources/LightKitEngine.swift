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
import MetalPerformanceShaders
import RealityKit
import SceneKit

class LightKitEngine: NSObject, ObservableObject {
    
    /// The core that is set currently for the engine to receive input
    private var core: LKCore?
    
    /// Retrieves the instance of LKCore that is being used for the engine at the time of calling.
    var currentCore: LKCore  {
        get throws{
            if let core = core{
                return core
            }
            throw LKError.coreUnavailable
        }
    }
    /// The sink that fetches the current core frames
    private var coreSink : AnyCancellable?
    
    let fallBackMTAllocator : MPSCopyAllocator =
    {
        (kernel: MPSKernel, buffer: MTLCommandBuffer, texture: MTLTexture) -> MTLTexture in
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: texture.pixelFormat,
                                                                  width: texture.width,
                                                                  height: texture.height,
                                                                  mipmapped: false)
        descriptor.usage = [.shaderWrite, .shaderRead]
        return buffer.device.makeTexture(descriptor: descriptor)!
    }
        
    /// The current buffer received from the core. This publisher will not receieve any value if the core is not LKCameraCore
    @Published public private(set) var currentBuffer : CMSampleBuffer?
    private var currentBufferSink : AnyCancellable?
    
    /// Unprocessed Metal Texture generated, i.e camera output or ARFrame output as is published.
    @Published public private(set) var originalTexture : LKTextureNode?
    private var orginalTextureSink : AnyCancellable?
    
    @Published public private(set) var processedTexture : LKTextureNode?
    
    private let context = CIContext()
    
    private var metalDevice : MTLDevice?
    private var metalView : MTKView?
    private var arView : ARView?
    private var arscnView : ARSCNView?
        
    private var textureCache : CVMetalTextureCache?
    private var _commandQueue : MTLCommandQueue?
    
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
        super.init()
        do {
            try loadCore(with: .camera(position: .back))
        } catch {
            print(error)
        }
        render()
    }
    
    func loadMTKView(){
        metalView = MTKView(frame: .zero)
        metalView?.device = MTLCreateSystemDefaultDevice()
        metalDevice = metalView?.device
        metalView?.backgroundColor = .clear
        metalView?.framebufferOnly = false
        metalView?.colorPixelFormat = .bgra8Unorm
        metalView?.contentScaleFactor = UIWindowScene.current?.screen.nativeScale ?? 1
        metalView?.preferredFramesPerSecond = 60
        _commandQueue = metalDevice?.makeCommandQueue()
    }
    
    @available(iOS 15, *)
    func loadARView(){
        arView = .init(frame: .zero)
        arView?.contentScaleFactor = UIWindowScene.current?.screen.nativeScale ?? 1
        arView?.renderCallbacks.postProcess = { [unowned self]
            context in
            processARRenderCallback(context: context)
        }
    }
    
    @available(iOS 15, *)
    func processARRenderCallback(context: ARView.PostProcessContext){
        let edge = MPSImageSobel(device: context.device)
        edge.encode(commandBuffer: context.commandBuffer, sourceTexture: context.sourceColorTexture, destinationTexture: context.compatibleTargetTexture)
        
    }
    
    func loadCore(with coreType: LKCoreType) throws {
        unloadCore()
        let coreResult = try coreType.getCore()
        self.core = coreResult.core
        if let _ = coreResult.viewType as? MTKView.Type{
            loadMTKView()
        }else if let _ = coreResult.viewType as? ARView.Type{
            if #available(iOS 15, *) {
                loadARView()
            } else {
                
            }
        }
        loadViewProcessor()
        coreSink = try (currentCore as! LKCameraCore).$currentFrame
            .receive(on: RunLoop.main)
            .compactMap({ frame in
                switch frame {
                case .video(buffer: let buffer):
                    return buffer
                case .augmentedFrame(frame: _):
                    return nil
                case .none:
                    return nil
                }
            })
            .sink(receiveValue: { [weak self] buffer in
                self?.currentBuffer = buffer
            })
            
        try currentCore.run()
    }
    
    func render(){
        $currentBuffer
            .receive(on: RunLoop.main)
            .compactMap({ [unowned self] buffer in
                if let buffer = buffer{
                    guard let cvbuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
                    return .init(texture: makeTexture(imageBuffer: cvbuffer), timestamp: CMSampleBufferGetPresentationTimeStamp(buffer))
                }
                return nil
            })
            .assign(to: &$originalTexture)
        
        orginalTextureSink = $originalTexture
            .receive(on: RunLoop.main)
            .sink { [unowned self] texture in
                commitToProcessor()
            }
    }
    
    private func makeThreadgroupsConfig(
        textureWidth: Int,
        textureHeight: Int,
        threadExecutionWidth: Int,
        maxTotalThreadsPerThreadgroup: Int
        ) -> (threadgroupsPerGrid: MTLSize, threadsPerThreadgroup: MTLSize) {
        
        let w = threadExecutionWidth
        let h = maxTotalThreadsPerThreadgroup / w
        
        let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
        let horizontalThreadgroupCount = (textureWidth + w - 1) / w
        let verticalThreadgroupCount = (textureHeight + h - 1) / h
        let threadgroupsPerGrid = MTLSizeMake(horizontalThreadgroupCount, verticalThreadgroupCount, 1)
        
        return (threadgroupsPerGrid: threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
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
        try? currentCore.stop()
        core = nil
    }
    
    func commitToProcessor(){
        guard var sourceTexture = originalTexture?.texture else { return }
        processedTexture = .init(texture: makeEmptyTexture(width: sourceTexture.width, height: sourceTexture.height), timestamp: originalTexture?.timestamp)
        autoreleasepool { [unowned self] in
            if let drawable = metalView?.currentDrawable, let commandBuffer = try? commandQueue.makeCommandBuffer(){
                do {
                    let sobel = MPSImageSobel(device: metalDevice!)
                    sobel.encode(commandBuffer: commandBuffer,
                                    inPlaceTexture: &sourceTexture,
                                    fallbackCopyAllocator: fallBackMTAllocator)
//                    let filter = MPSImageGaussianBlur(device: metalDevice!, sigma: 3)
//                    filter.encode(commandBuffer: commandBuffer, inPlaceTexture: &sourceTexture, fallbackCopyAllocator: fallBackMTAllocator)
//                    sobel.encode(commandBuffer: commandBuffer,
//                                    inPlaceTexture: &sourceTexture,
//                                    fallbackCopyAllocator: fallBackMTAllocator)
                    try currentProcessor.encode(commandBuffer: commandBuffer, targetDrawable: drawable, presentingTexture: sourceTexture)
                    commandBuffer.addCompletedHandler({ [unowned self] _ in
                        processedTexture = .init(texture: drawable.texture, timestamp: originalTexture?.timestamp)
                    })
                    commandBuffer.present(drawable)
                    commandBuffer.commit()
                    commandBuffer.waitUntilCompleted()
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
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: viewProcessor?.pixelFormat ?? .bgra8Unorm,
            width: CVPixelBufferGetWidth(imageBuffer),
            height: CVPixelBufferGetHeight(imageBuffer),
            mipmapped: false
        )
        textureDescriptor.usage = [MTLTextureUsage.shaderWrite, .shaderRead]
        if let ioSurface = CVPixelBufferGetIOSurface(imageBuffer){
            return metalDevice?.makeTexture(descriptor: textureDescriptor, iosurface: ioSurface.takeUnretainedValue(), plane: 0)
        }
        return nil
    }
}
