# Recent Changes

## AmpX rename

- Product identity is now **AmpX** (*Modern audio player. Classic spirit.*)
- Bundle ID `com.ampx.macos` (clean break — no prefs/playlist migration from `com.ampx.macos`)
- Types, Xcode project, scripts, and docs renamed mechanically (`Winamp*` → `AmpX*`)
- ENTHEA visualizer name unchanged; Classic Winamp 2.x / Webamp geometry attribution retained

---


## Fixes Applied

### ✅ Window Sizing Fixed
- Window now sizes exactly to content (275px width)
- No black space around left/right sides
- Added `.fixedSize()` to prevent extra space
- Window auto-sizes to content using `setContentSize()`

### ✅ Playlist Toggle Fixed  
- PL button now properly shows/hides the playlist window
- Fixed button binding order (was reversed)
- Playlist window fixed at 275px width × 250px height

### ✅ Frameless Window
- Removed macOS window chrome completely
- No red/yellow/green buttons visible
- Custom Winamp-style window controls work
- Draggable blue title bar

### 🎨 Sprite System Created
- Added `AmpXSkinSprites.swift` for using actual graphics
- Imported your Winamp skin image as `AmpXSkin` asset
- Defined sprite coordinates for all UI elements:
  - Buttons (Previous, Play, Pause, Stop, Next, Eject)
  - Toggle buttons (EQ, PL, Shuffle, Repeat) 
  - Sliders (Position, Volume, Balance)
  - LED numbers for time display

## Next Steps

To fully use the actual Winamp graphics, we need to:

1. **Extract button sprites** from the skin image at specific coordinates
2. **Replace SwiftUI buttons** with bitmap images
3. **Verify sprite coordinates** match your skin layout
4. **Add pressed/hover states** for each button

The sprite system is ready - we just need to integrate it with the button views.

## How to Test

1. Build: `xcodebuild -project AmpX.xcodeproj -scheme AmpX build`
2. Run: `open ~/Library/Developer/Xcode/DerivedData/Winamp-*/Build/Products/Debug/Winamp.app`
3. Test PL button to toggle playlist
4. Verify no black space around window edges
5. Check that window is exactly 275px wide

## Known Issues

- Still using SwiftUI-generated buttons (not bitmap sprites yet)
- Need to map exact sprite coordinates from your skin image
- Button graphics need to be swapped in next iteration

