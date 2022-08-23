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
//        CameraView()
//            .aspectRatio( .init(width: 1080, height: 1920) ,contentMode: .fit)
        GeometryReader { geometry in
            Image(uiImage: viewModel.image ?? UIImage())
            .resizable()
            .scaledToFill()
            .frame(
              width: geometry.size.width,
              height: geometry.size.height,
              alignment: .center)
            .clipped()
        }
    }
    
    class ViewModel : ObservableObject {
        @Published var image : UIImage?
        
        init(){
            LightKitEngine.instance.$originalTexture.receive(on: RunLoop.main).compactMap { texture in
                let image = texture?.toImage(orientation: .left)
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
