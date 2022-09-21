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

enum LKCoreType{
    case camera(position: AVCaptureDevice.Position)
    case arCamera(position: LKCore.Position)
    
    func getCore() throws -> LKCore {
        switch self {
        case .camera(position: let position):
            return try LKCameraCore(position: position)
        case .arCamera(position: let position):
            if #available(iOS 15, *) {
                return LKARCameraCore(position: position)
            } else {
                throw LKError.coreUnavailable
            }
        }
    }
}

class LKCore : NSObject, ObservableObject{
    typealias LKSession = NSObject
    
    @Published var currentFrame: LKFrame?
    @Published var audioBuffer: CMSampleBuffer?
        
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
}
