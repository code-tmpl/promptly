# Tech Stack Decisions

## Language & Framework: Swift 6 + SwiftUI + AppKit

**Why:**
- Native macOS APIs are non-negotiable for this app
- Notch-area window positioning requires precise NSScreen geometry
- Screen-share exclusion (`NSWindow.SharingType.none`) is AppKit-only
- Voice detection via Speech framework / AVAudioEngine — native only
- Window level management (`.floating`, `.statusBar`) — AppKit
- SwiftUI for the editor/settings UI — modern, fast to build
- AppKit for the prompter window — full control over positioning, transparency, mouse tracking

**Rejected alternatives:**
- Electron: Can't do notch integration, screen-share exclusion, or proper window levels
- Tauri: Same limitations as Electron for macOS-specific features
- React Native macOS: Immature, can't access the low-level window APIs needed

## Build System: Swift Package Manager + Xcode

**Why:**
- Standard for macOS apps
- No external dependency manager needed
- Xcode for signing, notarization pipeline

## Audio: AVAudioEngine + Speech Framework

**Why:**
- AVAudioEngine for real-time audio level monitoring (voice feedback visualization)
- Speech framework (SFSpeechRecognizer) for voice-activated scrolling
- On-device recognition — no network calls, privacy preserved
- Alternative: just use audio level thresholds (simpler, no Speech framework needed)
  - Detect speech vs silence based on decibel levels
  - More reliable, less overhead than full speech recognition
  - **Decision: Use audio level detection for v1, Speech framework for future**

## Data Storage: Local JSON/Plist + FileManager

**Why:**
- Scripts stored as local files (privacy-first, no cloud)
- UserDefaults for settings (speed, text size, color, mic sensitivity)
- No database needed — it's a document-based app essentially
- Consider NSDocument architecture for proper file management

## Window Management: NSPanel (AppKit)

**Why:**
- `NSPanel` with `.nonactivatingPanel` style — doesn't steal focus from other apps
- `window.level = .floating` — stays on top
- `window.sharingType = .none` — invisible to screen share/screenshots
- `window.isMovableByWindowBackground = true` — draggable
- `window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` — works in all Spaces, over full-screen apps
- Mouse tracking for hover-to-pause via `NSTrackingArea`

## Notch Integration: NSScreen Geometry

**Why:**
- Get the notch area from `NSScreen.main?.auxiliaryTopLeftArea` / `auxiliaryTopRightArea`
- Or calculate from `safeAreaInsets` on macOS 14+
- Position the prompter window straddling the notch, text flowing on both sides
- Need to handle non-notch Macs gracefully (fall back to top-center positioning)

## Testing: XCTest + XCUITest

**Why:**
- XCTest for unit tests (scrolling logic, speed calculations, audio threshold detection)
- XCUITest for UI tests (window positioning, text display, controls)
- Can be run from command line via `xcodebuild test`

## Architecture: MVVM

**Why:**
- SwiftUI naturally fits MVVM
- Clean separation: Models (Script, Settings), ViewModels (PrompterVM, EditorVM), Views
- Easy to test ViewModels independently

## Project Structure
```
Moody/
├── Moody.xcodeproj
├── Moody/
│   ├── App/
│   │   └── MoodyApp.swift
│   ├── Models/
│   │   ├── Script.swift
│   │   └── AppSettings.swift
│   ├── ViewModels/
│   │   ├── PrompterViewModel.swift
│   │   ├── EditorViewModel.swift
│   │   └── AudioMonitor.swift
│   ├── Views/
│   │   ├── EditorView.swift
│   │   ├── SettingsView.swift
│   │   └── PrompterOverlayView.swift
│   ├── Windows/
│   │   ├── PrompterWindowController.swift
│   │   ├── PrompterPanel.swift
│   │   └── NotchPositionCalculator.swift
│   ├── Audio/
│   │   ├── AudioLevelDetector.swift
│   │   └── VoiceScrollController.swift
│   ├── Utilities/
│   │   └── KeyboardShortcutManager.swift
│   └── Resources/
│       └── Assets.xcassets
├── MoodyTests/
│   ├── AudioLevelDetectorTests.swift
│   ├── VoiceScrollControllerTests.swift
│   ├── NotchPositionCalculatorTests.swift
│   ├── PrompterViewModelTests.swift
│   └── ScriptModelTests.swift
├── MoodyUITests/
│   ├── PrompterWindowTests.swift
│   └── EditorFlowTests.swift
├── CLAUDE.md
└── README.md
```
