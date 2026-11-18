#!/usr/bin/env bash
# Build ROLL36-Dev, install it and launch it on a connected iPhone.
# Usage: scripts/run-on-device.sh   (DEVICE_NAME=<substring of the device name>, default "Tài")
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE_NAME="${DEVICE_NAME:-Tài}"
BUNDLE_ID="$(sed -n 's/^APP_BUNDLE_IDENTIFIER *= *//p' Config/Dev.xcconfig)"
DERIVED=build/device
LOG=build/device.log

devices_json="$(mktemp)"
trap 'rm -f "$devices_json"' EXIT
xcrun devicectl list devices --json-output "$devices_json" >/dev/null
read -r DEVICE_ID DEVICE_UDID < <(python3 -I - "$devices_json" "$DEVICE_NAME" <<'PY'
import json, sys
path, wanted = sys.argv[1:]
for d in json.load(open(path))["result"]["devices"]:
    name = d["deviceProperties"]["name"]
    if wanted.lower() in name.lower() and d["connectionProperties"].get("tunnelState") != "unavailable":
        print(d["identifier"], d["hardwareProperties"]["udid"])
        break
PY
) || true
[[ -n "${DEVICE_ID:-}" ]] || { echo "No connected device matching '$DEVICE_NAME' (unlock it and check the cable)." >&2; exit 1; }

xcodegen generate >/dev/null
xcodebuild -project ROLL36.xcodeproj -scheme ROLL36-Dev -configuration Debug-Dev \
    -destination "id=$DEVICE_UDID" -derivedDataPath "$DERIVED" -allowProvisioningUpdates build \
    >"$LOG" 2>&1 || { grep -E "error:" "$LOG" | sort -u | head -n 30; echo "Build failed, full log: $LOG" >&2; exit 1; }

APP="$(find "$DERIVED/Build/Products" -maxdepth 2 -name '*.app' -path '*Debug-Dev-iphoneos*' | head -n 1)"
[[ -n "$APP" ]] || { echo "Build produced no .app" >&2; exit 1; }

xcrun devicectl device install app --device "$DEVICE_ID" "$APP"
xcrun devicectl device process launch --device "$DEVICE_ID" --terminate-existing "$BUNDLE_ID"
