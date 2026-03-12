# Promptly — QA Checklist

**What is this?** Promptly is a macOS teleprompter app. It puts scrolling text near your MacBook camera so you maintain eye contact during video calls. The text scrolls when you speak and pauses when you stop. The prompter window is invisible to screen share.

**Your job:** Follow every step below. Report pass/fail for each item. If something fails, describe what you expected vs. what happened. Screenshots are helpful.

---

## Setup (5 min)

### Prerequisites
- macOS 14.0 (Sonoma) or later
- Xcode 16+ (with command line tools)
- Homebrew installed
- A working microphone (built-in is fine)

### Install & Build

```bash
# 1. Install XcodeGen if you don't have it
brew install xcodegen

# 2. Clone the repo
git clone https://github.com/code-tmpl/promptly.git
cd promptly

# 3. Generate the Xcode project and build
xcodegen generate
xcodebuild -project Promptly.xcodeproj -scheme Promptly -configuration Debug build

# 4. Find the built app
open $(find ~/Library/Developer/Xcode/DerivedData/Promptly* -name "Promptly.app" -path "*/Debug/*" -type d | head -1)
```

If `xcodebuild` complains about developer directory, run this first:
```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

### Clean Slate (Important)
Before testing, remove any leftover data from previous runs:
```bash
rm -rf ~/Library/Application\ Support/Promptly/
defaults delete com.cmpx575.promptly 2>/dev/null
```

Then launch the app.

---

## Test 1: First Launch & Permissions

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 1.1 | Launch the app for the first time | App opens without crash. You see a main editor window. | |
| 1.2 | Look for a microphone permission dialog | macOS should ask "Promptly would like to access the microphone" | |
| 1.3 | Grant mic permission | Dialog dismisses. No crash. App continues running. | |
| 1.4 | Check the editor | You should see a welcome script with sample text explaining how to use the app | |

**If the app crashes on launch:** Check `~/Library/Logs/DiagnosticReports/` for a file starting with `Promptly-`. Send us the file.

---

## Test 2: Script Management

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 2.1 | Click the "+" button (or use the new script option) | A new script appears in the sidebar | |
| 2.2 | Type a title for the script | Title updates in the sidebar | |
| 2.3 | Paste the following text into the editor (all of it): | Text appears in the editor without lag or crash | |

```
Ladies and gentlemen, thank you for joining us today. I want to talk about something that matters to every person in this room — the future of how we work together.

Over the past year, our team has grown from twelve people in a single room to three hundred spread across four time zones. That growth brought challenges nobody warned us about. Communication broke down. Decisions that used to take five minutes started taking five days. People felt disconnected.

But here's what I've learned: scale doesn't break culture. Neglect breaks culture. When you stop being intentional about how people connect, when you let processes calcify, when you assume what worked for twelve will work for three hundred — that's when things fall apart.

So we made changes. We killed the meetings that existed out of habit. We wrote things down instead of saying them once and hoping everyone heard. We built tools that brought people closer instead of adding layers between them.

The results speak for themselves. Our cycle time dropped by forty percent. Employee satisfaction hit an all-time high. And for the first time since we scaled past fifty people, everyone I talk to says they understand where we're going and why.

That's not because we found some magic framework. It's because we decided to care about the boring stuff — the documentation, the onboarding, the check-ins, the feedback loops. The infrastructure of human connection.

Going forward, I'm asking each of you to own one piece of this. Pick the thing in your team that feels broken and fix it. Don't wait for permission. Don't write a proposal. Just fix it and tell us what you did.

Because three hundred people moving in the same direction isn't a management achievement. It's a cultural one. And culture isn't what you say — it's what you do, every single day, when nobody's watching. Thank you.
```

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 2.4 | Wait 3 seconds after pasting | No lag, no spinning beach ball | |
| 2.5 | Quit the app (⌘Q) | App closes cleanly | |
| 2.6 | Relaunch the app | The script you created is still there with all its content | |
| 2.7 | Verify the pasted text is complete | All paragraphs present, nothing truncated | |

---

## Test 3: Prompter — Notch Mode

This is the main feature. The prompter puts scrolling text near your camera.

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 3.1 | With your script selected, press ⌘⏎ (Cmd+Return) | A countdown appears (3... 2... 1...) then the prompter starts | |
| 3.2 | Look at the top of your screen near the camera/notch area | A dark overlay appears with your script text in large white font | |
| 3.3 | Observe the text | Text should be scrolling upward at a steady pace | |
| 3.4 | Press Space | Scrolling pauses. Press Space again — scrolling resumes. | |
| 3.5 | Press ⌘↑ (Cmd+Up Arrow) | Speed increases. You may see a speed indicator briefly. | |
| 3.6 | Press ⌘↓ (Cmd+Down Arrow) | Speed decreases. | |
| 3.7 | Press ⌘⏎ again to stop the prompter | Prompter overlay disappears. You're back to the editor. | |

---

## Test 4: Voice-Activated Scrolling

**This is the core feature.** The text should scroll when you speak and pause when you're silent.

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 4.1 | Start the prompter (⌘⏎) | Countdown, then prompter appears | |
| 4.2 | Stay silent for 5 seconds | Text should stop scrolling (or scroll very slowly) | |
| 4.3 | Start speaking out loud (read the script text) | Text starts scrolling in sync with your speech | |
| 4.4 | Stop speaking mid-sentence | Text should pause after roughly 300ms of silence | |
| 4.5 | Start speaking again | Text resumes scrolling | |
| 4.6 | Alternate: speak for 5 seconds, silent for 3, speak for 5, silent for 3 | Scrolling should follow your voice pattern consistently | |
| 4.7 | Stop the prompter (⌘⏎) | Returns to editor | |

**If voice scrolling doesn't work at all:** Check System Settings → Privacy & Security → Microphone and make sure Promptly has access.

---

## Test 5: Floating Mode

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 5.1 | Press ⌘T to switch to floating mode | The prompt mode switches (check settings or UI indicator) | |
| 5.2 | Start the prompter (⌘⏎) | A floating window appears (not attached to the notch) | |
| 5.3 | Drag the floating window to a new position | Window moves freely | |
| 5.4 | Resize the window by dragging edges/corners | Window resizes (within limits — it won't go huge or tiny) | |
| 5.5 | Stop the prompter (⌘⏎) | Window disappears | |
| 5.6 | Quit and relaunch the app | | |
| 5.7 | Start prompter in floating mode again | Window should appear at the same position and size you left it | |

---

## Test 6: Screen Share Invisibility

**This is a critical enterprise feature.** The prompter must NOT be visible when you share your screen.

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 6.1 | Start the prompter (⌘⏎) in either mode | Prompter visible on your screen | |
| 6.2 | Open Zoom, Google Meet, or FaceTime and start a screen share | | |
| 6.3 | Look at the shared screen preview (or have someone else check) | The prompter window should NOT appear in the screen share | |
| 6.4 | Other windows (Finder, browser, etc.) should appear normally | Only the prompter is hidden | |

**Alternative if you don't have Zoom/Meet:** Open QuickTime Player → File → New Screen Recording → pick "Record Selected Portion" and record your whole screen. Play back the recording — the prompter should not appear in it.

---

## Test 7: Settings Persistence

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 7.1 | Open Settings (⌘, or via menu) | Settings window/panel opens | |
| 7.2 | Change the font size | Font size updates | |
| 7.3 | Change the scroll speed | Speed value updates | |
| 7.4 | Change the background color or opacity | Visual change | |
| 7.5 | Quit the app (⌘Q) | | |
| 7.6 | Relaunch the app and open Settings | All your changes from 7.2–7.4 are still there | |

---

## Test 8: Hover to Pause

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 8.1 | Start the prompter | Text scrolling | |
| 8.2 | Move your mouse cursor over the prompter window | Scrolling pauses (may show a pause indicator) | |
| 8.3 | Move your mouse away from the prompter window | Scrolling resumes | |

---

## Test 9: Edge Cases

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 9.1 | Start prompter with an empty script (no text) | Should handle gracefully — no crash, maybe shows a message | |
| 9.2 | Start prompter, then ⌘Q the app | Clean shutdown, no crash | |
| 9.3 | If you have an external monitor: unplug it while prompter is running | Prompter should reposition to remaining screen, no crash | |
| 9.4 | Deny mic permission (System Settings → Privacy → Microphone → turn off Promptly) then start prompter | Should show an error or graceful degradation, NOT crash | |

---

## Test 10: Dark Mode

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 10.1 | Switch macOS to Light mode (System Settings → Appearance) | App looks fine, text readable | |
| 10.2 | Switch to Dark mode | App looks fine, text readable | |
| 10.3 | Start prompter in both modes | Prompter overlay looks good in both | |

---

## How to Report

For each test, mark **Pass** or **Fail**. For failures, include:
- What you expected
- What actually happened
- Screenshot if possible

Send the completed checklist back. Focus especially on **Test 4 (Voice Scrolling)** — that's the feature that matters most. Everything else is supporting infrastructure.

**Time estimate:** ~20 minutes for the full checklist.
