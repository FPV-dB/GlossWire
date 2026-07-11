import Foundation

public struct TimelineBookmark: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public var title: String
    public init(id: UUID = UUID(), timestamp: Date, title: String) { self.id = id; self.timestamp = timestamp; self.title = title }
}

@MainActor
public final class TimelineBookmarkStore: ObservableObject {
    @Published public private(set) var bookmarks: [TimelineBookmark] = []
    private let defaults: UserDefaults
    private let key = "timeline.bookmarks.v1"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults; load() }
    public func add(at timestamp: Date, title: String? = nil) {
        bookmarks.append(TimelineBookmark(timestamp: timestamp, title: title ?? "Bookmark at \(timestamp.formatted(date: .abbreviated, time: .shortened))"))
        bookmarks.sort { $0.timestamp > $1.timestamp }; save()
    }
    public func remove(_ bookmark: TimelineBookmark) { bookmarks.removeAll { $0.id == bookmark.id }; save() }
    private func load() { if let data = defaults.data(forKey: key) { bookmarks = (try? JSONDecoder().decode([TimelineBookmark].self, from: data)) ?? [] } }
    private func save() { defaults.set(try? JSONEncoder().encode(bookmarks), forKey: key) }
}
