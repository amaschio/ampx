# MilkDrop Managed Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make MilkDrop a managed dockable panel with classic chrome, defaulting to the right of main, with persisted size/visibility.

**Architecture:** Register `AmpXPanelID.visualizer` via `AmpXPanelDescriptor`; host `ClassicMilkdropPanelView` in its own borderless window; place first-open flush right of main; remove the inline `ContentView` expansion.

**Tech Stack:** Swift 6, SwiftUI + AppKit panel manager, Metal viz (`MilkdropMetalVisualizationView`), XCTest.

**Spec:** `docs/superpowers/specs/2026-08-01-milkdrop-panel-design.md`

## Global Constraints

- Classic Winamp chrome (no modern blue gradient header)
- Default dock: right of main, top-aligned
- Default size 600×450; user-resizable; persist size + visibility
- First-launch visibility: closed
- Do not force visualizer into `packMainVerticalColumn`
- Do not rename existing mini `ClassicVisualizerView` in `SpectrumView.swift`
- No commits unless the user explicitly asks

## File map

| File | Role |
|---|---|
| `Sources/AmpXPanelDescriptor.swift` | Add `.visualizer` ID |
| `Sources/AmpXPanelLayoutState.swift` | `showVisualizer`, `visualizerSize`, `visualizerMinimized` |
| `Sources/Utilities/AmpXMetrics.swift` | Default viz size constants |
| `Sources/AmpXPanelPlacement.swift` | Pure initial-origin helper (testable) |
| `Sources/Views/Classic/ClassicMilkdropPanelView.swift` | Classic chrome panel UI |
| `Sources/AmpXPanelWindowManager.swift` | Registry, place/resize/shade |
| `Sources/ContentView.swift` | Bind layout state; drop inline viz |
| `Sources/Views/Classic/ClassicMainPlayerView.swift` | Bindings → `showVisualizer` |
| `Sources/Views/Classic/ClassicShadeView.swift` | Same |
| `Sources/Views/Visualizer/MilkdropVisualizerView.swift` | Retire modern chrome or thin to unused |
| `Tests/AmpXTests/ClassicUITests.swift` | Layout persist + placement unit tests |

---

### Task 1: Layout state + placement helper

**Files:**
- Modify: `Sources/AmpXPanelDescriptor.swift`
- Modify: `Sources/Utilities/AmpXMetrics.swift`
- Modify: `Sources/AmpXPanelLayoutState.swift`
- Create: `Sources/AmpXPanelPlacement.swift`
- Modify: `Tests/AmpXTests/ClassicUITests.swift`

**Interfaces:**
- Produces: `AmpXPanelID.visualizer`
- Produces: `AmpXMetrics.defaultVisualizerWidth/Height` = 600 / 450
- Produces: `layout.showVisualizer: Bool` (UserDefaults key `showVisualizer`, default false)
- Produces: `layout.visualizerSize: CGSize` (keys `visualizerWidth` / `visualizerHeight`)
- Produces: `layout.visualizerMinimized: Bool` (in-memory)
- Produces: `layout.scaleVisualizerDimensions(by:)`
- Produces: `AmpXPanelPlacement.initialOrigin(panelID:panelSize:mainFrame:lowestClusterOriginY:)` → `CGPoint`

- [ ] **Step 1: Write failing tests** in `ClassicUITests.swift`:

```swift
@MainActor
func testVisualizerDefaultsHiddenWithDefaultSize() {
    let keyVis = "showVisualizer"
    let keyW = "visualizerWidth"
    let keyH = "visualizerHeight"
    // clear keys, construct layout…
    XCTAssertFalse(layout.showVisualizer)
    XCTAssertEqual(layout.visualizerSize.width, 600)
    XCTAssertEqual(layout.visualizerSize.height, 450)
}

@MainActor
func testVisualizerSizePersists() { /* set size, new layout, assert */ }

func testVisualizerInitialOriginIsRightOfMain() {
    let main = CGRect(x: 100, y: 400, width: 275, height: 116)
    let size = CGSize(width: 600, height: 450)
    let origin = AmpXPanelPlacement.initialOrigin(
        panelID: .visualizer,
        panelSize: size,
        mainFrame: main,
        stackBelowOrigin: nil
    )
    XCTAssertEqual(origin.x, 375) // 100+275
    XCTAssertEqual(origin.y, 66)  // 400+116-450
}

func testEqualizerInitialOriginStacksBelow() {
    let main = CGRect(x: 100, y: 400, width: 275, height: 116)
    let size = CGSize(width: 275, height: 116)
    let origin = AmpXPanelPlacement.initialOrigin(
        panelID: .equalizer,
        panelSize: size,
        mainFrame: main,
        stackBelowOrigin: CGPoint(x: 100, y: 400 - 116)
    )
    XCTAssertEqual(origin, CGPoint(x: 100, y: 168))
}
```

- [ ] **Step 2: Run tests — expect FAIL**

```bash
./scripts/run-tests.sh
```

- [ ] **Step 3: Implement ID, metrics, layout state, placement helper**

```swift
// AmpXPanelDescriptor.swift
static let visualizer = AmpXPanelID("visualizer")

// AmpXMetrics.swift
static let defaultVisualizerWidth: CGFloat = 600
static let defaultVisualizerHeight: CGFloat = 450

// AmpXPanelPlacement.swift
enum AmpXPanelPlacement {
    static func initialOrigin(
        panelID: AmpXPanelID,
        panelSize: CGSize,
        mainFrame: CGRect,
        stackBelowOrigin: CGPoint?
    ) -> CGPoint {
        if panelID == .visualizer {
            return CGPoint(
                x: mainFrame.maxX,
                y: mainFrame.maxY - panelSize.height
            )
        }
        if let below = stackBelowOrigin {
            return CGPoint(x: below.x, y: below.y - panelSize.height)
        }
        return CGPoint(x: mainFrame.minX, y: mainFrame.minY - panelSize.height)
    }
}
```

Layout state mirrors playlist width/height persistence for visualizer; `showVisualizer` uses `UserDefaults` bool (missing key → false).

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit** — skip unless user asks

---

### Task 2: ClassicMilkdropPanelView

**Files:**
- Create: `Sources/Views/Classic/ClassicMilkdropPanelView.swift`
- Ensure Xcode/SPM pick up new file (project may auto-include `Sources/` via folder refs — check `Package.swift` / pbxproj)

**Interfaces:**
- Consumes: `visualizerSize` Binding, `isMinimized` Binding, `showVisualizer` Binding, `MilkdropMetalVisualizationView`, pledit sprites
- Produces: `ClassicMilkdropPanelView` root used by panel hosting

- [ ] **Step 1: Implement panel**
  - Title bar: pledit-style tiled strip + shade/close + `PanelTitleBarDragOverlay` (copy playlist title-bar pattern, label “MILKDROP”)
  - Preset strip (~14px): ◀ / `MILKDROP • name` / ▶ using `ClassicSkinColors.led`; move timer/fade logic from `MilkdropVisualizerView`
  - Body: `MilkdropMetalVisualizationView` + black fill
  - Windowshade: title only
  - BR resize grip like playlist; min width `ClassicSkinMetrics.windowWidth * s`, min height `200 * s`
  - Frame: `visualizerSize` when expanded

- [ ] **Step 2: Build**

```bash
./build.sh
```

Expected: success

- [ ] **Step 3: Commit** — skip unless user asks

---

### Task 3: Register panel + manager hooks

**Files:**
- Modify: `Sources/AmpXPanelWindowManager.swift`

**Interfaces:**
- Consumes: Task 1 placement helper + layout fields; Task 2 view
- Produces: descriptor; `resizeVisualizerPanel()`; shade branch; no vertical force for visualizer

- [ ] **Step 1: Append descriptor** in `makeRegistry()`:

```swift
AmpXPanelDescriptor(
    id: .visualizer,
    isVisible: { [weak self] in self?.layoutState?.showVisualizer ?? false },
    makeRoot: { [weak self] in
        guard let layoutState = self?.layoutState else { return AnyView(EmptyView()) }
        return AnyView(VisualizerPanelRoot(layoutState: layoutState))
    },
    sizing: .explicit { [weak self] in
        guard let layoutState = self?.layoutState else { return .zero }
        let scale = self?.uiScale?.scale ?? 1
        let minimizedHeight = ClassicSkinMetrics.scaled(
            ClassicSkinMetrics.playlistShadeHeight, by: scale
        )
        if layoutState.visualizerMinimized {
            return CGSize(
                width: max(layoutState.visualizerSize.width,
                           ClassicSkinMetrics.scaled(ClassicSkinMetrics.windowWidth, by: scale)),
                height: minimizedHeight
            )
        }
        let width = max(
            layoutState.visualizerSize.width,
            ClassicSkinMetrics.scaled(ClassicSkinMetrics.windowWidth, by: scale)
        ).rounded(.toNearestOrAwayFromZero)
        let height = layoutState.visualizerSize.height.rounded(.toNearestOrAwayFromZero)
        return CGSize(width: width, height: height)
    }
)
```

- [ ] **Step 2: `placePanelInitially`** use `AmpXPanelPlacement.initialOrigin` when no saved offset

- [ ] **Step 3: `showPanel`** — for `.visualizer`, never call `packMainVerticalColumn(forcing: .visualizer)`. On new: place initially; on re-show: restore saved offset or right-of-main. Still call `packMainVerticalColumn(forcing: nil)` so EQ/PL column can reflow if needed.

- [ ] **Step 4: Add `resizeVisualizerPanel()`, wire `onChange` in ContentView; shade in `toggleWindowshade`; `isVisualizerWindow` helper

- [ ] **Step 5: Add `VisualizerPanelRoot` (mirror `PlaylistPanelRoot`)

- [ ] **Step 6: Build + unit tests pass

---

### Task 4: Wire UI + remove inline viz

**Files:**
- Modify: `Sources/ContentView.swift`
- Modify: `Sources/Views/Classic/ClassicMainPlayerView.swift`
- Modify: `Sources/Views/Classic/ClassicShadeView.swift`
- Modify: `Sources/Views/Visualizer/MilkdropVisualizerView.swift` (delete unused modern chrome, or leave thin dead code removed)

- [ ] **Step 1: Replace `@State showVisualization` with `panelLayout.showVisualizer` bindings
- [ ] **Step 2: Remove `HStack` MilkDrop branch and miniaturize one-off
- [ ] **Step 3: `onChange(of: showVisualizer)` → `syncPanelWindows()`; `onChange` size/minimized → `resizeVisualizerPanel()`
- [ ] **Step 4: Scale visualizer size in existing UI-scale `onChange` alongside playlist
- [ ] **Step 5: Build

---

### Task 5: Verify in app

- [ ] **Step 1:** `./build.sh --run` (or `./scripts/shoot.sh`)
- [ ] **Step 2:** Open via mini-viz double-click; confirm right-of-main dock, classic chrome, Metal animates with playback
- [ ] **Step 3:** Resize, shade, close, reopen; confirm persistence after relaunch if practical
- [ ] **Step 4:** `./scripts/run-tests.sh`

---

## Spec coverage check

| Spec item | Task |
|---|---|
| Panel ID + descriptor | 1, 3 |
| Layout persist visibility/size | 1 |
| Right-of-main default | 1, 3 |
| No vertical force | 3 |
| Classic chrome + presets | 2 |
| Resizable + shade | 2, 3 |
| Remove inline ContentView | 4 |
| Tests + manual verify | 1, 5 |
