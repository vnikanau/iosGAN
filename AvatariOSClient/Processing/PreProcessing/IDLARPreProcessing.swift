//
//  IDLARPreProcessing.swift
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 7/17/20.
//

import Foundation
import Accelerate
import ARKit
import RealityKit

class IDLARPreProcessing {

    static func confidenceImage(aPixelBuffer pixelBuffer: CVImageBuffer, aThreshold threshold: ARConfidenceLevel) {
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

        guard pixelFormat == kCVPixelFormatType_OneComponent8 else {
            return
        }

    }

    static func depthImage(aPixelBuffer pixelBuffer: CVImageBuffer) {

    }

    static func image(_ image:CVPixelBuffer, depthThreshold: UInt16) {

    }
}
