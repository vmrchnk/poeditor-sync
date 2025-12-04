import Foundation

// MARK: - Constants

enum Constants {
    // MARK: - Rate Limiting & Delays

    /// Delay between adding languages to POEditor (in seconds)
    static let languageAddDelay: TimeInterval = 2.0

    /// Delay between downloading translations (in seconds)
    static let downloadDelay: TimeInterval = 2.0

    /// POEditor API rate limit delay (in seconds)
    /// Used for uploads and operations that require API rate limiting
    /// Note: POEditor rate limit is 1 upload per 20 seconds
    static let apiRateLimitDelay: TimeInterval = 20.0

    // MARK: - File Paths & Names

    /// Directory name for downloaded translations
    static let downloadDirectory = "poeditor_downloads"

    /// Prefix for temporary export directories
    static let exportDirectoryPrefix = "poeditor_export"

    /// File extension for XLIFF files
    static let xliffExtension = ".xliff"

    /// Path component for localized contents in xcloc bundle
    static let localizedContentsPath = "Localized Contents"

    // MARK: - UI/Formatting

    /// Default separator line length for section headers
    static let sectionSeparatorLength = 60
}
