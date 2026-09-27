# SwiftUIMediaLists

Reusable SwiftUI media lists for iOS, tvOS, and macOS 26+. The library provides a featured Epic Stage and horizontal media shelves, populated by the host app.

## Design goal

An open SwiftUI implementation inspired by the media-browsing UI in Apple TV app. The goal is to compare the demo with the reference by geometry and behavior: hero layout, shelves, scrolling and parallax, native page indicators, and trailer previews. This is a media-list component, not a recreation of the full Apple TV app; host navigation and product-specific behavior stay with the host.

## Use

Add the `SwiftUIMediaLists` package product and provide a `MediaListDataSource`:

```swift
import SwiftUI
import SwiftUIMediaLists

struct Catalog: MediaListDataSource {
    func feeds() async throws -> [MediaFeed] {
        [MediaFeed(id: "featured", title: "Featured", kind: .promoted, items: items)]
    }

    func perform(_ action: MediaAction, for item: MediaItem) async throws {
        // Handle the action in the host app.
    }
}

struct HomeView: View {
    let catalog = Catalog()

    var body: some View {
        DataSourceMediaListsView(dataSource: catalog)
    }
}
```

For App Intents, return an `AppIntentAction` from `intent(for:action:)`. Actions without an intent go to `perform(_:for:)`. For preloaded data, use `MediaListsView(feeds:overlay:onAction:)`.

## Components

- `.promoted`: featured Epic Stage with native page-style paging when there are multiple items.
- `.landscape` and `.portrait`: horizontal media shelves.
- Optional item overlays for host-provided badges, progress, or metadata.
- Default loading, retry, empty, and artwork placeholders; shimmer respects Reduce Motion.
- Artwork loads with `AsyncImage`; trailer previews use `AVPlayer` when a preview URL is supplied.

The library renders media and routes actions. The host owns feed data, playback, watchlists, App Intents, and app navigation.

## Development

Run tests and build the library for each supported platform:

```sh
swift test
xcodebuild -scheme SwiftUIMediaLists -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme SwiftUIMediaLists -destination 'generic/platform=tvOS Simulator' build
xcodebuild -scheme SwiftUIMediaLists -destination 'generic/platform=macOS' build
```

The demo app is in `Demo/` and can be built with the `MediaListsDemo` scheme. Unit tests cover models, view construction, App Intent mapping, and consumer imports; they do not measure runtime frame rate or visual parity.
