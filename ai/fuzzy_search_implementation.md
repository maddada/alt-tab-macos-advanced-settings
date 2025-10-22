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
- Added `searchField`, `searchContainerView`, and `containerView` properties
- Added computed property `isSearchFieldActive` to detect focus state
- Implemented `setupSearchField()` to initialize text field with visual effect container
- Implemented `setupContainerView()` to create layout hierarchy
- Implemented `clearSearchField()` to reset filter state and UI
- Modified `show()` to call `clearSearchField()` on dialog open
- Implemented `updateLayout()` to position search field with 5px bottom margin and handle panel sizing
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

## Future Considerations

- Search history or recent searches could be stored in preferences
- Highlight matching characters in window/app names in the UI
- Configurable fuzzy match sensitivity (strict vs loose character ordering)
- Search syntax for filtering by app name only or window title only (e.g., "app:Chrome" or "title:Document")
