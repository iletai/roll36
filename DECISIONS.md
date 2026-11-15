# DECISIONS

Deviations from PLAN.md (PLAN §18.11). Each one was chosen deliberately; revisit by editing here first.

## D1. House scaffold (Dev / Staging / Prod) instead of a single `ROLL36` scheme
PLAN §5 describes one target and one scheme. The `ios-new-app` standard requires 3 environments, so the project has schemes `ROLL36-Dev`, `ROLL36-Staging`, `ROLL36`, fastlane lanes from `iletai/ios-shared`, and CI callers. Confirmed with the owner.
- Tests run on `ROLL36-Dev` (it owns `ROLL36Tests`).
- Sources live in `App/` (not `ROLL36/`) and tests in `Tests/`; the PLAN module folders (`DesignSystem/`, `Models/`, `FilmEngine/`, `Camera/`, `Storage/`, `Monetization/`, `Features/`) sit directly under `App/`.
- Team ID is `AP58YLHQ2S` (same as Titto/Serene), in `Config/Shared.xcconfig` and the gitignored `.env`.

## D2. Product IDs follow the environment bundle id
PLAN §12.1 hardcodes `com.lequangtrongtai.roll36.full`. With 3 bundle ids each ASC record has its own products, so `ProductCatalog` builds ids as `Bundle.main.bundleIdentifier + ".full"` / `".film.<stockID>"`. `App/Monetization/ROLL36.storekit` uses the Dev ids (`com.lequangtrongtai.roll36.dev.*`) and is attached to the `ROLL36-Dev` run scheme.

## D3. `new_app.sh --with` features not used
`storekit` is subscription-centric (PLAN §3.2 forbids subscriptions), `nav` adds an SPM package, `update`/`ads` add SDKs (PLAN §4.1: no third-party dependencies). StoreKit 2 and navigation are written natively.

## D4. Navigation is 3 tabs (Camera / Darkroom / Library)
The Stitch screens show two different bars (Roll/Framing/Trigger/Settings on viewfinder + import, Camera/Darkroom/Library on darkroom). PLAN §14 M1 says 3 tabs; Settings is reached from a toolbar button, Import from the Darkroom/Library screens.

## D5. Copy in the Stitch screens that contradicts PLAN
"DEVELOP FRAME — 1 CREDIT" (import) and "$0.99 / $1.49" per stock are Stitch placeholders. PLAN §11.2 (5 free imports, no credits) and §7.4 (prices per stock) win. Prices shown in the UI come from StoreKit `Product.displayPrice`, with the catalog price only as a fallback label.

## D6. Locked stocks: preview allowed, developing/export gated
PLAN §12.3 says locked stocks can be previewed and exports are watermarked. Implemented as: any stock can be previewed (Import preview, Library detail); developing an import with a locked stock opens the paywall; a roll is loaded only with an unlocked stock; `EntitlementStore.removesWatermark` (any purchase) decides whether `FilmEngine.watermarked` is applied on share/save.

## D7. Where the Stitch screens break the core mechanic
- The viewfinder shows a thumbnail of the last frame bottom-left; PLAN §9.4 forbids showing shots before developing, so only the frame number (`#11`) is shown.
- "Batch import roll" (import screen) is not in PLAN v1 and is skipped.
- Darkroom chemistry labels (tank, bath, temperature, stage) are decorative and derived from the roll/stock, not real data.

## D8. Navigation entry points
Camera tab: top-right sliders button opens `SettingsView` (sheet). Darkroom header flask button opens `ImportView` (full screen cover). Locked stock or limit reached opens `PaywallView(highlightStockID:)` (sheet). Developed roll pushes `ContactSheetView(roll:)` inside the Darkroom `NavigationStack`. The service container is `AppEnvironment` (`@Environment(AppEnvironment.self)`).
