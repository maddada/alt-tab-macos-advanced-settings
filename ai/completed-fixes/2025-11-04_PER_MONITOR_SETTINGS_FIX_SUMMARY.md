# Per-Monitor Resolution Settings - Bug Fix Summary

## Problem
When switching appearance style (Thumbnails ↔ App Icons ↔ Titles) on a per-monitor basis, changing to Thumbnails would not apply. The setting would save in the UI but not in the actual appearance. This only affected switching TO Thumbnails; switching TO other styles worked fine.

## Root Cause
The `controlWasChanged` function in `LabelAndControl.swift` was comparing the new preference value against the **base key** (`appearanceStyle`) instead of the **resolution-specific key** (`appearanceStyle_3840x2160`).

When the user clicked Thumbnails (value = 0), the code compared:
- `oldValue` = base key value = `"0"` (from a previous operation)
- `newValue` = `"0"` (the user's click)
- Since they matched, the function returned early without saving!

Meanwhile, the resolution-specific key had `"2"` (Titles), so the app still thought it was on Titles.

## Changes Made

### ✅ NECESSARY FIX (Apply This)

**File: `src/ui/preferences-window/LabelAndControl.swift`** (lines 304-323)

**What to change:**
```swift
// OLD CODE (BROKEN):
static func controlWasChanged(_ senderControl: NSControl, _ controlId: String?) {
    if let newValue = LabelAndControl.getControlValue(senderControl, controlId) {
        let identifier = senderControl.identifier!.rawValue
        if let oldValue = UserDefaults.standard.string(forKey: identifier), newValue == oldValue {
            return
        }
        // ... rest of function
    }
}

// NEW CODE (FIXED):
static func controlWasChanged(_ senderControl: NSControl, _ controlId: String?) {
    if let newValue = LabelAndControl.getControlValue(senderControl, controlId) {
        let identifier = senderControl.identifier!.rawValue

        // For resolution-sensitive keys, check the resolution-specific key, not the base key
        let resolutionSensitiveKeys = ["windowMaxWidthPercentage", "windowMaxHeightPercentage", "windowVerticalOffset", "appearanceStyle", "appearanceSize"]
        let keyToCheck = resolutionSensitiveKeys.contains(identifier) ?
            "\(identifier)_\(NSScreen.preferred.resolutionString())" : identifier

        if let oldValue = UserDefaults.standard.string(forKey: keyToCheck), newValue == oldValue {
            return
        }
        // ... rest of function
    }
}
```

**Why this fixes it:**
- Now when you click Thumbnails, it checks `appearanceStyle_3840x2160` (which has "2") against "0"
- They don't match, so the save proceeds
- The value is correctly saved to the resolution-specific key

---

### ❌ UNNECESSARY CHANGES (Can Remove)

#### 1. Debug Statements in `Preferences.swift` (lines 182-184, 193)
These are debug print statements that should be removed:
```swift
if isResolutionSensitive {
    print("DEBUG Preferences.set: key=\(key), value=\(value), finalKey=\(finalKey)")
}
...
print("DEBUG: Deleting base key: \(key)")
```

#### 2. All Debug Statements in `getResolutionSpecificMacroPref` (lines 272, 276, 281, 283)
These debug prints can be removed:
```swift
print("DEBUG getResolutionSpecificMacroPref: baseKey=\(baseKey), resolutionKey=\(resolutionKey), resolutionKeyValue=\(resolutionKeyValue ?? "nil")")
print("DEBUG: Reading from resolution key, got index=\(result.index)")
print("DEBUG: Resolution key not found, reading from base key")
print("DEBUG: Copying base key value to resolution key: \(value.indexAsString)")
```

#### 3. All Debug Statements in `LabelAndControl.swift` `controlWasChanged` (lines 307, 309, 315, 318, 312)
These debug prints can be removed:
```swift
print("DEBUG controlWasChanged: identifier=\(identifier), newValue=\(newValue)")
print("DEBUG: Value unchanged, returning early. oldValue=\(oldValue), newValue=\(newValue)")
print("DEBUG: Value changed or no old value found. Calling Preferences.set()")
```

#### 4. Logic Changes That Seemed Necessary But Weren't Critical
The following changes in `Preferences.swift` were attempts to fix the problem but weren't the root cause:
- Deleting the base key when saving to resolution-specific key (lines 192-195)
- Directly setting resolution keys in `getResolutionSpecificInt` and `getResolutionSpecificMacroPref` without using `Preferences.set()` (lines 260-263, 277-280)

These changes don't hurt, but they're not necessary to fix the bug. The real fix is just in `LabelAndControl.swift`.

---

## Summary of What Actually Works

The ONLY necessary fix is in **`LabelAndControl.swift`** line 311-312:

Change the key comparison to use the resolution-specific key instead of the base key:
```swift
let keyToCheck = resolutionSensitiveKeys.contains(identifier) ?
    "\(identifier)_\(NSScreen.preferred.resolutionString())" : identifier
```

Then use `keyToCheck` instead of `identifier` in the comparison on line 314.

All other changes can be reverted.

---

## Testing
After applying the fix, you should be able to:
1. Be on Titles appearance
2. Click Thumbnails → it applies immediately
3. Click App Icons → it applies immediately
4. Click Titles → it applies immediately
5. All switching should work correctly for all three styles
