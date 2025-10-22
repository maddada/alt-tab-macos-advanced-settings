# Window Highlight Overlay Implementation

## Feature Overview

When a user selects a window in the thumbnails panel and switches to it, a blinking border appears around the activated window to provide visual feedback. The border blinks once (configurable) with a blue outline.

## Requirements

- Display a border around the activated window immediately upon selection
- Border should blink (fade in/out) to draw user attention
- Border must not interfere with window interaction (mouse-transparent, non-activating)
- Overlay must position correctly across different screen configurations
- Animation should clean up automatically after completion

## Architecture

The implementation uses a singleton overlay window (`WindowHighlightOverlay`) that creates a transparent, non-activating `NSWindow` positioned over the target window. The overlay uses `NSAnimationContext` for smooth fade transitions and manages its own lifecycle.

## Files Modified

### 1. `/Users/madda/dev/alt-tab-macos/src/ui/main-window/WindowHighlightOverlay.swift` (Created)

**Purpose**: Main overlay implementation

**Key Components**:
- `WindowHighlightOverlay.shared`: Singleton instance to prevent multiple overlays
- `showBlinkingBorder(for: Window)`: Entry point that creates and positions overlay
- `createOverlayWindow(frame: NSRect)`: Sets up borderless window with specific properties:
  - `isOpaque = false`, `backgroundColor = .clear`: Transparency
  - `ignoresMouseEvents = true`: Mouse pass-through
  - `level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 1)`: Above target window
  - `collectionBehavior = [.canJoinAllSpaces, .stationary]`: Multi-space support
- `startBlinkingAnimation(blinkCount: Int)`: Timer-based animation loop using `NSAnimationContext`
- `BorderView`: Custom `NSView` subclass that renders the border via `CALayer` properties:
  - `borderColor = NSColor.systemBlue.cgColor`
  - `borderWidth = 6`
  - `cornerRadius = 8`
- `cleanup()`: Removes overlay window and invalidates timer

**Coordinate Conversion**: Quartz coordinates (origin bottom-left) are converted to Cocoa coordinates (origin top-left) using `primaryScreen.frame.maxY - frame.maxY`

### 2. `/Users/madda/dev/alt-tab-macos/src/logic/Window.swift:203-205` (Modified)

**Purpose**: Integration point for overlay activation

**Changes**: Added call to `WindowHighlightOverlay.shared.showBlinkingBorder(for: self)` within the `focus()` method's background operation queue

**Location**: Inside `BackgroundWork.accessibilityCommandsQueue.addOperation` closure, after window activation APIs (`_SLPSSetFrontProcessWithOptions`, `makeKeyWindow`, `focusWindow`)

**Threading**: Uses `DispatchQueue.main.async` to ensure overlay creation happens on main thread without delay

**Execution Context**: Only triggered in the main focus path (not for Alt-Tab's own windows or windowless apps)

### 3. `/Users/madda/dev/alt-tab-macos/alt-tab-macos.xcodeproj/project.pbxproj` (Modified)

**Purpose**: Xcode project integration

**Changes**:
- Added `WindowHighlightOverlay.swift` to PBXBuildFile section (reference: `AA974BAB29B7D84C0099A29F`)
- Added file reference in PBXFileReference section
- Included in `main-window` group alongside `PreviewPanel.swift`, `ThumbnailsPanel.swift`, etc.
- Added to build sources phase for compilation

## Technical Details

### Window Positioning

The overlay obtains position and size from the `Window` object's `position` and `size` properties (stored as `CGPoint?` and `CGSize?`). These values are populated from either CGWindow API (`kCGWindowBounds`) or AXUIElement API (`kAXPositionAttribute`, `kAXSizeAttribute`).

### Animation Mechanism

The blink animation uses a repeating `Timer` with interval matching the fade duration. Each timer tick toggles between `alphaValue = 0` and `alphaValue = 1` using `NSAnimationContext.runAnimationGroup()` with `easeInEaseOut` timing function. The completion handler tracks blink count and invokes cleanup after the final fade-out.

### Lifecycle Management

- **Creation**: Triggered by `Window.focus()` on successful window activation
- **Duration**: Controlled by `blinkCount` parameter (default: 3, user reduced to 1)
- **Cleanup**: Automatic via timer invalidation and window ordering out
- **Concurrency**: New overlay cancels any existing animation via `cleanup()` call

## Extension Points

### Customization Parameters

Developers can modify these properties in `WindowHighlightOverlay`:
- `blinkCount`: Number of blinks (currently 3 in code, user reduced to 1)
- `blinkDuration`: Fade transition time (currently 0.15 seconds)
- Border styling in `BorderView`: `borderColor`, `borderWidth`, `cornerRadius`
- Window level calculation for z-order positioning

### Alternative Activation Points

While currently integrated in `Window.focus()`, the overlay could be triggered from:
- `ThumbnailView.mouseUpCallback`: For immediate feedback on click
- `App.focusSelectedWindow()`: Earlier in the focus chain
- Keyboard event handlers in `KeyboardEventsTestable`

### Multi-Window Support

The singleton pattern prevents overlapping animations. For simultaneous multi-window highlighting, replace `WindowHighlightOverlay.shared` with an instance pool keyed by `CGWindowID`.

## Known Constraints

- Overlay requires valid `position` and `size` properties on `Window` object (guards against nil)
- Only appears for normal window focus path (excluded for Alt-Tab's own windows and windowless apps)
- Window level is hardcoded relative to `floatingWindow` key - may not appear above all window types
- Coordinate conversion assumes primary screen as reference point - may need adjustment for multi-monitor setups with different orientations

## Dependencies

- Cocoa framework: `NSWindow`, `NSPanel`, `NSAnimationContext`, `CALayer`
- Existing window management: `Window.position`, `Window.size`, `Window.cgWindowId`
- Threading: `DispatchQueue.main`, `BackgroundWork.accessibilityCommandsQueue`
- Screen API: `NSScreen.screens.first` for coordinate conversion
