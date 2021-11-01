//
//  ARCamera+Codable.swift
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 11/23/20.
//

import Foundation
import ARKit

class ARCameraContainer : Encodable {
    let camera: ARCamera

    init(camera: ARCamera) {
        self.camera = camera
    }

//    required init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        camera = ARCamera()
//    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(camera.transform, forKey: .transform)
        try container.encode(camera.eulerAngles, forKey: .eulerAngles)
        try container.encode(camera.intrinsics, forKey: .intrinsics)
        try container.encode(camera.imageResolution, forKey: .imageResolution)
        try container.encode(camera.exposureDuration, forKey: .exposureDuration)
        try container.encode(camera.exposureOffset, forKey: .exposureOffset)
        try container.encode(camera.projectionMatrix, forKey: .projectionMatrix)
    }

    enum CodingKeys: String, CodingKey {
        case transform
        case eulerAngles = "euler_angles"
        case intrinsics
        case imageResolution = "image_resolution"
        case exposureDuration = "exposure_duration"
        case exposureOffset = "exposure_offset"
        case projectionMatrix = "projection_matrix"
    }
}
