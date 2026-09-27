import AppIntents
import SwiftUI

/// Adapts a host-created App Intent to a media action button.
public struct MediaActionButton<Intent: AppIntent>: View {
    public let item: MediaItem
    public let action: MediaAction
    private let intent: Intent
    private let title: LocalizedStringKey
    private let systemImage: String
    private let prominent: Bool

    public var accessibilityLabel: String {
        switch action {
        case .play: "Play \(item.title)"
        case .add: "Add \(item.title)"
        case .select: "Select \(item.title)"
        case .custom(let name): "\(name) \(item.title)"
        }
    }

    public init(
        item: MediaItem,
        action: MediaAction,
        intent: Intent,
        title: LocalizedStringKey,
        systemImage: String,
        prominent: Bool = false
    ) {
        self.item = item
        self.action = action
        self.intent = intent
        self.title = title
        self.systemImage = systemImage
        self.prominent = prominent
    }

    @ViewBuilder public var body: some View {
        if prominent {
            MediaIntentButton(intent: intent) {
                Label(title, systemImage: systemImage)
            }
            .accessibilityIdentifier("media-action-\(action.accessibilityKey)-\(item.id)")
            .accessibilityLabel(accessibilityLabel)
            .buttonStyle(.borderedProminent)
        } else {
            MediaIntentButton(intent: intent) {
                Label(title, systemImage: systemImage)
            }
            .accessibilityIdentifier("media-action-\(action.accessibilityKey)-\(item.id)")
            .accessibilityLabel(accessibilityLabel)
            .buttonStyle(.bordered)
        }
    }
}
