# Moody — Product Research

## What Is It
Moody is a macOS teleprompter app ($59 one-time) that positions scrolling script text in the MacBook notch area, directly below the camera. This creates natural eye contact during video calls, recordings, and presentations.

## Target Users
- Content creators (YouTube, social media)
- Live streamers
- Remote workers (standups, team updates)
- Business professionals (exec presentations, client calls)
- Job seekers (video interviews)
- Educators/trainers (online courses, webinars)
- Sales teams (product demos, pitches)
- Public speakers

## Core Features

### 1. Notch-Based Prompting
- Text displayed in/around the MacBook notch area
- Positions script as close to camera as possible
- Creates natural eye-to-lens alignment
- macOS 14.7+ required, notch-equipped MacBooks

### 2. Voice-Activated Scrolling
- Script scrolls as user speaks
- Pauses when user pauses speaking
- Uses microphone input to detect speech
- Adjustable microphone sensitivity in settings
- Background noise can interfere (headphones help)

### 3. Floating Window Mode
- Prompter can be placed anywhere on screen
- Freely resizable
- Works for classic teleprompter setups
- Alternative to notch mode

### 4. Screen-Share Invisibility
- Prompter is invisible during screen sharing
- Also invisible in screenshots
- Uses macOS window sharing exclusion APIs
- Only the user can see the prompter

### 5. Pause Controls
- Hover over prompter to instantly pause
- Click icon for longer pause
- Resume on hover-out or click

### 6. Speed Control
- Adjust scrolling speed during presentation
- Keyboard shortcuts for speed changes
- Default speed configurable in settings

### 7. Built-in Script Editor
- Write or paste scripts directly
- No external file import mentioned
- Scripts stored locally on Mac (no cloud)

### 8. Display Options
- Adjustable text size and color
- Countdown timer before starting
- Visual voice feedback (speech level monitor)
- Works across all Spaces
- Stays on top of full-screen apps
- Works on whichever screen launched from

### 9. Compatibility
- Intel and Apple Silicon Macs
- macOS 14.7 or later
- Notch-equipped MacBooks (primary use case)

## Business Model
- $59 one-time purchase
- Free updates forever
- No subscriptions
- Local data (scripts on your Mac)
- Direct dev support
- 7-day money-back if doesn't work on your setup

## Competitive Landscape
- Teleprompter (App Store) — $10-20/mo subscription, full-featured
- Power Prompter — professional studio tool
- Teleprompter.com — multi-platform
- Teleprompter Pro+ — broadcast-grade

Moody differentiates by: notch integration, simplicity, one-time pricing, screen-share invisibility.

## Technical Observations
- Native macOS app (not Electron — needs notch integration)
- Uses macOS Speech/AVFoundation for voice detection
- Uses NSWindow/NSPanel APIs for screen-share exclusion
- Uses window level APIs for always-on-top
- Likely SwiftUI for editor, AppKit for window management
- No network calls needed (fully offline)
