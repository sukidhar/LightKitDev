//
//  LightKitEngine+ViewProcessor.swift
//  LightKitDev
//
//  Created by sukidhar on 21/09/22.
//

import Metal
import QuartzCore

extension LightKitEngine{
    class ViewProcessor{
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
                    0, 0,
                    1, 0,
                    0, 1,
                    1, 1,
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
                    0, 1,
                    1, 1,
                    0, 0,
                    1, 0,
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


