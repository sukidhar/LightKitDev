//
//  LKCore.swift
//  LightKitDev
//
//  Created by sukidhar on 07/08/22.
//

import Foundation
import AVFoundation
import ARKit
import MetalKit
import RealityKit

enum LKFrame{
    case video(buffer: CMSampleBuffer)
    case augmentedFrame(frame: ARFrame)
}

class LKCore : NSObject, ObservableObject{
    typealias LKSession = NSObject
    
    @Published var currentFrame: LKFrame?
    @Published var audioBuffer: CMSampleBuffer?
    
    var session : LKSession{
        fatalError("can't get the stored varibale from an abstract class")
    }
    
    func run(){
        fatalError("Can't call this method on super class. Need to implement this method in subclass")
    }
    
    func stop(){
        fatalError("Can't call this method on super class. Need to implement this method in subclass")
    }
    
    enum Position {
        case front
        case back
    }
    
    enum Mode{
        case ar
        case nonAR
    }
}
