# Distribution Guide — Promptly

## Quick Start (Development)

```bash
# Build
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Promptly.xcodeproj -target Promptly -configuration Debug build

# Run
open build/Debug/Promptly.app
```

## Release Build + DMG

```bash
./scripts/build-release.sh 1.0.0
# Creates: build/Promptly-1.0.dmg
```

## Enterprise Distribution (300+ users)

### Option A: Notarized DMG (Recommended)

For users to install without Gatekeeper warnings:

1. **Enroll in Apple Developer Program** ($99/year)
   - https://developer.apple.com/programs/
   - Need a "Developer ID Application" certificate

2. **Create App-Specific Password**
   - https://appleid.apple.com → Security → App-Specific Passwords

3. **Store credentials**
   ```bash
   xcrun notarytool store-credentials "Promptly-Notarize" \
     --apple-id "your@email.com" \
     --team-id "YOUR_TEAM_ID" \
     --password "your-app-specific-password"
   ```

4. **Build, sign, and notarize**
   ```bash
   ./scripts/build-release.sh 1.0.0
   ./scripts/notarize.sh 1.0.0
   ```

5. **Distribute the DMG**
   - Upload to internal file server, S3, GitHub Releases, etc.
   - Users drag Promptly.app to Applications

### Option B: MDM Distribution (No Notarization Needed)

If you use an MDM solution (Jamf, Mosyle, Kandji, etc.):

1. Build the Release DMG: `./scripts/build-release.sh 1.0.0`
2. Upload to your MDM
3. MDM can bypass Gatekeeper for managed devices
4. No Apple Developer account required

### Option C: Ad-hoc (Small Teams)

For teams < 10 where everyone trusts the source:

1. Build: `./scripts/build-release.sh 1.0.0`
2. Share the DMG
3. Users right-click → Open to bypass Gatekeeper on first launch

## System Requirements

- macOS 14.7+ (Sonoma or later)
- Intel or Apple Silicon Mac
- Notch-equipped MacBook recommended (floating mode works on any Mac)
- Microphone access (for voice-activated scrolling)

## Permissions

On first launch, Promptly will request:
- **Microphone Access** — Required for voice-activated scrolling
  - Users can still use manual speed control without microphone

## Known Considerations

- The prompter window is invisible during screen sharing (by design)
- Voice detection works best in quiet environments
- External microphones may require adjusting the sensitivity in Settings
- On non-notch Macs, the app defaults to floating mode

## Version Management

Update version in `project.yml`:
```yaml
settings:
  base:
    MARKETING_VERSION: "1.1.0"
    CURRENT_PROJECT_VERSION: "2"
```

Then regenerate: `xcodegen generate`

## Auto-Update (Future)

For auto-updates, integrate [Sparkle](https://sparkle-project.org/):
1. Add Sparkle as SPM dependency
2. Configure appcast URL
3. Host appcast XML + DMGs on your server

This is recommended for enterprise with 300+ users to avoid manual update distribution.
