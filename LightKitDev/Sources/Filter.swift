//
//  Filter.swift
//  LightKitDev
//
//  Created by sukidhar on 22/08/22.
//

import AVFoundation
import CoreImage

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
    static var edgeDetectionFilter: (_ strength: Int)->Filter = { strength in
        return Filter(metalFunction: "edgeDetector", expectedTextures: 1, processedTextures: 1)
    }
}

/// lets analyse things in full scale
///
///  firstly, we need some default filters
///  secondly, we need some chained default filters, i.e beauty etc
///  thirdly, we need some custom chaining to chain chained or normal filters.
///  after all, we dont want to store all this data on device, so we let them have custom datamodel to retrieve them
///
///     points to note:
///     we can't have custom fragment shader like them, because we 
