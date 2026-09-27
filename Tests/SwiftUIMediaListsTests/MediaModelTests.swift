import Testing
@testable import SwiftUIMediaLists

struct MediaModelTests {
    @Test func `Feed retains its items and kind`() {
        let item = MediaItem(id: "show-1", title: "A Show", artworkAspectRatio: 2.0 / 3.0)
        let feed = MediaFeed(id: "top", title: "Top Picks", kind: .portrait, items: [item])
        #expect(feed.items.first?.id == "show-1")
        #expect(feed.kind == .portrait)
        #expect(feed.items.first?.artworkAspectRatio == 2.0 / 3.0)
    }

    @Test func `Semantic action can be routed by host`() {
        #expect(MediaAction.custom("openDetails") == .custom("openDetails"))
    }

    @Test func `Datasource store loads feeds and forwards actions`() async throws {
        let item = MediaItem(id: "movie-1", title: "Film")
        let source = TestMediaDataSource(feeds: [
            MediaFeed(id: "featured", title: "Featured", kind: .promoted, items: [item])
        ])
        let store = await MainActor.run { MediaListStore(dataSource: source) }

        await store.load()
        let loadedIDs = await MainActor.run { store.feeds.map(\.id) }
        #expect(loadedIDs == ["featured"])

        try await store.perform(.play, for: item)
        #expect(await source.recordedActions() == ["play:movie-1"])
    }
}

private actor TestMediaDataSource: MediaListDataSource {
    private let snapshot: [MediaFeed]
    private var actions: [String] = []

    init(feeds: [MediaFeed]) { self.snapshot = feeds }

    func feeds() async throws -> [MediaFeed] { snapshot }

    func perform(_ action: MediaAction, for item: MediaItem) async throws {
        let name: String
        switch action {
        case .play: name = "play"
        case .add: name = "add"
        case .select: name = "select"
        case .custom(let value): name = value
        }
        actions.append("\(name):\(item.id)")
    }

    func recordedActions() -> [String] { actions }
}
