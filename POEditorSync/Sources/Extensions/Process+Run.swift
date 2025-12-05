import Foundation

extension Process {
    /// Executes a command and returns its output or throws an error if it fails
    @discardableResult
    static func run(_ executable: String, arguments: [String], verbose: Bool = false) throws -> String {
        let startTime = Date()

        // Log command if verbose
        if verbose {
            let command = "\(executable) \(arguments.joined(separator: " "))"
            print("  🔧 Running command: \(command)")
            print("  ⏰ Started at: \(DateFormatter.localizedString(from: startTime, dateStyle: .none, timeStyle: .medium))")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        var outputData = Data()
        var errorData = Data()

        // Read output in real-time if verbose
        if verbose {
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    outputData.append(data)
                    if let string = String(data: data, encoding: .utf8) {
                        print(string, terminator: "")
                        fflush(stdout)
                    }
                }
            }

            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    errorData.append(data)
                    if let string = String(data: data, encoding: .utf8) {
                        print(string, terminator: "")
                        fflush(stdout)
                    }
                }
            }
        }

        try process.run()
        process.waitUntilExit()

        // Close handlers
        if verbose {
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
        }

        // Read remaining data if not verbose
        if !verbose {
            outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        }

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        let combinedOutput = output + error

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        if verbose {
            print("  ⏱️  Completed in \(String(format: "%.1f", duration))s")
        }

        guard process.terminationStatus == 0 else {
            throw ValidationError("\(executable) failed with status \(process.terminationStatus): \(combinedOutput)")
        }

        return combinedOutput
    }
}
