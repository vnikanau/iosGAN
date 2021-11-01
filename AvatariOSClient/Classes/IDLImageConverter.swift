//
//  IDLImageConverter.swift
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 8/20/20.
//

import UIKit
import Accelerate
import CoreGraphics
import ImageIO
import MobileCoreServices
import VideoToolbox

class IDLImageConverter: NSObject {

    private var infoYpCbCrToARGB = vImage_YpCbCrToARGB()
    private var destinationARGBBuffer = vImage_Buffer()
    private var destinationDepthBuffer = vImage_Buffer()
    private var grayColorSpace = CGColorSpaceCreateDeviceGray()
    private var argbImageFormat = vImage_CGImageFormat(bitsPerComponent: 8,
                                                       bitsPerPixel: 32,
                                                       colorSpace: nil,
                                                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue),
                                                       version: 0,
                                                       decode: nil,
                                                       renderingIntent: .defaultIntent)
    private var depthImageFormat:vImage_CGImageFormat = vImage_CGImageFormat()
    private var depthPreviewImageFormat:vImage_CGImageFormat!


    override init() {
        super.init()

        guard configureYpCbCrToARGBInfo() == kvImageNoError else {
            fatalError("Failed to initialize vImageConvert")
        }

        guard configureDepthToGrayInfo() == kvImageNoError else {
            fatalError("Failed to initialize vImageConvert")
        }
    }

    func configureYpCbCrToARGBInfo() -> vImage_Error {
        var pixelRange = vImage_YpCbCrPixelRange(Yp_bias: 16,
                                                 CbCr_bias: 128,
                                                 YpRangeMax: 235,
                                                 CbCrRangeMax: 240,
                                                 YpMax: 235,
                                                 YpMin: 16,
                                                 CbCrMax: 240,
                                                 CbCrMin: 16)

        let error = vImageConvert_YpCbCrToARGB_GenerateConversion(
            kvImage_YpCbCrToARGBMatrix_ITU_R_601_4!,
            &pixelRange,
            &infoYpCbCrToARGB,
            kvImage422CbYpCrYp8,
            kvImageARGB8888,
            vImage_Flags(kvImageNoFlags))

        return error
    }

    func configureDepthToGrayInfo() -> vImage_Error {
        /*
        depthImageFormat = vImage_CGImageFormat(bitsPerComponent: 16,
                                                bitsPerPixel: 16,
                                                colorSpace: Unmanaged.passUnretained(grayColorSpace),
                                                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                                version: 0,
                                                decode: nil,
                                                renderingIntent: .defaultIntent)
         */
        depthImageFormat = vImage_CGImageFormat()
        depthImageFormat.colorSpace = Unmanaged.passUnretained(grayColorSpace)
        depthImageFormat.bitsPerComponent = 16
        depthImageFormat.bitsPerPixel = 16
        depthImageFormat.bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue | CGBitmapInfo.byteOrder16Little.rawValue)

        depthPreviewImageFormat = vImage_CGImageFormat()
        depthPreviewImageFormat.colorSpace = Unmanaged.passUnretained(grayColorSpace)
        depthPreviewImageFormat.bitsPerComponent = 8
        depthPreviewImageFormat.bitsPerPixel = 8
        depthPreviewImageFormat.bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)

        return kvImageNoError
    }

    func convertYpCbCrToRGBData(aSource: CVPixelBuffer) -> Data? {
        assert(CVPixelBufferGetPlaneCount(aSource) == 2, "Pixel buffer should have 2 planes")

        CVPixelBufferLockBaseAddress(aSource, .readOnly)

        defer {
            CVPixelBufferUnlockBaseAddress(aSource, .readOnly)
        }

        let lumaBaseAddress = CVPixelBufferGetBaseAddressOfPlane(aSource, 0)
        let lumaWidth = CVPixelBufferGetWidthOfPlane(aSource, 0)
        let lumaHeight = CVPixelBufferGetHeightOfPlane(aSource, 0)
        let lumaRowBytes = CVPixelBufferGetBytesPerRowOfPlane(aSource, 0)

        var sourceLumaBuffer = vImage_Buffer(data: lumaBaseAddress,
                                             height: vImagePixelCount(lumaHeight),
                                             width: vImagePixelCount(lumaWidth),
                                             rowBytes: lumaRowBytes)

        let chromaBaseAddress = CVPixelBufferGetBaseAddressOfPlane(aSource, 1)
        let chromaWidth = CVPixelBufferGetWidthOfPlane(aSource, 1)
        let chromaHeight = CVPixelBufferGetHeightOfPlane(aSource, 1)
        let chromaRowBytes = CVPixelBufferGetBytesPerRowOfPlane(aSource, 1)

        var sourceChromaBuffer = vImage_Buffer(data: chromaBaseAddress,
                                               height: vImagePixelCount(chromaHeight),
                                               width: vImagePixelCount(chromaWidth),
                                               rowBytes: chromaRowBytes)

        var error = kvImageNoError
        if destinationARGBBuffer.data == nil {
            error = vImageBuffer_Init(&destinationARGBBuffer,
                                      sourceLumaBuffer.height,
                                      sourceLumaBuffer.width,
                                      argbImageFormat.bitsPerPixel,
                                      vImage_Flags(kvImageNoFlags))

            guard error == kvImageNoError else {
                return nil
            }
        }

        error = vImageConvert_420Yp8_CbCr8ToARGB8888(&sourceLumaBuffer,
                                                     &sourceChromaBuffer,
                                                     &destinationARGBBuffer,
                                                     &infoYpCbCrToARGB,
                                                     nil,
                                                     255,
                                                     vImage_Flags(kvImagePrintDiagnosticsToConsole))

        guard error == kvImageNoError else {
            return nil
        }

        let cgImage = vImageCreateCGImageFromBuffer(&destinationARGBBuffer,
                                                    &argbImageFormat,
                                                    nil,
                                                    nil,
                                                    vImage_Flags(kvImageNoFlags),
                                                    &error)

        if let cgImage = cgImage, error == kvImageNoError {

            let result = NSMutableData()
            let destination = CGImageDestinationCreateWithData(result, kUTTypePNG, 1, nil)

            if (destination == nil) {
                return nil
            }

            CGImageDestinationAddImage(destination!, cgImage.takeRetainedValue(), nil)

            if CGImageDestinationFinalize(destination!) {
                return result as Data
            }

        }
        return nil
    }

    func convertPixelBufferToData(aSource source:CVPixelBuffer) -> Data? {
//        assert(CVPixelBufferGetPlaneCount(aSource) == 2, "Pixel buffer should have 2 planes")

        CVPixelBufferLockBaseAddress(source, .readOnly)

        defer {
            CVPixelBufferUnlockBaseAddress(source, .readOnly)
        }


        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(source, options: nil, imageOut: &cgImage)

        if let cgImage = cgImage {

            let result = NSMutableData()
            let destination = CGImageDestinationCreateWithData(result, kUTTypePNG, 1, nil)

            if (destination == nil) {
                return nil
            }

            CGImageDestinationAddImage(destination!, cgImage, nil)

            if CGImageDestinationFinalize(destination!) {
                return result as Data
            }
        }

        return nil
    }

    func convertDepthToDataAndPreview(aSource: CVPixelBuffer, aThreshold: UInt16 = 65535) -> (Data?, Data?) {
        assert(CVPixelBufferGetPixelFormatType(aSource) == kCVPixelFormatType_DepthFloat32, "Invalid pixel buffer format")

        CVPixelBufferLockBaseAddress(aSource, .readOnly)

        defer {
            CVPixelBufferUnlockBaseAddress(aSource, .readOnly)
        }

        let depthBaseAddress = CVPixelBufferGetBaseAddressOfPlane(aSource, 0)
        let depthWidth = CVPixelBufferGetWidthOfPlane(aSource, 0)
        let depthHeight = CVPixelBufferGetHeightOfPlane(aSource, 0)
        let depthRowBytes = CVPixelBufferGetBytesPerRowOfPlane(aSource, 0)


        let sourceBuffer = vImage_Buffer(data: depthBaseAddress,
                                         height: vImagePixelCount(depthHeight),
                                         width: vImagePixelCount(depthWidth),
                                         rowBytes: depthRowBytes)

        var error = kvImageNoError
        if destinationDepthBuffer.data == nil {
            error = vImageBuffer_Init(&destinationDepthBuffer,
                                      sourceBuffer.height,
                                      sourceBuffer.width,
                                      depthImageFormat.bitsPerPixel,
                                      vImage_Flags(kvImageNoFlags))

            guard error == kvImageNoError else {
                return (nil, nil)
            }
        }

        var destinationDepthPreviewBuffer = vImage_Buffer()
        error = vImageBuffer_Init(&destinationDepthPreviewBuffer,
                                  sourceBuffer.height,
                                  sourceBuffer.width,
                                  depthPreviewImageFormat.bitsPerPixel,
                                  vImage_Flags(kvImageNoFlags))


        let srcPointer = UnsafePointer<Float32>(OpaquePointer(sourceBuffer.data))
        let dstPointer = UnsafeMutablePointer<UInt16>(OpaquePointer(destinationDepthBuffer.data))
        let dstPreviewPointer = UnsafeMutablePointer<UInt8>(OpaquePointer(destinationDepthPreviewBuffer.data))
        let depthLength = depthWidth * depthHeight
        var maxValue:UInt16 = 0

        // lock
        for idx in 0..<depthLength {
            let depth = UInt16((srcPointer!+idx).pointee * 1000.0)
            if depth > maxValue {
                maxValue = depth
            }

            (dstPointer!+idx).pointee = depth >= aThreshold ? 0 : depth
        }
        // unlock

        for idx in 0..<depthLength {
            (dstPreviewPointer!+idx).pointee = UInt8(Float((dstPointer!+idx).pointee) / Float(maxValue) * 255.0)
        }

        let cgImage = try? destinationDepthBuffer.createCGImage(format: depthImageFormat)

        let result = NSMutableData()

        if let cgImage = cgImage, error == kvImageNoError {


            let destination = CGImageDestinationCreateWithData(result, kUTTypePNG, 1, nil)

            if destination == nil {
                return (nil, nil)
            }

            CGImageDestinationAddImage(destination!, cgImage, nil)

            if !CGImageDestinationFinalize(destination!) {
                print("Error converting")
            }

        }

        let preview = try? destinationDepthPreviewBuffer.createCGImage(format: depthPreviewImageFormat)
        let previewData = NSMutableData()

        if let preview = preview {

            let orientation = UIDevice.current.orientation

            let options = [
                kCGImagePropertyOrientation : cgImageOrientation(forDeviceOrientation: orientation).rawValue
            ];
            let destination = CGImageDestinationCreateWithData(previewData, kUTTypePNG, 1, nil)

            if destination == nil {
                return (result as Data, nil)
            }

            CGImageDestinationAddImage(destination!, preview, options as CFDictionary)

            if !CGImageDestinationFinalize(destination!) {
                print("Error converting")
            }

        }

        return (result as Data, previewData as Data)
    }

    func convertDepthToData(aSource: CVPixelBuffer, aThreshold: UInt16 = 65535) -> Data? {
        assert(CVPixelBufferGetPixelFormatType(aSource) == kCVPixelFormatType_DepthFloat32, "Invalid pixel buffer format")

        CVPixelBufferLockBaseAddress(aSource, .readOnly)

        defer {
            CVPixelBufferUnlockBaseAddress(aSource, .readOnly)
        }

        let depthBaseAddress = CVPixelBufferGetBaseAddressOfPlane(aSource, 0)
        let depthWidth = CVPixelBufferGetWidthOfPlane(aSource, 0)
        let depthHeight = CVPixelBufferGetHeightOfPlane(aSource, 0)
        let depthRowBytes = CVPixelBufferGetBytesPerRowOfPlane(aSource, 0)


        let sourceBuffer = vImage_Buffer(data: depthBaseAddress,
                                         height: vImagePixelCount(depthHeight),
                                         width: vImagePixelCount(depthWidth),
                                         rowBytes: depthRowBytes)

        var error = kvImageNoError
        if destinationDepthBuffer.data == nil {
            error = vImageBuffer_Init(&destinationDepthBuffer,
                                      sourceBuffer.height,
                                      sourceBuffer.width,
                                      depthImageFormat.bitsPerPixel,
                                      vImage_Flags(kvImageNoFlags))

            guard error == kvImageNoError else {
                return nil
            }
        }

        let srcPointer = UnsafePointer<Float32>(OpaquePointer(sourceBuffer.data))
        let dstPointer = UnsafeMutablePointer<UInt16>(OpaquePointer(destinationDepthBuffer.data))

        // lock

        for y in 0..<depthHeight {

            for x in 0..<depthWidth {

                let srcIdx = y * depthWidth + x

                var value = (srcPointer! + srcIdx).pointee
                if !value.isFinite {
                    value = 0.0
                }

                value = value * 1000.0
                if !value.isFinite {
                    value = 0.0
                }

                if value >= Float(aThreshold) {
                    value = 0.0
                }

                let depth = UInt16(value)

                let idx = y * depthWidth + x
                (dstPointer!+idx).pointee = depth >= aThreshold ? 0 : depth
            }
        }

        // unlock

        let cgImage = try? destinationDepthBuffer.createCGImage(format: depthImageFormat)

        let result = NSMutableData()

        if let cgImage = cgImage, error == kvImageNoError {


            let destination = CGImageDestinationCreateWithData(result, kUTTypePNG, 1, nil)

            if destination == nil {
                return nil
            }

            CGImageDestinationAddImage(destination!, cgImage, nil)

            if !CGImageDestinationFinalize(destination!) {
                print("Error converting")
            }
        }

        return result as Data
    }

    func convertDepthToDataAndPreview(aSource: CVPixelBuffer, aConfidence: CVPixelBuffer, aThreshold: UInt16 = 65535, aConfThreshold: UInt8 = 2) -> (Data?, Data?) {
        
        assert(CVPixelBufferGetPixelFormatType(aSource) == kCVPixelFormatType_DepthFloat32, "Invalid pixel buffer format")

        CVPixelBufferLockBaseAddress(aSource, .readOnly)
        CVPixelBufferLockBaseAddress(aConfidence, .readOnly)

        defer {
            CVPixelBufferUnlockBaseAddress(aConfidence, .readOnly)
            CVPixelBufferUnlockBaseAddress(aSource, .readOnly)
        }

        let depthBaseAddress = CVPixelBufferGetBaseAddressOfPlane(aSource, 0)
        let depthWidth = CVPixelBufferGetWidthOfPlane(aSource, 0)
        let depthHeight = CVPixelBufferGetHeightOfPlane(aSource, 0)
        let depthRowBytes = CVPixelBufferGetBytesPerRowOfPlane(aSource, 0)

        let confBaseAddress = CVPixelBufferGetBaseAddressOfPlane(aConfidence, 0)
        let confWidth = CVPixelBufferGetWidthOfPlane(aConfidence, 0)
        let confHeight = CVPixelBufferGetHeightOfPlane(aConfidence, 0)
        let confRowBytes = CVPixelBufferGetBytesPerRowOfPlane(aConfidence, 0)

        
        let sourceBuffer = vImage_Buffer(data: depthBaseAddress,
                                         height: vImagePixelCount(depthHeight),
                                         width: vImagePixelCount(depthWidth),
                                         rowBytes: depthRowBytes)
        let confBuffer = vImage_Buffer(data: confBaseAddress,
                                       height: vImagePixelCount(confHeight),
                                       width: vImagePixelCount(confWidth),
                                       rowBytes: confRowBytes)
        
        var error = kvImageNoError
        if destinationDepthBuffer.data == nil {
            error = vImageBuffer_Init(&destinationDepthBuffer,
                                      sourceBuffer.height,
                                      sourceBuffer.width,
                                      depthImageFormat.bitsPerPixel,
                                      vImage_Flags(kvImageNoFlags))

            guard error == kvImageNoError else {
                return (nil, nil)
            }
        }

        var destinationDepthPreviewBuffer = vImage_Buffer()
        error = vImageBuffer_Init(&destinationDepthPreviewBuffer,
                                  sourceBuffer.height,
                                  sourceBuffer.width,
                                  depthPreviewImageFormat.bitsPerPixel,
                                  vImage_Flags(kvImageNoFlags))


        let srcPointer = UnsafePointer<Float32>(OpaquePointer(sourceBuffer.data))
        let dstPointer = UnsafeMutablePointer<UInt16>(OpaquePointer(destinationDepthBuffer.data))
        let dstPreviewPointer = UnsafeMutablePointer<UInt8>(OpaquePointer(destinationDepthPreviewBuffer.data))
        var maxValue:UInt16 = 0
        let confPointer = UnsafePointer<UInt8>(OpaquePointer(confBuffer.data))

        // lock
        /*
        for idx in 0..<depthLength {
            let depth = UInt16((srcPointer!+idx).pointee * 1000.0)
            
            if depth > maxValue {
                maxValue = depth
            }

            (dstPointer!+idx).pointee = depth >= aThreshold ? 0 : depth
        }
         */
        
        for y in 0..<depthHeight {

            for x in 0..<depthWidth {

                let srcIdx = y * depthWidth + x
                let confIdx = y * confWidth + x

                var value = (srcPointer! + srcIdx).pointee
                let confidence = (confPointer! + confIdx).pointee
                
                if confidence >= aConfThreshold {

                    if !value.isFinite {
                        value = 0.0
                    }

                    value = value * 1000.0
                    if !value.isFinite {
                        value = 0.0
                    }

                    if value >= Float(aThreshold) {
                        value = 0.0
                    }

                } else {
                    
                    value = 0.0
                    
                }

                let depth = UInt16(value)
                
                if depth > maxValue {
                    maxValue = depth
                }

                let idx = y * depthWidth + x
                (dstPointer!+idx).pointee = depth >= aThreshold ? 0 : depth
            }
        }
        // unlock

        if (maxValue > 0) {
            
            let maxDepthScaled =  Float(maxValue)
            
            for y in 0..<depthHeight {

                for x in 0..<depthWidth {

                    let srcIdx = y * depthWidth + x
                    let confidence = (confPointer! + srcIdx).pointee
                    var depth = UInt16((srcPointer!+srcIdx).pointee * 1000.0)
                    
                    if confidence >= aConfThreshold {
                        depth = depth >= aThreshold ? 0 : depth
                    } else {
                        depth = 0
                    }
                
                    (dstPreviewPointer!+srcIdx).pointee = UInt8(Float(depth) * 255.0 / maxDepthScaled)

                }
            }
        }

        let cgImage = try? destinationDepthBuffer.createCGImage(format: depthImageFormat)

        let result = NSMutableData()

        if let cgImage = cgImage, error == kvImageNoError {


            let destination = CGImageDestinationCreateWithData(result, kUTTypePNG, 1, nil)

            if destination == nil {
                return (nil, nil)
            }

            CGImageDestinationAddImage(destination!, cgImage, nil)

            if !CGImageDestinationFinalize(destination!) {
                print("Error converting")
            }

        }

        let preview = try? destinationDepthPreviewBuffer.createCGImage(format: depthPreviewImageFormat)
        let previewData = NSMutableData()

        if let preview = preview {

            let orientation = UIDevice.current.orientation

            let options = [
                kCGImagePropertyOrientation : cgImageOrientation(forDeviceOrientation: orientation).rawValue
            ];
            let destination = CGImageDestinationCreateWithData(previewData, kUTTypePNG, 1, nil)

            if destination == nil {
                return (result as Data, nil)
            }

            CGImageDestinationAddImage(destination!, preview, options as CFDictionary)

            if !CGImageDestinationFinalize(destination!) {
                print("Error converting")
            }

        }

        return (result as Data, previewData as Data)
    }
    
    func convertDepthToData(aSource: CVPixelBuffer, aConfidence: CVPixelBuffer, aThreshold: UInt16 = 65535, aConfThreshold: UInt8 = 2) -> Data? {
        assert(CVPixelBufferGetPixelFormatType(aSource) == kCVPixelFormatType_DepthFloat32, "Invalid pixel buffer format")

        CVPixelBufferLockBaseAddress(aSource, .readOnly)
        CVPixelBufferLockBaseAddress(aConfidence, .readOnly)

        defer {
            CVPixelBufferLockBaseAddress(aConfidence, .readOnly)
            CVPixelBufferUnlockBaseAddress(aSource, .readOnly)
        }

        let depthBaseAddress = CVPixelBufferGetBaseAddressOfPlane(aSource, 0)
        let depthWidth = CVPixelBufferGetWidthOfPlane(aSource, 0)
        let depthHeight = CVPixelBufferGetHeightOfPlane(aSource, 0)
        let depthRowBytes = CVPixelBufferGetBytesPerRowOfPlane(aSource, 0)

        let confBaseAddress = CVPixelBufferGetBaseAddressOfPlane(aConfidence, 0)
        let confWidth = CVPixelBufferGetWidthOfPlane(aConfidence, 0)
        let confHeight = CVPixelBufferGetHeightOfPlane(aConfidence, 0)
        let confRowBytes = CVPixelBufferGetBytesPerRowOfPlane(aConfidence, 0)

        let sourceBuffer = vImage_Buffer(data: depthBaseAddress,
                                         height: vImagePixelCount(depthHeight),
                                         width: vImagePixelCount(depthWidth),
                                         rowBytes: depthRowBytes)

        let confBuffer = vImage_Buffer(data: confBaseAddress,
                                       height: vImagePixelCount(confHeight),
                                       width: vImagePixelCount(confWidth),
                                       rowBytes: confRowBytes)

        var error = kvImageNoError
        if destinationDepthBuffer.data == nil {
            error = vImageBuffer_Init(&destinationDepthBuffer,
                                      sourceBuffer.height,
                                      sourceBuffer.width,
                                      depthImageFormat.bitsPerPixel,
                                      vImage_Flags(kvImageNoFlags))

            guard error == kvImageNoError else {
                return nil
            }
        }

        let srcPointer = UnsafePointer<Float32>(OpaquePointer(sourceBuffer.data))
        let dstPointer = UnsafeMutablePointer<UInt16>(OpaquePointer(destinationDepthBuffer.data))
        let confPointer = UnsafePointer<UInt8>(OpaquePointer(confBuffer.data))


        // lock

        for y in 0..<depthHeight {

            for x in 0..<depthWidth {

                let srcIdx = y * depthWidth + x

                var value = (srcPointer! + srcIdx).pointee
                let confidence = (confPointer! + srcIdx).pointee
                
                if confidence >= aConfThreshold {

                    if !value.isFinite {
                        value = 0.0
                    }

                    value = value * 1000.0
                    if !value.isFinite {
                        value = 0.0
                    }

                    if value >= Float(aThreshold) {
                        value = 0.0
                    }

                } else {
                    
                    value = 0.0
                    
                }

                let depth = UInt16(value)
                
                let idx = y * depthWidth + x
                (dstPointer!+idx).pointee = depth >= aThreshold ? 0 : depth
            }
        }

        // unlock

        let cgImage = try? destinationDepthBuffer.createCGImage(format: depthImageFormat)

        let result = NSMutableData()

        if let cgImage = cgImage, error == kvImageNoError {


            let destination = CGImageDestinationCreateWithData(result, kUTTypePNG, 1, nil)

            if destination == nil {
                return nil
            }

            CGImageDestinationAddImage(destination!, cgImage, nil)

            if !CGImageDestinationFinalize(destination!) {
                print("Error converting")
            }
        }

        return result as Data
    }

    
    func convertDepthToCGimage(aSource: CVPixelBuffer, aThreshold: UInt16 = 65535) -> CGImage? {

        assert(CVPixelBufferGetPixelFormatType(aSource) == kCVPixelFormatType_DepthFloat32, "Invalid pixel buffer format")

        CVPixelBufferLockBaseAddress(aSource, .readOnly)

        defer {
            CVPixelBufferUnlockBaseAddress(aSource, .readOnly)
        }

        let depthBaseAddress = CVPixelBufferGetBaseAddressOfPlane(aSource, 0)
        let depthWidth = CVPixelBufferGetWidthOfPlane(aSource, 0)
        let depthHeight = CVPixelBufferGetHeightOfPlane(aSource, 0)
        let depthRowBytes = CVPixelBufferGetBytesPerRowOfPlane(aSource, 0)


        let sourceBuffer = vImage_Buffer(data: depthBaseAddress,
                                         height: vImagePixelCount(depthHeight),
                                         width: vImagePixelCount(depthWidth),
                                         rowBytes: depthRowBytes)

        var error = kvImageNoError
        var destinationDepthPreviewBuffer = vImage_Buffer()
        error = vImageBuffer_Init(&destinationDepthPreviewBuffer,
                                  sourceBuffer.height,
                                  sourceBuffer.width,
                                  depthPreviewImageFormat.bitsPerPixel,
                                  vImage_Flags(kvImageNoFlags))

        guard error == kvImageNoError else {
            return nil
        }

        let srcPointer = UnsafePointer<Float32>(OpaquePointer(sourceBuffer.data))
        let dstPreviewPointer = UnsafeMutablePointer<UInt8>(OpaquePointer(destinationDepthPreviewBuffer.data))

        var maxValue:UInt16 = 0

        // lock

        for y in 0..<depthHeight {

            for x in 0..<depthWidth {

                let srcIdx = y * depthWidth + x

                var value = (srcPointer! + srcIdx).pointee
                
                if !value.isFinite {
                    value = 0.0
                }

                value = value * 1000.0
                if !value.isFinite {
                    value = 0.0
                }

                if value >= Float(aThreshold) {
                    value = 0.0
                }

                let depth = UInt16(value)
                
                if depth > maxValue {
                    maxValue = depth
                }
                
            }
        }

        // unlock
        
        if (maxValue > 0) {
            
            for y in 0..<depthHeight {

                for x in 0..<depthWidth {

                    let srcIdx = y * depthWidth + x
                    var depth = UInt16((srcPointer!+srcIdx).pointee * 1000.0)
                    depth = depth >= aThreshold ? 0 : depth
                    (dstPreviewPointer!+srcIdx).pointee = UInt8(Float(depth) / Float(maxValue) * 255.0)

                }
            }
        }

        let preview = try? destinationDepthPreviewBuffer.createCGImage(format: depthPreviewImageFormat)

        return preview
    }

    func convertDepthToCGimage(aSource: CVPixelBuffer, aConfidence: CVPixelBuffer, aThreshold: UInt16 = 65535, aConfThreshold: UInt8 = 2) -> CGImage? {

        assert(CVPixelBufferGetPixelFormatType(aSource) == kCVPixelFormatType_DepthFloat32, "Invalid pixel buffer format")

        CVPixelBufferLockBaseAddress(aSource, .readOnly)
        CVPixelBufferLockBaseAddress(aConfidence, .readOnly)

        defer {
            CVPixelBufferUnlockBaseAddress(aConfidence, .readOnly)
            CVPixelBufferUnlockBaseAddress(aSource, .readOnly)
        }

        let depthBaseAddress = CVPixelBufferGetBaseAddressOfPlane(aSource, 0)
        let depthWidth = CVPixelBufferGetWidthOfPlane(aSource, 0)
        let depthHeight = CVPixelBufferGetHeightOfPlane(aSource, 0)
        let depthRowBytes = CVPixelBufferGetBytesPerRowOfPlane(aSource, 0)

        let confBaseAddress = CVPixelBufferGetBaseAddressOfPlane(aConfidence, 0)
        let confWidth = CVPixelBufferGetWidthOfPlane(aConfidence, 0)
        let confHeight = CVPixelBufferGetHeightOfPlane(aConfidence, 0)
        let confRowBytes = CVPixelBufferGetBytesPerRowOfPlane(aConfidence, 0)


        let sourceBuffer = vImage_Buffer(data: depthBaseAddress,
                                         height: vImagePixelCount(depthHeight),
                                         width: vImagePixelCount(depthWidth),
                                         rowBytes: depthRowBytes)

        let confBuffer = vImage_Buffer(data: confBaseAddress,
                                       height: vImagePixelCount(confHeight),
                                       width: vImagePixelCount(confWidth),
                                       rowBytes: confRowBytes)

        var error = kvImageNoError
        var destinationDepthPreviewBuffer = vImage_Buffer()
        error = vImageBuffer_Init(&destinationDepthPreviewBuffer,
                                  sourceBuffer.height,
                                  sourceBuffer.width,
                                  depthPreviewImageFormat.bitsPerPixel,
                                  vImage_Flags(kvImageNoFlags))

        guard error == kvImageNoError else {
            return nil
        }

        let srcPointer = UnsafePointer<Float32>(OpaquePointer(sourceBuffer.data))
        let dstPreviewPointer = UnsafeMutablePointer<UInt8>(OpaquePointer(destinationDepthPreviewBuffer.data))
//        let depthLength = depthWidth * depthHeight
        let confPointer = UnsafePointer<UInt8>(OpaquePointer(confBuffer.data))

        var maxValue:UInt16 = 0

        // lock

        for y in 0..<depthHeight {

            for x in 0..<depthWidth {

                let srcIdx = y * depthWidth + x

                var value = (srcPointer! + srcIdx).pointee
                let confidence = (confPointer! + srcIdx).pointee
                
                if confidence >= aConfThreshold {

                    if !value.isFinite {
                        value = 0.0
                    }

                    value = value * 1000.0
                    
                    if !value.isFinite {
                        value = 0.0
                    }

                    if value >= Float(aThreshold) {
                        value = 0.0
                    }

                } else {
                    
                    value = 0.0
                    
                }

                let depth = UInt16(value)
                
                if depth > maxValue {
                    maxValue = depth
                }
                
            }
        }

        // unlock
//        for idx in 0..<depthLength {
//            var depth = UInt16((srcPointer!+idx).pointee * 1000.0)
//            depth = depth > aThreshold ? 0 : depth
//            var v = Float(depth) / Float(maxValue) * 255.0
//            v = v > 255 ? 255 : v
//            (dstPreviewPointer!+idx).pointee = UInt8(v)
//        }

        if (maxValue > 0) {
            
            let maxDepthScaled =  Float(maxValue)
            
            for y in 0..<depthHeight {

                for x in 0..<depthWidth {

                    let srcIdx = y * depthWidth + x
                    let confidence = (confPointer! + srcIdx).pointee
                    var depth = UInt16((srcPointer!+srcIdx).pointee * 1000.0)
                    
                    if confidence >= aConfThreshold {
                        depth = depth >= aThreshold ? 0 : depth
                    } else {
                        depth = 0
                    }
                
                    (dstPreviewPointer!+srcIdx).pointee = UInt8(Float(depth) * 255.0 / maxDepthScaled)

                }
            }
        }
        
        let preview = try? destinationDepthPreviewBuffer.createCGImage(format: depthPreviewImageFormat)

        return preview
    }
}

func cgImageOrientation(forDeviceOrientation orientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
    switch orientation {
    case .portraitUpsideDown:
        return .down
    case .landscapeLeft:
        return .left
    case .landscapeRight:
        return .right
    case .portrait:
         return .up
    default:
        return .up
    }
}
