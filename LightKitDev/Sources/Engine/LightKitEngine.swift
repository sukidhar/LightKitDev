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
    
    private let fallBackMTAllocator : MPSCopyAllocator =
    {
        (kernel: MPSKernel, buffer: MTLCommandBuffer, texture: MTLTexture) -> MTLTexture in
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: texture.pixelFormat,
                                                                  width: texture.width,
                                                                  height: texture.height,
                                                                  mipmapped: false)
        descriptor.usage = [.shaderWrite, .shaderRead]
        return buffer.device.makeTexture(descriptor: descriptor)!
    }
    
    private var arCallBackSemaphore = DispatchSemaphore(value: 1)
        
    /// The current buffer received from the core. This publisher will not receieve any value if the core is not LKCameraCore
    @Published public private(set) var currentBuffer : CMSampleBuffer?
    private var currentBufferSink : AnyCancellable?
    
    @Published public private(set) var currentARFrame : ARFrame?
    private var currentARFrameSink : AnyCancellable?
    
    /// Unprocessed Metal Texture generated, i.e camera output or ARFrame output as is published.
    @Published public private(set) var originalTexture : LKTextureNode?
    private var orginalTextureSink : AnyCancellable?
    
    @Published public private(set) var processedTexture : LKTextureNode?
    
    private var intermediaryTexture : MTLTexture?
    
    private let context = CIContext()
    
    private var metalDevice : MTLDevice?

    @Published private(set) var view : UIView = .init(frame: .zero)
    
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
    
    private var offScreenProcesser: OffScreenProcessor?
    private var currentOffScreenProcessor : ViewProcessor {
        get throws{
            if let viewProcessor = viewProcessor{
                return viewProcessor
            }
            throw LKError.failedToInitialiseOffScreenProcessor
        }
    }
    
    static let instance = LightKitEngine()
    
    override private init() {
        super.init()
        do {
            try loadCore(position: .back, mode: .nonAR)
        } catch {
            print(error)
        }
        render()
    }
    
    func loadMTKView(){
        view = MTKView(frame: .zero)
        if let metalView = view as? MTKView{
            metalDevice = MTLCreateSystemDefaultDevice()
            metalView.device = metalDevice
            metalView.backgroundColor = .clear
            metalView.framebufferOnly = false
            metalView.colorPixelFormat = .bgra8Unorm
            metalView.contentScaleFactor = UIWindowScene.current?.screen.nativeScale ?? 1
            metalView.preferredFramesPerSecond = 60
            _commandQueue = metalDevice?.makeCommandQueue()
        }
    }
    
    func loadARMetalView(){
        loadMTKView()
        if let metalView = view as? MTKView{
            metalView.depthStencilPixelFormat = .depth32Float_stencil8
            metalView.colorPixelFormat = .bgra8Unorm
            metalView.sampleCount = 1
        }
    }
    
    @available(iOS 15, *)
    func loadARView(){
        view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        if let arView = view as? ARView{
            arView.contentScaleFactor = UIWindowScene.current?.screen.nativeScale ?? 1
            arView.renderCallbacks.postProcess = { [unowned self]
                context in
                processARRenderCallback(context: context)
            }
        }
    }

    @available(iOS 15, *)
    func processARRenderCallback(context: ARView.PostProcessContext){
        arCallBackSemaphore.wait()
        context.prepareTexture(&self.intermediaryTexture)
        let blur = MPSImageGaussianBlur(device: context.device, sigma: 5)
        blur.encode(commandBuffer: context.commandBuffer, sourceTexture: context.sourceColorTexture, destinationTexture: intermediaryTexture!)
        let edge = MPSImageSobel(device: context.device)
        edge.encode(commandBuffer: context.commandBuffer, inPlaceTexture: &intermediaryTexture!, fallbackCopyAllocator: fallBackMTAllocator)
        let blitEncoder = context.commandBuffer.makeBlitCommandEncoder()
        blitEncoder?.copy(from:  intermediaryTexture!, to: context.compatibleTargetTexture)
        blitEncoder?.endEncoding()
        context.commandBuffer.addCompletedHandler { [unowned self] _ in
            arCallBackSemaphore.signal()
        }
    }
    
    func loadCore(position: LKCore.Position, mode: LKCore.Mode) throws{
        unloadCore()
        switch mode{
        case .ar:
//            if #available(iOS 15, *) {
//                loadARView()
//                if let arView = view as? ARView{
//                    switch position{
//                    case .front:
//                        core = LKARCameraCore(position: .front, session: arView.session)
//                    case .back:
//                        core = LKARCameraCore(position: .back, session: arView.session)
//                    }
//                }
//            }else{
                loadARMetalView()
                switch position{
                case .front:
                    core = LKARCameraCore(position: .front)
                    viewProcessor = try? .init(device: metalDevice)
                case .back:
                    core = LKARCameraCore(position: .back)
                }
                if let device = metalDevice{
                    if let queue = try? commandQueue{
                        offScreenProcesser = .init(device: device, commandQueue: queue)
                    }
                }
//            }
            
        case .nonAR:
            switch position{
            case .front:
                core = try LKCameraCore(position: .front, fps: 60)
                loadMTKView()
                viewProcessor = try? .init(device: metalDevice, metaDataType: .mirrored)
            case .back:
                core = try LKCameraCore(position: .back, fps: 60)
                loadMTKView()
                viewProcessor = try? .init(device: metalDevice)
            }
        }
        
        coreSink = try currentCore.$currentFrame
            .receive(on: RunLoop.main)
            .compactMap({ frame in
                switch frame {
                case .none:
                    return nil
                case .some(let frame):
                    return frame
                }
            })
            .sink(receiveValue: { [weak self] (frame: LKFrame) in
                switch frame{
                case .video(buffer: let buffer):
                    self?.currentBuffer = buffer
                case .augmentedFrame(frame: let frame):
                    self?.currentARFrame = frame
                }
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
        
        currentARFrameSink = $currentARFrame
            .receive(on: RunLoop.main)
            .compactMap({ $0 })
            .sink(receiveValue: { [unowned self] frame in
                process(arFrame: frame)
            })
        
        orginalTextureSink = $originalTexture
            .receive(on: RunLoop.main)
            .compactMap({ $0 })
            .sink { [unowned self] texture in
                commitToViewProcessor()
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

    
    func unloadCore() {
        try? currentCore.stop()
        core = nil
    }
    
    func process(arFrame frame: ARFrame){
        if let metalView = view as? MTKView, let drawable = metalView.currentDrawable {
            intermediaryTexture = makeEmptyTexture(width: drawable.texture.width, height: drawable.texture.height)
            offScreenProcesser?.render(viewportSize: view.frame.size, frame: frame, drawable: drawable)
//            do {
//                commandBuffer.present(drawable)
//                commandBuffer.commit()
//                commandBuffer.waitUntilCompleted()
//            } catch {
//                print(error)
//            }
        }
    }
    
    
    func commitToViewProcessor(){
        guard let sourceTexture = originalTexture?.texture else { return }
        autoreleasepool { [unowned self] in
            if let metalView = view as? MTKView, let drawable = metalView.currentDrawable, let commandBuffer = try? commandQueue.makeCommandBuffer(), var pipelineTexture = makeEmptyTexture(width: sourceTexture.width, height: sourceTexture.height){
                do {
                    let sobel = MPSImageSobel(device: metalDevice!)
                    sobel.encode(commandBuffer: commandBuffer, sourceTexture: sourceTexture, destinationTexture: pipelineTexture)
                
                    let filter = MPSImageGaussianBlur(device: metalDevice!, sigma: 9)
                    filter.encode(commandBuffer: commandBuffer, inPlaceTexture: &pipelineTexture)
                    sobel.encode(commandBuffer: commandBuffer,
                                    inPlaceTexture: &pipelineTexture,
                                    fallbackCopyAllocator: fallBackMTAllocator)
                    try currentProcessor.encode(commandBuffer: commandBuffer, targetDrawable: drawable, presentingTexture: pipelineTexture)
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
    
    func makeEmptyTexture(pixelFormat: MTLPixelFormat = .bgra8Unorm, width: Int, height: Int, metalDevice: MTLDevice? = nil) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [MTLTextureUsage.shaderWrite, .shaderRead, .renderTarget]
        return (metalDevice ?? self.metalDevice)?.makeTexture(descriptor: textureDescriptor)
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
