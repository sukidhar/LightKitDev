//
//  LKCore.swift
//  LightKitDev
//
//  Created by sukidhar on 07/08/22.
//

import Foundation
import AVFoundation
import ARKit

enum LKFrame{
    case video(buffer: CMSampleBuffer)
    case augmentedFrame(frame: ARFrame)
}

protocol LKCore {
    associatedtype LKSession : NSObject
    var currentFrame : LKFrame? { get set }
    var audioBuffer : CMSampleBuffer? { get set }
    var position : AVCaptureDevice.Position { get set }
    var session : LKSession { get }
    
    func run()
    func stop()
}


enum LKCoreType{
    case camera(position: AVCaptureDevice.Position)
    case arCamera(position: AVCaptureDevice.Position)
    case customCore(core: any LKCore)
    
    func getCore() throws -> any LKCore {
        switch self {
        case .camera(position: let position):
            return try LKCameraCore(position: position)
        case .arCamera(position: _):
            throw LKError.coreUnavailable
        case .customCore(core: let core):
            return core
        }
    }
}
