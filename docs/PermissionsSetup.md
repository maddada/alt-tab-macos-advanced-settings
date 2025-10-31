# Fixing macOS Permissions Reset on Every Build

## The Problem

When building the app during development, you may notice that macOS forgets the permissions you've granted (Accessibility and Screen Recording) every time you rebuild. This means you have to:
- Go to System Settings → Privacy & Security
- Remove the app from Accessibility permissions
- Remove the app from Screen Recording permissions
- Add them back again

This happens because by default, the app is signed with **ad-hoc signing**, which generates a new signature on every build. macOS uses this signature to identify apps, so each build appears as a completely different app.

## The Solution

Use a stable self-signed certificate for code signing. This allows macOS to recognize your app as the same application across builds, preserving all granted permissions.

## Step-by-Step Setup

### 1. Run the Codesign Setup Script

Open Terminal in the project directory and run:

```bash
scripts/codesign/setup_local.sh
```

This script will:
- Generate a self-signed certificate
- Import it into your macOS keychain
- Configure it as a trusted certificate for code signing

The script completes in a few seconds and you should see output indicating successful certificate import.

### 2. Build Your App

Build the app using either:

**Option A: Xcode**
1. Open `alt-tab-macos.xcworkspace` in Xcode
2. Select either the **Debug** or **alt-tab-macos** scheme (both work!)
3. Press `Cmd+R` to build and run

**Option B: Command Line**
```bash
# Debug scheme
xcodebuild -workspace alt-tab-macos.xcworkspace -scheme Debug build

# or Release scheme (alt-tab-macos)
xcodebuild -workspace alt-tab-macos.xcworkspace -scheme alt-tab-macos build
```

### 3. Grant Permissions (One-Time Setup)

The first time you run the newly signed app:

1. **Remove old permissions** (if you previously granted them):
   - Open System Settings → Privacy & Security → Accessibility
   - Remove the old AltTab app
   - Open System Settings → Privacy & Security → Screen Recording
   - Remove the old AltTab app

2. **Run your app** - it will request permissions

3. **Grant the permissions** when prompted

### 4. Done!

From now on, all future builds will maintain these permissions. You won't need to remove and re-add the app anymore.

## How It Works

The setup script creates a **stable self-signed certificate** named "Local Self-Signed" that remains the same across all your builds. Both Debug and Release configurations are configured to use this certificate. macOS uses this certificate to identify your app, so it recognizes each new build as the same application and preserves all granted permissions.

## What Configurations Are Supported?

Both build configurations now use the stable certificate:
- ✅ **Debug scheme** - Uses the "Local Self-Signed" certificate
- ✅ **alt-tab-macos scheme** (Release) - Uses the "Local Self-Signed" certificate

You can switch between schemes without losing permissions!

## Troubleshooting

**If permissions still reset after following these steps:**

1. Verify the certificate was imported:
   ```bash
   security find-identity -v -p codesigning
   ```
   You should see exactly **one** certificate named **"Local Self-Signed"** in the list.

2. If you have multiple certificates, clean them up and re-run the setup script:
   ```bash
   # Delete old certificates
   security delete-certificate -c "Local Self-Signed"

   # Re-run setup
   scripts/codesign/setup_local.sh
   ```

3. Check that the app is actually signed:
   ```bash
   # For Debug builds
   codesign -dv ~/Library/Developer/Xcode/DerivedData/alt-tab-macos-*/Build/Products/Debug/AltTab.app

   # For Release builds
   codesign -dv ~/Library/Developer/Xcode/DerivedData/alt-tab-macos-*/Build/Products/Release/AltTab.app
   ```
   This should show the "Local Self-Signed" certificate information.

4. Clean derived data if issues persist:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/alt-tab-macos-*
   ```
   Then rebuild the app.

**If you see keychain access prompts:**
- Click "Always Allow" to avoid repeated prompts during builds
