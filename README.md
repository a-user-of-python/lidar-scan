# LiDARScan

A test app that uses the iPhone's **LiDAR scanner** (ARKit scene reconstruction)
to build a 3D mesh **entirely on-device**, then exports it as a binary **STL** file.

No accounts, no cloud, no subscriptions — the mesh never leaves your phone.

## How it works

- `ARWorldTrackingConfiguration` with `sceneReconstruction = .mesh` — this is
  Apple's LiDAR depth pipeline. ARKit fuses LiDAR depth samples into `ARMeshAnchor`
  objects in real time, all on-device.
- The live mesh is rendered in the AR view (scene-understanding debug view) so you
  can see what you've captured.
- Every mesh anchor's vertices/faces are baked to world space and written as a
  binary STL (little-endian, meters, one triangle per 50 bytes).

## Build & install (Mac)

1. Open `LiDARScan.xcodeproj` in Xcode.
2. In the project editor, select the **LiDARScan** target → **Signing & Capabilities**:
   - Set **Team** to your Apple ID (free accounts work — the app stays valid 7 days).
   - Change the **Bundle Identifier** to something unique (e.g. `com.yourname.lidarscan`).
3. Connect your iPhone 18 Pro Max, select it as the run destination, press **Run** (⌘R).
4. On first launch, allow camera access.

## Use

1. Tap **Start Scan**, then walk slowly around the object. The mesh appears live.
2. Tap **Stop** when done.
3. Tap **Export STL** → share sheet → Save to Files / AirDrop it to your Mac.
4. Slice the STL in your slicer of choice (Bambu Studio, PrusaSlicer, Cura…).

Tip: LiDAR meshes are rough — run the STL through Meshmixer (free) or
Bambu Studio's mesh repair before slicing if the print has holes.

## Files

- `LiDARScanApp.swift` — app entry point
- `ContentView.swift` — UI: AR view, scan controls, export/share
- `LiDARScanner.swift` — ARKit session, mesh anchor collection (thread-safe)
- `STLWriter.swift` — mesh → binary STL
- `Info.plist` — camera usage description, etc.

To regenerate the Xcode project file: `python3 gen_project.py`
