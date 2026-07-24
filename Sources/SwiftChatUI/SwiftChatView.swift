#if canImport(UIKit)
import SwiftUI
import SwiftChatCore

public typealias SwiftChatSession = ChatViewModel

public struct SwiftChatTheme {
    public var accentColor: Color
    public var backgroundColor: Color
    public var cornerRadius: CGFloat
    public var spacing: CGFloat

    public init(
        accentColor: Color = Color(red: 16 / 255, green: 185 / 255, blue: 129 / 255),
        backgroundColor: Color = .clear,
        cornerRadius: CGFloat = 12,
        spacing: CGFloat = 12
    ) {
        self.accentColor = accentColor
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.spacing = spacing
    }

    public static let `default` = SwiftChatTheme()
}

public struct SwiftChatView: View {
    @ObservedObject private var session: SwiftChatSession
    private let theme: SwiftChatTheme

    public init(
        session: SwiftChatSession,
        theme: SwiftChatTheme = .default
    ) {
        self.session = session
        self.theme = theme
    }

    public init(
        provider: any SwiftChatProvider,
        configuration: SwiftChatConfiguration = SwiftChatConfiguration(),
        store: any SwiftChatConversationStore = InMemoryConversationStore(),
        context: SwiftChatHostContext? = nil,
        transcriptionProvider: (any SwiftChatTranscriptionProvider)? = nil,
        theme: SwiftChatTheme = .default
    ) {
        session = SwiftChatSession(
            provider: provider,
            configuration: configuration,
            store: store,
            context: context,
            transcriptionProvider: transcriptionProvider
        )
        self.theme = theme
    }

    public var body: some View {
        ChatContainer()
            .environmentObject(session)
            .tint(theme.accentColor)
            .background(theme.backgroundColor)
    }
}

enum SwiftChatResources {
    static let bundle = Bundle.module
}
#endif
