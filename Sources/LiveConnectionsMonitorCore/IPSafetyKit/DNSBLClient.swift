import Foundation

public struct DNSBLClient: Sendable {
    public static let providers = [
        "zen.spamhaus.org",
        "bl.spamcop.net",
        "dnsbl.sorbs.net",
        "b.barracudacentral.org",
        "all.spamrats.com"
    ]

    public init() {}

    public func check(ip: String) async -> [DNSBLListing] {
        guard IPSafetyAddressClassifier.classify(ip) == .publicIPv4,
              let reversed = IPSafetyAddressClassifier.reversedIPv4(ip) else {
            return []
        }
        return await withTaskGroup(of: DNSBLListing.self) { group in
            for provider in Self.providers {
                group.addTask {
                    await Self.lookup(provider: provider, query: "\(reversed).\(provider)")
                }
            }
            var values: [DNSBLListing] = []
            for await value in group { values.append(value) }
            return values.sorted { $0.provider < $1.provider }
        }
    }

    private static func lookup(provider: String, query: String) async -> DNSBLListing {
        let executable = FileManager.default.isExecutableFile(atPath: "/usr/bin/dig") ? "/usr/bin/dig" : "/usr/bin/nslookup"
        let arguments = executable.hasSuffix("dig") ? ["+short", "A", query] : ["-type=A", query]
        do {
            let output = try await run(executable: executable, arguments: arguments)
            let lines = output.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let listed = lines.contains { $0.hasPrefix("127.") }
            return DNSBLListing(provider: provider, listed: listed, response: lines.joined(separator: "\n"), error: nil)
        } catch {
            return DNSBLListing(provider: provider, listed: false, response: nil, error: error.localizedDescription)
        }
    }

    static func run(executable: String, arguments: [String]) async throws -> String {
        try await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        }.value
    }
}
