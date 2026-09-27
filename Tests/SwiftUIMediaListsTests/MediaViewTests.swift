import AppIntents
import SwiftUI
import Testing
@testable import SwiftUIMediaLists

struct MediaViewTests {
    @MainActor
    @Test func `Epic Stage and shelf views can be constructed`() {
        let first = MediaItem(id: "one", title: "One", artworkURL: URL(string: "https://example.com/one.jpg"))
        let second = MediaItem(id: "two", title: "Two")
        let stage = EpicStage(items: [first], overlay: { item in
            Text(item.badge ?? "Featured")
        }, onAction: { _, _ in })
        let shelf = MediaShelf(
            feed: MediaFeed(id: "series", title: "Series", kind: .landscape, items: [first, second]),
            overlay: { item in Text(item.title) },
            onAction: { _, _ in }
        )

        _ = stage.body
        _ = shelf.body
        let intentStage = EpicStage(items: [first], overlay: { _ in EmptyView() }, onAction: { _, _ in }, appIntentButton: { item, action in
            guard action == .play else { return nil }
            return AnyView(MediaActionButton(item: item, action: action, intent: TestPlayIntent(itemID: item.id), title: "Play", systemImage: "play.fill", prominent: true))
        })
        _ = intentStage.body
    }

    @MainActor
    @Test func `Intent button wraps a host intent`() {
        let item = MediaItem(id: "one", title: "One")
        let button = MediaActionButton(
            item: item,
            action: .play,
            intent: TestPlayIntent(itemID: item.id),
            title: "Play",
            systemImage: "play.fill",
            prominent: true
        )
        _ = button.body
        #expect(button.accessibilityLabel == "Play One")
        #expect(button.item.id == "one")
        #expect(button.action == .play)
    }
}

private struct TestPlayIntent: AppIntent {
    static let title: LocalizedStringResource = "Test Play"
    @Parameter(title: "Item ID") var itemID: String

    init() { itemID = "" }
    init(itemID: String) { self.itemID = itemID }

    func perform() async throws -> some IntentResult { .result() }
}
