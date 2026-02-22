#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="WhisperNotes"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"

echo "Building ${APP_NAME}..."
swift build -c release 2>&1

echo "Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${CONTENTS}/MacOS"
mkdir -p "${CONTENTS}/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${CONTENTS}/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${CONTENTS}/Info.plist"
cp "Resources/AppIcon.icns" "${CONTENTS}/Resources/AppIcon.icns"

echo "Signing ad-hoc..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo ""
echo "Done! App bundle: $(pwd)/${APP_BUNDLE}"
echo ""
echo "To install:"
echo "  cp -r ${APP_BUNDLE} /Applications/"
echo ""
echo "First launch: right-click > Open (to bypass Gatekeeper)"
