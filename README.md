# POEditor Sync Tool

A command-line tool for synchronizing translations between Xcode projects and [POEditor](https://poeditor.com).

## Features

- **Upload**: Export localization strings from Xcode project to POEditor
- **Download**: Download translations from POEditor and import into Xcode project
- Automatic language creation in POEditor if they don't exist
- Support for download filters (e.g., only translated strings)
- Respects POEditor API rate limits
- Detailed logging of the synchronization process

## Installation

### Requirements

- macOS with Xcode installed
- Swift 5.5+
- Xcode Command Line Tools

### Building

1. Clone the repository or navigate to the scripts folder:
```bash
cd scripts
```

2. Build the project:
```bash
make
```

This will create an executable at `bin/poeditor-sync`.

3. (Optional) Add to PATH for convenience:
```bash
export PATH="$PATH:$(pwd)/bin"
```

## Configuration

Create a `.poeditor.yml` file in the root of your project:

```yaml
# POEditor Configuration
api_token: YOUR_API_TOKEN_HERE
project_id: YOUR_PROJECT_ID

# Xcode project path
project_path: YourProject.xcodeproj

# Upload configuration
upload:
  updating: terms_translations  # What to update: terms, translations, terms_translations
  overwrite: true              # Overwrite existing translations
  sync_terms: true             # Synchronize terms

# Download configuration
download:
   filters:
     - translated              # Filters: translated, untranslated, fuzzy, etc.

# Verbose output
verbose: false
```

### How to get API Token and Project ID

1. **API Token**:
   - Go to [POEditor](https://poeditor.com)
   - Navigate to Settings → API Access
   - Copy your API token

2. **Project ID**:
   - Open your project in POEditor
   - The project ID will be in the URL: `https://poeditor.com/projects/view?id=YOUR_PROJECT_ID`

## Usage

### Upload (Push strings to POEditor)

Basic usage - upload all languages:
```bash
scripts/bin/poeditor-sync upload
```

Initialize project (only base language en):
```bash
scripts/bin/poeditor-sync upload --initial
```

Upload specific languages:
```bash
scripts/bin/poeditor-sync upload --language uk --language pt-br
```

Delete terms that are missing in the project:
```bash
scripts/bin/poeditor-sync upload --delete-other-keys
```

### Download (Pull translations from POEditor)

Basic usage - download all project languages:
```bash
scripts/bin/poeditor-sync download
```

Download specific languages:
```bash
scripts/bin/poeditor-sync download --language uk --language pt-br
```

### Show Help

```bash
scripts/bin/poeditor-sync --help
scripts/bin/poeditor-sync upload --help
scripts/bin/poeditor-sync download --help
```

## Workflow Examples

### Initial Project Setup

1. Create localizations in your Xcode project
2. Configure `.poeditor.yml`
3. Run initialization:
```bash
scripts/bin/poeditor-sync upload --initial
```

### Adding New Strings

1. Add new `NSLocalizedString` calls in your code
2. Upload strings to POEditor:
```bash
scripts/bin/poeditor-sync upload
```

### Getting Translations

1. After translators complete their work in POEditor
2. Download translations:
```bash
scripts/bin/poeditor-sync download
```

### Adding a New Language

1. Add localization in Xcode project (File → New → File → Strings File)
2. Upload the language to POEditor:
```bash
scripts/bin/poeditor-sync upload --language NEW_LANG_CODE
```
3. After translation, download the translations:
```bash
scripts/bin/poeditor-sync download --language NEW_LANG_CODE
```

## Project Structure

```
scripts/
├── Package.swift              # Swift Package Manager configuration
├── Makefile                   # Build commands
├── bin/                       # Compiled executable
│   └── poeditor-sync
└── sources/
    └── POEditorSync/
        ├── main.swift                    # Entry point
        ├── Commands/                     # Commands
        │   ├── UploadCommand.swift
        │   └── DownloadCommand.swift
        ├── Models/                       # Data models
        │   ├── POEditorConfig.swift
        │   ├── POEditorAPIResponse.swift
        │   ├── Constants.swift
        │   ├── ValidationError.swift
        │   └── FileStatistics.swift
        ├── Networking/                   # Network requests
        │   ├── NetworkClient.swift
        │   ├── POEditorEndpoint.swift
        │   └── POEditorAPIService.swift
        ├── Services/                     # Business logic
        │   ├── ConfigService.swift
        │   ├── FileSystemService.swift
        │   ├── XcodeService.swift
        │   └── Logger.swift
        └── Extensions/                   # Extensions
            ├── Process+Run.swift
            └── URLSession+Sync.swift
```

## Rate Limits

The tool automatically respects POEditor API rate limits:

- **Adding languages**: 2 seconds between requests
- **Downloading translations**: 2 seconds between requests
- **Uploading translations**: 20 seconds between requests (per POEditor limit: 1 upload/20s)

These values can be configured in `Constants.swift`:
- `languageAddDelay`: delay between adding languages
- `downloadDelay`: delay between downloads
- `apiRateLimitDelay`: delay for upload operations

## Troubleshooting

### "xcodebuild not found" error

Install Xcode Command Line Tools:
```bash
xcode-select --install
```

### POEditor authorization error

Check that:
- API token is correct in `.poeditor.yml`
- Project ID exists and matches your project
- You have access rights to the project

### Localization files not found

Make sure that:
- `project_path` in `.poeditor.yml` points to the correct `.xcodeproj`
- Localizations are created in the Xcode project
- Languages exist in both Xcode and POEditor

## Development

### Clean and rebuild

```bash
make clean
make build
make install
```

Or all together:
```bash
make
```

### Run from source

```bash
swift run poeditor-sync --help
```

### Adding new dependencies

Edit `Package.swift` and add dependencies in the `dependencies` section.

## License

MIT

## Authors

Created for iOS development needs using POEditor as a translation management system.
