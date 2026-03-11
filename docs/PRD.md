# Product Requirements Document: Moody (Clone)

## Overview
A native macOS teleprompter app that positions scrolling script text near the MacBook camera (notch area) for natural eye contact during video calls, recordings, and presentations. Voice-activated scrolling, screen-share invisible, floating window support.

## App Name: Promptly (working title)
To differentiate from the original.

---

## User Stories

### US-1: Script Creation
**As a** content creator  
**I want to** write or paste my script in a built-in editor  
**So that** I can prepare my talking points without leaving the app  

**Acceptance Criteria:**
- [ ] Rich text editor with basic formatting (bold, italic, headings for section markers)
- [ ] Paste plain text from clipboard
- [ ] Auto-save scripts locally
- [ ] Multiple scripts management (list, create, delete, rename)
- [ ] Script word/character count

### US-2: Notch-Mode Prompting
**As a** presenter using a notch-equipped MacBook  
**I want to** see my script displayed in the notch area  
**So that** my eyes stay naturally aligned with the camera  

**Acceptance Criteria:**
- [ ] Text appears straddling the notch (left and right sides)
- [ ] Text scrolls vertically at configurable speed
- [ ] Font size adjustable (minimum readable at arm's length)
- [ ] Text color and background configurable
- [ ] Smooth anti-aliased text rendering
- [ ] Graceful fallback on non-notch Macs (top-center positioning)

### US-3: Voice-Activated Scrolling
**As a** presenter  
**I want to** have the script scroll when I speak and pause when I stop  
**So that** I can present naturally without manual controls  

**Acceptance Criteria:**
- [ ] Microphone permission requested on first use
- [ ] Speech detection via audio level thresholds
- [ ] Script scrolls while speech detected
- [ ] Script pauses within 0.5s of silence
- [ ] Adjustable microphone sensitivity (settings)
- [ ] Visual voice level indicator
- [ ] Works with built-in and external microphones

### US-4: Manual Speed Control
**As a** presenter  
**I want to** adjust scrolling speed during my presentation  
**So that** I can match my natural speaking pace  

**Acceptance Criteria:**
- [ ] Keyboard shortcuts for speed up / slow down
- [ ] Default speed configurable in settings
- [ ] Speed indicator visible in prompter
- [ ] Trackpad/mouse scroll for manual navigation through script

### US-5: Floating Window Mode
**As a** presenter with an external monitor or non-notch Mac  
**I want to** place the prompter anywhere on my screen  
**So that** I can position it optimally for my setup  

**Acceptance Criteria:**
- [ ] Toggle between notch mode and floating mode
- [ ] Floating window freely resizable
- [ ] Floating window draggable to any position
- [ ] Position/size remembered between sessions
- [ ] Same scrolling features as notch mode

### US-6: Screen-Share Invisibility
**As a** remote worker presenting on a video call  
**I want to** the prompter to be invisible during screen sharing  
**So that** my audience doesn't see I'm reading from a script  

**Acceptance Criteria:**
- [ ] Prompter window excluded from screen capture
- [ ] Invisible in screenshots
- [ ] Invisible in screen recordings
- [ ] Invisible when sharing screen via Zoom/Teams/Meet/etc.
- [ ] Uses `NSWindow.SharingType.none`

### US-7: Pause/Resume Controls
**As a** presenter  
**I want to** pause and resume scrolling easily  
**So that** I can take breaks or handle interruptions  

**Acceptance Criteria:**
- [ ] Hover over prompter → instant pause
- [ ] Mouse leaves prompter → auto resume
- [ ] Click pause button for persistent pause
- [ ] Keyboard shortcut for pause/resume
- [ ] Visual indicator showing paused state

### US-8: Countdown Timer
**As a** presenter about to start recording  
**I want to** have a countdown before the prompter starts  
**So that** I can get ready and composed  

**Acceptance Criteria:**
- [ ] Configurable countdown (3, 5, 10 seconds)
- [ ] Visual countdown display
- [ ] Prompter begins scrolling after countdown

### US-9: Settings & Preferences
**As a** user  
**I want to** customize the prompter appearance and behavior  
**So that** it works optimally for my setup  

**Acceptance Criteria:**
- [ ] Text size adjustment (slider)
- [ ] Text color picker
- [ ] Background opacity/color
- [ ] Default scrolling speed
- [ ] Microphone sensitivity
- [ ] Microphone source selection
- [ ] Countdown duration
- [ ] Keyboard shortcut customization
- [ ] Settings persisted via UserDefaults

### US-10: Multi-Space & Full-Screen Support
**As a** user who uses multiple Spaces or full-screen apps  
**I want to** the prompter to be visible everywhere  
**So that** it works regardless of my desktop layout  

**Acceptance Criteria:**
- [ ] Prompter visible across all Spaces
- [ ] Prompter visible over full-screen apps
- [ ] Prompter visible on the screen it was launched from

---

## Non-Functional Requirements

### Performance
- Audio processing latency < 100ms
- Scroll animation at 60fps
- App launch < 2 seconds
- Memory footprint < 100MB

### Privacy
- All data stored locally (no network calls)
- Microphone used only for voice detection (no recording/storage)
- No analytics or telemetry

### Compatibility
- macOS 14.7+ (Sonoma and later)
- Intel and Apple Silicon
- Notch and non-notch Macs

### Accessibility
- VoiceOver support for editor
- Keyboard-only navigation for all features
- High contrast mode support

---

## Out of Scope (v1)
- Text size per-display scaling (future update)
- Remote control from iPhone
- Script import from files (just paste for v1)
- Cloud sync
- Windows/Linux versions
- App Store distribution (direct download for now)

---

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Start/Stop Prompter | ⌘⏎ |
| Pause/Resume | Space |
| Speed Up | ⌘↑ |
| Speed Down | ⌘↓ |
| Toggle Notch/Float | ⌘T |
| Open Settings | ⌘, |
| New Script | ⌘N |
