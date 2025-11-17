# Search Field Placeholder Styling

## Requirements

- Placeholder text color: #BBBBBB (configurable via hex color code)
- Placeholder text must be centered horizontally
- Placeholder must hide when search field is focused or contains text
- Placeholder text: "Search windows..."

## Implementation

### Files Modified

**`src/ui/main-window/ThumbnailsPanel.swift`**
- Modified `setupSearchField()` function (lines 94-105)

### Technical Details

#### Placeholder Color and Centering

The placeholder is implemented using `placeholderAttributedString` rather than `placeholderString` to support custom styling. The attributed string requires three attributes:

1. **`.foregroundColor`**: Uses `NSColor(hex: 0xBBBBBB)` from the existing `NSColor` extension in `src/api-wrappers/HelperExtensions.swift:18-23`

2. **`.paragraphStyle`**: Critical for centering. The text field's `.alignment` property only affects typed text, not attributed string placeholders. An `NSMutableParagraphStyle` with `.alignment = .center` must be included in the attributed string's attributes dictionary.

3. **`.font`**: Must match the text field's font (`NSFont.systemFont(ofSize: 14)`) to ensure consistent appearance

#### Auto-Hide Behavior

The placeholder automatically hides when the field becomes first responder or contains text. This is NSTextField's default behavior—no additional implementation required.

The existing `onBecomeFirstResponder` callback and `isSearchFieldActive` static property remain unchanged and handle focus state for other purposes (preventing panel close on hotkey release).

#### Text Alignment

The search field's `.alignment = .center` property (line 130) controls typed text centering but does not affect the placeholder when using `placeholderAttributedString`. Both must be set independently.

## Future Modifications

To change placeholder color: modify the hex value in the `.foregroundColor` attribute (line 98).

To change placeholder text: modify the string parameter in the `NSAttributedString` initializer (line 103).

To change alignment: update both `paragraphStyle.alignment` (line 96) and `searchField?.alignment` (line 130).
