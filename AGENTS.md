# Repository Guidelines

## Project Structure & Module Organization
`ZenPlayer/` contains the app target. Follow the existing MVVM split: `Models/` for API/data types, `ViewModels/` for `@MainActor` state and actions, `Views/` for SwiftUI screens and reusable rows, `Services/` for networking, downloads, and audio processing, and `Utilities/` for cross-platform helpers. Bundled C sources for RNNoise live in `ZenPlayer/Libraries/RNNoise/`. UI assets and localized strings are under `ZenPlayer/Assets.xcassets` and `ZenPlayer/Localizable.xcstrings`. Reference material and store assets live in `Documents/`, `Screenshots/`, and `AppStore/`.

## Build, Test, and Development Commands
Open the project in Xcode with `open ZenPlayer.xcodeproj`.

- `xcodebuild -project ZenPlayer.xcodeproj -scheme ZenPlayer -destination 'platform=macOS' build` builds the macOS app from the command line.
- `xcodebuild -project ZenPlayer.xcodeproj -scheme ZenPlayer -destination 'platform=iOS Simulator,name=iPhone 16' build` smoke-tests the iOS target.
- `xcodebuild -list -project ZenPlayer.xcodeproj` lists shared schemes and configurations.

Swift Package dependencies are resolved automatically by Xcode and `xcodebuild`.

## Coding Style & Naming Conventions
Use Swift 5 style and match the existing codebase: 4-space indentation, one primary type per file, `UpperCamelCase` for types, and `lowerCamelCase` for properties and methods. Keep SwiftUI views thin and move async work, parsing, and playback/download orchestration into `ViewModels` or `Services`. Preserve naming patterns such as `HomeView`, `PlayerViewModel`, `APIService`, and `LayoutConstants`. No repository-level `SwiftLint` or `SwiftFormat` config is checked in, so consistency with nearby files is the standard.

## Testing Guidelines
There is currently no committed `XCTest` target in this repository. Before opening a PR, run both command-line builds above and manually verify the affected flow in Xcode on iOS and macOS when relevant. For future automated tests, prefer `ZenPlayerTests/` and name cases after behavior, for example `testPlayerFallsBackToRemoteURL()`.

## Configuration Tips
Do not commit secrets or ad-hoc environment changes. Keep bundle identifiers, versioning, and target settings aligned with `ZenPlayer.xcodeproj/project.pbxproj` and `ZenPlayer/Info.plist`.
