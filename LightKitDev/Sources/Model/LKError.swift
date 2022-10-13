//
//  LKError.swift
//  LightKitDev
//
//  Created by sukidhar on 17/08/22.
//

import Foundation

enum LKError : Error {
    case insufficientPermissions
    case devicesUnavailable
    case coreUnavailable
    case failedToIntialiseViewProcessor
    case failedToInitialiseOffScreenProcessor
}

extension LKError : LocalizedError {
    public var errorDescription: String?{
        switch self{
        case .insufficientPermissions:
            return NSLocalizedString("AVCaptureDevices access permissions are insufficient, please ask user to provide the access from settings", comment: "")
        case .devicesUnavailable:
            return NSLocalizedString("AVCaptureDevices are not available at the moment, please close other concurrent sessions", comment: "")
        case .coreUnavailable:
            return NSLocalizedString("LKCore is not loaded to fire up engine", comment: "")
        case .failedToIntialiseViewProcessor:
            return NSLocalizedString("Due to invalid ViewProcessorMetaData, Failed to configure the ViewProcessor", comment: "")
        case .failedToInitialiseOffScreenProcessor:
            return NSLocalizedString("Due to invalid MetaData, Failed to configure the OffScreenViewProcessor", comment: "")
        }
    }
}
