# ZenPlayer Project Context

## Project overview

ZenPlayer is a cross-platform Apple app for browsing, downloading, and playing lecture content. The app is built with SwiftUI and uses an MVVM split across app code in `ZenPlayer/`.

Current project settings show:

- iOS deployment target: 17+
- macOS deployment target: 14+
- Supported platforms: iPhone simulator/device and macOS

## Repository structure

```text
ZenPlayer/
├── ZenPlayerApp.swift
├── ContentView.swift
├── Models/
├── ViewModels/
├── Views/
├── Services/
├── Utilities/
└── Libraries/RNNoise/
```

- `Models/`: API and domain types, usually `Codable`, `Identifiable`, and `Hashable`
- `ViewModels/`: `@MainActor` + `@Observable` state and user actions
- `Views/`: SwiftUI screens and row/card components
- `Services/`: API access, downloads, playback helpers, denoise processing
- `Utilities/`: shared layout and platform-specific helpers
- `Libraries/RNNoise/`: bundled C implementation used by denoise processing

## Navigation and flow

- App launch: `ZenPlayerApp` -> `ContentView`
- `ContentView` registers value-based navigation for:
  - `CategoryItem` -> `CategoryDetailView`
  - `SeriesItem` -> `SeriesDetailView`
  - `PlaybackContext` -> `PlayerView`
- Primary user flow:
  1. `HomeView` loads top-level categories
  2. `CategoryDetailView` loads series
  3. `SeriesDetailView` loads episodes
  4. `EpisodeRowView` navigates to `PlayerView`

## Domain terms

- `Category`: top-level classification
- `Series`: lecture series under a category
- `Episode`: playable item with media URLs
- `PlaybackContext`: `EpisodeItem + serverUrl`, used for navigation into playback

## Project conventions

- Keep business logic out of SwiftUI view structs when possible.
- Prefer local downloaded files before remote media URLs.
- Use `APIError` for network/business error normalization.
- Use English code identifiers; Chinese comments are acceptable for business rules.
- Use `MARK:` sections to keep large files navigable.
