#!/usr/bin/env bash
# App Store screenshots (iPhone 6.9", 1320x2868) for ROLL 36, vi + en-US.
# Usage: scripts/screenshots/capture.sh [locale ...]   (default: vi en-US)
# Env:   UDID=<simulator>  SKIP_BUILD=1  (reuse build/dd)
set -euo pipefail
[[ -z "${TRACE:-}" ]] || set -x
cd "$(dirname "$0")/../.."

UDID="${UDID:-D98676ED-D44E-4DE1-98B3-E9BD503998DE}" # iPhone 17 Pro Max
BUNDLE="com.lequangtrongtai.roll36.dev"
APP="build/dd/Build/Products/Debug-Dev-iphonesimulator/ROLL36.app"
OUT="$PWD/fastlane/screenshots"
LOCALES=("$@")
[[ ${#LOCALES[@]} -gt 0 ]] || LOCALES=(vi en-US)

# Tab bar and header coordinates in points (440x956); the layout does not depend on the language.
TAB_DARKROOM=(220 891)
TAB_LIBRARY=(367 891)

tap() { axe tap -x "$1" -y "$2" --udid "$UDID" >/dev/null; }
ui() { axe describe-ui --udid "$UDID" 2>/dev/null; }

# Polls the accessibility tree until it contains the (extended regex) pattern.
wait_for() {
  local pattern="$1" tries="${2:-40}"
  for ((i = 0; i < tries; i++)); do
    if ui | grep -Eq "$pattern"; then return 0; fi
    sleep 0.5
  done
  echo "timeout waiting for: $pattern" >&2
  return 1
}

shot() { # <locale> <name> [settle seconds]
  sleep "${3:-1.5}"
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$1/$2.png" >/dev/null 2>&1
  echo "  saved $OUT/$1/$2.png"
}

boot() {
  xcrun simctl boot "$UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState discharging --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiBars 3
}

launch() { # <locale> [extra app args...]
  local locale="$1"
  shift
  local lang region
  case "$locale" in
    vi) lang="vi" region="vi_VN" ;;
    *) lang="en" region="en_US" ;;
  esac
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE" -demoSeed -onboardingSeen YES \
    -AppleLanguages "($lang)" -AppleLocale "$region" "$@" >/dev/null
  # Camera tab = demo store is seeded; the counter = the viewfinder has read the active roll.
  wait_for '"AXLabel" : "Camera"' 120
  wait_for '12 (trên|of) 36'
}

# --- build -------------------------------------------------------------------
if [[ -z "${SKIP_BUILD:-}" ]]; then
  [[ -d ROLL36.xcodeproj ]] || xcodegen generate
  xcodebuild -scheme ROLL36-Dev -configuration Debug-Dev -destination "id=$UDID" \
    -derivedDataPath build/dd build -quiet
fi

boot

for locale in "${LOCALES[@]}"; do
  echo "== $locale"
  mkdir -p "$OUT/$locale"

  # Clean install, then copy the sample photos where DemoSeed reads them.
  xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl install "$UDID" "$APP"
  data="$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)"
  mkdir -p "$data/Documents/DemoPhotos"
  cp docs/screenshot-assets/photo-*.jpg "$data/Documents/DemoPhotos/"

  # 01 viewfinder (first launch seeds the store)
  launch "$locale"
  sleep 2
  shot "$locale" 01-viewfinder

  # 02 darkroom, 03 contact sheet
  tap "${TAB_DARKROOM[@]}"
  shot "$locale" 02-darkroom
  tap 305 551 # "contact sheet" of the first developed roll
  shot "$locale" 03-contact-sheet 2.5

  # 04 library
  launch "$locale"
  tap "${TAB_LIBRARY[@]}"
  shot "$locale" 04-library 2

  # 05 import (-seedImport loads a sample photo as if it had been picked), 06 paywall
  launch "$locale" -seedImport
  tap "${TAB_DARKROOM[@]}"
  sleep 1
  tap 399 101 # flask button
  sleep 3
  shot "$locale" 05-import 1
  # Selecting a locked stock and developing opens the paywall with that stock highlighted.
  tap 291 593 # second emulsion tile (Ektar 100)
  sleep 1.5
  tap 219 877 # develop
  shot "$locale" 06-paywall 2
done

mkdir -p "$OUT/_iap_review"
cp "$OUT/en-US/06-paywall.png" "$OUT/_iap_review/paywall-1320x2868.png" 2>/dev/null || true
for file in "$OUT"/*/[0-9]*.png; do
  printf '%s ' "${file#"$OUT"/}"
  sips -g pixelWidth -g pixelHeight "$file" | awk '/pixel/ {printf "%s ", $2} END {print ""}'
done
xcrun simctl status_bar "$UDID" clear
