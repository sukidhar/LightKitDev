//
//  LightKitEngine+OffScreenProcessor.swift
//  LightKitDev
//
//  Created by sukidhar on 23/09/22.
//

import ARKit
import MetalKit
import SceneKit

extension LightKitEngine{
    class OffScreenProcessor{
        let session : ARSession! = nil
        var commandQueue: MTLCommandQueue!
        var sharedUniformBuffer: MTLBuffer!
        var anchorUniformBuffer: MTLBuffer!
        var imagePlaneVertexBuffer: MTLBuffer!
        var capturedImagePipelineState: MTLRenderPipelineState!
        var capturedImageDepthState: MTLDepthStencilState!
        var anchorPipelineState: MTLRenderPipelineState!
        var anchorDepthState: MTLDepthStencilState!
        var capturedImageTextureY: CVMetalTexture?
        var capturedImageTextureCbCr: CVMetalTexture?
    }
}
