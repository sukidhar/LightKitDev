//
//  Extensions.swift
//  LightKitDev
//
//  Created by sukidhar on 22/08/22.
//

import UIKit
import AVFoundation
import RealityKit
import MetalKit

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

@available(iOS 15, *)
extension RealityKit.ARView.PostProcessContext {
    
    /// Returns the output texture, ensuring that the pixel format is appropriate for the current device's
    /// GPU.
    var compatibleTargetTexture: MTLTexture! {
        if self.device.supportsFamily(.apple2) {
            return targetColorTexture
        } else {
            return targetColorTexture.makeTextureView(pixelFormat: .bgra8Unorm)!
        }
    }
}

@available(iOS 15, *)
extension ARView.PostProcessContext {
    /// Reallocates a new Metal output texture if the input and output textures don't match in size.
    func prepareTexture(_ texture: inout MTLTexture?, format pixelFormat: MTLPixelFormat = .rgba8Unorm) {
        if texture?.width != self.sourceColorTexture.width
            || texture?.height != self.sourceColorTexture.height {
            let descriptor = MTLTextureDescriptor()
            descriptor.width = self.sourceColorTexture.width
            descriptor.height = self.sourceColorTexture.height
            descriptor.pixelFormat = pixelFormat
            descriptor.usage = [.shaderRead, .shaderWrite]
            texture = self.device.makeTexture(descriptor: descriptor)
        }
    }
}
