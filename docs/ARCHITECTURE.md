# Architecture

## Overview
MVVM architecture with SwiftUI for content views and AppKit for window management.

```
┌─────────────────────────────────────────────┐
│                  MoodyApp                    │
│              (SwiftUI App)                   │
├──────────────┬──────────────────────────────┤
│  Editor UI   │     Prompter System          │
│  (SwiftUI)   │     (AppKit)                 │
│              │                              │
│ EditorView   │  PrompterWindowController    │
│ ScriptList   │  PrompterPanel (NSPanel)     │
│ SettingsView │  NotchPositionCalculator     │
│              │  PrompterContentView(SwiftUI)│
├──────────────┴──────────────────────────────┤
│              ViewModels                      │
│  EditorViewModel  PrompterViewModel          │
│  ScriptStore      SettingsManager            │
├─────────────────────────────────────────────┤
│              Services                        │
│  AudioLevelDetector   VoiceScrollController  │
│  KeyboardShortcutMgr  ScriptPersistence      │
├─────────────────────────────────────────────┤
│              Models                          │
│  Script   AppSettings   PrompterState        │
└─────────────────────────────────────────────┘
```

## Component Details

### PrompterPanel (NSPanel subclass)
The core window that displays the teleprompter text.

**Notch Mode:**
- Positioned using `NSScreen.main?.frame` and safe area calculations
- Window spans the top of the screen, text flows around notch
- Window level: `.statusBar + 1` (above menu bar)
- `sharingType = .none` (invisible to screen capture)
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`
- `isOpaque = false`, `backgroundColor = .clear`
- `styleMask = [.borderless, .nonactivatingPanel]`

**Floating Mode:**
- Standard floating panel
- Window level: `.floating`
- Resizable via drag handles
- Position/size persisted

### AudioLevelDetector
Monitors microphone input for speech detection.

```swift
class AudioLevelDetector: ObservableObject {
    @Published var isSpeaking: Bool = false
    @Published var audioLevel: Float = 0.0
    
    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?
    private var threshold: Float = -30.0 // dB, configurable
    
    func start()   // Begin monitoring
    func stop()    // Stop monitoring
    func updateThreshold(_ dB: Float)
}
```

- Uses `AVAudioEngine` with an input node tap
- Calculates RMS audio level from buffer
- Converts to decibels
- Compares against configurable threshold
- Publishes `isSpeaking` with debounce (0.3s silence → false)

### VoiceScrollController
Bridges audio detection to scroll behavior.

```swift
class VoiceScrollController: ObservableObject {
    @Published var scrollOffset: CGFloat = 0
    @Published var isScrolling: Bool = false
    
    var speed: Double = 1.0
    var isPaused: Bool = false
    
    func bind(to audioDetector: AudioLevelDetector)
    func manualScroll(delta: CGFloat)
    func adjustSpeed(by: Double)
}
```

- Observes `AudioLevelDetector.isSpeaking`
- When speaking: advances `scrollOffset` at configured speed
- When silent: stops advancing
- DisplayLink-based animation for smooth 60fps scrolling

### NotchPositionCalculator
Calculates window frame for notch-mode positioning.

```swift
struct NotchPositionCalculator {
    static func calculateFrame(for screen: NSScreen) -> NSRect
    static func hasNotch(_ screen: NSScreen) -> Bool
    static func notchRect(for screen: NSScreen) -> NSRect?
}
```

- Detects notch presence via `screen.safeAreaInsets.top > 0`
- Calculates text regions on left and right of notch
- Returns appropriate window frame

### ScriptStore
Manages script persistence.

```swift
class ScriptStore: ObservableObject {
    @Published var scripts: [Script] = []
    @Published var currentScript: Script?
    
    func save(_ script: Script)
    func delete(_ script: Script)
    func load() -> [Script]
}
```

- Stores scripts as JSON files in `~/Library/Application Support/Moody/`
- Auto-saves on edit (debounced 1s)

## Data Models

```swift
struct Script: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
}

struct AppSettings: Codable {
    var fontSize: CGFloat = 24
    var textColor: String = "#FFFFFF"  // hex
    var backgroundColor: String = "#000000"
    var backgroundOpacity: Double = 0.8
    var scrollSpeed: Double = 1.0
    var micSensitivity: Float = -30.0  // dB threshold
    var countdownSeconds: Int = 3
    var preferredMode: PrompterMode = .notch
}

enum PrompterMode: String, Codable {
    case notch
    case floating
}

struct PrompterState {
    var isActive: Bool = false
    var isPaused: Bool = false
    var scrollOffset: CGFloat = 0
    var currentSpeed: Double = 1.0
}
```

## Key Flows

### Start Prompting
1. User selects script → presses ⌘⏎
2. PrompterViewModel creates PrompterWindowController
3. Window positioned (notch or floating based on settings)
4. Countdown displayed (3, 5, or 10s)
5. AudioLevelDetector starts monitoring mic
6. VoiceScrollController begins driving scroll
7. Text scrolls when user speaks

### Pause on Hover
1. NSTrackingArea detects mouse enter on PrompterPanel
2. VoiceScrollController.isPaused = true
3. Visual "paused" indicator shown
4. Mouse exit → isPaused = false → scrolling resumes

### Screen-Share Exclusion
1. PrompterPanel.sharingType = .none (set on init)
2. macOS automatically excludes window from all capture APIs
3. No additional code needed — it's a system-level feature
