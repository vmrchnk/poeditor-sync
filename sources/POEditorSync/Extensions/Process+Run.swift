import Foundation

extension Process {
    /// Executes a command and returns its output or throws an error if it fails
    @discardableResult
    static func run(_ executable: String, arguments: [String], verbose: Bool = false) throws -> String {
        // Log command if verbose
        if verbose {
            let command = "\(executable) \(arguments.joined(separator: " "))"
            print("  🔧 Running command: \(command)")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw ValidationError("\(executable) failed with status \(process.terminationStatus): \(output)")
        }

        return output
    }
}
