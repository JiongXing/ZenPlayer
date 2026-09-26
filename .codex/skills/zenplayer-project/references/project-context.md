# ZenPlayer Project Context

Use this as a query map, not a substitute for current source. Workflow and delivery rules are in [AGENTS.md](../../../../AGENTS.md); product scope and stage status are in [ROADMAP.md](../../../../ROADMAP.md). The baseline below was checked with CodeGraph on 2026-09-26; update affected facts when implementation changes.

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
- `Localization/`: `L10n` and `Localizable.xcstrings`, fixed Traditional Chinese UI
- `Utilities/`: shared layout and platform-specific helpers
- `Libraries/RNNoise/`: bundled C implementation used by denoise processing

## Navigation and flow

- App launch: `ZenPlayerApp` -> `ContentView`
- Current root container: `NavigationStack` with a `TabView`; do not infer a split-navigation architecture from older README wording.
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
- `PlaybackContext`: `EpisodeItem + serverUrl + preferredMediaType?`, currently defined in `ViewModels/PlayerViewModel.swift`. Its navigation `id` is not the legacy progress key.

## Playback and data boundaries

- Useful CodeGraph queries: `reloadCurrentPlayback restorePlaybackPositionIfNeeded persistPlaybackProgress`, `RecentPlaybackStore RecentPlaybackRecord`, `completedFileURL removeCompletedDownload`.
- Playback currently belongs to `PlayerView`'s model. History and completed-download views also construct a player page directly; root value routes are not the only entry points. A future global session must account for those paths.
- Legacy progress uses UserDefaults `recentPlayback.records`; `RecentPlaybackRecord.recordID` is `episode.id + "|" + raw serverUrl`. Do not normalize that URL, use title/episode number as identity, or confuse the progress key with download keys (`episodeId_mp3` / `episodeId_mp4`).
- Existing progress and recent display share a ten-record store. Long-term storage, explicit completion, migration protection and a global queue are planned capabilities, not established implementation. Read the active change before touching this boundary.
- Media resolution: audio is local mp3 then remote mp3 (including existing audio-in-video-field fallback); video is local mp4 then remote mp4/vod. Audio Tap failure falls back to raw AVPlayer. Keep these fallbacks when changing resume or switching behavior.
- Observe the captured media/request identity across async prepare, seek, tick and completion callbacks. Releasing observers or using weak self alone does not invalidate already queued work.
- Download deletion and invalid-file cleanup own download artifacts, not listening progress. iOS background downloads and macOS save-panel/security-scoped access have different lifecycles; test the affected platform paths.
- Progress and migration tests use temporary files and isolated UserDefaults, never the user's live App container. Do not promise recovery of old records already evicted or unreadable.

## Project conventions

- Keep business logic out of SwiftUI view structs when possible.
- Prefer local downloaded files before remote media URLs.
- Use `APIError` for network/business error normalization.
- Use English code identifiers; Chinese comments are acceptable for business rules.
- Use `MARK:` sections to keep large files navigable.
