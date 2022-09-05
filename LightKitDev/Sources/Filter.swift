//
//  Filter.swift
//  LightKitDev
//
//  Created by sukidhar on 22/08/22.
//

import AVFoundation

class Filter{
    
    let metalFunction : String
    let expectedTextures : Int
    let processedTextures : Int
    
    init(metalFunction: String, expectedTextures: Int, processedTextures: Int) {
        self.metalFunction = metalFunction
        self.expectedTextures = expectedTextures
        self.processedTextures = processedTextures
    }
}

extension Filter{
    static let edgeDetectionFilter = Filter(metalFunction: "edgeDetector", expectedTextures: 1, processedTextures: 1)
}
