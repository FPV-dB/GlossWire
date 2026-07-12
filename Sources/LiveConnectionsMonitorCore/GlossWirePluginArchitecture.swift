import Foundation

public enum GlossWirePluginCapability: String, CaseIterable, Codable, Sendable {
    case metadataCatalog, reverseDNS, geoIP, reputation, tlsInspection, serviceRecognition, reportExporter, networkDiscovery
}
public struct GlossWirePluginManifest: Identifiable, Codable, Hashable, Sendable {
    public let identifier: String; public let name: String; public let version: String; public let apiVersion: Int; public let capabilities: [GlossWirePluginCapability]
    public let executable: String?; public let minimumGlossWireVersion: String?; public var id: String { identifier }
}
public enum GlossWirePluginState: String, Codable, Sendable { case ready = "Ready", dataOnly = "Data only", unsigned = "Unsigned", invalid = "Invalid", incompatible = "Incompatible" }
public struct GlossWirePluginDescriptor: Identifiable, Hashable, Sendable {
    public var id: String { manifest.identifier }; public let manifest: GlossWirePluginManifest; public let directory: URL; public let state: GlossWirePluginState; public let teamIdentifier: String?; public let detail: String
}

public struct GlossWirePluginValidator: Sendable {
    public static let apiVersion = 1
    public init() {}
    public func validate(manifest: GlossWirePluginManifest, directory: URL) async -> GlossWirePluginDescriptor {
        guard manifest.apiVersion == Self.apiVersion, !manifest.identifier.isEmpty, !manifest.name.isEmpty else { return descriptor(manifest, directory, .incompatible, nil, "Unsupported API version or missing identity.") }
        guard Set(manifest.capabilities).count == manifest.capabilities.count else { return descriptor(manifest, directory, .invalid, nil, "Capabilities must be unique.") }
        guard let executable = manifest.executable else {
            let allowed: Set<GlossWirePluginCapability> = [.metadataCatalog, .serviceRecognition]
            return Set(manifest.capabilities).isSubset(of: allowed) ? descriptor(manifest, directory, .dataOnly, nil, "Declarative plugin; no code is loaded.") : descriptor(manifest, directory, .invalid, nil, "This capability requires a signed executable plugin.")
        }
        let candidate = directory.appendingPathComponent(executable).standardizedFileURL
        guard candidate.path.hasPrefix(directory.standardizedFileURL.path + "/"), FileManager.default.isExecutableFile(atPath: candidate.path) else { return descriptor(manifest, directory, .invalid, nil, "Executable is missing, not executable, or escapes the plugin directory.") }
        guard let result = try? await CommandRunner().run("/usr/bin/codesign", arguments: ["-dv", "--verbose=4", candidate.path]), result.exitCode == 0 else { return descriptor(manifest, directory, .unsigned, nil, "Executable code signature validation failed.") }
        let output = result.output + result.errorOutput
        let team = output.split(whereSeparator: \.isNewline).map(String.init).first { $0.hasPrefix("TeamIdentifier=") }?.split(separator: "=", maxSplits: 1).last.map(String.init)
        guard let team, !team.isEmpty, team != "not set" else { return descriptor(manifest, directory, .unsigned, nil, "A stable TeamIdentifier is required.") }
        return descriptor(manifest, directory, .ready, team, "Signature verified. Runtime execution remains isolated behind the plugin host boundary.")
    }
    private func descriptor(_ manifest: GlossWirePluginManifest, _ directory: URL, _ state: GlossWirePluginState, _ team: String?, _ detail: String) -> GlossWirePluginDescriptor { GlossWirePluginDescriptor(manifest: manifest, directory: directory, state: state, teamIdentifier: team, detail: detail) }
}

public actor GlossWirePluginRegistry {
    private let roots: [URL]
    public init(roots: [URL]? = nil) { if let roots { self.roots = roots } else { let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser; self.roots = [support.appendingPathComponent("GlossWire/Plugins", isDirectory: true), support.appendingPathComponent("Live Connections Monitor/Plugins", isDirectory: true)] } }
    public func discover() async -> [GlossWirePluginDescriptor] {
        var results: [GlossWirePluginDescriptor] = []; let decoder = JSONDecoder()
        for root in roots { let directories = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []; for directory in directories where directory.hasDirectoryPath { let url = directory.appendingPathComponent("plugin.json"); guard let data = try? Data(contentsOf: url), let manifest = try? decoder.decode(GlossWirePluginManifest.self, from: data) else { continue }; results.append(await GlossWirePluginValidator().validate(manifest: manifest, directory: directory)) } }
        return results.sorted { $0.manifest.name < $1.manifest.name }
    }
}

public protocol GlossWirePluginHostBoundary: Sendable {
    func request(pluginID: String, capability: GlossWirePluginCapability, payload: Data) async throws -> Data
}
