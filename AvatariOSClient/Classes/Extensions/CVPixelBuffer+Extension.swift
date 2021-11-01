//
//  CVPixelBuffer+Extension.swift
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 7/17/20.
//

import Foundation
import CoreVideo
import Accelerate

extension CVPixelBuffer {

    func configureYpCbCrToARGBInfo() -> vImage_Error {
        var infoYpCbCrToARGB = vImage_YpCbCrToARGB()
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

    func rgbaFromYCrCb() -> CVImageBuffer? {

        guard CVPixelBufferGetPixelFormatType(self) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange else {
            return nil
        }

        var infoYpCbCrToARGB = vImage_YpCbCrToARGB()
        
        // Lock?
        
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        var destinationBuffer:vImage_Buffer = try! vImage_Buffer(width: width, height: height, bitsPerPixel: 32)



        let lumaBaseAddress = CVPixelBufferGetBaseAddressOfPlane(self, 0)
        let lumaWidth = CVPixelBufferGetWidthOfPlane(self, 0)
        let lumaHeight = CVPixelBufferGetHeightOfPlane(self, 0)
        let lumaRowBytes = CVPixelBufferGetBytesPerRowOfPlane(self, 0)

        var sourceLumaBuffer = vImage_Buffer(data: lumaBaseAddress,
                                             height: vImagePixelCount(lumaHeight),
                                             width: vImagePixelCount(lumaWidth),
                                             rowBytes: lumaRowBytes)

        let chromaBaseAddress = CVPixelBufferGetBaseAddressOfPlane(self, 1)
        let chromaWidth = CVPixelBufferGetWidthOfPlane(self, 1)
        let chromaHeight = CVPixelBufferGetHeightOfPlane(self, 1)
        let chromaRowBytes = CVPixelBufferGetBytesPerRowOfPlane(self, 1)

        var sourceChromaBuffer = vImage_Buffer(data: chromaBaseAddress,
                                               height: vImagePixelCount(chromaHeight),
                                               width: vImagePixelCount(chromaWidth),
                                               rowBytes: chromaRowBytes)


        var error = kvImageNoError
        if destinationBuffer.data == nil {
            error = vImageBuffer_Init(&destinationBuffer,
                                      sourceLumaBuffer.height,
                                      sourceLumaBuffer.width,
                                      32, //cgImageFormat.bitsPerPixel,
                                      vImage_Flags(kvImageNoFlags))


      guard error == kvImageNoError else {
                return nil
            }
        }

        error = vImageConvert_420Yp8_CbCr8ToARGB8888(&sourceLumaBuffer,
                                                     &sourceChromaBuffer,
                                                     &destinationBuffer,
                                                     &infoYpCbCrToARGB,
                                                     nil,
                                                     255,
                                                     vImage_Flags(kvImagePrintDiagnosticsToConsole))

        return nil
    }

    func copy() -> CVPixelBuffer {

        precondition(CFGetTypeID(self) == CVPixelBufferGetTypeID(), "copy() cannot be called on a non-CVPixelBuffer")

        var _copy: CVPixelBuffer?

        CVPixelBufferCreate(
            nil,
            CVPixelBufferGetWidth(self),
            CVPixelBufferGetHeight(self),
            CVPixelBufferGetPixelFormatType(self),
            CVBufferGetAttachments(self, .shouldPropagate),
            &_copy)

        guard let copy = _copy else { fatalError() }

        CVPixelBufferLockBaseAddress(self, .readOnly)
        CVPixelBufferLockBaseAddress(copy, [])
        defer {
            CVPixelBufferUnlockBaseAddress(copy, [])
            CVPixelBufferUnlockBaseAddress(self, .readOnly)
        }

        for plane in 0 ..< CVPixelBufferGetPlaneCount(self) {

            let dest        = CVPixelBufferGetBaseAddressOfPlane(copy, plane)
            let source      = CVPixelBufferGetBaseAddressOfPlane(self, plane)
            let height      = CVPixelBufferGetHeightOfPlane(self, plane)
            let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(self, plane)

            memcpy(dest, source, height * bytesPerRow)
        }

        return copy
    }
}
