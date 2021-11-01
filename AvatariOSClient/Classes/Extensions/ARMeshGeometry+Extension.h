//
//  ARMeshGeometry+Extension.h
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 11/18/20.
//

#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct IDLVertex {
    float x;
    float y;
    float z;
} IDLVertex;

typedef struct IDLNormal {
    float nx;
    float ny;
    float nz;
} IDLNormal;


typedef struct IDLFace {
    
} IDLFace;

@interface ARMeshGeometry (Extension)

- (IDLVertex)vertexAtIndex:(NSInteger)anIndex;
- (IDLNormal)normalAtIndex:(NSInteger)anIndex;
- (NSArray *)vertexIndicesOfFaceWithIndex:(NSInteger)anIndex;
- (void)vertexForFaceWithIndex:(NSInteger)anIndex data:(int32_t *)aData chunkSize:(size_t)aSize;

@end

NS_ASSUME_NONNULL_END
