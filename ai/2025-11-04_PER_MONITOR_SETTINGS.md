# Per-Monitor Resolution Settings Implementation

## Overview

This feature enables AltTab to save and restore appearance settings independently for each monitor resolution. Users can configure different window sizes, offsets, and appearance styles for their MacBook Pro screen and external 4K monitor without manual profile switching.

## Requirements

- Store settings per monitor resolution (width × height), ignoring refresh rate and scaling
- Automatically detect monitor resolution and load/save corresponding settings
- Copy settings from the first known resolution when a new resolution is encountered
- Display current monitor resolution in the Preferences UI
- Simple implementation without profile management system

## Architecture

### Resolution-Keyed Storage

Settings are stored in UserDefaults with a resolution suffix appended to the base key. For example:
- Base key: `windowMaxWidthPercentage`
- Resolution-specific key: `windowMaxWidthPercentage_1920x1080`

When retrieving a setting, the system checks for a resolution-specific key first. If not found, it reads the base key and automatically creates the resolution-specific entry by copying the value.

### Resolution Detection

Screen resolution is obtained from `NSScreen.preferred.frame` dimensions, converted to an integer string format (`"widthxheight"`). This approach ignores scaling factors and refresh rates as required.

### Settings Scope

The following settings are resolution-sensitive:
- `windowMaxWidthPercentage` (window width as percentage)
- `windowMaxHeightPercentage` (window height as percentage)
- `windowVerticalOffset` (vertical position offset as percentage)
- `appearanceStyle` (thumbnails/appIcons/titles)
- `appearanceSize` (small/medium/large)

All other settings (theme, visibility, keyboard shortcuts, etc.) remain global across monitors.

## Files Modified

### 1. `src/logic/NSScreen.swift`

**Purpose**: Add screen resolution detection capability.

**Changes**:
- Added `resolutionString()` method that returns the current screen resolution as a formatted string (`"{width}x{height}"`)
- Uses `frame.width` and `frame.height` cast to `Int` to match the physical pixel dimensions

**Why**: Provides a consistent, simple resolution identifier that can be appended to preference keys.

### 2. `src/logic/Preferences.swift`

**Purpose**: Implement resolution-aware preference storage and retrieval.

**Changes**:

1. **Modified property getters** for resolution-sensitive settings:
   - `windowMaxWidthPercentage`, `windowMaxHeightPercentage`, `windowVerticalOffset` now call `getResolutionSpecificInt()`
   - `appearanceStyle`, `appearanceSize` now call `getResolutionSpecificMacroPref()`

2. **Updated `set()` method**:
   - Detects resolution-sensitive keys via a local allowlist
   - Automatically appends resolution suffix to keys before writing to UserDefaults
   - Clears cache entries for both base and resolution-specific keys

3. **Added helper methods**:
   - `currentResolution()`: Returns `NSScreen.preferred.resolutionString()`
   - `resolutionSpecificKey()`: Constructs suffixed key name
   - `getResolutionSpecificInt()`: Retrieves integer values with fallback to base key
   - `getResolutionSpecificMacroPref<T>()`: Retrieves enum values with fallback to base key, requires `MacroPreference & CaseIterable & Equatable` constraints

**Why**: Centralizes all resolution-aware logic in the Preferences class, making it transparent to the rest of the codebase. The fallback mechanism ensures backward compatibility and handles first-time detection of new resolutions.

### 3. `src/ui/preferences-window/tabs/appearance/AppearanceTab.swift`

**Purpose**: Display the current monitor resolution in the Preferences UI.

**Changes**:
- Added an `NSTextField` in `makeAppearanceView()` that displays the current resolution
- Label text: `"Settings for: "` + `NSScreen.preferred.resolutionString()`
- Styled with small system font and secondary label color for visual de-emphasis
- Positioned as the first row in the Appearance section

**Why**: Provides user feedback about which monitor's settings they are currently editing, preventing accidental misconfiguration.

## Implementation Notes

### Cache Invalidation

Both the base key and resolution-specific key are removed from `CachedUserDefaults.cache` when a setting is updated. This ensures subsequent reads reflect the new value without stale data.

### Type Safety

The generic parameter constraints in `getResolutionSpecificMacroPref<T>()` ensure that only types supporting the `indexAsString` property (via `CaseIterable & Equatable`) can be passed. The `MacroPreference` constraint ensures compatibility with the app's preferences system.

### First-Use Behavior

When a user connects a monitor with a previously unseen resolution:
1. The resolution-specific key does not exist in UserDefaults
2. The fallback mechanism reads from the base key
3. The value is immediately written to the resolution-specific key via `set()`
4. Future accesses on this resolution use the cached resolution-specific value

This avoids creating separate "profile" data structures while still achieving per-resolution behavior.

## Future Considerations

- **Migration**: Existing users will automatically benefit from this feature. Their current settings become the "base" for all new resolutions detected.
- **Additional Settings**: To make more settings resolution-specific, add the key to the allowlist in `Preferences.set()` and wrap the getter with `getResolutionSpecificInt()` or `getResolutionSpecificMacroPref()`.
- **Resolution Changes**: If a user adjusts macOS scaling or connects a monitor with a different resolution, the system treats it as a new resolution entry. Settings are not lost; they're associated with their original resolution keys.
- **Cleanup**: Old unused resolution-specific keys accumulate in UserDefaults but have minimal storage impact. Manual cleanup is not necessary but could be implemented if needed.
