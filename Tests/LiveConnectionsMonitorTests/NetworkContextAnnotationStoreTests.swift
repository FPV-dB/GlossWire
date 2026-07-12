import Foundation
import Testing
@testable import LiveConnectionsMonitorCore

@MainActor @Test func networkContextAnnotationsPersistAndRemainNonEnforcing() {
    let name = "GlossWireAnnotations-\(UUID().uuidString)"; let defaults = UserDefaults(suiteName: name)!; defer { defaults.removePersistentDomain(forName: name) }
    let store = NetworkContextAnnotationStore(defaults: defaults)
    store.setFavourite(true, for: "203.0.113.1"); store.setTrusted(true, for: "203.0.113.1"); store.setWatched(true, for: "203.0.113.1")
    store.setTags("work, dns", for: "203.0.113.1"); store.setNote("Expected resolver", for: "203.0.113.1")
    let restored = NetworkContextAnnotationStore(defaults: defaults).annotation(for: "203.0.113.1")
    #expect(restored.isFavourite && restored.isTrusted && restored.isWatched)
    #expect(restored.tags == ["work", "dns"])
    #expect(restored.note == "Expected resolver")
}
