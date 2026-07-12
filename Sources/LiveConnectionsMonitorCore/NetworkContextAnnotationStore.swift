import Foundation

public struct NetworkContextAnnotation: Codable, Hashable, Sendable {
    public var tags: [String] = []; public var note = ""; public var isFavourite = false; public var isTrusted = false; public var isWatched = false
}

@MainActor public final class NetworkContextAnnotationStore: ObservableObject {
    @Published public private(set) var annotations: [String: NetworkContextAnnotation] = [:]
    private let defaults: UserDefaults; private let key = "networkContext.annotations.v1"
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults; if let data = defaults.data(forKey: key) { annotations = (try? JSONDecoder().decode([String: NetworkContextAnnotation].self, from: data)) ?? [:] } }
    public func annotation(for id: String) -> NetworkContextAnnotation { annotations[id] ?? NetworkContextAnnotation() }
    public func setFavourite(_ value: Bool, for id: String) { update(id) { $0.isFavourite = value } }
    public func setTrusted(_ value: Bool, for id: String) { update(id) { $0.isTrusted = value } }
    public func setWatched(_ value: Bool, for id: String) { update(id) { $0.isWatched = value } }
    public func setNote(_ value: String, for id: String) { update(id) { $0.note = value } }
    public func setTags(_ value: String, for id: String) { update(id) { $0.tags = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } } }
    private func update(_ id: String, _ body: (inout NetworkContextAnnotation) -> Void) { var value = annotation(for: id); body(&value); if value == NetworkContextAnnotation() { annotations.removeValue(forKey: id) } else { annotations[id] = value }; defaults.set(try? JSONEncoder().encode(annotations), forKey: key) }
}
