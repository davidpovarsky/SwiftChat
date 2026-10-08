#if canImport(UIKit)
import XCTest
import SwiftChat

@MainActor
final class SwiftChatPublicAPITests: XCTestCase {
    func testUmbrellaImportCompilesDocumentedUsage() {
        let provider = MockSwiftChatProvider(
            events: [.outputTextDelta("Hello"), .completed]
        )
        let session = SwiftChatSession(
            provider: provider,
            configuration: SwiftChatConfiguration(
                presentationStyle: .embedded
            ),
            store: InMemoryConversationStore(),
            context: SwiftChatHostContext(title: "Host")
        )
        _ = SwiftChatView(session: session)
    }
}
#endif
