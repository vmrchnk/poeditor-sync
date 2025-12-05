import Foundation

// MARK: - File System Service

struct FileSystemService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - File Existence

    func fileExists(atPath path: String) -> Bool {
        return fileManager.fileExists(atPath: path)
    }

    // MARK: - Directory Operations

    func createDirectory(atPath path: String, withIntermediateDirectories: Bool = true) throws {
        try fileManager.createDirectory(
            atPath: path,
            withIntermediateDirectories: withIntermediateDirectories,
            attributes: nil
        )
    }

    func createDirectory(at url: URL, withIntermediateDirectories: Bool = true) throws {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: withIntermediateDirectories,
            attributes: nil
        )
    }

    func ensureDirectoryExists(atPath path: String) throws {
        if !fileExists(atPath: path) {
            try createDirectory(atPath: path, withIntermediateDirectories: true)
        }
    }

    // MARK: - Removal Operations

    func removeItem(atPath path: String) throws {
        guard fileExists(atPath: path) else { return }
        try fileManager.removeItem(atPath: path)
    }

    func removeItem(at url: URL) throws {
        guard fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    // MARK: - Enumeration

    func findLanguageDirectories(inPath path: String) throws -> [String] {
        guard let enumerator = fileManager.enumerator(atPath: path) else {
            throw ValidationError("Failed to enumerate directory: \(path)")
        }

        var languages = Set<String>()

        for case let file as String in enumerator {
            if file.hasSuffix(".lproj") {
                let languageCode = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
                languages.insert(languageCode)
            }
        }

        return Array(languages).sorted()
    }

    // MARK: - File I/O

    func readData(atPath path: String) throws -> Data {
        let url = URL(fileURLWithPath: path)
        return try Data(contentsOf: url)
    }

    func readFile(atPath path: String) throws -> String {
        let data = try readData(atPath: path)
        guard let content = String(data: data, encoding: .utf8) else {
            throw ValidationError("Failed to decode file content as UTF-8: \(path)")
        }
        return content
    }

    func writeData(_ data: Data, toPath path: String) throws {
        let url = URL(fileURLWithPath: path)
        try data.write(to: url)
    }

    // MARK: - Temporary Directory

    func createTemporaryDirectory(prefix: String = "temp") throws -> URL {
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("\(prefix)_\(UUID().uuidString)")
        try createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
}
