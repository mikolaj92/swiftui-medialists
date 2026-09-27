import AppIntents
import SwiftUI
import Testing
import SwiftUIMediaLists

/// Intentionally imports only the published main product, mirroring a client target's imports.
struct ConsumerAppIntentTests {
    @MainActor
    @Test func `Main product exports native App Intent adapter`() {
        let intent = ConsumerPlayIntent(mediaID: "consumer-title")
        let adapter: any MediaActionIntent = AppIntentAction(intent)
        _ = adapter.makeButton(label: AnyView(Label("Play", systemImage: "play.fill")))
    }
}

private struct ConsumerPlayIntent: AppIntent {
    static let title: LocalizedStringResource = "Consumer Play"
    @Parameter(title: "Media ID") var mediaID: String

    init() { mediaID = "" }
    init(mediaID: String) { self.mediaID = mediaID }

    func perform() async throws -> some IntentResult { .result() }
}
