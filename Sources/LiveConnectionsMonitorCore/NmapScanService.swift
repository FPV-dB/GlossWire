import Foundation

public final class NmapScanService: @unchecked Sendable {
    private let fileManager: FileManager
    private var process: Process?

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public var isRunning: Bool {
        process?.isRunning == true
    }

    public func cancel() {
        process?.terminate()
    }

    public func commandPreview(arguments: [String], customPath: String) throws -> String {
        let path = try nmapPath(customPath: customPath)
        return ([path] + arguments).joined(separator: " ")
    }

    public func run(
        arguments: [String],
        customPath: String,
        output: @escaping @Sendable (String) -> Void
    ) async throws -> Int32 {
        guard let target = arguments.last, Self.isAllowedTarget(target) else {
            throw NmapScanError.publicTarget
        }

        let executablePath = try nmapPath(customPath: customPath)

        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .utility) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = arguments

                let stdout = Pipe()
                let stderr = Pipe()
                process.standardOutput = stdout
                process.standardError = stderr
                self.process = process

                let appendData: @Sendable (FileHandle) -> Void = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                    output(text)
                }
                stdout.fileHandleForReading.readabilityHandler = appendData
                stderr.fileHandleForReading.readabilityHandler = appendData

                do {
                    try process.run()
                } catch {
                    stdout.fileHandleForReading.readabilityHandler = nil
                    stderr.fileHandleForReading.readabilityHandler = nil
                    self.process = nil
                    throw NmapScanError.launchFailed(error.localizedDescription)
                }

                process.waitUntilExit()
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                self.process = nil
                return process.terminationStatus
            }.value
        } onCancel: {
            self.cancel()
        }
    }

    public func nmapPath(customPath: String) throws -> String {
        let trimmed = customPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = ([trimmed] + [
            "/opt/homebrew/bin/nmap",
            "/usr/local/bin/nmap",
            "/usr/bin/nmap"
        ]).filter { !$0.isEmpty }

        guard let match = candidates.first(where: { fileManager.isExecutableFile(atPath: $0) }) else {
            throw NmapScanError.nmapMissing
        }
        return match
    }

    public static func isAllowedTarget(_ rawValue: String) -> Bool {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value == "localhost" || value == "::1" { return true }
        let octets = value.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) else { return false }
        if octets[0] == 127 { return true }
        if octets[0] == 10 { return true }
        if octets[0] == 172 && (16...31).contains(octets[1]) { return true }
        if octets[0] == 192 && octets[1] == 168 { return true }
        return false
    }
}
