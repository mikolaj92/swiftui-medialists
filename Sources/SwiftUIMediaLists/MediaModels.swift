import Foundation
import Observation
import SwiftUI

/// A collection of media presented together in a shelf or featured stage.
public struct MediaFeed: Identifiable, Sendable, Hashable {
    public enum Kind: String, Sendable, Hashable {
        case promoted
        case landscape
        case portrait
    }

    public let id: String
    public var title: String
    public var kind: Kind
    public var items: [MediaItem]

    public init(id: String, title: String, kind: Kind, items: [MediaItem]) {
        self.id = id
        self.title = title
        self.kind = kind
        self.items = items
    }
}

/// Media metadata and remote/local artwork supplied by the host application.
public struct MediaItem: Identifiable, Sendable, Hashable {
    public let id: String
    public var title: String
    public var subtitle: String?
    public var synopsis: String?
    public var badge: String?
    public var kindLabel: String?
    public var rating: String?
    public var artworkURL: URL?
    public var previewURL: URL?
    public var artworkAspectRatio: Double
    /// Optional rank/progress/availability metadata for host-defined overlays.
    public var overlayValues: [String: String]

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        synopsis: String? = nil,
        badge: String? = nil,
        kindLabel: String? = nil,
        rating: String? = nil,
        artworkURL: URL? = nil,
        previewURL: URL? = nil,
        artworkAspectRatio: Double = 16.0 / 9.0,
        overlayValues: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.synopsis = synopsis
        self.badge = badge
        self.kindLabel = kindLabel
        self.rating = rating
        self.artworkURL = artworkURL
        self.previewURL = previewURL
        self.artworkAspectRatio = artworkAspectRatio
        self.overlayValues = overlayValues
    }
}

/// The host owns loading, persistence and refresh policy; the library consumes snapshots.
public protocol MediaListDataSource: Sendable {
    func feeds() async throws -> [MediaFeed]
    func perform(_ action: MediaAction, for item: MediaItem) async throws
    /// Optionally bind a semantic action to the host's concrete App Intent button.
    @MainActor func intent(for item: MediaItem, action: MediaAction) -> (any MediaActionIntent)?

    /// Optionally supply a custom native App Intent-backed button for an item/action.
    /// `nil` selects the automatic intent mapping, then the datasource callback fallback.
    @MainActor func appIntentButton(for item: MediaItem, action: MediaAction) -> AnyView?
}

public extension MediaListDataSource {
    @MainActor func intent(for item: MediaItem, action: MediaAction) -> (any MediaActionIntent)? { nil }
    @MainActor func appIntentButton(for item: MediaItem, action: MediaAction) -> AnyView? { nil }
}

/// Type-erased host intent that can be executed by SwiftUI's native `Button(intent:)`.
@MainActor public protocol MediaActionIntent {
    func makeButton(label: AnyView) -> AnyView
}

/// Semantic actions are intentionally data-only so hosts can route them to App Intents.
public enum MediaAction: Sendable, Hashable {
    case play
    case add
    case select
    case custom(String)

    public var accessibilityKey: String {
        switch self {
        case .play: "play"
        case .add: "add"
        case .select: "select"
        case .custom(let key): key
        }
    }
}

/// Loads feed snapshots and routes UI actions through the host-provided datasource.
@MainActor @Observable
public final class MediaListStore {
    public private(set) var feeds: [MediaFeed] = []
    public private(set) var loading = true
    public private(set) var error: (any Error)?
    private let dataSource: any MediaListDataSource

    public init(dataSource: any MediaListDataSource) {
        self.dataSource = dataSource
    }

    public func load() async {
        loading = true
        defer { loading = false }
        do {
            feeds = try await dataSource.feeds()
            error = nil
        } catch {
            self.error = error
        }
    }

    public func perform(_ action: MediaAction, for item: MediaItem) async throws {
        try await dataSource.perform(action, for: item)
    }
}
