import AppIntents
import SwiftUI
import SwiftUIMediaLists

@main
struct MediaListsDemoApp: App {
    var body: some Scene {
        WindowGroup { DemoHomeView() }
    }
}

struct DemoHomeView: View {
    private let source = DemoDataSource()

    var body: some View {
        DataSourceMediaListsView(dataSource: source, overlay: { item in
            if let rank = item.overlayValues["rank"] {
                Text(rank).font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white).padding(8)
                    .background(.black.opacity(0.55), in: Circle())
            }
        })
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}

struct DemoDataSource: MediaListDataSource {
    private static let items = (0..<40).map { index in
        MediaItem(
            id: "title-\(index)",
            title: ["The Far Shore", "Night Signals", "Paper Kingdom", "Blue Meridian", "After the Rain"][index % 5] + " \(index + 1)",
            synopsis: "A journey beyond the familiar, where every choice changes what comes next.",
            badge: index.isMultiple(of: 3) ? "NEW" : nil,
            kindLabel: "Drama",
            rating: "TV-14",
            artworkURL: URL(string: "https://picsum.photos/seed/swiftui-media-\(index)/960/540"),
            previewURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4"),
            overlayValues: ["rank": "\(index + 1)"]
        )
    }

    func feeds() async throws -> [MediaFeed] {
        try await Task.sleep(for: .seconds(2))
        return [
            MediaFeed(id: "featured", title: "Featured", kind: .promoted, items: Array(Self.items.prefix(4))),
            MediaFeed(id: "continue", title: "Continue Watching", kind: .landscape, items: Array(Self.items.suffix(12))),
            MediaFeed(id: "trending", title: "Trending Now", kind: .landscape, items: Self.items),
            MediaFeed(id: "new", title: "New & Noteworthy", kind: .landscape, items: Array(Self.items.reversed())),
            MediaFeed(id: "popular", title: "Popular Series", kind: .portrait, items: Self.items),
            MediaFeed(id: "movies", title: "Movies for You", kind: .portrait, items: Array(Self.items.suffix(24))),
            MediaFeed(id: "classics", title: "Classics", kind: .landscape, items: Array(Self.items.prefix(20)))
        ]
    }

    func perform(_ action: MediaAction, for item: MediaItem) async throws {
        print("Fallback action: \(action.accessibilityKey) on \(item.id)")
    }

    @MainActor func intent(for item: MediaItem, action: MediaAction) -> (any MediaActionIntent)? {
        switch action {
        case .play: AppIntentAction(DemoPlayIntent(mediaID: item.id))
        case .add: AppIntentAction(DemoAddIntent(mediaID: item.id))
        case .select: nil
        case .custom: nil
        }
    }
}

struct DemoPlayIntent: AppIntent {
    static let title: LocalizedStringResource = "Play Media"
    @Parameter(title: "Media ID") var mediaID: String
    init() { mediaID = "" }
    init(mediaID: String) { self.mediaID = mediaID }
    func perform() async throws -> some IntentResult {
        print("Play intent for \(mediaID)")
        return .result()
    }
}

struct DemoAddIntent: AppIntent {
    static let title: LocalizedStringResource = "Add to Watchlist"
    @Parameter(title: "Media ID") var mediaID: String
    init() { mediaID = "" }
    init(mediaID: String) { self.mediaID = mediaID }
    func perform() async throws -> some IntentResult {
        print("Add intent for \(mediaID)")
        return .result()
    }
}
