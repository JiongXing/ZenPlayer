---
name: zenplayer-project
description: Use when working in the ZenPlayer repository or on requests about its SwiftUI Apple app architecture, navigation, playback, downloads, localization, or domain models such as Category, Series, Episode, and PlaybackContext. Applies to feature work, debugging, refactors, reviews, and documentation for this repo.
---

# ZenPlayer Project

Use this skill for any task inside the ZenPlayer codebase.

## Quick context

- ZenPlayer is a SwiftUI app organized as `Models / ViewModels / Views / Services / Utilities`.
- Current targets are iOS 17+ and macOS 14+.
- Core flows are category browsing, series detail, episode playback, and offline downloads.
- Playback is local-file-first, with remote URLs as fallback. Denoising uses `AVPlayer` audio tap plus bundled RNNoise code.

## Working rules

- Keep SwiftUI views presentation-focused; move async work and business logic into `ViewModels` or `Services`.
- Preserve value-based navigation registered in `ZenPlayer/ContentView.swift` for `CategoryItem`, `SeriesItem`, and `PlaybackContext`.
- Treat playback and download reliability as priority behavior: avoid changes that break local-file fallback, resume behavior, or graceful degradation to raw playback.
- Follow existing conventions: English identifiers, Chinese business comments when helpful, `@MainActor` and `@Observable` for UI-facing models.

## When to read more

Read [references/project-context.md](references/project-context.md) when you need the repo layout, routing chain, domain definitions, or project-specific coding conventions.
