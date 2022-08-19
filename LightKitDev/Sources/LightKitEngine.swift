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

class LightKitEngine : NSObject, ObservableObject {
    @Published private var core : (any LKCore)?
    private let context = CIContext()
    
    var currentCore : any LKCore  {
        get throws{
            if let core = core{
                return core
            }
            throw LKError.coreUnavailable
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
    }
    
    func loadCore(with coreType: LKCoreType) throws {
        core = try coreType.getCore()
        try (currentCore as! LKCameraCore).$currentFrame
            .receive(on: RunLoop.main)
            .compactMap({ frame in
            switch frame {
            case .video(buffer: let buffer):
                return UIImage(ciImage: CIImage(cvPixelBuffer: buffer.imageBuffer!))
            case .augmentedFrame(frame: _):
                return nil
            case .none:
                return nil
            }
        })
        try currentCore.run()
    }
    
    func unloadCore() {
        core = nil
    }
}
