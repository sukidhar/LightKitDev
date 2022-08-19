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
    @Published var image : CGImage?
    
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
        try currentCore.currentFrame.publisher
            .receive(on: RunLoop.main)
            .compactMap({ frame in
                print(frame)
            switch frame {
            case .video(buffer: let buffer):
                guard let cgImage = CGImage.create(from: CMSampleBufferGetImageBuffer(buffer)), let ciImage = CIImage(cgImage: cgImage) else {
                    return nil
                }
                return self.context.createCGImage(ciImage, from: ciImage.extent)
            case .augmentedFrame(frame: _):
                return nil
            }
        })
        .assign(to: &$image)
        try currentCore.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
            print((try? self.currentCore.session as? AVCaptureSession)?.isRunning)
        })
    }
    
    func unloadCore() {
        core = nil
    }
}

extension CGImage {
  static func create(from cvPixelBuffer: CVPixelBuffer?) -> CGImage? {
    guard let pixelBuffer = cvPixelBuffer else {
      return nil
    }

    var image: CGImage?
    VTCreateCGImageFromCVPixelBuffer(
      pixelBuffer,
      options: nil,
      imageOut: &image)
    return image
  }
}
