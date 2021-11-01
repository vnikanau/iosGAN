//
//  IDLARDumper.swift
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 11/26/20.
//  Copyright © 2020 InData Labs Ltd. All rights reserved.
//

import Foundation
import ARKit
//import RealityKit
import CoreMotion

class IDLARDumper: NSObject {

    static let shared = IDLARDumper()
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let imgConverter = IDLImageConverter()

//    override private init() {
//    }

    func dump(anImage: CVPixelBuffer, atTimeStamp timeStamp: UInt64, aStore:Bool = false, aFileName:String? = nil) {

        let data = imgConverter.convertYpCbCrToRGBData(aSource: anImage)

        guard data != nil else {
            print("Failed to convert image data")
            return
        }

        let filePath = documentsPath.appendingPathComponent(aFileName != nil ? aFileName! : String.init(format: "%010d_c.png", timeStamp))
        try! data?.write(to: filePath, options: .atomicWrite)

    }

    func dump(aDepth: CVPixelBuffer, atTimeStamp timeStamp: UInt64, aThreshold threshold: UInt16 = 65535) {

        let data = imgConverter.convertDepthToData(aSource: aDepth, aThreshold: threshold)

        guard data != nil else {
            print("Failed to convert depth data")
            return
        }

        let filePath = documentsPath.appendingPathComponent(String.init(format: "%010d_d.png", timeStamp))
        try! data?.write(to: filePath, options: .atomicWrite)
    }

    func dump(aConfidence: CVPixelBuffer, atTimeStamp: UInt64) {

        #if false
        let filePath = session.path!.appendingPathComponent(String.init(format: "%010d_conf.dat", timeStamp))

        CVPixelBufferLockBaseAddress(aConfidence, .readOnly)

        let dataSize = CVPixelBufferGetDataSize(aConfidence)
        let dataAddr = CVPixelBufferGetBaseAddress(aConfidence)
        let data = Data(bytes: dataAddr!, count: dataSize)
        try! data.write(to: filePath, options: .atomicWrite)

        CVPixelBufferUnlockBaseAddress(aConfidence, .readOnly)
        #endif

    }

    func dump(aCamera: ARCamera, atTimeStamp timestamp: UInt64) {

        let filePath = documentsPath.appendingPathComponent(String.init(format: "%010d_camera.json", timestamp))
        let jsonEncoder = JSONEncoder()
        let jsonData = try! jsonEncoder.encode(ARCameraContainer(camera: aCamera))
        try! jsonData.write(to: filePath, options: .atomicWrite)

    }

    func dump(calibration: AVCameraCalibrationData) {

        let jsonDict: [String : Any] = [
            "extrinsic" : (0 ..< 3).map { x in
                (0 ..< 3).map { y in calibration.extrinsicMatrix[x][y] }
            }.reduce([], +),
            "intrinsic" : (0 ..< 3).map{ x in
                (0 ..< 3).map{ y in calibration.intrinsicMatrix[x][y] }
            }.reduce([], +),
            "intrinsicReferenceDimensionHeight" : calibration.intrinsicMatrixReferenceDimensions.height,
            "intrinsicReferenceDimensionWidth" : calibration.intrinsicMatrixReferenceDimensions.width,
            "inverseLensDistortionLookup" : calibration.inverseLensDistortionLookupTable?.base64EncodedString() as Any,
//            "inverseLensDistortionLookup" : convertLensDistortionLookupTable(
//                lookupTable: calibration.inverseLensDistortionLookupTable!
//            ),
            "lensDistortionCenter" : [
                calibration.lensDistortionCenter.x,
                calibration.lensDistortionCenter.y
            ],
//            "lensDistortionLookup" : convertLensDistortionLookupTable(
//                lookupTable: calibration.lensDistortionLookupTable!
//            ),
            "lensDistortionLookup" : calibration.lensDistortionLookupTable?.base64EncodedString() as Any,
            "pixelSize" : calibration.pixelSize
        ]
        let jsonData = try! JSONSerialization.data(
            withJSONObject: jsonDict,
            options: .prettyPrinted
        )

        let filePath = documentsPath.appendingPathComponent("calibration.json")
        try! jsonData.write(to: filePath, options: .atomicWrite)

    }


    func dump(aRotationMatrix: CMRotationMatrix, atTimeStamp timestamp: UInt64) {

        let filePath = documentsPath.appendingPathComponent(String.init(format: "%010d_rotation.json", timestamp))
        let jsonEncoder = JSONEncoder()
        let jsonData = try! jsonEncoder.encode(CMRotationMatrixContainer(aMatrix: aRotationMatrix))
        try! jsonData.write(to: filePath, options: .atomicWrite)
    }

    func dump(anAttitude: CMAttitude, atTimestamp timestamp: UInt64) {

        struct EulerAngles : Encodable {
            var roll: Double
            var pitch: Double
            var yaw: Double
        }

        let angles = EulerAngles(roll: anAttitude.roll, pitch: anAttitude.pitch, yaw: anAttitude.yaw)

        let filePath = documentsPath.appendingPathComponent(String.init(format: "%010d_angles.json", timestamp))
        let jsonEncoder = JSONEncoder()
        let jsonData = try! jsonEncoder.encode(angles)
        try! jsonData.write(to: filePath, options: .atomicWrite)
    }

}
