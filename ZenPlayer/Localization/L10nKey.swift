//
//  L10nKey.swift
//  ZenPlayer
//

import Foundation

enum L10nKey: String, CaseIterable {
    case commonCancel = "common.cancel"
    case commonSelected = "common.selected"
    case commonNotSelected = "common.not_selected"

    case homeLoading = "home.loading"
    case homeLoadFailed = "home.load_failed"
    case homeRetry = "home.retry"
    case homeSettingsAccessibility = "home.settings_accessibility"

    case settingsLanguageTitle = "settings.language.title"
    case settingsLanguageNameZhHans = "settings.language.name.zh_hans"
    case settingsLanguageNameZhHant = "settings.language.name.zh_hant"
    case settingsLanguageSwitchedTo = "settings.language.switched_to"

    case contentSelectCategoryHint = "content.select_category_hint"
    case contentBrowseSeries = "content.browse_series"

    case categorySeriesCount = "category.series_count"
    case categorySortField = "category.sort_field"
    case categorySortAsc = "category.sort_asc"
    case categorySortDesc = "category.sort_desc"
    case categorySortAscHint = "category.sort_asc_hint"
    case categorySortDescHint = "category.sort_desc_hint"
    case categorySortByNumber = "category.sort_by_number"
    case categorySortByDate = "category.sort_by_date"

    case seriesEpisodeCount = "series.episode_count"
    case seriesPlaylist = "series.playlist"
    case seriesNumberLabel = "series.number_label"

    case episodeFormat = "episode.format"
    case episodePlay = "episode.play"
    case episodeAudio = "episode.audio"
    case episodeVideo = "episode.video"
    case episodeDownload = "episode.download"
    case episodePauseDownload = "episode.pause_download"
    case episodeResumeDownload = "episode.resume_download"
    case episodeCancelDownload = "episode.cancel_download"

    case playerLoading = "player.loading"
    case playerCannotPlay = "player.cannot_play"
    case playerVoiceDenoise = "player.voice_denoise"
    case playerVolumeBoost = "player.volume_boost"
    case playerOriginal = "player.original"

    case errorNoPlayableAddress = "error.no_playable_address"
    case errorNoAudioDownload = "error.no_audio_download"
    case errorNoVideoDownload = "error.no_video_download"
    case errorInvalidDownloadUrl = "error.invalid_download_url"
    case errorResumeDownloadFailed = "error.resume_download_failed"
    case errorLastDownloadFailed = "error.last_download_failed"
    case errorChooseSaveLocation = "error.choose_save_location"
    case errorSaveToMessage = "error.save_to_message"
    case errorDownloadFailedRetry = "error.download_failed_retry"
    case episodeDownloadComplete = "episode.download_complete"
}
