# Promptly — QA Test Report

**Tester:** Nipun Sharma
**Date:** 2026-03-12
**Build:** Debug (commit f38cf46 + local fixes)
**Environment:** macOS 26.3.1 (25D2128), MacBook Pro M1 Max, 64 GB RAM
**Xcode:** 16+ (ARM-64 native)

---

## Build & Setup

| Step | Result |
|------|--------|
| Clean slate (rm app data + defaults) | Pass |
| `xcodebuild` Debug build | Pass |
| Unit tests (184 total) | **184/184 passed** |
| App launch | Pass |

---

## Test 1: First Launch & Permissions

| # | Step | Expected | Result | Notes |
|---|------|----------|--------|-------|
| 1.1 | Launch app for first time | App opens, editor visible | **Pass** | |
| 1.2 | Microphone permission dialog | macOS prompts for mic access | **Pass** | |
| 1.3 | Grant mic permission | Dialog dismisses, no crash | **Pass** | |
| 1.4 | Welcome script in editor | Sample text explaining usage | **Pass** | |

---

## Test 2: Script Management

| # | Step | Expected | Result | Notes |
|---|------|----------|--------|-------|
| 2.1 | Click "+" to create new script | New script in sidebar | **Pass** | |
| 2.2 | Type a title | Title updates in sidebar | **Pass** | |
| 2.3 | Paste long speech text (~8 paragraphs) | Text appears without lag | **Pass** | |
| 2.4 | Wait 3 seconds after paste | No lag or beach ball | **Pass** | |
| 2.5 | Quit app (⌘Q) | Clean exit | **Pass** | |
| 2.6 | Relaunch app | Script still present with full content | **Pass** | |
| 2.7 | Verify pasted text is complete | All paragraphs present | **Pass** | |

### UX Observations (Test 2)

- **Save indicator animation janky:** The spinning circle briefly appears full-screen before animating to its correct position. Functional but visually jarring.
- **Seconds display next to word count:** Redundant — word count alone is sufficient. Consider removing the seconds estimate.

---

## Test 3: Prompter — Notch Mode

| # | Step | Expected | Result | Notes |
|---|------|----------|--------|-------|
| 3.1 | Press ⌘⏎ to start prompter | Countdown → prompter starts | **Fail (Crash) → Fixed → Pass** | See crash details below |
| 3.2 | Dark overlay near camera/notch | Large white text on dark background | **Fail** | Window only ~80px tall, shows 1 line of text |
| 3.3 | Text scrolling upward | Steady scroll | **Fail** | No auto-scroll on start; text is static |
| 3.4 | Space pauses/resumes scrolling | Toggle pause | **Pass** | Space bar works correctly |
| 3.5 | ⌘↑ increases speed | Speed increases | **Fail** | Key events not reaching prompter; captured by app behind it |
| 3.6 | ⌘↓ decreases speed | Speed decreases | **Fail** | Same as 3.5 |
| 3.7 | ⌘⏎ stops prompter | Returns to editor | **Pass** | |

### Crash: Swift 6 Actor Isolation (Blocker — Fixed During QA)

**Severity:** P0 — app crashes on every prompter launch

**Symptom:** Pressing ⌘⏎ to start the prompter crashes the app immediately. The crash occurs in `AudioLevelDetector.start()` when the `AVAudioEngine` input tap callback is invoked on Core Audio's realtime thread.

**Crash signature:**
```
Thread N Crashed :: Dispatch queue: RealtimeMessenger.mServiceQueue
0  libdispatch.dylib       _dispatch_assert_queue_fail
3  libswift_Concurrency    _swift_task_checkIsolatedSwift
4  libswift_Concurrency    swift_task_isCurrentExecutorWithFlagsImpl
5  Promptly.debug.dylib    closure #N in AudioLevelDetector.start()
6  Promptly.debug.dylib    thunk for @escaping @callee_guaranteed
                           (@guaranteed AVAudioPCMBuffer, @guaranteed AVAudioTime) -> ()
```

**Root cause:** Swift 6 strict concurrency (SE-0423) infers closures defined inside `@MainActor` methods as `@MainActor`-isolated. The compiler inserts a runtime isolation assertion into the closure thunk. When Core Audio invokes the `installTap` callback on its realtime thread (`RealtimeMessenger.mServiceQueue`), the assertion fails because the thread is not the main queue. This is a known Swift 6 issue: [swiftlang/swift#75453](https://github.com/swiftlang/swift/issues/75453).

**Attempts that did NOT work:**
1. `Task { @MainActor [weak self] in }` inside the tap — crash at thunk entry
2. `DispatchQueue.main.async { [weak self] in }` inside the tap — crash at thunk entry
3. `@Sendable` closure created on MainActor, captured in tap — crash at thunk entry
4. Non-`@MainActor` bridge class (`AudioTapBridge`), captured in tap — crash at thunk entry

All failed because the crash occurs at the **closure invocation level** (the thunk), not inside the closure body. The isolation check fires before any body code runs.

**Fix applied:** Extracted the tap handler into a `nonisolated private static func makeTapHandler(bridge:)`. Because the function is `nonisolated static`, the returned closure has no actor isolation — Swift 6 does not insert an assertion. The closure captures only `AudioTapBridge` (a non-actor `@unchecked Sendable` type) and bounces audio levels to MainActor via `DispatchQueue.main.async` inside `bridge.send()`.

**File changed:** `Promptly/Audio/AudioLevelDetector.swift`

**Verification:** 184/184 unit tests pass. App no longer crashes on prompter start.

### Functional Issues (Post-Crash Fix)

**Issue 3A — Window too small (P1)**
The prompter overlay is only ~80px tall (`NotchPositionCalculator.defaultWindowHeight = 80`). At typical font sizes (16-24pt), this shows only 1 line of text. The prompter is not usable as a teleprompter with a single visible line.

**File:** `Promptly/Windows/NotchPositionCalculator.swift` line 6

**Issue 3B — No auto-scroll on start (P1)**
The `VoiceScrollController.start()` method is a no-op — it waits for `isSpeaking` to become true before starting the DisplayLink. Text sits static after countdown completes. Expected: text should begin scrolling immediately (at base speed), with voice modulating the rate.

**File:** `Promptly/Audio/VoiceScrollController.swift` lines 87-89, 119-127

**Issue 3C — ⌘↑/⌘↓ keyboard shortcuts not working (P2)**
The `KeyboardShortcutManager` uses `NSEvent.addLocalMonitorForEvents` which should work app-wide, but speed adjustment shortcuts don't appear to have any effect. The prompter `NSPanel` is non-activating, so key focus stays in the editor window behind it. The local event monitor should still capture these, suggesting the issue may be in the shortcut wiring or the speed adjustment itself having no visible effect.

**Files:** `Promptly/Utilities/KeyboardShortcutManager.swift`, `Promptly/Windows/PrompterPanel.swift`

---

## Test 4: Voice-Activated Scrolling

| # | Step | Expected | Result | Notes |
|---|------|----------|--------|-------|
| 4.1 | Start prompter (⌘⏎) | Countdown → prompter | **Pass** | After crash fix |
| 4.2 | Stay silent 5 seconds | Text stops/slows | **N/A** | Text never starts scrolling (see Issue 3B) |
| 4.3 | Speak out loud | Text scrolls with speech | **Fail** | Mic captures audio (level indicator shows signal) but scrolling does not engage |
| 4.4 | Stop speaking mid-sentence | Text pauses after ~300ms | **Fail** | No scrolling to pause |
| 4.5 | Resume speaking | Text resumes | **Fail** | |
| 4.6 | Alternate speak/silence pattern | Consistent tracking | **Fail** | |
| 4.7 | Stop prompter (⌘⏎) | Returns to editor | **Pass** | |

**Summary:** Voice detection is working (mic level indicator responds to speech), but the `isSpeaking` state change does not trigger the scroll controller to start scrolling. The audio-to-scroll pipeline is broken somewhere between `AudioLevelDetector.isSpeaking` and `VoiceScrollController.startScrolling()`.

---

## Tests 5–10: Not Yet Executed

The following tests were blocked by the prompter being non-functional:

| Test | Area | Status | Reason |
|------|------|--------|--------|
| 5 | Floating Mode | **Blocked** | Prompter unusable; need functional scrolling first |
| 6 | Screen Share Invisibility | **Blocked** | Can verify window appears, but no scrolling to test |
| 7 | Settings Persistence | **Not started** | |
| 8 | Hover to Pause | **Blocked** | No scrolling to pause |
| 9 | Edge Cases | **Not started** | |
| 10 | Dark Mode | **Not started** | |

---

## Summary

| Test | Result |
|------|--------|
| 1. First Launch & Permissions | **Pass** |
| 2. Script Management | **Pass** (with UX notes) |
| 3. Prompter — Notch Mode | **Fail** (crash fixed, 3 functional issues remain) |
| 4. Voice-Activated Scrolling | **Fail** (mic works, scroll doesn't engage) |
| 5. Floating Mode | Blocked |
| 6. Screen Share Invisibility | Blocked |
| 7. Settings Persistence | Not started |
| 8. Hover to Pause | Blocked |
| 9. Edge Cases | Not started |
| 10. Dark Mode | Not started |

### Bugs Filed

| ID | Severity | Summary | Status |
|----|----------|---------|--------|
| BUG-001 | P0 | Swift 6 actor isolation crash in AudioLevelDetector.start() on prompter launch | **Fixed** |
| BUG-002 | P1 | Prompter window only 80px tall — shows 1 line of text | Open |
| BUG-003 | P1 | No auto-scroll on prompter start — text is static | Open |
| BUG-004 | P1 | Voice detection doesn't trigger scrolling — audio-to-scroll pipeline broken | Open |
| BUG-005 | P2 | ⌘↑/⌘↓ speed shortcuts don't work during prompting | Open |
| BUG-006 | P3 | Save indicator animation janky — briefly appears full-screen | Open |
| BUG-007 | P3 | Seconds estimate next to word count is redundant | Open |
