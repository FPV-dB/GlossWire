import Foundation

public struct ProcessHierarchyEntry: Identifiable, Hashable, Sendable { public var id: Int { pid }; public let pid: Int; public let parentPID: Int; public let command: String }
public struct ProcessConnectionNode: Identifiable, Hashable, Sendable { public var id: Int { process.pid }; public let process: ProcessHierarchyEntry; public let depth: Int; public let connectionCount: Int; public let destinations: Int }
public struct ProcessFlowEdge: Identifiable, Hashable, Sendable { public var id: String { process + "|" + destination }; public let process: String; public let destination: String; public let count: Int }

public struct ProcessHierarchyService: Sendable {
    public init() {}
    public func snapshot() async -> [ProcessHierarchyEntry] { guard let result = try? await CommandRunner().run("/bin/ps", arguments: ["-axo", "pid=,ppid=,comm="]), result.exitCode == 0 else { return [] }; return Self.parse(result.output) }
    public static func parse(_ text: String) -> [ProcessHierarchyEntry] { text.split(whereSeparator: \.isNewline).compactMap { line in let parts = line.split(maxSplits: 2, whereSeparator: \.isWhitespace).map(String.init); guard parts.count == 3, let pid = Int(parts[0]), let parent = Int(parts[1]) else { return nil }; return ProcessHierarchyEntry(pid: pid, parentPID: parent, command: parts[2]) } }
}
public struct InvestigationVisualAnalyzer: Sendable {
    public init() {}
    public func processNodes(processes: [ProcessHierarchyEntry], records: [AppConnectionRecord]) -> [ProcessConnectionNode] {
        let byPID = Dictionary(uniqueKeysWithValues: processes.map { ($0.pid, $0) }), grouped = Dictionary(grouping: records, by: \.pid)
        return grouped.compactMap { pid, values in guard let process = byPID[pid] else { return nil }; var depth = 0, cursor = process.parentPID, visited = Set<Int>(); while let parent = byPID[cursor], !visited.contains(cursor), depth < 12 { visited.insert(cursor); depth += 1; cursor = parent.parentPID }; return ProcessConnectionNode(process: process, depth: depth, connectionCount: values.count, destinations: Set(values.compactMap(\.remoteAddress)).count) }.sorted { $0.process.command < $1.process.command }
    }
    public func flowEdges(records: [AppConnectionRecord], limit: Int = 40) -> [ProcessFlowEdge] {
        let grouped = Dictionary(grouping: records.filter { $0.remoteAddress != nil }) { record in let destination = record.remoteHostname.flatMap { $0.isEmpty ? nil : $0 } ?? record.remoteAddress!; return record.appBundleIdentifier + "|" + destination }
        return grouped.map { key, values in let split = key.split(separator: "|", maxSplits: 1).map(String.init); return ProcessFlowEdge(process: split[0], destination: split.count > 1 ? split[1] : "Unknown", count: values.count) }.sorted { $0.count > $1.count }.prefix(limit).map { $0 }
    }
}

@MainActor public final class InvestigationVisualsViewModel: ObservableObject {
    @Published public private(set) var processes: [ProcessHierarchyEntry] = []
    public func refresh() async { processes = await ProcessHierarchyService().snapshot() }
}
