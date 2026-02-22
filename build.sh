#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="WhisperNotes"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"

echo "Building ${APP_NAME}..."
swift build -c release 2>&1

# Verify binary was created
if [ ! -f "${BUILD_DIR}/${APP_NAME}" ]; then
    echo "Error: Build succeeded but binary not found at ${BUILD_DIR}/${APP_NAME}"
    exit 1
fi

echo "Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${CONTENTS}/MacOS"
mkdir -p "${CONTENTS}/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${CONTENTS}/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${CONTENTS}/Info.plist"
cp "Resources/AppIcon.icns" "${CONTENTS}/Resources/AppIcon.icns"

# Verify bundle structure
for f in "${CONTENTS}/MacOS/${APP_NAME}" "${CONTENTS}/Info.plist" "${CONTENTS}/Resources/AppIcon.icns"; do
    if [ ! -f "$f" ]; then
        echo "Error: Missing bundle file: $f"
        exit 1
    fi
done

echo "Signing ad-hoc..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo ""
echo "Done! App bundle: $(pwd)/${APP_BUNDLE}"
echo ""
echo "To install:"
echo "  cp -r ${APP_BUNDLE} /Applications/"
echo ""
echo "First launch: right-click > Open (to bypass Gatekeeper)"
