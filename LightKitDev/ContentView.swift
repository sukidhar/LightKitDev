//
//  ContentView.swift
//  LightKitDev
//
//  Created by sukidhar on 31/07/22.
//

import SwiftUI
import Combine
import MetalKit
import RealityKit

struct ContentView: View {
    private let label = Text("Video feed")
//    @StateObject var viewModel = ViewModel()
    var body: some View {
        CameraView()
            .aspectRatio( .init(width: 1080, height: 1920) ,contentMode: .fit)
            .onTapGesture {
                try? LightKitEngine.instance.loadCore(position: .back, mode: .ar)
            }
        //        FrameView()
    }
    
    class ViewModel : ObservableObject {
        @Published var image : UIImage?
        
        init(){
            LightKitEngine.instance.$originalTexture.receive(on: RunLoop.main).compactMap { node in
                let image = node?.texture?.toImage(orientation: .leftMirrored)
                return image
            }.assign(to: &$image)
        }
    }
    
    struct CameraView: UIViewRepresentable {
        func updateUIView(_ uiView: UIView, context: Context) {
           
        }
        
        func makeUIView(context: Context) -> UIView {
            let uiView = UIView()
            context.coordinator.viewSink = LightKitEngine.instance.$view.receive(on: DispatchQueue.main).sink(receiveValue: { view in
                uiView.subviews.forEach{$0.removeFromSuperview()}
                uiView.addSubview(view)
                view.translatesAutoresizingMaskIntoConstraints = false
                view.topAnchor.constraint(equalTo: uiView.topAnchor).isActive = true
                view.leadingAnchor.constraint(equalTo: uiView.leadingAnchor).isActive = true
                view.bottomAnchor.constraint(equalTo: uiView.bottomAnchor).isActive = true
                view.trailingAnchor.constraint(equalTo: uiView.trailingAnchor).isActive = true
            })
            return uiView
        }
        
        func makeCoordinator() -> Coordinator {
            Coordinator()
        }
        
        class Coordinator {
            var viewSink : AnyCancellable?
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
