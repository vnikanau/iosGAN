//
//  ARMeshGeometry+Extension.swift
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 11/17/20.
//

import ARKit
import RealityKit
import MetalKit

extension simd_float4x4 {
    var position: SIMD3<Float> {
        return SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}

extension Transform {
    static func * (left: Transform, right: Transform) -> Transform {
        return Transform(matrix: simd_mul(left.matrix, right.matrix))
    }
}

extension ARMeshGeometry {

    /*
    func vertex(at index: UInt32) -> SIMD3<Float> {
        assert(vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per vertex.")
        let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * Int(index)))
        let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
        return vertex
    }
     */

    func vertex(at index: UInt32) -> (Float, Float, Float) {
        assert(vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per vertex.")
        let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * Int(index)))
        let vertex = vertexPointer.assumingMemoryBound(to: (Float, Float, Float).self).pointee
        return vertex
    }

    /*
    func normal(at index: UInt32) -> SIMD3<Float> {
        assert(vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per normal.")
        let normalPointer = normals.buffer.contents().advanced(by: normals.offset + (normals.stride * Int(index)))
        let normal = normalPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
        return normal
    }
     */

    func normal(at index: UInt32) -> (Float, Float, Float) {
        assert(vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per normal.")
        let normalPointer = normals.buffer.contents().advanced(by: normals.offset + (normals.stride * Int(index)))
        let normal = normalPointer.assumingMemoryBound(to: (Float, Float, Float).self).pointee
        return normal
    }

    func toMDLMesh(device: MTLDevice) -> MDLMesh {
        let allocator = MTKMeshBufferAllocator(device: device);

        let data = Data.init(bytes: vertices.buffer.contents(), count: vertices.stride * vertices.count);
        let vertexBuffer = allocator.newBuffer(with: data, type: .vertex);

        let indexData = Data.init(bytes: faces.buffer.contents(), count: faces.bytesPerIndex * faces.count * faces.indexCountPerPrimitive);
        let indexBuffer = allocator.newBuffer(with: indexData, type: .index);

        let submesh = MDLSubmesh(indexBuffer: indexBuffer,
                                 indexCount: faces.count * faces.indexCountPerPrimitive,
                                 indexType: .uInt32,
                                 geometryType: .triangles,
                                 material: nil);

        let vertexDescriptor = MDLVertexDescriptor();
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                            format: .float3,
                                                            offset: 0,
                                                            bufferIndex: 0);
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: vertices.stride);

        return MDLMesh(vertexBuffer: vertexBuffer,
                       vertexCount: vertices.count,
                       descriptor: vertexDescriptor,
                       submeshes: [submesh]);
    }

    func vertexIndicesOf(faceWithIndex index: Int) -> [Int] {
        let indicesPerFace = faces.indexCountPerPrimitive
        let facesPointer = faces.buffer.contents()
        var vertexIndices = [Int]()
        for offset in 0..<indicesPerFace {
            let vertexIndexAddress = facesPointer.advanced(by: (index * indicesPerFace + offset) * MemoryLayout<UInt32>.size)
            vertexIndices.append(Int(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee))
        }
        return vertexIndices
    }

}
