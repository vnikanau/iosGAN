//
//  OCVMat.h
//  DepthGrabber
//
//  Created by Andrei Kazialetski on 7/17/20.
//

#import <Foundation/Foundation.h>
#import <opencv2/core.hpp>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

@interface OCVMat : NSObject

+ (cv::Mat)matFromCVPixelBuffer:(CVPixelBufferRef)aPixelBuffer;

@end

NS_ASSUME_NONNULL_END
