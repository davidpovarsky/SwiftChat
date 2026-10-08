import SwiftUI
import SwiftChat

@main
struct PackageExampleApp: App {
    var body: some Scene {
        WindowGroup {
            PackageExampleRoot()
        }
    }
}

@MainActor
private struct PackageExampleRoot: View {
    @StateObject private var session: SwiftChatSession
    @State private var showsInspector = false
    @State private var showsUIOnly = false

    init() {
        let provider = MockSwiftChatProvider(
            events: [
                .reasoningDelta("Checking the package integration."),
                .outputTextDelta(
                    "This response is streamed by a provider-neutral mock. "
                ),
                .outputTextDelta("Replace it with OpenAIResponsesProvider for production."),
                .completed,
            ]
        )
        _session = StateObject(
            wrappedValue: SwiftChatSession(
                provider: provider,
                configuration: SwiftChatConfiguration(
                    presentationStyle: .embedded
                ),
                store: InMemoryConversationStore(),
                context: SwiftChatHostContext(
                    title: "Package Example",
                    subtitle: "Embedded host context",
                    selectedText: "Text selected in the host application",
                    sourceIdentifier: "package-example",
                    metadata: ["mode": "demo"]
                )
            )
        )
    }

    var body: some View {
        NavigationStack {
            SwiftChatView(
                session: session,
                theme: SwiftChatTheme(accentColor: .purple)
            )
            .navigationTitle("SwiftChat Package")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("UI only") { showsUIOnly = true }
                    Button("Inspector") { showsInspector = true }
                }
            }
            .safeAreaInset(edge: .bottom) {
                CustomToolCardExample()
                    .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showsUIOnly) {
            UIOnlyExample()
        }
        .inspector(isPresented: $showsInspector) {
            SwiftChatView(session: session)
                .inspectorColumnWidth(min: 320, ideal: 420, max: 560)
        }
    }
}

/// A production composition root can use the same UI with the real adapter.
@MainActor
private func makeOpenAISessionFromEnvironment() -> SwiftChatSession? {
    guard let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
          !key.isEmpty else {
        return nil
    }
    let provider = OpenAIResponsesProvider(
        configuration: OpenAIProviderConfiguration(apiKey: key)
    )
    return SwiftChatSession(
        provider: provider,
        transcriptionProvider: provider
    )
}
