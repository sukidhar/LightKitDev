//
//  Extensions.swift
//  LightKitDev
//
//  Created by sukidhar on 22/08/22.
//

import UIKit
import AVFoundation

extension UIWindowScene{
    public static var current : UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene
    }
}

extension AVCaptureDevice {
    func set(frameRate: Double) {
    do { try lockForConfiguration()
        activeFormat = formats.first(where: { format in
            format.videoSupportedFrameRateRanges.contains { range in
                range.maxFrameRate == frameRate
            }
        }) ?? activeFormat
        print(activeFormat)
        guard let range = activeFormat.videoSupportedFrameRateRanges.first,
            range.minFrameRate...range.maxFrameRate ~= frameRate
            else {
                print("Requested FPS is not supported by the device's activeFormat !")
                return
        }

    
        activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
        activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
        unlockForConfiguration()
    } catch {
        print("LockForConfiguration failed with error: \(error.localizedDescription)")
    }
  }
}
