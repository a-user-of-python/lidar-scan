import Foundation
import simd

// Writes mesh triangles as a binary STL file (little-endian, meters).
enum STLWriter {
    static func binarySTL(from meshes: [CapturedMesh]) -> Data {
        let triCount = meshes.reduce(0) { $0 + $1.indices.count / 3 }
        var data = Data()
        data.reserveCapacity(84 + triCount * 50)

        // 80-byte header
        var header = [UInt8](repeating: 0, count: 80)
        let label = Array("LiDARScan".utf8)
        for (i, b) in label.enumerated() where i < 80 { header[i] = b }
        data.append(contentsOf: header)

        // triangle count (LE uint32)
        var count = UInt32(triCount)
        data.append(Data(bytes: &count, count: 4))

        // 50 bytes per triangle: normal(12) + 3 verts(36) + attr(2)
        for mesh in meshes {
            let idx = mesh.indices
            let pos = mesh.positions
            var i = 0
            while i + 2 < idx.count {
                let a = pos[Int(idx[i])]
                let b = pos[Int(idx[i + 1])]
                let c = pos[Int(idx[i + 2])]
                var n = simd_normalize(simd_cross(b - a, c - a))
                if !n.x.isFinite || !n.y.isFinite || !n.z.isFinite {
                    n = SIMD3<Float>(0, 0, 0)
                }
                appendFloat(&data, n.x); appendFloat(&data, n.y); appendFloat(&data, n.z)
                appendFloat(&data, a.x); appendFloat(&data, a.y); appendFloat(&data, a.z)
                appendFloat(&data, b.x); appendFloat(&data, b.y); appendFloat(&data, b.z)
                appendFloat(&data, c.x); appendFloat(&data, c.y); appendFloat(&data, c.z)
                var attr: UInt16 = 0
                data.append(Data(bytes: &attr, count: 2))
                i += 3
            }
        }
        return data
    }

    private static func appendFloat(_ data: inout Data, _ v: Float) {
        var x = v
        data.append(Data(bytes: &x, count: 4))
    }
}
