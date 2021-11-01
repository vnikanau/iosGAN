//
//  DGCamCalibraion.swift
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 8/24/20.
//

import Foundation

class Calibration: Codable {

    var cx: Float
    var cy: Float
    var fx: Float
    var fy: Float
    var height: Float = 1440.0
    var width: Float = 1920.0
    var k1: Float = 0.0
    var k2: Float = 0.0
    var p1: Float = 0.0
    var p2: Float = 0.0
    var k3: Float = 0.0
    var k4: Float = 0.0
    var k5: Float = 0.0
    var k6: Float = 0.0
    var cod_x: Float = 0.0
    var cod_y: Float = 0.0
    var mr: Float = 0.0

    enum CodingKeys: String, CodingKey {
        case cx, cy, fx, fy, height, width, k1, k2, p1, p2, k3, k4, k5, k6, cod_x, cod_y, mr
    }
}

struct DGCameraCalibration: Codable {

    var cx: Float
    var cy: Float
    var fx: Float
    var fy: Float
    var height: Float = 1440.0
    var width: Float = 1920.0
    var k1: Float = 0.0
    var k2: Float = 0.0
    var p1: Float = 0.0
    var p2: Float = 0.0
    var k3: Float = 0.0
    var k4: Float = 0.0
    var k5: Float = 0.0
    var k6: Float = 0.0
    var cod_x: Float = 0.0
    var cod_y: Float = 0.0
    var mr: Float = 0.0
    var modelName: String? = "Untitled"
    var modelDescription: String? = "Empty description"
    var client: String? = "iOS Client"

    enum CodingKeys: String, CodingKey {
        case cx, cy, fx, fy, height, width, k1, k2, p1, p2, k3, k4, k5, k6, cod_x, cod_y, mr
        case modelName = "model_name"
        case modelDescription = "description"
        case client
    }

}

struct DGDepthCalibration: Codable {
    var cx: Float
    var cy: Float
    var fx: Float
    var fy: Float
    var height: Float = 1440.0
    var width: Float = 1920.0
    var k1: Float = 0.0
    var k2: Float = 0.0
    var p1: Float = 0.0
    var p2: Float = 0.0
    var k3: Float = 0.0
    var k4: Float = 0.0
    var k5: Float = 0.0
    var k6: Float = 0.0
    var cod_x: Float = 0.0
    var cod_y: Float = 0.0
    var mr: Float = 0.0

    enum CodingKeys: String, CodingKey {
        case cx, cy, fx, fy, height, width, k1, k2, p1, p2, k3, k4, k5, k6, cod_x, cod_y, mr
    }
}
