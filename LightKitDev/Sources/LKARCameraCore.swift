//
//  LKARCameraCore.swift
//  LightKitDev
//
//  Created by sukidhar on 20/09/22.
//

import ARKit
import SceneKit

class LKARCameraCore : NSObject, LKCore{
    var currentFrame: LKFrame?
    
    var audioBuffer: CMSampleBuffer?
    
    var position: AVCaptureDevice.Position
    
    var session: ARSession
    
    private var configuration : ARConfiguration
    
    func run() {
        session.run(configuration, options: .resetTracking)
    }
    
    func stop() {
        session.pause()
    }
    
    init(currentFrame: LKFrame? = nil, audioBuffer: CMSampleBuffer? = nil, position: AVCaptureDevice.Position, session: ARSession) {
        self.currentFrame = currentFrame
        self.audioBuffer = audioBuffer
        self.position = position
        self.session = session
        switch position{
        case .unspecified:
            configuration = ARWorldTrackingConfiguration()
        case .back:
            configuration = ARWorldTrackingConfiguration()
            if ARWorldTrackingConfiguration.supportsUserFaceTracking{
                (configuration as? ARWorldTrackingConfiguration)?.userFaceTrackingEnabled = true
            }
        case .front:
            configuration = ARFaceTrackingConfiguration()
            if ARFaceTrackingConfiguration.supportsWorldTracking{
                (configuration as? ARFaceTrackingConfiguration)?.isWorldTrackingEnabled = true
            }
        @unknown default:
            fatalError("Unkown configuration required, please create a custom core by extending LKCore")
        }
        super.init()
        session.delegate = self
    }
}

extension LKARCameraCore : ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
    }
    
    func session(_ session: ARSession, didOutputAudioSampleBuffer audioSampleBuffer: CMSampleBuffer) {
        
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        
    }
}
