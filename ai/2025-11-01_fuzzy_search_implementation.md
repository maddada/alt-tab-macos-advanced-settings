# Fuzzy Search Implementation

## Overview

Implemented a floating search field above the window switcher dialog that enables real-time fuzzy filtering of windows by application name and window title. The search field appears outside the window list container (not in preferences) and matches the visual style of the main dialog.

## Requirements

- Search field floats above the window list with matching width and visual styling
- Fuzzy search matches against both `application.localizedName` and `window.title` regardless of which is displayed in UI
- Letter-based keyboard shortcuts (W, M, F, Q, H, etc.) are disabled when search field has focus
- Search field is cleared on window selection (Enter/Space/Click) and dialog dismissal (any method)
- Text remains vertically centered in the field during editing
- 5px bottom margin separates search field from window list
- Typing any printable character auto-focuses search field and inserts the character (both modes)
- Clicking search field in "Focus on release" mode prevents panel from closing on hotkey release
- Search field auto-focuses on panel open in "Do nothing on release" mode

## Architecture

### Search Field State Management

Search field active state is tracked via computed property `ThumbnailsPanel.isSearchFieldActive` which checks if the panel's `firstResponder` equals the field editor for `searchField`. This approach provides real-time state detection during keyboard event processing, eliminating race conditions from delegate callbacks.

Filter text is stored in static variable `Windows.filterText` and applied during window visibility evaluation in `refreshIfWindowShouldBeShownToTheUser()`.

### Fuzzy Matching Algorithm

Implemented in `Windows.fuzzyMatch()` and `Windows.fuzzyMatchString()`. The algorithm checks if pattern characters appear in order within the target text (case-insensitive). A window passes the filter if either its application name or window title matches the pattern.

### Keyboard Shortcut Filtering

Modified `handleKeyboardEvent()` in `KeyboardEventsTestable.swift` to skip shortcuts where `ATShortcut.isLetterBasedShortcut()` returns true when `ThumbnailsPanel.isSearchFieldActive` is true. Letter detection uses carbon key codes (0-46 covering A-Z).

### Visual Implementation

Search field uses `VerticalCenteredTextField` (custom `NSTextField` subclass) with `VerticalCenteredTextFieldCell` that overrides `drawingRect(forBounds:)`, `select(withFrame:...)`, and `edit(withFrame:...)` to maintain vertical centering during all text field states.

Container is `NSVisualEffectView` with `material = Appearance.material`, `blendingMode = .behindWindow`, and `cornerRadius = Appearance.windowCornerRadius` to match the thumbnails view styling.

## Modified Files

### `src/ui/main-window/ThumbnailsPanel.swift`
- Added `VerticalCenteredTextField` and `VerticalCenteredTextFieldCell` classes for text vertical centering
- Added `onBecomeFirstResponder` callback property to `VerticalCenteredTextField` for focus detection
- Overrode `becomeFirstResponder()` in `VerticalCenteredTextField` to trigger callback when field gains focus
- Changed `searchField` property type from `NSTextField?` to `VerticalCenteredTextField?`
- Added `searchField`, `searchContainerView`, and `containerView` properties
- Added computed property `isSearchFieldActive` to detect focus state
- Implemented `setupSearchField()` to initialize text field with visual effect container and wire up focus callback
- Implemented `setupContainerView()` to create layout hierarchy
- Implemented `clearSearchField()` to reset filter state and UI
- Modified `show()` to call `clearSearchField()` on dialog open
- Implemented `updateLayout()` to position search field with 5px bottom margin and handle panel sizing
- Added `handleSearchFieldBecameActive()` to set `forceDoNothingOnRelease` flag when search field gains focus in "Focus on release" mode
- Overrode `keyDown(with:)` to auto-focus search field and insert character when typing printable characters
- Added `isPrintableCharacter()` helper to filter control characters from auto-focus trigger
- Added `NSTextFieldDelegate` methods: `controlTextDidChange()` for real-time filtering and `control(_:textView:doCommandBy:)` for Escape key handling

### `src/logic/Windows.swift`
- Added `filterText` static variable to store search query
- Changed `refreshIfWindowShouldBeShownToTheUser()` from private to public for external filtering calls
- Modified `refreshIfWindowShouldBeShownToTheUser()` to check `passesSearchFilter` condition
- Implemented `fuzzyMatch()` to match against both application and window names
- Implemented `fuzzyMatchString()` for character-order matching algorithm

### `src/logic/ATShortcut.swift`
- Implemented `isLetterBasedShortcut()` to identify letter-based shortcuts using carbon key code set (A-Z)

### `src/logic/events/KeyboardEventsTestable.swift`
- Modified `handleKeyboardEvent()` to skip letter-based shortcuts when `ThumbnailsPanel.isSearchFieldActive` is true

### `src/ui/App.swift`
- Modified `hideUi()` to call `thumbnailsPanel.clearSearchField()` before hiding
- Modified `focusTarget()` to call `thumbnailsPanel.clearSearchField()` before window focus

### `src/api-wrappers/HelperExtensions.swift`
- Added `NSColor.init(hex:alpha:)` convenience initializer for #181818 background color

## Layout Specifications

- Search field height: 40px
- Horizontal padding: 10px (left/right within container)
- Bottom margin: 5px (between search field and window list)
- Gap between search container and thumbnails: 5px
- Background height reduction: 25px (container is shorter than default padding would create)
- Container height: `searchFieldHeight + (searchFieldPadding * 2) + searchFieldBottomMargin - backgroundHeightReduction`
- Search field is vertically centered within its container using `adjustedTopPadding = (searchContainerHeight - searchFieldHeight) / 2`
- Total panel height includes search container height plus thumbnails height with padding and gap
- Search field positioned at `y = thumbnailsHeight + Appearance.windowPadding * 2 + gapBetweenSearchAndList`
- Panel repositioning handled via `NSScreen.repositionPanel()` after layout updates

## Edge Cases Handled

- `application.localizedName` is optional, defaults to empty string in fuzzy match
- `window.title` is optional, defaults to empty string in fuzzy match
- Layout updates during text changes do not steal focus from search field (no forced `makeFirstResponder` calls)
- Filter state cleared on all dialog dismissal paths: explicit close, window selection, focus loss, and Escape key
- Vertical centering maintained during editing via overridden field editor methods
- Search field focus detection uses field editor comparison rather than delegate timing
- First typed character preserved during auto-focus by directly inserting into `stringValue` before `makeFirstResponder` completes
- Auto-focus typing works in both "Focus on release" and "Do nothing on release" modes

## Auto-Focus Search Field in "Do Nothing" Mode

When the window switcher is launched with "After release, do nothing" mode enabled, the search field is automatically focused to allow immediate typing.

### Implementation

**File:** `src/ui/main-window/ThumbnailsPanel.swift` (Lines 300-307)

In the `show()` method, after making the panel key and visible:
- Checks if `Preferences.shortcutStyle[App.app.shortcutIndex] == .doNothingOnRelease`
- If true, schedules `makeFirstResponder(searchField)` with 15ms delay
- Delay ensures panel is visible and overrides the VoiceOver first responder call (10ms)
- Uses weak self to prevent retain cycles
- Guards against app being hidden before focus can be set

### Rationale

In "do nothing" mode, users must explicitly press Enter to focus a window (no auto-focus on key release). Focusing the search field immediately provides a better UX:
- Users can start typing to filter windows right away
- Keyboard shortcuts are disabled when search is active (existing behavior)
- Search field focus triggers `becomeFirstResponder()` which sets `searchFieldWasFocusedDuringSession = true`
- This flag prevents accidental auto-focus if mode is changed during session

### Compatibility

- **VoiceOver:** Still functions normally; users can tab to thumbnails after initial focus
- **Keyboard navigation:** Arrow keys and other shortcuts work after Escape unfocuses search
- **Other modes:** "Focus on release" mode unchanged; thumbnails receive focus as before

## Auto-Focus Search Field on Click (Focus on Release Mode)

When user clicks on the search field in "Focus on release" mode, the panel behavior switches to "Do nothing on release" to prevent the panel from closing when the hotkey is released.

### Implementation

**File:** `src/ui/main-window/ThumbnailsPanel.swift` (Lines 3-28, 105-108, 427-434)

- `VerticalCenteredTextField` has `onBecomeFirstResponder` callback property
- `becomeFirstResponder()` override triggers callback when field gains focus (from click or programmatic focus)
- In `setupSearchField()`, callback is wired to call `handleSearchFieldBecameActive()`
- `handleSearchFieldBecameActive()` checks if current mode is `focusOnRelease` and sets `App.app.forceDoNothingOnRelease = true`
- The `forceDoNothingOnRelease` flag is checked in `ATShortcut.shouldTrigger()` to prevent hotkey release from triggering focus action

### Rationale

Users in "Focus on release" mode who click the search field intend to type and search. Allowing the panel to close when they release the hotkey would interrupt their workflow. By setting `forceDoNothingOnRelease`, the panel stays open until they explicitly press Enter or Escape.

## Auto-Focus Search Field When Typing

When user types any printable character while the panel is visible (in both modes), the search field automatically gains focus and the typed character is inserted.

### Implementation

**File:** `src/ui/main-window/ThumbnailsPanel.swift` (Lines 302-328)

- `keyDown(with:)` override intercepts keyboard events at panel level
- Checks if search field is not already active using `ThumbnailsPanel.isSearchFieldActive`
- Filters printable characters using `isPrintableCharacter()` which excludes control characters and special keys
- Directly sets `searchField.stringValue` to the typed character (avoids race condition with `makeFirstResponder`)
- Calls `makeFirstResponder(searchField)` to focus the field
- Sets cursor position to end of text using `currentEditor()?.selectedRange`
- Posts `NSControl.textDidChangeNotification` to trigger filtering logic in `controlTextDidChange()`
- In "Focus on release" mode, also sets `App.app.forceDoNothingOnRelease = true`

### Character Insertion Approach

Initial implementation used `keyDown(with:)` forwarding, but this caused the first character to be lost due to `makeFirstResponder` timing. Current approach directly inserts the character into `stringValue` before focusing, ensuring all typed characters appear in the search field.

## Enter Key Activates First Filtered Window

Pressing Enter while the search field is focused activates the first visible window in the filtered list.

**File:** `src/ui/main-window/ThumbnailsPanel.swift` (Lines 398-406)

In `control(_:textView:doCommandBy:)`, the Enter key handler finds the first window where `shouldShowTheUser == true` and calls `App.app.focusTarget()` to activate it.

**File:** `src/ui/main-window/ThumbnailsPanel.swift` (Lines 385-394)

In `controlTextDidChange()`, when filtering updates, the focused window index is set directly to avoid calling `Windows.voiceOverWindow()` which would steal focus from the search field via `makeFirstResponder()`. Visual highlighting is updated manually with `ThumbnailsView.highlight()`.

## Future Considerations

- Highlight matching characters in window/app names in the UI
- Configurable fuzzy match sensitivity (strict vs loose character ordering)
- Search syntax for filtering by app name only or window title only (e.g., "app:Chrome" or "title:Document")
