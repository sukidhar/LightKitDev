//
//  LKCameraCore.swift
//  LightKitDev
//
//  Created by sukidhar on 07/08/22.
//

import Foundation
import AVFoundation

class LKCameraCore : LKCore {
    var position: AVCaptureDevice.Position {
        device.position
    }
    let session: AVCaptureSession = .init()
    let videoOutput : AVCaptureVideoDataOutput = .init()
    let audioOutput : AVCaptureAudioDataOutput = .init()
    
    let device : AVCaptureDevice
    
    private var sessionQueue = DispatchQueue.init(label: "com.lightkit.sessionqueue")
    private var cameraQueue = DispatchQueue(label: "com.lightkit.videodata",
                                            qos: .userInitiated,
                                            attributes: [],
                                            autoreleaseFrequency: .workItem)
    
    override func run() {
        sessionQueue.async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    override func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }
    
    init(position: AVCaptureDevice.Position = .unspecified, fps: Double = 60) throws {
        guard let captureDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera], mediaType: .video, position: position).devices.first else {
            throw LKError.devicesUnavailable
        }
        device = captureDevice
        super.init()
        session.beginConfiguration()
        guard let videoInput = try? AVCaptureDeviceInput(device: device) else {
            throw LKError.insufficientPermissions
        }
        guard session.canAddInput(videoInput) else {
            throw LKError.insufficientPermissions
        }
        session.addInput(videoInput)
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else
        {
            throw LKError.devicesUnavailable
        }
        guard let audioInput = try? AVCaptureDeviceInput(device: audioDevice) else {
            throw LKError.insufficientPermissions
        }
        guard session.canAddInput(audioInput) else {
            throw LKError.insufficientPermissions
        }
        session.addInput(audioInput)
        videoOutput.videoSettings =
          [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.connection(with: .video)?.videoOrientation = .portrait
        guard session.canAddOutput(videoOutput) else {
            throw LKError.insufficientPermissions
        }
        session.addOutput(videoOutput)
        guard session.canAddOutput(audioOutput) else {
            throw LKError.insufficientPermissions
        }
        session.addOutput(audioOutput)
        videoOutput.setSampleBufferDelegate(self, queue: cameraQueue)
        audioOutput.setSampleBufferDelegate(self, queue: cameraQueue)
        session.automaticallyConfiguresApplicationAudioSession = false
        device.set(frameRate: fps)
        session.commitConfiguration()
    }
}

extension LKCameraCore : AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        DispatchQueue.main.async {
            if output == self.videoOutput {
                self.currentFrame = .video(buffer: sampleBuffer)
            }else{
                self.audioBuffer = sampleBuffer
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
    }
}
