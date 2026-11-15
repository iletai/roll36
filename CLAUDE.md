# CLAUDE.md

## What this app is

ROLL 36 is an analog film camera for iOS: you shoot a finite roll of 36 frames, frames stay hidden until the roll is developed (real-time wait, 60 min, no skip), and a darkroom applies film stocks to imported photos. One-time purchases only (1 free stock + 13 paid, or full unlock); no subscription, account, ads or analytics. `PLAN.md` is the source of truth, `DECISIONS.md` records every deviation from it. Moat = scarcity and waiting: never add anything that shows frames early or speeds up developing.

## Architecture

- `App/` — SwiftUI app target: `App/` (AppEnvironment DI container), `DesignSystem/`, `Models/`, `FilmEngine/` (LUT generated in code, no .cube), `Camera/` (protocol + Live + Mock for the simulator), `Storage/`, `Monetization/` (StoreKit 2 non-consumables; product ids = bundle id + `.full` / `.film.<stockID>`), `Features/<Name>/` per screen.
- `Packages/` — local Swift packages (add to `project.yml` `packages:` + target `dependencies:`).
- No third-party dependencies (PLAN §4.1): no SPM packages, so do not use `new_app.sh --with nav|update|ads`.

## Conventions

- iOS 18+, Swift 6 strict concurrency.
- `project.yml` is the source of truth; run `xcodegen generate` after editing it (`*.xcodeproj` is not committed).
- Environments Dev / Staging / Prod (Staging uses the Prod backend): schemes `ROLL36-Dev`, `ROLL36-Staging`, `ROLL36`; configs `{Debug,Release}-{Dev,Staging,Prod}`; per-env values only in `Config/{Dev,Staging,Prod}.xcconfig` (+ `Backend-Prod.xcconfig`). Read the env via `AppConfiguration.environment`. Never add schemes/configs outside this set.
- Secrets only in `.env` (gitignored); non-secret fastlane values in `fastlane/.env.default` + `fastlane/.env.{dev,staging,prod}`.
- Build-time values: xcconfig variable → `project.yml` `info.properties` → `AppConfiguration`. Never `INFOPLIST_KEY_<custom>` (Xcode drops it).
- Log with `Log.<area>` (os.Logger), not `print`.
- Heavy builds/screenshots run on GitHub Actions, not locally.

## Release

Git Flow: `feature/*` → `develop` → `release/x.y.z` → `main` + tag `x.y.z`; `hotfix/x.y.z` from `main`. Lanes come from `iletai/ios-shared` (`--env dev|staging|prod`). Workflows: `ci.yml`, `deploy-{dev,staging,prod}.yml`.
Release steps: skill `app-store-release`. Signing: skill `ios-cicd-signing`.
