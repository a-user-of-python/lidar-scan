import ARKit
import RealityKit
import SceneKit
import SwiftUI
import simd

// One ARKit mesh anchor, baked into world-space triangles.
struct CapturedMesh {
    var positions: [SIMD3<Float>]  // world-space, meters
    var indices: [UInt32]          // 3 per triangle

    init?(from anchor: ARMeshAnchor) {
        let geometry = anchor.geometry

        // ---- Vertices (must be float3) ----
        guard geometry.vertices.format == .float3 else { return nil }
        let vCount = geometry.vertices.count
        guard vCount > 0 else { return nil }
        let vStride = geometry.vertices.stride
        let vOffset = geometry.vertices.offset
        let vBase = geometry.vertices.buffer.contents()

        // ---- Faces (triangles) ----
        let fCount = geometry.faces.count
        guard fCount > 0, geometry.faces.indexCountPerPrimitive == 3 else { return nil }
        let fStride = geometry.faces.stride
        let fOffset = geometry.faces.offset
        let fBase = geometry.faces.buffer.contents()
        let bytesPerIndex = geometry.faces.bytesPerIndex
        guard bytesPerIndex == 2 || bytesPerIndex == 4 else { return nil }

        let transform = anchor.transform

        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity(vCount)
        for i in 0..<vCount {
            let src = vBase.advanced(by: vOffset + i * vStride)
                .assumingMemoryBound(to: SIMD3<Float>.self).pointee
            let w = transform * SIMD4<Float>(src, 1.0)
            positions.append(SIMD3<Float>(w.x, w.y, w.z))
        }

        var indices: [UInt32] = []
        indices.reserveCapacity(fCount * 3)
        for f in 0..<fCount {
            for k in 0..<3 {
                let src = fBase.advanced(by: fOffset + f * fStride + k * bytesPerIndex)
                let idx: UInt32
                if bytesPerIndex == 4 {
                    idx = src.assumingMemoryBound(to: UInt32.self).pointee
                } else {
                    idx = UInt32(src.assumingMemoryBound(to: UInt16.self).pointee)
                }
                indices.append(idx)
            }
        }

        self.positions = positions

        // Defensive: every index must reference a real vertex,
        // or the STL writer / preview would crash out-of-bounds.
        for idx in indices {
            guard idx < vCount else { return nil }
        }
        self.indices = indices
    }
}

// Owns the AR session, collects LiDAR mesh anchors, exports STL.
class LiDARScanner: NSObject, ObservableObject, ARSessionDelegate {
    @Published var isScanning = false
    @Published var meshCount = 0
    @Published var triangleCount = 0
    @Published var statusMessage = "Tap Start Scan"
    @Published var supportsLiDAR = false

    private var meshes: [UUID: CapturedMesh] = [:]
    private let meshesLock = NSLock()
    private weak var arView: ARView?

    override init() {
        super.init()
        supportsLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        if !supportsLiDAR {
            statusMessage = "This device has no LiDAR scanner"
        }
    }

    func attach(to arView: ARView) {
        self.arView = arView
        arView.session.delegate = self
    }

    func startScanning() {
        guard supportsLiDAR, let arView = arView else { return }
        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .mesh   // LiDAR depth -> on-device mesh
        config.planeDetection = [.horizontal, .vertical]
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        clearMeshes()
        updateCounts()
        isScanning = true
        statusMessage = "Scanning — move slowly around the object"
    }

    func stopScanning() {
        arView?.session.pause()
        isScanning = false
        statusMessage = "Stopped — export your STL"
    }

    func clear() {
        clearMeshes()
        // Always reset the session so the rendered mesh clears too —
        // otherwise the old mesh stays visible with a "0 triangles" count.
        if let arView = arView {
            let config = ARWorldTrackingConfiguration()
            config.sceneReconstruction = .mesh
            arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            if !isScanning {
                arView.session.pause()
            }
        }
        updateCounts()
        statusMessage = isScanning ? "Scanning — move slowly around the object" : "Cleared"
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        ingest(anchors)
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        ingest(anchors)
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isScanning = false
            self.statusMessage = "Camera error: \(error.localizedDescription)"
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async {
            self.statusMessage = "Session interrupted — move back to where you were"
        }
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        DispatchQueue.main.async {
            self.statusMessage = self.isScanning
                ? "Scanning — move slowly around the object"
                : "Tap Start Scan"
        }
    }

    private func ingest(_ anchors: [ARAnchor]) {
        // Parse outside the lock — buffer copies are the expensive part.
        var newMeshes: [UUID: CapturedMesh] = [:]
        for anchor in anchors {
            guard let meshAnchor = anchor as? ARMeshAnchor,
                  let mesh = CapturedMesh(from: meshAnchor) else { continue }
            newMeshes[meshAnchor.identifier] = mesh
        }
        guard !newMeshes.isEmpty else { return }
        meshesLock.lock()
        meshes.merge(newMeshes) { _, new in new }
        meshesLock.unlock()
        updateCounts()
    }

    private func updateCounts() {
        meshesLock.lock()
        let tris = meshes.values.reduce(0) { $0 + $1.indices.count / 3 }
        let mCount = meshes.count
        meshesLock.unlock()
        DispatchQueue.main.async {
            self.meshCount = mCount
            self.triangleCount = tris
        }
    }

    func clearMeshes() {
        meshesLock.lock()
        meshes.removeAll()
        meshesLock.unlock()
    }

    func allMeshes() -> [CapturedMesh] {
        meshesLock.lock()
        defer { meshesLock.unlock() }
        return Array(meshes.values)
    }

    // MARK: - Export

    func makeSTL() -> Data {
        STLWriter.binarySTL(from: allMeshes())
    }

    // MARK: - Preview

    /// Builds a single SceneKit geometry from all captured meshes (for preview).
    func makeSCNGeometry() -> SCNGeometry? {
        let meshes = allMeshes()
        guard !meshes.isEmpty else { return nil }

        var vertices: [SCNVector3] = []
        var indices: [UInt32] = []
        var offset: UInt32 = 0
        for mesh in meshes {
            vertices.append(contentsOf: mesh.positions.map { SCNVector3($0.x, $0.y, $0.z) })
            indices.append(contentsOf: mesh.indices.map { $0 + offset })
            offset += UInt32(mesh.positions.count)
        }
        guard !indices.isEmpty else { return nil }

        let vertexSource = SCNGeometrySource(vertices: vertices)
        let indexData = indices.withUnsafeBytes { Data($0) }
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .triangles,
            primitiveCount: indices.count / 3,
            bytesPerIndex: 4
        )

        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemTeal
        material.isDoubleSided = true
        material.lightingModel = .lambert

        return SCNGeometry(sources: [vertexSource], elements: [element], materials: [material])
    }
}
