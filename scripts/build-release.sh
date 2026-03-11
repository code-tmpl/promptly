#!/bin/bash
set -euo pipefail

# Promptly Release Build Script
# Usage: ./scripts/build-release.sh [version]

VERSION="${1:-1.0.0}"
BUILD_DIR="$(pwd)/build"
RELEASE_DIR="${BUILD_DIR}/Release"
DMG_PATH="${BUILD_DIR}/Promptly-${VERSION}.dmg"
APP_PATH="${RELEASE_DIR}/Promptly.app"

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

echo "🔨 Building Promptly v${VERSION}..."

# Clean previous build
rm -rf "${BUILD_DIR}"

# Build Release
"${DEVELOPER_DIR}/usr/bin/xcodebuild" \
  -project Promptly.xcodeproj \
  -target Promptly \
  -configuration Release \
  SYMROOT="${BUILD_DIR}" \
  MARKETING_VERSION="${VERSION}" \
  CURRENT_PROJECT_VERSION="${VERSION}" \
  build

echo "✅ Build succeeded"

# Verify the app
if [ ! -d "${APP_PATH}" ]; then
  echo "❌ App not found at ${APP_PATH}"
  exit 1
fi

# Show app info
echo "📦 App size: $(du -sh "${APP_PATH}" | cut -f1)"

# Create DMG
echo "📀 Creating DMG..."
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

echo "✅ DMG created: ${DMG_PATH}"
echo "📦 DMG size: $(du -sh "${DMG_PATH}" | cut -f1)"

# Code signing check
echo ""
echo "⚠️  NOTARIZATION:"
echo "   This build is signed 'ad-hoc' (Sign to Run Locally)."
echo "   For enterprise distribution to 300+ users, you need:"
echo ""
echo "   1. Apple Developer Program enrollment (\$99/year)"
echo "   2. Developer ID Application certificate"
echo "   3. Run: ./scripts/notarize.sh $VERSION"
echo ""
echo "   Without notarization, users will see Gatekeeper warnings."
echo "   For internal MDM distribution, this may be acceptable."
echo ""
echo "🎉 Done! DMG at: ${DMG_PATH}"
