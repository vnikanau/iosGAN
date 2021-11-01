//
//  IDLPLYAsset.h
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 11/16/20.
//

#import <Foundation/Foundation.h>
#import <ModelIO/ModelIO.h>
#import <ARKit/ARKit.h>
#import "IDLObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface IDLPLYAsset : IDLObject

+ (instancetype)asset;
+ (instancetype)fromMDLAsset:(MDLAsset *)anAsset;
+ (instancetype)fromARMeshGeometry:(ARMeshGeometry *)aGeometry;
+ (instancetype)fromAnchors:(NSArray<ARAnchor *> *)anchors;

#pragma mark - Public methods

- (instancetype)initWithMDLAsset:(MDLAsset *)anAsset;
- (instancetype)initWithARMeshGeometry:(ARMeshGeometry *)aGeometry;
- (instancetype)initWithAnchors:(NSArray<ARAnchor *> *)anchors;

//- (void)appendParticleUniforms:(ParticleUniforms)anItem;

- (BOOL)readFromPath:(NSString *)aPath error:(NSError * _Nullable *)anError;
- (BOOL)writeToPath:(NSString *)aPath error:(NSError * _Nullable *)anError;

@end

NS_ASSUME_NONNULL_END
