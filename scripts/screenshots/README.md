# App Store screenshots

Run `scripts/screenshots/capture.sh [vi] [en-US]` (default: both). Needs Xcode, XcodeGen and the `axe` CLI.
It builds Debug-Dev into `build/dd`, boots the iPhone 17 Pro Max simulator (`UDID=...` to override), sets the 9:41 status bar, and per locale reinstalls the app, copies `docs/screenshot-assets/photo-*.jpg` into `Documents/DemoPhotos/` and launches with `-demoSeed` (seeds five rolls with the real film engine, shows a sample photo in the mock viewfinder).
`SKIP_BUILD=1` reuses `build/dd`; `TRACE=1` prints every command.
Output (gitignored): `fastlane/screenshots/<vi|en-US>/01-viewfinder … 06-paywall.png` at 1320x2868, plus `_iap_review/paywall-1320x2868.png` (English paywall for the in-app-purchase review).
Taps use fixed point coordinates (440x956 screen), so re-check every image after a layout change.
The demo code lives in `App/Infrastructure/DemoSeed.swift` inside `#if DEBUG`; Release builds contain none of it.
`make_photos.py` regenerates the sample photos from `design/*.png` (Pillow + numpy); the JPEGs are committed, not bundled in the app.
Delete `build/dd` afterwards if disk is tight.
