---
name: zenplayer-project
description: Use for ZenPlayer application architecture, navigation, playback, progress, downloads, localization, and domain models. Applies to feature work, debugging, reviews, refactors, and architecture documentation; generic repository tooling and editorial changes follow AGENTS.md directly.
---

# ZenPlayer Project

Use this skill for application work. Task routing, OpenSpec, authorization and delivery gates live in [AGENTS.md](../../../AGENTS.md); do not duplicate their workflow here.

## Quick context

- ZenPlayer is a SwiftUI app organized as `Models / ViewModels / Views / Services / Utilities`.
- Current targets are iOS 17+ and macOS 14+.
- Core flows are category browsing, series detail, episode playback, and offline downloads.
- Playback is local-file-first, with remote URLs as fallback. Denoising uses `AVPlayer` audio tap plus bundled RNNoise code.

## Working rules

- Keep SwiftUI views presentation-focused; move async work and business logic into `ViewModels` or `Services`.
- Trace affected owners and entry points with CodeGraph before editing. Follow the root fallback rules when the index cannot answer; read only missing details.
- Preserve value-based navigation registered in `ZenPlayer/ContentView.swift` for `CategoryItem`, `SeriesItem`, and `PlaybackContext` unless the approved change explicitly changes it.
- Treat playback and download reliability as priority behavior: avoid changes that break local-file fallback, resume behavior, or graceful degradation to raw playback.
- Follow existing conventions: English identifiers, Chinese business comments when helpful, `@MainActor` and `@Observable` for UI-facing models.

## When to read more

Read only the relevant section of [references/project-context.md](references/project-context.md) for entry-point hints, legacy identity, or playback/download constraints. It is a map for queries, not proof that planned capabilities exist; verify changing facts in current source.
