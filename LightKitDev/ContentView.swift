//
//  ContentView.swift
//  LightKitDev
//
//  Created by sukidhar on 31/07/22.
//

import SwiftUI

struct ContentView: View {
    private let label = Text("Video feed")
    var body: some View {
        if let image = LightKitEngine.instance.image {
          GeometryReader { geometry in
            Image(image, scale: 1.0, orientation: .upMirrored, label: label)
              .resizable()
              .scaledToFill()
              .frame(
                width: geometry.size.width,
                height: geometry.size.height,
                alignment: .center)
              .clipped()
          }
        } else {
          EmptyView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
