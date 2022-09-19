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
            activeFormat = formats.sorted(by: { f1, f2 in
                f1.formatDescription.dimensions.height > f2.formatDescription.dimensions.height && f1.formatDescription.dimensions.width > f2.formatDescription.dimensions.width
            })
            .first(where: { format in
                format.videoSupportedFrameRateRanges.contains { range in
                    range.maxFrameRate == frameRate
                }
            }) ?? activeFormat
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

extension MTLTexture{    
    func toImage(scale: CGFloat = 1.0, orientation: UIImage.Orientation = .upMirrored) -> UIImage? {
        let context = CIContext()
        guard let ciImage = CIImage.init(mtlTexture: self, options: [.colorSpace: CGColorSpaceCreateDeviceRGB()]),         let cgImage : CGImage = context.createCGImage(ciImage, from: ciImage.extent)
        else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: orientation)
    }
}
