//
//  DGDevice.swift
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 9/2/20.
//

import UIKit
import ARKit

class IDLDevice {

    static let shared = IDLDevice()

    private init() {

    }

    var clientString: String {
        get {
            return self.modelName + " " + self.clientVersion
        }
    }

    var modelName: String {
        get {

            var sysInfo = utsname()
            uname(&sysInfo)

            let mirror = Mirror(reflecting: sysInfo.machine)
            let identifier = mirror.children.reduce("") { identifier, element in
                guard let value = element.value as? Int8, value != 0 else  {
                    return identifier
                }
                return identifier + String(UnicodeScalar(UInt8(value)))
            }

            return identifier
        }
    }

    var clientVersion: String {
        get {

            guard let versionString = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String else {
                return ""
            }

            return versionString
        }
    }
    
    var isLidarSupported: Bool {
        get {
            let result = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
            return result
        }
    }
}
