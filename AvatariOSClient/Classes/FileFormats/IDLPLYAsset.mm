//
//  IDLPLYAsset.m
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 11/16/20.
//

#import "IDLPLYAsset.h"
#import "plycpp.h"
#import "ARMeshGeometry+Extension.h"

#include <unordered_map>
#include <vector>

using namespace plycpp;

@interface IDLPLYAsset()
{

}

@property PLYData _ply;

//- (std::shared_ptr<ElementArray>)vertex;
//- (std::shared_ptr<ElementArray>)face;

//- (void)createVertexElementWithNormals:(BOOL)haveNormals andColors:(BOOL)haveColors;
//- (void)createFaceElement;

@end

@implementation IDLPLYAsset

#pragma mark - Static methods

+ (instancetype)asset
{
    return [IDLPLYAsset new];
}

+ (instancetype)fromMDLMesh:(MDLMesh *)aMesh
{
    return [IDLPLYAsset new];
}

+ (instancetype)fromMDLAsset:(MDLAsset *)anAsset
{
    return [IDLPLYAsset new];
}

+ (instancetype)fromARMeshGeometry:(ARMeshGeometry *)aGeometry
{
    id result = nil;

    if (aGeometry != nil) {
        result = [[IDLPLYAsset alloc] initWithARMeshGeometry:aGeometry];
    }

    return result;
}


+ (instancetype)fromAnchors:(NSArray<ARAnchor *> *)anchors
{
    id result = nil;

    if (anchors != nil) {
        result = [[IDLPLYAsset alloc] initWithAnchors:anchors];
    }

    return result;
}

#pragma mark -

- (instancetype)initWithMDLAsset:(MDLAsset *)anAsset
{
    if (self = [super init]) {
        if (anAsset != nil) {
            [self parseMDLAsset:anAsset];
        }
    }

    return self;
}

- (instancetype)initWithARMeshGeometry:(ARMeshGeometry *)aGeometry
{
    if (self = [super init]) {
//        [self parse];
    }

    return self;
}

- (instancetype)initWithAnchors:(NSArray<ARAnchor *> *)anchors
{
    if (self = [super init]) {
        if (anchors != nil) {
            [self appendAnchors:anchors];
        }
    }

    return self;
}

#pragma mark -

- (void)initialize
{
    // TODO:
    __ply.clear();
}

#pragma mark - Private methods

- (void)parseMDLAsset:(MDLAsset *)anAsset
{
//    id meshes = [anAsset childObjectsOfClass:[MDLMesh class]];

}

- (void)appendAnchors:(NSArray<ARAnchor *> *)anchors
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:
                              @"self isKindOfClass: %@",
                              [ARMeshAnchor class]];
    NSArray *elements = [anchors filteredArrayUsingPredicate:predicate];

    for (ARMeshAnchor *element in elements) {
        [self appendARMeshGeometry:element.geometry];
    }

//    [self appendARMeshGeometry:[(ARMeshAnchor *)elements[0] geometry]];
}

- (void)appendARMeshGeometry:(ARMeshGeometry *)aGeometry
{
    struct {
        uint8_t vertices:1;
        uint8_t normals:1;
        uint8_t faces:1;
    } having;

    struct {
        size_t points;
        size_t faces;
    } offset = { 0, 0 };

    NSInteger cntVert = aGeometry.vertices.count;
    NSInteger cntNorm = aGeometry.normals.count;
    NSInteger cntFaces = aGeometry.faces.count;

    // 1. Check vertices count >0
    having.vertices = cntVert > 0;
    // 2. Check normals count > 0 && vertices count == normals count
    having.normals = cntNorm > 0 && cntNorm == cntVert;
    // 3. Check faces count
    having.faces = cntFaces >0;

    if (cntVert < 1) {
        return;
    }

    // 4. Populate properties

    std::shared_ptr<ElementArray> currentElement = nullptr;
    if (!__ply.hasElementWithKey("vertex")) {
        currentElement.reset(new ElementArray(cntVert));
        __ply.push_back("vertex", currentElement);

        std::string propertiesVertex[] = { "x", "y", "z", "red", "green", "blue" };

        for (int idx = 0, cnt = sizeof(propertiesVertex) / sizeof(propertiesVertex[0]); idx < cnt; ++idx) {
            auto propertyName = propertiesVertex[idx];

            std::shared_ptr<PropertyArray> newProperty = nullptr;

            if (idx < 3) {
                newProperty.reset(new PropertyArray(plycpp::FLOAT, currentElement->size()));
            } else {
                newProperty.reset(new PropertyArray(plycpp::UCHAR, currentElement->size()));
            }

            currentElement->properties.push_back(propertyName, newProperty);
        }

        if (having.normals) {

            std::string properitiesNormal[] = { "nx", "ny", "nz" };

            for (int idx = 0, cnt = sizeof(properitiesNormal) / sizeof(properitiesNormal[0]); idx < cnt; ++idx) {
                auto propertyName = properitiesNormal[idx];

                std::shared_ptr<PropertyArray> newProperty(new PropertyArray(plycpp::FLOAT, currentElement->size()));
                currentElement->properties.push_back(propertyName, newProperty);
            }

        }

        if (having.faces) {
            currentElement.reset(new ElementArray(cntFaces));
            __ply.push_back("face", currentElement);

//            const std::type_index indexCountType = plycpp::UCHAR;
            const std::type_index dataType = plycpp::INT;
            const std::string name = "vertex_indices";

            std::shared_ptr<PropertyArray> newProperty(new PropertyArray(dataType, 3 * currentElement->size(), true));
            currentElement->properties.push_back(name, newProperty);
        }

    } else {

        currentElement = __ply["vertex"];
        offset.points = currentElement->size();
        size_t newSize = offset.points + cntVert;
        currentElement->resize(newSize);

        currentElement = __ply["face"];
//        auto &prop = currentElement->properties;
        offset.faces = currentElement->size();
        size_t newFaceSize = offset.faces + cntFaces;
        currentElement->resize(newFaceSize);

    }

//    std::unordered_map<PropertyArray *, unsigned char *> writingPlace;
//    for (auto &elementTuple : __ply) {
//        auto &element = elementTuple.data;
//        for (auto &propertyTuple : element->properties) {
//            auto &prop = propertyTuple.data;
//            writingPlace[prop.get()] = prop->data.data();
//        }
//    }

    // 5. process vertices and normals if exists
    currentElement = __ply["vertex"];

    for (int idx = 0; idx < cntVert; ++idx) {
        IDLVertex vertex = [aGeometry vertexAtIndex:idx];
        IDLNormal normal = [aGeometry normalAtIndex:idx];

        size_t elementIdx = offset.points + idx;
        currentElement->properties["x"]->at<float>(elementIdx) = vertex.x;
        currentElement->properties["y"]->at<float>(elementIdx) = vertex.y;
        currentElement->properties["z"]->at<float>(elementIdx) = vertex.z;
        currentElement->properties["red"]->at<unsigned char>(elementIdx) = 255;
        currentElement->properties["green"]->at<unsigned char>(elementIdx) = 255;
        currentElement->properties["blue"]->at<unsigned char>(elementIdx) = 255;

        if (having.normals) {
            currentElement->properties["nx"]->at<float>(elementIdx) = normal.nx;
            currentElement->properties["ny"]->at<float>(elementIdx) = normal.ny;
            currentElement->properties["nz"]->at<float>(elementIdx) = normal.nz;
        }

    }

    // Process faces
    if (having.faces) {

        currentElement = __ply["face"];

        NSInteger indexSize = aGeometry.faces.bytesPerIndex;
        NSInteger components = aGeometry.faces.indexCountPerPrimitive;

        int32_t *vertexData = new int32_t[components];

        auto prop = currentElement->properties["vertex_indices"];
//        const size_t chunkSize = 3 * prop->stepSize;

        for (int idx = 0; idx < cntFaces; ++idx) {
            size_t elementIdx = (offset.faces + idx) * components;

            [aGeometry vertexForFaceWithIndex:idx data:vertexData chunkSize:indexSize * components];

            for (int valueIdx = 0; valueIdx < 3; ++valueIdx) {
                prop->at<int32_t>(elementIdx + valueIdx) = vertexData[valueIdx] + (int32_t)offset.points;
            }

//            memcpy(ptData, vertexData, chunkSize);

//            NSArray<NSNumber *>*values = [aGeometry vertexIndicesOfFaceWithIndex:elementIdx];
//
//            for (NSUInteger valueIdx = 0, cnt = values.count; valueIdx < cnt; ++valueIdx) {
//                size_t propertyIdx = (elementIdx * 3) + valueIdx;
//                currentElement->properties["vertex_indices"]->at<int32_t>(propertyIdx) =
//                (int32_t)[values[valueIdx] intValue];
//            }

        }

        if (vertexData != nullptr) {
            delete[] vertexData;
        }

    }

    //    aGeometry.faces;
}

//- (void)appendParticleUniforms:(ParticleUniforms)anItem
//{
//
//}

- (BOOL)readFromPath:(NSString *)aPath error:(NSError * _Nullable *)anError
{
    return YES;
}

- (BOOL)writeToPath:(NSString *)aPath error:(NSError * _Nullable *)anError
{
    save([aPath UTF8String], __ply, plycpp::FileFormat::BINARY);
    return YES;
}

@end
