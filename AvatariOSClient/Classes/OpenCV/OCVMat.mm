//
//  OCVMat.m
//  DepthGrabber
//
//  Created by Andrei Kazialetski on 7/17/20.
//

#import "OCVMat.hpp"
#import "AvatariOSClient-Bridging-Header.h"

@implementation OCVMat

+ (cv::Mat)matFromCVPixelBuffer:(CVPixelBufferRef)aPixelBuffer {
    return cv::Mat();
}

@end
