//
//  ContentView.swift
//  LightKitDev
//
//  Created by sukidhar on 31/07/22.
//

import SwiftUI
import MetalKit
import RealityKit
struct ContentView: View {
    private let label = Text("Video feed")
//    @StateObject var viewModel = ViewModel()
    var body: some View {
        CameraView()
            .aspectRatio( .init(width: 1080, height: 1920) ,contentMode: .fit)
            .onTapGesture {
                
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
    
    struct FrameView : View{
        @StateObject var viewModel = ViewModel()
        var body : some View{
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
    }
    
    struct CameraView: UIViewRepresentable {
        func updateUIView(_ uiView: UIView, context: Context) {
        }
        
        func makeUIView(context: Context) -> UIView {
            return LightKitEngine.instance.outputView!
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
