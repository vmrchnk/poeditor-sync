import Foundation
import ArgumentParser

struct POEditorSync: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "poeditor-sync",
        abstract: "Synchronize translations with POEditor",
        version: "1.0.0",
        subcommands: [UploadCommand.self, DownloadCommand.self]
    )
}

POEditorSync.main()
