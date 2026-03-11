#!/bin/bash
set -euo pipefail

# Promptly Notarization Script
# Prerequisites:
#   - Apple Developer Program enrollment
#   - Developer ID Application certificate in Keychain
#   - App-specific password stored in Keychain
#
# Setup (one-time):
#   xcrun notarytool store-credentials "Promptly-Notarize" \
#     --apple-id "your@email.com" \
#     --team-id "YOUR_TEAM_ID" \
#     --password "your-app-specific-password"

VERSION="${1:-1.0.0}"
BUILD_DIR="$(pwd)/build"
RELEASE_DIR="${BUILD_DIR}/Release"
APP_PATH="${RELEASE_DIR}/Promptly.app"
DMG_PATH="${BUILD_DIR}/Promptly-${VERSION}.dmg"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application}"
CREDENTIAL_PROFILE="${CREDENTIAL_PROFILE:-Promptly-Notarize}"

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

echo "🔐 Starting notarization pipeline for Promptly v${VERSION}..."

# Step 1: Code sign with Developer ID
echo "1/5 Code signing app..."
codesign --force --deep --options runtime \
  --sign "${SIGNING_IDENTITY}" \
  --entitlements Promptly/Promptly.entitlements \
  "${APP_PATH}"

codesign --verify --deep --strict "${APP_PATH}"
echo "✅ Code signing verified"

# Step 2: Create signed DMG
echo "2/5 Creating signed DMG..."
rm -f "${DMG_PATH}"
mkdir -p "${BUILD_DIR}/dmg-staging"
cp -R "${APP_PATH}" "${BUILD_DIR}/dmg-staging/"
ln -sf /Applications "${BUILD_DIR}/dmg-staging/Applications"

hdiutil create \
  -volname "Promptly" \
  -srcfolder "${BUILD_DIR}/dmg-staging" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

rm -rf "${BUILD_DIR}/dmg-staging"

codesign --force --sign "${SIGNING_IDENTITY}" "${DMG_PATH}"
echo "✅ DMG signed"

# Step 3: Submit for notarization
echo "3/5 Submitting for notarization..."
xcrun notarytool submit "${DMG_PATH}" \
  --keychain-profile "${CREDENTIAL_PROFILE}" \
  --wait

echo "✅ Notarization complete"

# Step 4: Staple the ticket
echo "4/5 Stapling notarization ticket..."
xcrun stapler staple "${DMG_PATH}"
echo "✅ Ticket stapled"

# Step 5: Verify
echo "5/5 Verifying..."
xcrun stapler validate "${DMG_PATH}"
spctl --assess --type open --context context:primary-signature -v "${DMG_PATH}"

echo ""
echo "🎉 Notarized DMG ready for distribution: ${DMG_PATH}"
echo "📦 Size: $(du -sh "${DMG_PATH}" | cut -f1)"
echo ""
echo "Users can now install without Gatekeeper warnings."
