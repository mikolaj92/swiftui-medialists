import AppIntents
import SwiftUI

/// A SwiftUI button that runs a host-defined App Intent from a media-list control.
/// Keep the intent implementation in the app target and construct it here with its item parameters.
public struct MediaIntentButton<Intent: AppIntent, Label: View>: View {
    private let intent: Intent
    private let label: Label

    public init(intent: Intent, @ViewBuilder label: () -> Label) {
        self.intent = intent
        self.label = label()
    }

    public var body: some View {
        Button(intent: intent) { label }
    }
}

/// Type-erases a host-defined App Intent for automatic media-action mapping.
@MainActor public struct AppIntentAction<Intent: AppIntent>: MediaActionIntent {
    private let intent: Intent

    public init(_ intent: Intent) { self.intent = intent }

    public func makeButton(label: AnyView) -> AnyView {
        AnyView(MediaIntentButton(intent: intent) { label })
    }
}
