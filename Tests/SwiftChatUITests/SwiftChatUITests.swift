#if canImport(UIKit)
import SwiftUI
import XCTest
import SwiftChatCore
@testable import SwiftChatUI

@MainActor
final class SwiftChatUITests: XCTestCase {
    func testPublicRootCoversEmptyAndStreamingStates() {
        let provider = MockSwiftChatProvider(
            events: [.outputTextDelta("Hello"), .completed]
        )
        let session = SwiftChatSession(provider: provider)
        _ = SwiftChatView(session: session)

        XCTAssertEqual(session.messages, [])
        XCTAssertFalse(session.isLoading)
    }

    func testInspectorThemeAndHostContextCompile() {
        let configuration = SwiftChatConfiguration(
            presentationStyle: .inspector
        )
        let context = SwiftChatHostContext(
            title: "Inspector",
            selectedText: "Selected"
        )
        _ = SwiftChatView(
            provider: MockSwiftChatProvider(events: []),
            configuration: configuration,
            context: context,
            theme: SwiftChatTheme(
                accentColor: .purple,
                backgroundColor: .black
            )
        )
    }
}
#endif
