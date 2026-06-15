#!/usr/bin/env bash
#
# Build StockBar.app from the SwiftPM executable, then optionally sign,
# notarize, and staple it for distribution.
#
# Usage:
#   ./Scripts/build-app.sh                       # build unsigned .app + zip
#   SIGN_ID="Developer ID Application: Your Name (TEAMID)" \
#     ./Scripts/build-app.sh                     # build + sign
#   SIGN_ID="..." NOTARY_PROFILE="stockbar" \
#     ./Scripts/build-app.sh                     # build + sign + notarize + staple
#
# Set up the notary keychain profile once with:
#   xcrun notarytool store-credentials "stockbar" \
#     --apple-id "you@example.com" \
#     --team-id "TEAMID" \
#     --password "app-specific-password"
#
set -euo pipefail

APP_NAME="StockBar"
BUNDLE_ID="com.skumar.stockbar"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/.build/release"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

echo "==> Building release binary"
swift build -c release --package-path "$ROOT"

echo "==> Assembling $APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# Optional: drop an AppIcon.icns into Resources/ and uncomment to bundle it.
# cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

if [[ -n "${SIGN_ID:-}" ]]; then
    echo "==> Code signing with: $SIGN_ID"
    codesign --force --options runtime --timestamp \
        --sign "$SIGN_ID" "$APP"
    codesign --verify --deep --strict --verbose=2 "$APP"
else
    echo "==> SIGN_ID not set; producing UNSIGNED build (users must right-click → Open)"
fi

ZIP="$DIST/$APP_NAME.zip"
echo "==> Zipping to $ZIP"
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"

if [[ -n "${SIGN_ID:-}" && -n "${NOTARY_PROFILE:-}" ]]; then
    echo "==> Submitting to Apple notary service (profile: $NOTARY_PROFILE)"
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    echo "==> Stapling ticket"
    xcrun stapler staple "$APP"
    # Re-zip so the distributed archive contains the stapled app.
    rm -f "$ZIP"
    /usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"
    xcrun stapler validate "$APP"
fi

echo "==> Done: $ZIP"
