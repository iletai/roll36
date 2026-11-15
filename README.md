# ROLL36

<!-- One line: what the app does. -->

## Setup

```bash
brew install xcodegen swiftlint
bundle install
cp .env.example .env && chmod 600 .env          # fill values, never commit
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig   # if the app has build-time secrets
xcodegen generate && open ROLL36.xcodeproj
```

## Environments

| Scheme | Bundle id | Backend | Ships to |
|---|---|---|---|
| `ROLL36-Dev` | `com.lequangtrongtai.roll36.dev` | Dev | TestFlight (on every push to `develop`) |
| `ROLL36-Staging` | `com.lequangtrongtai.roll36.staging` | Prod | TestFlight (on push to `release/*`, `hotfix/*`) |
| `ROLL36` | `com.lequangtrongtai.roll36` | Prod | App Store (on tag `x.y.z`) |

fastlane: `bundle exec fastlane <lane> --env dev|staging|prod` (lanes from [iletai/ios-shared](https://github.com/iletai/ios-shared)).

## Branches

`feature/*` → PR into `develop` → `release/x.y.z` (version bump) → PR into `main` → tag `x.y.z` on the merge commit → merge `main` back into `develop`. Hotfix: `hotfix/x.y.z` from `main`. Conventional commits.

Store text lives in `fastlane/metadata/`; screenshots come from `bundle exec fastlane screenshots --env prod`.
