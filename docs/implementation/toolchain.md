# Toolchain and reproducible commands

Recorded 2026-09-21 for plan 00.

## Installed toolchain

- Active `xcode-select -p`: `/Library/Developer/CommandLineTools`. This cannot run `xcodebuild`; commands below pin the full installation with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- Xcode: 27.0 (`27A266a`).
- Swift: Apple Swift 6.4 (`swiftlang-6.4.0.34.1`, clang `2100.3.34.1`), arm64 macOS host.
- Installed iOS SDKs: iOS 27.0 and iOS Simulator 27.0.
- Installed simulator runtimes: iOS 18.6, 26.0, 26.5, and 27.0. No iOS 17 simulator runtime is installed.
- Selected repeatable destination: iPhone 16, iOS 18.6, arm64, UDID `8DFAAEF4-C763-42DD-9DB6-03776F020008`.
- No connected physical iPhone appeared in `-showdestinations`; only the generic iOS device placeholder was available.

## Project choices

- Shared scheme: `facetracking`.
- Targets: `facetracking`, `facetrackingTests`, `facetrackingUITests`.
- Deployment target: iOS 17.0 across Debug/Release and all targets. This is the provisional D02 choice and is not minimum-OS runtime evidence.
- Language/concurrency: Swift 6, complete concurrency checking, `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated`. UI owners must opt into `@MainActor`; pure tracking and future camera types do not accidentally inherit main-actor isolation.
- Platform: iPhone only (`TARGETED_DEVICE_FAMILY = 1`), iPhone portrait only, iOS/iOS Simulator only.
- Bundle/signing preserved: `xim.facetracking`, automatic signing. Test identifiers append `Tests` and `UITests`.
- Unit framework: XCTest. UI framework: XCTest/XCUITest.

## Discovery commands

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift --version
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -showsdks
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -list -project facetracking.xcodeproj
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project facetracking.xcodeproj -scheme facetracking -showdestinations
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list devices available
```

## Working verification commands

Use fresh temporary paths when a prior result bundle already exists.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project facetracking.xcodeproj -scheme facetracking -destination 'platform=iOS Simulator,id=8DFAAEF4-C763-42DD-9DB6-03776F020008' -derivedDataPath /tmp/facetracking-plan00-unit-derived -resultBundlePath /tmp/facetracking-plan00-unit.xcresult -only-testing:facetrackingTests test

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project facetracking.xcodeproj -scheme facetracking -destination 'platform=iOS Simulator,id=8DFAAEF4-C763-42DD-9DB6-03776F020008' -derivedDataPath /tmp/facetracking-plan00-ui-final-derived -resultBundlePath /tmp/facetracking-plan00-ui-final.xcresult -only-testing:facetrackingUITests test

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project facetracking.xcodeproj -scheme facetracking -destination 'generic/platform=iOS' -derivedDataPath /tmp/facetracking-plan00-final-derived CODE_SIGNING_ALLOWED=NO build
```

A signed physical-device test command remains pending until a real UDID and signing ownership are confirmed:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project facetracking.xcodeproj -scheme facetracking -destination 'platform=iOS,id=<SIGNED_DEVICE_UDID>' -derivedDataPath /tmp/facetracking-device-derived test
```
