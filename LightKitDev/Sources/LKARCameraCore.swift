//
//  LKARCameraCore.swift
//  LightKitDev
//
//  Created by sukidhar on 20/09/22.
//



import ARKit
import RealityKit
import SceneKit


@available(iOS 15, *)
class LKARCameraCore : LKCore{
    var position: Position
    
    var session: ARSession
    
    var view: ARView = .init(frame: .zero)
    
    private var configuration : ARConfiguration
    
    override func run() {
        session.run(configuration, options: .resetTracking)
    }
    
    override func stop() {
        session.pause()
    }
    
    init(position: Position = .back) {
        self.position = position
        self.session = .init()
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
            }
        }
        super.init()
        session.delegate = self
    }
}

@available(iOS 15, *)
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
