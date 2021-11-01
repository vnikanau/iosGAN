//
//  ARMeshGeometry+Extension.m
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 11/18/20.
//

#import "ARMeshGeometry+Extension.h"

@implementation ARMeshGeometry (Extension)

- (IDLVertex)vertexAtIndex:(NSInteger)anIndex
{
    IDLVertex result = { 0., 0., 0. };
    NSAssert(self.vertices.format == MTLVertexFormatFloat3, @"Expected three floats (twelve bytes) per vertex.");

    ARGeometrySource *vertices = self.vertices;
    id<MTLBuffer> buffer = vertices.buffer;

    NSInteger stride = vertices.stride;
    NSInteger offset = vertices.offset;

    float *rawVertices = [buffer contents];
    memcpy(&result, rawVertices + offset + (anIndex * vertices.componentsPerVector), stride);

    return result;
}

- (IDLNormal)normalAtIndex:(NSInteger)anIndex
{
    IDLNormal result = { 0., 0., 0. };
    NSAssert(self.normals.format == MTLVertexFormatFloat3, @"Expected three floats (twelve bytes) per normal.");
    ARGeometrySource *normals = self.normals;
    id<MTLBuffer> buffer = normals.buffer;

    NSInteger stride = normals.stride;
    NSInteger offset = normals.offset;
    float *rawNormals = [buffer contents];

    memcpy(&result, rawNormals + offset + (anIndex * normals.componentsPerVector), stride);


    return result;
}

- (NSArray *)vertexIndicesOfFaceWithIndex:(NSInteger)anIndex
{
    NSInteger indicesPerFace = self.faces.indexCountPerPrimitive;
    id<MTLBuffer> buffer = self.faces.buffer;
    UInt32 *rawValues = [buffer contents];

    NSMutableArray *vertexIndices = [@[] mutableCopy];

    for (int offset = 0; offset < indicesPerFace; ++offset) {
//        let vertexIndexAddress = facesPointer.advanced(by: (index * indicesPerFace + offset) * MemoryLayout<UInt32>.size)
//       vertexIndices.append(Int(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee))
        UInt32 value = 0;
        memcpy(&value, rawValues + (anIndex * indicesPerFace + offset), sizeof(UInt32));

        [vertexIndices addObject:@(value)];
   }
    return vertexIndices;
}

- (void)vertexForFaceWithIndex:(NSInteger)anIndex data:(int32_t *)aData chunkSize:(size_t)aSize
{
    if (aData == nil) {
        return;
    }

    NSInteger indicesPerFace = self.faces.indexCountPerPrimitive;
    id<MTLBuffer> buffer = self.faces.buffer;
    UInt32 *rawValues = [buffer contents];

    memcpy(aData, rawValues + (anIndex * indicesPerFace), aSize);

}

@end
