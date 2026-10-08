# SwiftChat public API

SwiftChat exposes four products:

- `SwiftChatCore`: provider-neutral models, requests, stream events, storage,
  host context, and tool contracts.
- `SwiftChatUI`: the original SwiftChat interface and controller, adapted for
  dependency injection.
- `SwiftChatOpenAI`: the original OpenAI-compatible Responses API and Whisper
  behavior.
- `SwiftChat`: an umbrella product that re-exports all three modules.

The complete UI supports iOS 18 and later. The manifest declares macOS 15 so
Core-only validation can resolve all package dependencies on macOS; the
upstream UIKit UI is not a macOS interface.

## Full OpenAI chat

```swift
import SwiftUI
import SwiftChat

struct ContentView: View {
    @StateObject private var session: SwiftChatSession

    init(apiKey: String) {
        let provider = OpenAIResponsesProvider(
            configuration: OpenAIProviderConfiguration(apiKey: apiKey)
        )
        _session = StateObject(
            wrappedValue: SwiftChatSession(
                provider: provider,
                configuration: SwiftChatConfiguration(),
                store: InMemoryConversationStore(),
                transcriptionProvider: provider
            )
        )
    }

    var body: some View {
        SwiftChatView(session: session)
    }
}
```

Do not hard-code or commit the API key. The host application owns credential
collection and secure storage.

## UI-only integration

`SwiftChatUI` does not import OpenAI:

```swift
import SwiftChatCore
import SwiftChatUI

let provider = MockSwiftChatProvider(
    events: [.outputTextDelta("Hello"), .completed]
)
let session = SwiftChatSession(provider: provider)

SwiftChatView(session: session)
```

Implement `SwiftChatProvider` to connect another backend. A provider maps its
native streamed response to `SwiftChatEvent`. Audio transcription is optional
and is provided separately through `SwiftChatTranscriptionProvider`.

## Embedded and inspector presentation

The root view is embedded by default and does not add a Done button, sheet,
sidebar wrapper, or dismissal behavior owned by the host.

```swift
SwiftChatView(session: session)

.inspector {
    SwiftChatView(session: session)
        .inspectorColumnWidth(min: 320, ideal: 420, max: 560)
}
```

Set `SwiftChatConfiguration.presentationStyle` to communicate host intent. The
host remains responsible for applying `.sheet`, `.fullScreenCover`, or
`.inspector`.

## Host context

```swift
let context = SwiftChatHostContext(
    title: "Current note",
    selectedText: selection,
    surroundingText: documentText,
    sourceIdentifier: noteID,
    metadata: ["workspace": workspaceID]
)

let session = SwiftChatSession(
    provider: provider,
    context: context
)
```

The OpenAI adapter appends the context to the system instructions. Custom
providers receive it unchanged on `SwiftChatRequest`.

## Custom storage

Implement `SwiftChatConversationStore`:

```swift
public actor MyStore: SwiftChatConversationStore {
    public func conversations() async throws -> [Chat] { /* ... */ }
    public func save(_ conversation: Chat) async throws { /* ... */ }
    public func delete(id: Chat.ID) async throws { /* ... */ }
}
```

`InMemoryConversationStore` is provided for previews, tests, and ephemeral
sessions. Upstream did not contain durable persistence, so the default preserves
that behavior.

## Theme

```swift
SwiftChatView(
    session: session,
    theme: SwiftChatTheme(
        accentColor: .purple,
        backgroundColor: .clear
    )
)
```

The default theme preserves the upstream colors and layout.

## Tools

`SwiftChatToolCall`, `SwiftChatToolResult`, and `SwiftChatToolExecutor` provide
provider-neutral host contracts. Upstream only rendered the Responses API web
search tool and did not expose a generic tool-card builder. Hosts may render
their own tool status or result card alongside SwiftChat without coupling the
package to application-specific tools.

## Access-control policy

Only integration types, models, protocols, and the root session/view are
public. The original rendering subviews, table coordinators, chunk caches,
platform wrappers, and other implementation details remain internal.
