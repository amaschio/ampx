# Building AmpX

This guide covers how to build and run the AmpX application.

## Prerequisites

- macOS 26.5 (Tahoe) or later
- Xcode 26 or later
- Command Line Tools installed

### Installing Command Line Tools

If you haven't already:

```bash
xcode-select --install
```

## Building with Xcode (Recommended)

1. **Open the Project**
   ```bash
   cd /path/to/ampx
   open AmpX.xcodeproj
   ```

2. **Select the Scheme**
   - In Xcode, select the "AmpX" scheme from the scheme dropdown
   - Select "My Mac" as the destination

3. **Build**
   - Press `⌘B` to build
   - Or select **Product → Build**

4. **Run**
   - Press `⌘R` to build and run
   - Or select **Product → Run**

## Building from Command Line

### Build Debug Version

```bash
cd /path/to/ampx
xcodebuild -project AmpX.xcodeproj \
           -scheme AmpX \
           -configuration Debug \
           build
```

### Build Release Version

```bash
xcodebuild -project AmpX.xcodeproj \
           -scheme AmpX \
           -configuration Release \
           build
```

### Run the Built Application

Debug build:
```bash
open ~/Library/Developer/Xcode/DerivedData/AmpX-*/Build/Products/Debug/AmpX.app
```

Release build:
```bash
open ~/Library/Developer/Xcode/DerivedData/AmpX-*/Build/Products/Release/AmpX.app
```

## Using Swift Package Manager (Alternative)

The project also includes a `Package.swift` file for SPM support:

```bash
swift build
swift run
```

Note: SPM builds won't include the asset catalog and proper app bundling. Use Xcode for a complete build.

## Clean Build

If you encounter issues, try a clean build:

### In Xcode
1. Press `⌘⇧K` or select **Product → Clean Build Folder**
2. Build again with `⌘B`

### Command Line
```bash
xcodebuild -project AmpX.xcodeproj \
           -scheme AmpX \
           -configuration Debug \
           clean build
```

## Build Configurations

### Debug Configuration
- Optimization level: None (-Onone)
- Debug symbols: Enabled
- Assertions: Enabled
- Best for development and debugging

### Release Configuration
- Optimization level: Whole Module (-O)
- Debug symbols: Included (dSYM)
- Assertions: Disabled
- Best for distribution

## Code Signing

The project uses ad-hoc signing by default (sign-to-run-locally). For distribution:

1. **Select Your Team**
   - Open the project in Xcode
   - Select the "AmpX" target
   - Go to "Signing & Capabilities"
   - Select your development team

2. **Configure Signing**
   - Signing Certificate: Apple Development
   - Or for distribution: Developer ID Application

3. **Entitlements**
   The app uses these entitlements:
   - `com.apple.security.app-sandbox`: App Sandbox
   - `com.apple.security.files.user-selected.read-only`: User-selected file access
   - `com.apple.security.assets.music.read-only`: Music library access

## Troubleshooting Build Issues

### "No such module 'SwiftUI'"
- Ensure you're building for macOS 26.5+
- Check your Xcode version (26+)

### "Command CodeSign failed"
- Set signing to "Sign to Run Locally"
- Or configure your developer account

### "Build input file cannot be found"
- Clean build folder (`⌘⇧K`)
- Quit Xcode
- Delete DerivedData:
  ```bash
  rm -rf ~/Library/Developer/Xcode/DerivedData/AmpX-*
  ```
- Reopen and rebuild

### "Sandbox: deny file-read-data"
- This is expected for files outside user selection
- The app will prompt for file access when needed

## Build Output Location

Default build output locations:

- **Debug**: `~/Library/Developer/Xcode/DerivedData/AmpX-*/Build/Products/Debug/`
- **Release**: `~/Library/Developer/Xcode/DerivedData/AmpX-*/Build/Products/Release/`

### Archiving for Distribution

1. In Xcode, select **Product → Archive**
2. When complete, the Organizer window opens
3. Select your archive
4. Click **Distribute App**
5. Follow the distribution wizard

## Development Tips

### Xcode Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘B` | Build |
| `⌘R` | Run |
| `⌘.` | Stop |
| `⌘⇧K` | Clean Build Folder |
| `⌘⇧O` | Open Quickly |
| `⌘/` | Toggle Comment |
| `⌘⌥[` | Move Line Up |
| `⌘⌥]` | Move Line Down |

### Live Preview

SwiftUI views support live preview in Xcode:

1. Open any view file (e.g., `MainPlayerView.swift`)
2. Press `⌘⌥↩` to show/hide canvas
3. Click "Resume" in the canvas to see live preview
4. Edit code and see changes in real-time

### Debugging

1. Set breakpoints by clicking the gutter
2. Run in debug mode (`⌘R`)
3. Use `po` in the console to print objects
4. View hierarchy debugger: **Debug → View Debugging → Capture View Hierarchy**

## Performance Profiling

### Using Instruments

1. Select **Product → Profile** (`⌘I`)
2. Choose an instrument:
   - **Time Profiler**: CPU usage
   - **Allocations**: Memory usage
   - **Leaks**: Memory leaks
   - **Audio**: Audio performance
3. Record and analyze

### SwiftUI Performance

- Use `@State` and `@StateObject` appropriately
- Prefer `LazyVStack` over `VStack` for long lists
- Profile with the SwiftUI Profiler in Instruments

## Continuous Integration

There is **no** GitHub Actions (or other) CI workflow in this repo — local builds and
`./scripts/run-tests.sh` are the intended verification path. If you add automation later,
prefer that script over raw `xcodebuild test` so fixtures are generated first.
## Next Steps

After building successfully:
1. Read [USAGE.md](USAGE.md) for usage instructions
2. Check [README.md](README.md) for project overview
3. Explore the source code in the `Sources/` directory
4. Consider contributing improvements!

## Getting Help

If you encounter build issues:
1. Check this guide's troubleshooting section
2. Verify your Xcode and macOS versions
3. Try a clean build
4. Check the project's issue tracker
5. Review Xcode's build logs for specific errors

