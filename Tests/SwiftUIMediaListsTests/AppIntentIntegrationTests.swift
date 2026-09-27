import AppIntents
import SwiftUI
import Testing
@testable import SwiftUIMediaLists

struct AppIntentIntegrationTests {
    @MainActor
    @Test func `Datasource exposes native intent controls`() {
        let item = MediaItem(id: "film-42", title: "Featured")
        let source = IntentDataSource(feeds: [
            MediaFeed(id: "featured", title: "Featured", kind: .promoted, items: [item])
        ])

        let intent = source.intent(for: item, action: .play)
        guard let intent else {
            Issue.record("Datasource should provide a Play intent")
            return
        }
        _ = intent.makeButton(label: AnyView(Text("Play")))
        #expect(source.requestedActions == ["film-42:play"])
    }
}

private struct PlayIntent: AppIntent {
    static let title: LocalizedStringResource = "Play Media"
    @Parameter(title: "Media ID") var mediaID: String

    init() { mediaID = "" }
    init(mediaID: String) { self.mediaID = mediaID }

    func perform() async throws -> some IntentResult { .result() }
}

@MainActor
private final class IntentDataSource: MediaListDataSource {
    private let snapshot: [MediaFeed]
    private(set) var requestedActions: [String] = []

    init(feeds: [MediaFeed]) { self.snapshot = feeds }

    func feeds() async throws -> [MediaFeed] { snapshot }
    func perform(_ action: MediaAction, for item: MediaItem) async throws { }

    func intent(for item: MediaItem, action: MediaAction) -> (any MediaActionIntent)? {
        requestedActions.append("\(item.id):\(action.accessibilityKey)")
        guard action == .play || action == .add || action == .select else { return nil }
        return AppIntentAction(PlayIntent(mediaID: item.id))
    }
}
