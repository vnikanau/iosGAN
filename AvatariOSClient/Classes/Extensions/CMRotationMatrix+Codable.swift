//
//  CMRotationMatrix.swift
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 12/16/20.
//

import Foundation
import CoreMotion

class CMRotationMatrixContainer : Codable {
    
    var matrix: CMRotationMatrix

    init (aMatrix: CMRotationMatrix) {
        self.matrix = aMatrix
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let m11 = try container.decode(Double.self, forKey: .m11)
        let m12 = try container.decode(Double.self, forKey: .m12)
        let m13 = try container.decode(Double.self, forKey: .m12)
        let m21 = try container.decode(Double.self, forKey: .m11)
        let m22 = try container.decode(Double.self, forKey: .m12)
        let m23 = try container.decode(Double.self, forKey: .m12)
        let m31 = try container.decode(Double.self, forKey: .m11)
        let m32 = try container.decode(Double.self, forKey: .m12)
        let m33 = try container.decode(Double.self, forKey: .m12)

        matrix = CMRotationMatrix(m11: m11, m12: m12, m13: m13, m21: m21, m22: m22, m23: m23, m31: m31, m32: m32, m33: m33)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(matrix.m11, forKey: .m11)
        try container.encode(matrix.m12, forKey: .m12)
        try container.encode(matrix.m13, forKey: .m13)
        try container.encode(matrix.m21, forKey: .m21)
        try container.encode(matrix.m22, forKey: .m22)
        try container.encode(matrix.m23, forKey: .m23)
        try container.encode(matrix.m31, forKey: .m31)
        try container.encode(matrix.m32, forKey: .m32)
        try container.encode(matrix.m33, forKey: .m33)
    }


    enum CodingKeys: String, CodingKey {
        case m11, m12, m13
        case m21, m22, m23
        case m31, m32, m33
    }
}
