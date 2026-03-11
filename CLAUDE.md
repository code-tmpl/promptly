# CLAUDE.md — Promptly (Moody Clone)

## Project Overview
A native macOS teleprompter app that positions scrolling script text near the MacBook camera (notch area) for natural eye contact. Voice-activated scrolling, screen-share invisible, floating window support.

## Tech Stack
- **Language:** Swift 6
- **UI:** SwiftUI (editor, settings) + AppKit (prompter window)
- **Audio:** AVAudioEngine for voice detection
- **Architecture:** MVVM
- **Min Target:** macOS 14.7 (Sonoma)
- **Architectures:** Intel + Apple Silicon (Universal Binary)

## Key Technical Decisions
- `NSPanel` with `sharingType = .none` for screen-share invisibility
- Audio level threshold detection (not Speech framework) for v1 voice scrolling
- DisplayLink-based smooth scrolling at 60fps
- Scripts stored as JSON in `~/Library/Application Support/Promptly/`
- Settings in UserDefaults

## Project Structure
```
Promptly/
├── Promptly/
│   ├── App/MoodyApp.swift           — App entry point
│   ├── Models/                       — Data models (Script, AppSettings)
│   ├── ViewModels/                   — MVVM view models
│   ├── Views/                        — SwiftUI views (Editor, Settings)
│   ├── Windows/                      — AppKit window controllers
│   ├── Audio/                        — Audio detection & voice scroll
│   └── Utilities/                    — Keyboard shortcuts, helpers
├── PromptlyTests/                    — Unit tests
├── PromptlyUITests/                  — UI tests
└── docs/                             — PRD, architecture, research
```

## Build & Test
```bash
# Build
xcodebuild -project Promptly.xcodeproj -scheme Promptly -configuration Debug build

# Test
xcodebuild -project Promptly.xcodeproj -scheme Promptly test

# Or with swift package if SPM-based:
swift build
swift test
```

## Branch Strategy
- `main` — protected, PRs only
- `feature/*` — feature branches per task
- `fix/*` — bugfix branches

## Code Style
- Swift 6 strict concurrency
- `@Observable` macro for view models (macOS 14+)
- Explicit access control (public/internal/private)
- Documentation comments for public API
- No force unwraps except in tests

## Important APIs
- `NSPanel` — prompter window (borderless, non-activating)
- `NSWindow.SharingType.none` — hide from screen capture
- `NSWindow.Level.statusBar` — above menu bar
- `NSWindow.CollectionBehavior` — join all spaces, full-screen auxiliary
- `NSTrackingArea` — hover detection for pause
- `AVAudioEngine` — microphone input monitoring
- `NSScreen.safeAreaInsets` — notch detection
