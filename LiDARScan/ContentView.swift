import SwiftUI
import RealityKit
import SceneKit

struct ScannerView: UIViewRepresentable {
    @ObservedObject var scanner: LiDARScanner

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        // Render the LiDAR mesh live so you can see what you're capturing
        arView.debugOptions.insert(.showSceneUnderstanding)
        scanner.attach(to: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

struct ActivityView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Full-screen 3D preview of the scanned model. Drag to orbit, pinch to zoom.
struct ModelPreviewView: UIViewRepresentable {
    let geometry: SCNGeometry

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        scnView.backgroundColor = .black

        let scene = SCNScene()
        let node = SCNNode(geometry: geometry)
        scene.rootNode.addChildNode(node)

        // Frame the model with the initial camera
        let (bbMin, bbMax) = geometry.boundingBox
        let cx = (bbMin.x + bbMax.x) / 2, cy = (bbMin.y + bbMax.y) / 2, cz = (bbMin.z + bbMax.z) / 2
        let size = max(max(bbMax.x - bbMin.x, bbMax.y - bbMin.y), max(bbMax.z - bbMin.z, 0.1))

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(cx + size * 0.8, cy + size * 0.6, cz + size * 0.8)
        // Look at the model's center, NOT the scene origin — the mesh lives in
        // ARKit world space, which can be meters away from (0,0,0).
        let targetNode = SCNNode()
        targetNode.position = SCNVector3(cx, cy, cz)
        scene.rootNode.addChildNode(targetNode)
        cameraNode.constraints = [SCNLookAtConstraint(target: targetNode)]
        scene.rootNode.addChildNode(cameraNode)
        scnView.pointOfView = cameraNode

        scnView.scene = scene
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}

struct ContentView: View {
    @StateObject private var scanner = LiDARScanner()
    @State private var shareURL: URL?
    @State private var showingShare = false
    @State private var showingNoLiDAR = false
    @State private var showingPreview = false
    @State private var previewGeometry: SCNGeometry?

    var body: some View {
        ZStack {
            ScannerView(scanner: scanner)
                .edgesIgnoringSafeArea(.all)

            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text(scanner.statusMessage)
                            .font(.headline)
                        Text("\(scanner.meshCount) meshes · \(scanner.triangleCount) triangles")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                }
                .padding()
                .background(Color.black.opacity(0.55))
                .foregroundColor(.white)

                Spacer()

                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        if scanner.isScanning {
                            Button("Stop") { scanner.stopScanning() }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                        } else {
                            Button("Start Scan") {
                                if scanner.supportsLiDAR {
                                    scanner.startScanning()
                                } else {
                                    showingNoLiDAR = true
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        Button("Clear") { scanner.clear() }
                            .buttonStyle(.bordered)
                    }

                    HStack(spacing: 12) {
                        Button("Preview") { showPreview() }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                            .disabled(scanner.triangleCount == 0)

                        Button("Export STL") { exportSTL() }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .disabled(scanner.triangleCount == 0)
                    }
                }
                .font(.title3)
                .padding()
                .background(Color.black.opacity(0.55))
            }
        }
        .sheet(isPresented: $showingShare) {
            if let url = shareURL {
                ActivityView(url: url)
            }
        }
        .sheet(isPresented: $showingPreview) {
            if let geometry = previewGeometry {
                ZStack {
                    ModelPreviewView(geometry: geometry)
                        .edgesIgnoringSafeArea(.all)
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Button("Close") { showingPreview = false }
                                .buttonStyle(.bordered)
                            Button("Export STL") {
                                showingPreview = false
                                // Give the preview sheet time to dismiss before
                                // presenting the share sheet, or SwiftUI drops it.
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    exportSTL()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                        .font(.title3)
                        .padding()
                    }
                }
            }
        }
        .alert("No LiDAR", isPresented: $showingNoLiDAR) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This iPhone doesn't have a LiDAR scanner.")
        }
    }

    private func showPreview() {
        guard let geometry = scanner.makeSCNGeometry() else { return }
        previewGeometry = geometry
        showingPreview = true
    }

    private func exportSTL() {
        guard scanner.triangleCount > 0 else { return }
        let data = scanner.makeSTL()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lidar-scan.stl")
        do {
            try data.write(to: url)
            shareURL = url
            showingShare = true
        } catch {
            scanner.statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }
}
