# Mind Map Feature Architecture Overview

This document provides a breakdown of all the files modified and created to implement the Interactive Mind Mapping feature. The architecture is split into four distinct layers: **Data**, **Layout/Rendering**, **UI**, and **Export**.

---

## 1. Data Layer
Responsible for parsing the raw JSON from the backend LLM into strongly-typed Dart objects.

### `lib/models/mind_map_data.dart`
- **Purpose**: Defines the data structures (`MindMapNode`, `MindMapEdge`, `MindMapResponseData`).
- **Key Logic**: Contains `fromJson` factory constructors. It ensures that raw JSON arrays are safely mapped into Dart lists. It also introduces the `position` (Offset) and `size` (Size) properties on nodes, which are initially empty but later populated by the Layout Engine.

---

## 2. Layout & Rendering Layer
The mathematical and visual core of the feature. Separates the calculation of coordinates from the actual drawing of pixels.

### `lib/mind_map/layout_engine.dart`
- **Purpose**: The mathematical brain of the mind map. It does not draw anything; it only calculates geometry.
- **Key Logic**: 
  - Exposes a static `applyLayout(MindMapData)` method that mutates the `position` of every node.
  - Contains 5 distinct algorithms depending on the `mapType`:
    1. **Hierarchical**: Depth-First Search (DFS) for top-down trees.
    2. **Flowchart**: Topological sorting for linear chains with parallel branching lanes.
    3. **Bubble**: Polar trigonometry (`cos`/`sin`) to position child nodes in a radial orbit around the center.
    4. **Tree Map**: Squarified subdivision, recursively slicing a large parent rectangle into smaller nested boxes.
    5. **Concept Map**: Similar to hierarchical but with wider horizontal spacing to accommodate edge text labels.

### `lib/mind_map/edge_painter.dart`
- **Purpose**: A `CustomPainter` responsible for drawing the physical lines connecting the nodes.
- **Key Logic**:
  - Calculates start/end anchor points on the edges of the node bounding boxes.
  - Uses `Path()..cubicTo(...)` to draw smooth Bézier S-curves.
  - Uses `atan2` trigonometry to calculate angles and draw directional arrowheads.
  - Uses `TextPainter` to draw relationship labels precisely at the midpoint of an edge (used in Concept maps).

---

## 3. UI Layer
The user-facing screens and interactive elements.

### `lib/mind_map_screen.dart`
- **Purpose**: The canvas viewer where the generated map is displayed.
- **Key Logic**:
  - Calculates the maximum required canvas size by measuring the bounds of all nodes.
  - Wraps a two-layer `Stack` inside an `InteractiveViewer` (allowing infinite pan/zoom).
    - **Layer 1 (Bottom)**: The `EdgePainter` drawing the vector lines.
    - **Layer 2 (Top)**: Absolute `Positioned` widgets rendering the `GlassContainer` node cards.
  - Renders conditional UI depending on the map type (e.g., drawing nested blocks for Tree Maps instead of glass cards).

### `lib/pdf_chat_screen.dart`
- **Purpose**: The entry point for triggering the mind map generation.
- **Key Logic**:
  - Adds the AppBar action button to open the configuration modal.
  - Implements `_showMindMapDialog()` using a `StatefulBuilder` to manage local dialog state (toggling between Chat History and PDF Range, selecting map types via a visual grid).
  - Handles the asynchronous HTTP POST request to the backend and navigates to the `MindMapScreen` upon success.

---

## 4. Export & Integration Layer
A cross-platform system for saving the canvas as a high-resolution image and copying syntax data.

### `lib/export/png_exporter.dart`
- **Purpose**: Captures the UI widget tree and encodes it into a PNG image.
- **Key Logic**: Finds the `RenderRepaintBoundary` mapped to the canvas, rasterizes it using `.toImage(pixelRatio: 3.0)` for high resolution, converts it to `Uint8List` byte data, and passes it to the platform-specific file saver. Provides `SnackBar` success/error feedback.

### `lib/export/file_saver.dart` (and web/io stubs)
- **Purpose**: Handles writing files to the user's hard drive depending on their Operating System.
- **Key Logic**: Uses Dart Conditional Imports to switch implementations at compile-time:
  - **`file_saver_web.dart`**: Uses `dart:html` to generate a Blob ObjectURL and simulates a click on an invisible `<a>` tag to trigger the browser's native download prompt.
  - **`file_saver_io.dart`**: Uses `path_provider` and `dart:io` to locate the native Desktop/Mobile 'Downloads' or 'Documents' folder and writes the byte stream directly to disk.

### `lib/export/clipboard_helper.dart`
- **Purpose**: Copies the raw Mermaid syntax to the system clipboard.
- **Key Logic**: Employs a Guard Clause to ensure data exists, uses Flutter's `Clipboard.setData()` platform channel to talk to the OS, and triggers a sleek success `SnackBar`.
