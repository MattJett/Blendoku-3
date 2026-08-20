#!/bin/bash
#
# Build Blendoku and run it on an iOS Simulator.
#
#   Tools/run-simulator.sh                 # boot a simulator and play
#   Tools/run-simulator.sh 42              # open straight into level 42
#   Tools/run-simulator.sh 42 paper        # ...on the light ground
#
# No signing involved: simulator builds are not code signed, so this needs
# nothing from your Apple ID. Requires Xcode 16+ — the project is written in
# the objectVersion 77 format, which Xcode 15 cannot open.

set -euo pipefail
cd "$(dirname "$0")/.."

level="${1:-}"
appearance="${2:-}"
bundle_id="com.mattjett.blendoku3"

if ! xcodebuild -version >/dev/null 2>&1; then
    echo "error: xcodebuild not found. Install Xcode from the App Store," >&2
    echo "       then run: sudo xcode-select -s /Applications/Xcode.app" >&2
    exit 1
fi

major="$(xcodebuild -version | sed -n 's/^Xcode \([0-9]*\).*/\1/p')"
if [ -n "$major" ] && [ "$major" -lt 16 ]; then
    echo "error: Xcode $major cannot open this project (needs 16 or newer)." >&2
    exit 1
fi

# Reuse whatever is already booted, so repeated runs land in the same
# simulator you are looking at rather than opening another one.
udid="$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1 || true)"
if [ -z "$udid" ]; then
    udid="$(xcrun simctl list devices available \
        | grep -E 'iPhone 16 Pro \(|iPhone 16 \(|iPhone 15 Pro \(|iPhone 15 \(' \
        | grep -oE '[0-9A-F-]{36}' | head -1)"
    [ -n "$udid" ] || { echo "error: no iPhone simulator installed." >&2; exit 1; }
    echo "==> Booting simulator $udid"
    xcrun simctl boot "$udid"
fi
open -a Simulator

echo "==> Building"
xcodebuild build \
    -project Blendoku3.xcodeproj \
    -scheme Blendoku3 \
    -configuration Debug \
    -destination "id=$udid" \
    -derivedDataPath .build \
    CODE_SIGNING_ALLOWED=NO \
    | grep -E '^(\*\*|error:|warning:.*Blendoku)' || true

app="$(find .build/Build/Products -maxdepth 2 -name 'Blendoku3.app' -type d | head -1)"
[ -n "$app" ] || { echo "error: build produced no app bundle." >&2; exit 1; }

echo "==> Installing $app"
xcrun simctl install "$udid" "$app"

args=()
[ -n "$level" ] && args+=(-uiPreviewLevel "$level")
[ -n "$appearance" ] && args+=(-uiPreviewAppearance "$appearance")

echo "==> Launching"
xcrun simctl launch --console-pty "$udid" "$bundle_id" "${args[@]}"
