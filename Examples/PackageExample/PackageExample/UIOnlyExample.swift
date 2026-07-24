import SwiftUI
import SwiftChatCore
import SwiftChatUI

@MainActor
struct UIOnlyExample: View {
    @StateObject private var session = SwiftChatSession(
        provider: MockSwiftChatProvider(
            events: [
                .outputTextDelta("SwiftChatUI works without importing OpenAI."),
                .completed,
            ]
        ),
        configuration: SwiftChatConfiguration(
            presentationStyle: .sheet
        )
    )

    var body: some View {
        SwiftChatView(
            session: session,
            theme: SwiftChatTheme(accentColor: .orange)
        )
    }
}
