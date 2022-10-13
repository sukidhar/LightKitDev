//
//  Filter.swift
//  LightKitDev
//
//  Created by sukidhar on 22/08/22.
//

import MetalKit
import AVFoundation
import simd
import Foundation

class LKFilter{
    
}

class LKModel{
    let name: String
    let mdlMeshes: [MDLMesh]
    let mtkMeshes: [MTKMesh]
    let textures: [MTLTexture]? = nil
    var isLoaded: Bool = false
    var transform = LKModelTransform()
    
    init(device: MTLDevice, vertexDescriptor: MDLVertexDescriptor, fileName: String, fileExtension: String = "obj", textureFiles: [String], textureLoadingOptions: [MTKTextureLoader.Option : Any]) {
        self.name = fileName
        let assetUrl = Bundle.main.url(forResource: fileName, withExtension: fileExtension)
        let allocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: assetUrl, vertexDescriptor: vertexDescriptor, bufferAllocator: allocator)
        
        guard let (mdlMeshes, mtkMeshes) = try? MTKMesh.newMeshes(asset: asset, device: device) else {
            self.mdlMeshes = []
            self.mtkMeshes = []
            return
        }
        
        self.mdlMeshes = mdlMeshes
        self.mtkMeshes = mtkMeshes
        isLoaded.toggle()
    }
}

struct LKModelTransform{
    var position = SIMD3<Float>(repeating: 0)
    var rotation = SIMD3<Float>(repeating: 0)
    var scale: Float = 1

    var matrix: float4x4  {
      let translateMatrix = float4x4(translation: position)
      let rotationMatrix = float4x4(rotation: rotation)
      let scaleMatrix = float4x4(scaling: scale)
      return translateMatrix * scaleMatrix * rotationMatrix
    }
}
