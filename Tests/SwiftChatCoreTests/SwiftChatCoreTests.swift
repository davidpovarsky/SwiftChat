import XCTest
@testable import SwiftChatCore

final class SwiftChatCoreTests: XCTestCase {
    private let model = ModelType(
        id: "test-model",
        displayName: "Test",
        fullName: "Test Model",
        isMultimodal: true
    )

    func testConversationMutationAndMessageOrdering() {
        var chat = Chat(modelType: model)
        let first = Message(role: .user, content: "First")
        let second = Message(role: .assistant, content: "Second")

        chat.messages.append(first)
        chat.messages.append(second)
        chat.title = "A title"
        chat.titleState = .manual

        XCTAssertEqual(chat.messages.map(\.id), [first.id, second.id])
        XCTAssertEqual(chat.titleState, .manual)
        XCTAssertFalse(chat.isBlankChat)
    }

    func testStreamingEventReduction() {
        let chunker = StreamingMarkdownChunker()
        chunker.appendToken("A paragraph")
        chunker.appendToken("\n\n")
        chunker.appendToken("```swift\nlet value = 1\n```")
        chunker.finalize()

        let chunks = chunker.getAllChunks()
        XCTAssertEqual(chunks.first?.content, "A paragraph")
        XCTAssertTrue(chunks.contains { chunk in
            if case .codeBlock = chunk.type { return true }
            return false
        })
    }

    func testReasoningAccumulation() {
        let chunker = ThinkingTextChunker()
        chunker.appendToken("First thought.\n\n")
        chunker.appendToken("Second thought.")
        chunker.finalize()

        XCTAssertEqual(
            chunker.getAllChunks().map(\.content),
            ["First thought.", "Second thought."]
        )
    }

    func testCitationAccumulation() {
        var state = WebSearchState(status: .searching)
        state.sources.append(
            WebSearchSource(title: "Source", url: "https://example.com")
        )
        state.status = .completed

        XCTAssertEqual(state.sources.count, 1)
        XCTAssertEqual(state.status, .completed)
    }

    func testToolCallStateTransitions() {
        var call = SwiftChatToolCall(name: "lookup", arguments: "{}")
        XCTAssertEqual(call.state, .pending)
        call.state = .running
        XCTAssertEqual(call.state, .running)
        call.state = .success
        XCTAssertEqual(call.state, .success)
    }

    func testProviderEventsAndCancellationSurface() async throws {
        let provider = MockSwiftChatProvider(
            events: [
                .reasoningDelta("thinking"),
                .outputTextDelta("answer"),
                .completed,
            ]
        )
        let request = SwiftChatRequest(
            conversationID: "test",
            model: model,
            messages: [],
            systemPrompt: "Test"
        )
        var values: [SwiftChatEvent] = []
        for try await event in provider.stream(request: request) {
            values.append(event)
        }
        XCTAssertEqual(values.count, 3)
    }

    func testPersistenceAdapter() async throws {
        let store = InMemoryConversationStore()
        let older = Chat(id: "older", createdAt: Date(timeIntervalSince1970: 1), modelType: model)
        let newer = Chat(id: "newer", createdAt: Date(timeIntervalSince1970: 2), modelType: model)

        try await store.save(older)
        try await store.save(newer)
        let savedIDs = try await store.conversations().map(\.id)
        XCTAssertEqual(savedIDs, ["newer", "older"])

        try await store.delete(id: newer.id)
        let remainingIDs = try await store.conversations().map(\.id)
        XCTAssertEqual(remainingIDs, ["older"])
    }

    func testContextEncoding() throws {
        let context = SwiftChatHostContext(
            title: "Document",
            selectedText: "Selection",
            sourceIdentifier: "doc-1",
            metadata: ["kind": "note"]
        )
        let data = try JSONEncoder().encode(context)
        XCTAssertEqual(try JSONDecoder().decode(SwiftChatHostContext.self, from: data), context)
    }

    func testProviderErrorDescriptions() {
        XCTAssertTrue(
            SwiftChatProviderError.authentication.localizedDescription
                .localizedCaseInsensitiveContains("api key")
        )
        XCTAssertTrue(
            SwiftChatProviderError.rateLimited.localizedDescription
                .localizedCaseInsensitiveContains("rate")
        )
    }
}
