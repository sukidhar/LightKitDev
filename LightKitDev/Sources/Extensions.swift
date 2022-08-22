//
//  Extensions.swift
//  LightKitDev
//
//  Created by sukidhar on 22/08/22.
//

import UIKit

extension UIWindowScene{
    public static var current : UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene
    }
}
