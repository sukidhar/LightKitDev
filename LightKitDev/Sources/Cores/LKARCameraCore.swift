//
//  LKARCameraCore.swift
//  LightKitDev
//
//  Created by sukidhar on 20/09/22.
//



import ARKit
import RealityKit
import SceneKit


class LKARCameraCore : LKCore{
    var position: Position
    
    let _session : ARSession
    
    override var session: LKCore.LKSession{
        return _session
    }
            
    private var configuration : ARConfiguration
    
    override func run() {
        _session.run(configuration, options: .resetTracking)
    }
    
    override func stop() {
        _session.pause()
    }
    
    init(position: Position = .back, session : ARSession = .init()) {
        self.position = position
        _session = session
        switch position{
        case .back:
            configuration = ARWorldTrackingConfiguration()
            if ARWorldTrackingConfiguration.supportsUserFaceTracking{
                (configuration as? ARWorldTrackingConfiguration)?.userFaceTrackingEnabled = true
            }
        case .front:
            configuration = ARFaceTrackingConfiguration()
            if ARFaceTrackingConfiguration.supportsWorldTracking{
                (configuration as? ARFaceTrackingConfiguration)?.isWorldTrackingEnabled = true
                (configuration as? ARFaceTrackingConfiguration)?.maximumNumberOfTrackedFaces = ARFaceTrackingConfiguration.supportedNumberOfTrackedFaces
            }
        }
        super.init()
        _session.delegate = self
    }
}

extension LKARCameraCore : ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        print("anchor added")
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        print("anchor removed")
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        currentFrame = .augmentedFrame(frame: frame)
    }
    
    func session(_ session: ARSession, didOutputAudioSampleBuffer audioSampleBuffer: CMSampleBuffer) {
        audioBuffer = audioSampleBuffer
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        print("anchor updated \(session.currentFrame?.timestamp)")
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        
    }
}
