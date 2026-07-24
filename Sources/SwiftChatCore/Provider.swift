import Foundation

public struct SwiftChatRequest: Sendable {
    public let conversationID: Chat.ID
    public let model: ModelType
    public let messages: [Message]
    public let systemPrompt: String
    public let rules: String
    public let maxMessages: Int
    public let webSearchEnabled: Bool
    public let hostContext: SwiftChatHostContext?

    public init(
        conversationID: Chat.ID,
        model: ModelType,
        messages: [Message],
        systemPrompt: String,
        rules: String = "",
        maxMessages: Int = 75,
        webSearchEnabled: Bool = false,
        hostContext: SwiftChatHostContext? = nil
    ) {
        self.conversationID = conversationID
        self.model = model
        self.messages = messages
        self.systemPrompt = systemPrompt
        self.rules = rules
        self.maxMessages = maxMessages
        self.webSearchEnabled = webSearchEnabled
        self.hostContext = hostContext
    }
}

public enum SwiftChatEvent: Sendable, Equatable {
    case outputTextDelta(String)
    case reasoningDelta(String)
    case citation(WebSearchSource)
    case webSearchStarted
    case webSearchCompleted
    case completed
}

public protocol SwiftChatProvider: Sendable {
    func stream(
        request: SwiftChatRequest
    ) -> AsyncThrowingStream<SwiftChatEvent, Error>
}

public protocol SwiftChatTranscriptionProvider: Sendable {
    func transcribe(audio: Data, fileExtension: String) async throws -> String
}

public protocol SwiftChatCredentialProvider: Sendable {
    func credential(for provider: SwiftChatProviderID) async throws -> String
}

public struct SwiftChatProviderID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let openAI = SwiftChatProviderID(rawValue: "openai")
}

public enum SwiftChatProviderError: LocalizedError, Sendable, Equatable {
    case authentication
    case rateLimited
    case modelNotFound
    case invalidRequest(String)
    case server(statusCode: Int)
    case transport(String)
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case .authentication:
            return "Invalid API key. Please check your key and try again."
        case .rateLimited:
            return "Rate limit exceeded. Please wait a moment and try again."
        case .modelNotFound:
            return "Model not found. The selected model may not be available."
        case .invalidRequest(let message):
            return message
        case .server:
            return "The server encountered an error. Please try again later."
        case .transport(let message), .unsupported(let message):
            return message
        }
    }
}

public struct MockSwiftChatProvider: SwiftChatProvider {
    public var events: [SwiftChatEvent]

    public init(events: [SwiftChatEvent]) {
        self.events = events
    }

    public func stream(
        request: SwiftChatRequest
    ) -> AsyncThrowingStream<SwiftChatEvent, Error> {
        AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }
}
