//
//  ContentView.swift
//  LightKitDev
//
//  Created by sukidhar on 31/07/22.
//

import SwiftUI
import MetalKit

struct ContentView: View {
    @StateObject var viewModel = ViewModel()
    private let label = Text("Video feed")
    var body: some View {
        CameraView().edgesIgnoringSafeArea(.all)
    }
    
    class ViewModel : ObservableObject {
        @Published var image : CGImage?
        
        init(){
            LightKitEngine.instance.$image.receive(on: RunLoop.main).compactMap { image in
                return image
            }.assign(to: &$image)
        }
    }
    
    struct CameraView: UIViewRepresentable {
        func updateUIView(_ uiView: MTKView, context: Context) {
            uiView.isHidden = false
        }
        
        func makeUIView(context: Context) -> MTKView {
            return LightKitEngine.instance.metalView
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
