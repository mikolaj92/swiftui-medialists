import SwiftUI
import AVKit

/// Plug-and-play datasource-backed lists with sensible loading and error defaults.
/// Actions without a native App Intent button are sent to `dataSource.perform`.
public struct DataSourceMediaListsView: View {
    @State private var store: MediaListStore
    private let overlay: (MediaItem) -> AnyView
    private let failureView: (any Error, @escaping () -> Void) -> AnyView
    private let intentButton: ((MediaItem, MediaAction) -> AnyView?)?

    public init(
        dataSource: any MediaListDataSource,
        @ViewBuilder overlay: @escaping (MediaItem) -> some View = { _ in EmptyView() },
        failure: ((any Error, @escaping () -> Void) -> AnyView)? = nil,
        appIntentButton: ((MediaItem, MediaAction) -> AnyView?)? = nil,
        intentButton: ((MediaItem, MediaAction) -> AnyView?)? = nil
    ) {
        _store = State(initialValue: MediaListStore(dataSource: dataSource))
        self.overlay = { AnyView(overlay($0)) }
        self.failureView = failure ?? { error, retry in AnyView(VStack(spacing: 12) {
            Text(error.localizedDescription)
            Button("Retry", action: retry)
        }.padding()) }
        self.intentButton = appIntentButton ?? intentButton ?? { item, action in
            if let button = dataSource.appIntentButton(for: item, action: action) { return button }
            guard let intent = dataSource.intent(for: item, action: action) else { return nil }
            let label: AnyView
            switch action {
            case .play: label = AnyView(Label("Play", systemImage: "play.fill"))
            case .add: label = AnyView(Label("Add", systemImage: "plus"))
            case .select: label = AnyView(Label("Select", systemImage: "play.rectangle"))
            case .custom(let title): label = AnyView(Text(title))
            }
            return intent.makeButton(label: label)
        }
    }

    public var body: some View {
        Group {
            if let error = store.error, store.feeds.isEmpty {
                failureView(error) { Task { await store.load() } }
            } else if store.feeds.isEmpty {
                Color.clear
            } else {
                MediaListsView(feeds: store.feeds, overlay: overlay, onAction: { item, action in
                    Task { try? await store.perform(action, for: item) }
                }, intentButton: intentButton)
            }
        }
        .overlay {
            if store.loading && store.feeds.isEmpty {
                FeedLoadingPlaceholder()
                    .ignoresSafeArea()
                    .accessibilityIdentifier("media-feed-loading-surface")
            }
        }
        .task { await store.load() }
    }
}

/// Renders feed snapshots with a host-supplied overlay and action handling.
public struct MediaListsView<Overlay: View>: View {
    public let feeds: [MediaFeed]
    private let overlay: (MediaItem) -> Overlay
    private let action: (MediaItem, MediaAction) -> Void
    private let intentButton: ((MediaItem, MediaAction) -> AnyView?)?

    public init(
        feeds: [MediaFeed],
        @ViewBuilder overlay: @escaping (MediaItem) -> Overlay,
        onAction: @escaping (MediaItem, MediaAction) -> Void,
        appIntentButton: ((MediaItem, MediaAction) -> AnyView?)? = nil,
        intentButton: ((MediaItem, MediaAction) -> AnyView?)? = nil
    ) {
        self.feeds = feeds
        self.overlay = overlay
        self.action = onAction
        self.intentButton = appIntentButton ?? intentButton
    }

    public var body: some View {
        GeometryReader { viewport in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(feeds) { feed in
                        if feed.kind == .promoted {
                            EpicStage(items: feed.items, overlay: overlay, onAction: action, intentButton: intentButton)
                                .frame(height: viewport.size.height * 0.52)
                                .clipped()
                        } else {
                            MediaShelf(feed: feed, overlay: overlay, onAction: action, intentButton: intentButton)
                        }
                    }
                }
                .padding(.vertical)
            }
            .coordinateSpace(name: "mediaListsScroll")
        }
        .background(Color(red: 0.10, green: 0.10, blue: 0.10))
    }
}

public struct EpicStage<Overlay: View>: View {
    public let items: [MediaItem]
    private let overlay: (MediaItem) -> Overlay
    private let onAction: (MediaItem, MediaAction) -> Void
    private let intentButton: ((MediaItem, MediaAction) -> AnyView?)?
    @State private var selectedID: MediaItem.ID?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var trailerItemID: MediaItem.ID?
    @State private var isVisible = false

    public init(items: [MediaItem], @ViewBuilder overlay: @escaping (MediaItem) -> Overlay,
                onAction: @escaping (MediaItem, MediaAction) -> Void,
                appIntentButton: ((MediaItem, MediaAction) -> AnyView?)? = nil,
                intentButton: ((MediaItem, MediaAction) -> AnyView?)? = nil) {
        self.items = items
        self.overlay = overlay
        self.onAction = onAction
        self.intentButton = appIntentButton ?? intentButton
    }

    private var current: MediaItem? {
        items.first(where: { $0.id == selectedID }) ?? items.first
    }

    public var body: some View {
        Group {
            if items.isEmpty {
                Color.black
            } else if items.count == 1, let item = items.first {
                stage(item)
            } else {
                TabView(selection: $selectedID) {
                    ForEach(items) { item in stage(item).tag(Optional(item.id)) }
                }
                #if os(iOS) || os(tvOS)
                .tabViewStyle(.page)
                #if os(tvOS)
                .focusSection()
                #endif
                #endif
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear { isVisible = true }
        .onDisappear {
            isVisible = false
            trailerItemID = nil
        }
        .task(id: current?.id) {
            trailerItemID = nil
            guard isVisible, let current, current.previewURL != nil else { return }
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, isVisible else { return }
            trailerItemID = current.id
        }
    }

    private func stage(_ item: MediaItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            EpicStageArtwork(item: item, trailerURL: trailerItemID == item.id ? item.previewURL : nil)
            VStack(alignment: .leading, spacing: horizontalSizeClass == .compact ? 7 : 10) {
                overlay(item)
                if let badge = item.badge {
                    Text(badge).font(.caption.bold()).padding(7).background(.white.opacity(0.2), in: Capsule())
                }
                Text(item.title)
                    .font((horizontalSizeClass == .compact ? Font.title : .largeTitle).bold())
                    .lineLimit(1)
                if let details = [item.kindLabel, item.rating].compactMap({ $0 }).joined(separator: " · ").nilIfEmpty {
                    Text(details).foregroundStyle(.secondary)
                }
                if let synopsis = item.synopsis {
                    Text(synopsis)
                        .font(horizontalSizeClass == .compact ? .subheadline : .body)
                        .lineLimit(horizontalSizeClass == .compact ? 1 : 2)
                        .frame(maxWidth: horizontalSizeClass == .compact ? 340 : 600, alignment: .leading)
                }
                EpicStageActions(item: item, onAction: onAction, intentButton: intentButton)
            }
            .padding(.leading, horizontalSizeClass == .compact ? 24 : 52)
            .padding(.bottom, horizontalSizeClass == .compact ? 90 : 104)
        }
        .foregroundStyle(.white)
    }

}

private struct EpicStageActions: View {
    let item: MediaItem
    let onAction: (MediaItem, MediaAction) -> Void
    let intentButton: ((MediaItem, MediaAction) -> AnyView?)?

    var body: some View {
        HStack {
            actionButton(.play)
            actionButton(.add)
        }
    }

    @ViewBuilder private func actionButton(_ action: MediaAction) -> some View {
        if let intentButton, let intentView = intentButton(item, action) {
            intentView
                .accessibilityIdentifier("media-action-\(action.accessibilityKey)-\(item.id)")
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .controlSize(.large)
        } else {
            Button { onAction(item, action) } label: {
                if action == .play { Label("Play", systemImage: "play.fill") }
                else { Image(systemName: "plus") }
            }
            .accessibilityIdentifier("media-action-\(action.accessibilityKey)-\(item.id)")
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
            .controlSize(.large)
        }
    }
}

public struct MediaShelf<Overlay: View>: View {
    public let feed: MediaFeed
    private let overlay: (MediaItem) -> Overlay
    private let onAction: (MediaItem, MediaAction) -> Void
    private let intentButton: ((MediaItem, MediaAction) -> AnyView?)?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public init(feed: MediaFeed, @ViewBuilder overlay: @escaping (MediaItem) -> Overlay,
                onAction: @escaping (MediaItem, MediaAction) -> Void,
                appIntentButton: ((MediaItem, MediaAction) -> AnyView?)? = nil,
                intentButton: ((MediaItem, MediaAction) -> AnyView?)? = nil) {
        self.feed = feed
        self.overlay = overlay
        self.onAction = onAction
        self.intentButton = appIntentButton ?? intentButton
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(feed.title).font(.title2.bold()).padding(.horizontal)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 16) {
                    ForEach(feed.items) { item in
                        MediaShelfCard(item: item, feed: feed, overlay: overlay, onAction: onAction, intentButton: intentButton)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var itemsPerContainer: CGFloat {
        let regular = horizontalSizeClass == .regular
        switch (feed.kind, regular) {
        case (.portrait, false): return 3.5
        case (.portrait, true): return 6.5
        case (.landscape, false): return 2.5
        case (.landscape, true): return 3.5
        case (.promoted, _): return 1
        }
    }

    private var cardAspectRatio: CGFloat {
        feed.kind == .portrait ? 2.0 / 3.0 : 16.0 / 9.0
    }

}

private struct MediaShelfCard<Overlay: View>: View {
    let item: MediaItem
    let feed: MediaFeed
    let overlay: (MediaItem) -> Overlay
    let onAction: (MediaItem, MediaAction) -> Void
    let intentButton: ((MediaItem, MediaAction) -> AnyView?)?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var itemsPerContainer: CGFloat {
        let regular = horizontalSizeClass == .regular
        switch (feed.kind, regular) {
        case (.portrait, false): return 3.5
        case (.portrait, true): return 6.5
        case (.landscape, false): return 2.5
        case (.landscape, true): return 3.5
        case (.promoted, _): return 1
        }
    }

    private var cardAspectRatio: CGFloat {
        feed.kind == .portrait ? 2.0 / 3.0 : 16.0 / 9.0
    }

    private var card: some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkView(item: item)
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 5) {
                overlay(item)
                Text(item.title).font(.headline).lineLimit(2)
            }
            .padding(12)
            .foregroundStyle(.white)
        }
        .containerRelativeFrame(.horizontal) { length, _ in length / itemsPerContainer }
        .aspectRatio(cardAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("media-card-\(item.id)")
    }

    @ViewBuilder var body: some View {
        if let intentButton, let intentView = intentButton(item, .select) {
            intentView
                .containerRelativeFrame(.horizontal) { length, _ in length / itemsPerContainer }
                .aspectRatio(cardAspectRatio, contentMode: .fit)
                .accessibilityIdentifier("media-action-select-\(item.id)")
                #if os(tvOS)
                .buttonStyle(.card)
                #else
                .buttonStyle(.plain)
                #endif
        } else {
            Button { onAction(item, .select) } label: { card }
                .accessibilityIdentifier("media-action-select-\(item.id)")
                #if os(tvOS)
                .buttonStyle(.card)
                #else
                .buttonStyle(.plain)
                #endif
        }
    }
}

private struct EpicStageArtwork: View {
    let item: MediaItem
    let trailerURL: URL?

    var body: some View {
        GeometryReader { geometry in
            let minY = geometry.frame(in: .named("mediaListsScroll")).minY
            ArtworkView(item: item)
                .scaleEffect(1.12)
                .offset(y: minY > 0 ? -minY * 0.18 : 0)
                .overlay {
                    if let trailerURL { TrailerPreview(url: trailerURL) }
                }
                .overlay {
                    LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                }
        }
    }
}

private struct TrailerPreview: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .onAppear { player.play() }
                    .onDisappear { player.pause() }
            }
        }
        .task(id: url) {
            player?.pause()
            player = AVPlayer(url: url)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ArtworkView: View {
    let item: MediaItem
    var body: some View {
        AsyncImage(url: item.artworkURL, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill()
            case .empty, .failure: ShimmerPlaceholder()
            @unknown default: ShimmerPlaceholder()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.25))
        .clipped()
    }
}

/// One full-page skeleton that mirrors the hero and shelf hierarchy without mounting feeds.
private struct FeedLoadingPlaceholder: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                RoundedRectangle(cornerRadius: 14)
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 10) {
                            RoundedRectangle(cornerRadius: 4).frame(width: 220, height: 30)
                            RoundedRectangle(cornerRadius: 4).frame(width: 320, height: 14)
                            HStack(spacing: 12) {
                                Capsule().frame(width: 110, height: 36)
                                Capsule().frame(width: 90, height: 36)
                            }
                        }
                        .padding(32)
                    }
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)

                ForEach(0..<5, id: \.self) { row in
                    VStack(alignment: .leading, spacing: 12) {
                        RoundedRectangle(cornerRadius: 4)
                            .frame(width: row < 3 ? 190 : 150, height: 22)
                            .padding(.horizontal)
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 16) {
                                ForEach(0..<5, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 10)
                                        .aspectRatio(row < 3 ? 16.0 / 9.0 : 2.0 / 3.0, contentMode: .fit)
                                        .frame(width: row < 3 ? 280 : 150)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .foregroundStyle(.white.opacity(0.12))
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
    }
}

private struct ShimmerPlaceholder: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            GeometryReader { proxy in
                Rectangle().fill(Color.gray.opacity(0.28)).overlay {
                    let phase = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
                    LinearGradient(colors: [.clear, .white.opacity(0.22), .clear], startPoint: .leading, endPoint: .trailing)
                        .rotationEffect(.degrees(-18))
                        .offset(x: (phase * 2 - 1) * proxy.size.width * 1.5)
                }
                .clipped()
            }
        }
        .accessibilityHidden(true)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
