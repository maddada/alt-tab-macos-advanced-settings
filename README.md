# AltTab

[![Screenshot](docs/public/demo/frontpage.jpg)](docs/public/demo/frontpage.jpg)

**AltTab** brings the power of Windows alt-tab to macOS

Now with more advanced features which were removed from the original project.

[Find out more on the official website](https://alt-tab-macos.netlify.app/)

## Features added compared to the original project:
- Ability to set the max width and height with a slider
- Ability to offset the dialog vertically with a slider
- Ability to show the preview window when using the Titles style

Will try to keep it in sync with the original project.

## If you have access to Claude 4.5 Sonnet or a newer model you can just write this prompt to build the project and make the app work:

    ```
    I want to run this project in dev mode so I can add features to it.
    Reference the README.md file and the Contributing.md files to achieve this.
    ```

## Building the Project

### Prerequisites
- Xcode (with macOS SDK)
- CocoaPods (already set up in this project)

### Setup for Development

1. **Set up local code signing** (avoids re-checking Security & Privacy permissions on every build):
   ```bash
   scripts/codesign/setup_local.sh
   ```

   It will ask you for the password to the computer to run the script, select allow always and write the password then accept.

2. **Install npm dependencies** (optional, for pre-commit hooks):
   ```bash
   npm install
   ```

3. **Open the project in Xcode**:
   ```bash
   open alt-tab-macos.xcworkspace
   ```

4. **Build and run**:
   - Select the **Debug** scheme in Xcode
   - Press `Cmd+R` to build and run
   - The built app is located at: `~/Library/Developer/Xcode/DerivedData/alt-tab-macos-*/Build/Products/Debug/AltTab.app`

### Building from Command Line

```bash
xcodebuild -workspace alt-tab-macos.xcworkspace -scheme Debug -configuration Debug build
```

For more detailed information about contributing, see [docs/Contributing.md](docs/Contributing.md).
